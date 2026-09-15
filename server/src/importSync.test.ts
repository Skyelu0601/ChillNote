import assert from "node:assert/strict";
import test from "node:test";
import type { Note } from "@prisma/client";
import { applySync } from "./sync.js";
import { getChangesSinceCursor, type SyncDatabase } from "./store.js";
import type { NoteDTO, SyncPayload } from "./types.js";

const userId = "import-test-user";
const noteId = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const cloneId = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
const jobId = "cccccccc-cccc-4ccc-8ccc-cccccccccccc";
const tagId = "dddddddd-dddd-4ddd-8ddd-dddddddddddd";
const timestamp = new Date("2026-09-12T00:00:00Z");
type Row = Note & { tags: Array<{ id: string }> };

function row(overrides: Partial<Row> = {}): Row {
  return {
    id: noteId, userId, content: "Importing https://www.tiktok.com/@example/video/123",
    createdAt: timestamp, updatedAt: timestamp, serverUpdatedAt: timestamp,
    deletedAt: null, serverDeletedAt: null, pinnedAt: null, version: 7,
    lastModifiedByDeviceId: null, lastMutationId: "worker-mutation",
    sourceURL: "https://www.tiktok.com/@example/video/123", sourceTitle: "TikTok",
    sourcePlatformID: "tiktok", sourcePlatformName: "TikTok", sourceHost: "www.tiktok.com",
    sourceAuthorName: null, sourceAuthorHandle: null, sourceCapturedAt: timestamp,
    section: "inbox", importStatus: "processing", importJobId: jobId,
    importErrorCode: null, importStartedAt: timestamp, importCompletedAt: null,
    tags: [], ...overrides
  };
}

function upload(overrides: Partial<NoteDTO> = {}): NoteDTO {
  return {
    id: noteId, content: row().content, createdAt: timestamp.toISOString(),
    sourceURL: row().sourceURL, section: "inbox", importStatus: "queued", importJobId: jobId,
    importStartedAt: new Date(timestamp.getTime() + 1000).toISOString(),
    baseVersion: 0, mutationId: "old-client-mutation", tagIds: [], ...overrides
  };
}

// Exercise the production applySync + response assembly through their database
// boundary. These tests never connect to the configured production database.
function fixture(initial: Row[] = [row()]) {
  const notes = new Map(initial.map((note) => [note.id, structuredClone(note)]));
  const jobs = new Map([[jobId, { id: jobId, userId, noteId }]]);
  const tags = [{ id: tagId, userId, parentId: null, deletedAt: null, serverDeletedAt: null }];
  const logs: any[] = initial.map((note, i) => ({
    id: i + 1, userId, entityType: "note", entityId: note.id, version: note.version,
    operation: "upsert", serverUpdatedAt: timestamp
  }));
  const tombstones: any[] = [];
  let writes = 0;
  function matches(item: any, where: any = {}): boolean {
    return Object.entries(where).every(([key, value]: [string, any]) => {
      if (value && typeof value === "object") {
        if ("equals" in value) return String(item[key]).toLowerCase() === value.equals.toLowerCase();
        if ("in" in value) return value.in.includes(item[key]);
        return (value.gt == null || item[key] > value.gt) && (value.lte == null || item[key] <= value.lte);
      }
      return item[key] === value;
    });
  }
  function save(id: string, data: any): Row {
    writes++;
    const { tags: relations, ...values } = data;
    const saved = {
      ...notes.get(id), ...values,
      tags: relations?.set ?? relations?.connect ?? notes.get(id)?.tags ?? []
    } as Row;
    notes.set(id, saved);
    return saved;
  }
  const database = {
    note: {
      findMany: async ({ where }: any) => [...notes.values()].filter((note) => matches(note, where)),
      findFirst: async ({ where }: any) => [...notes.values()].find((note) => matches(note, where)) ?? null,
      findUnique: async ({ where }: any) => notes.get(where.id) ?? null,
      create: async ({ data }: any) => save(data.id, data),
      update: async ({ where, data }: any) => save(where.id, data)
    },
    tag: {
      findMany: async ({ where }: any) => tags.filter((tag) => matches(tag, where)),
      findFirst: async ({ where }: any) => tags.find((tag) => matches(tag, where)) ?? null
    },
    linkImportJob: {
      findFirst: async ({ where }: any) => [...jobs.values()].find((job) => matches(job, where)) ?? null
    },
    hardDeleteTombstone: {
      findMany: async ({ where }: any) => tombstones.filter((item) => matches(item, where))
    },
    syncLog: {
      aggregate: async ({ where }: any) => ({ _max: { id: Math.max(0, ...logs.filter((item) => matches(item, where)).map((item) => item.id)) } }),
      create: async ({ data }: any) => { logs.push({ ...data, id: logs.length + 1 }); },
      findFirst: async ({ where }: any) => [...logs].reverse().find((item) => matches(item, where)) ?? null,
      findMany: async ({ where }: any) => logs.filter((item) => matches(item, where))
    }
  } as unknown as SyncDatabase;
  async function sync(note: NoteDTO, protocolVersion = 4) {
    const payload: SyncPayload = { protocolVersion, deviceId: "old-mobile", notes: [note], tags: [] };
    const cursor = String(logs.length);
    const applied = await applySync(payload, userId, database);
    const response = await getChangesSinceCursor(userId, cursor, database, { protocolVersion, ...applied });
    return { ...applied, ...response };
  }
  return { sync, notes, jobs, tombstones, logs, get writes() { return writes; } };
}

for (const protocol of [2, 3, 4]) {
  test(`v${protocol}: pending share/enqueue races return the canonical row without a clone-triggering conflict`, async () => {
    for (const status of ["queued", "processing"]) {
      for (const incomingJob of [jobId, undefined, ""]) {
        const db = fixture([row({ importStatus: status })]);
        const response = await db.sync(upload({ importJobId: incomingJob }), protocol);
        assert.deepEqual(response.conflicts, []);
        assert.deepEqual(response.forcedNoteIds, [noteId]);
        assert.equal(response.changes.notes.length, 1, "forced row is returned even at the latest cursor");
        assert.equal(response.changes.notes[0].importStatus, status);
        assert.equal(response.changes.notes[0].version, 7);
        assert.equal(db.writes, 0);
      }
    }
  });

  test(`v${protocol}: success and failure remain authoritative over stale queued uploads`, async () => {
    for (const status of ["completed", "failed"]) {
      const db = fixture([row({ content: "Server result", importStatus: status, importCompletedAt: timestamp })]);
      const response = await db.sync(upload(), protocol);
      assert.deepEqual(response.conflicts, []);
      assert.deepEqual(response.forcedNoteIds, [noteId]);
      assert.equal(response.changes.notes[0].content, "Server result");
      assert.equal(response.changes.notes[0].importStatus, status);
      assert.equal(db.writes, 0);
    }
  });

  test(`v${protocol}: an old-client conflict copy keeps its text but cannot inherit another note's job`, async () => {
    const db = fixture();
    const incoming = upload({ id: cloneId, content: "My unsaved idea", section: "drafts", tagIds: [tagId] });
    const response = await db.sync(incoming, protocol);
    const clone = db.notes.get(cloneId)!;
    assert.equal(clone.content, incoming.content);
    assert.equal(clone.section, "drafts");
    assert.deepEqual(clone.tags, [{ id: tagId }]);
    for (const field of ["importStatus", "importJobId", "importErrorCode", "importStartedAt", "importCompletedAt"] as const) {
      assert.equal(clone[field], null);
    }
    assert.equal(db.notes.get(noteId)?.importStatus, "processing");
    assert.equal(db.jobs.get(jobId)?.noteId, noteId);
    assert.deepEqual(response.conflicts, []);
    assert.deepEqual(response.forcedNoteIds, [cloneId]);
    assert.equal(response.changes.notes[0].importJobId, null);

    const retry = await db.sync(incoming, protocol);
    assert.deepEqual(retry.conflicts, [], "lost normalization ACK must not create another copy");
    assert.deepEqual(retry.forcedNoteIds, [cloneId]);
    assert.equal(db.writes, 1);
  });
}

test("real text, tag, location, pin and delete changes retain optimistic conflict protection", async () => {
  for (const changes of [
    { content: "My real edit" }, { tagIds: [tagId] }, { section: "drafts" },
    { pinnedAt: timestamp.toISOString() }, { deletedAt: timestamp.toISOString() },
    { sourceURL: "https://www.youtube.com/watch?v=other" }
  ]) {
    const db = fixture();
    const response = await db.sync(upload(changes));
    assert.equal(response.conflicts[0]?.message, "sync.conflict.version");
    assert.equal(db.writes, 0);
  }
});

test("a valid-base user edit or deletion is still applied to a pending import", async () => {
  for (const changes of [{ content: "My real edit" }, { deletedAt: timestamp.toISOString() }]) {
    const db = fixture();
    const response = await db.sync(upload({ baseVersion: 7, ...changes }));
    assert.deepEqual(response.conflicts, []);
    assert.equal(db.writes, 1);
    const saved = db.notes.get(noteId)!;
    if (changes.content) assert.equal(saved.content, changes.content);
    if (changes.deletedAt) assert.ok(saved.deletedAt);
    assert.equal(saved.importJobId, jobId);
  }
});

test("a newer edit made after detachment cannot be erased by a stale retry", async () => {
  const db = fixture();
  const incoming = upload({ id: cloneId, section: "drafts" });
  await db.sync(incoming);
  db.notes.get(cloneId)!.content = "Newer saved idea";
  db.notes.get(cloneId)!.lastMutationId = "different-device";
  const response = await db.sync(incoming, 3);
  assert.equal(response.conflicts[0]?.message, "sync.conflict.version");
  assert.equal(db.notes.get(cloneId)?.content, "Newer saved idea");
});

test("unknown and foreign-account job references cannot leave a new note spinning", async () => {
  for (const foreign of [false, true]) {
    const db = fixture();
    if (foreign) db.jobs.get(jobId)!.userId = "another-user";
    else db.jobs.clear();
    const response = await db.sync(upload({ id: cloneId, section: "drafts" }));
    assert.deepEqual(response.conflicts, []);
    assert.equal(db.notes.get(cloneId)?.importStatus, null);
    assert.equal(db.notes.get(cloneId)?.content, upload().content);
  }
});

test("new placeholders without an enqueue acknowledgement are not detached", async () => {
  const db = fixture([]);
  await db.sync(upload({ importJobId: undefined }));
  assert.equal(db.notes.get(noteId)?.importStatus, "queued");
});

test("UUID case and omitted tags retain the same pending import identity", async () => {
  const db = fixture([row({ tags: [{ id: tagId }] })]);
  const response = await db.sync(upload({ id: noteId.toUpperCase(), importJobId: jobId.toUpperCase(), tagIds: undefined }));
  assert.deepEqual(response.conflicts, []);
  assert.deepEqual(response.forcedNoteIds, [noteId]);
  assert.deepEqual(response.changes.notes[0].tagIds, [tagId]);
  assert.equal(db.writes, 0);
});

test("a tombstone wins over pending-import authority and does not recreate the note", async () => {
  const db = fixture([]);
  db.tombstones.push({ userId, entityType: "note", entityId: noteId, deletedAt: timestamp });
  const response = await db.sync(upload());
  assert.equal(response.conflicts[0]?.message, "sync.conflict.hard_deleted");
  assert.deepEqual(response.forcedHardDeletedNoteIds, [noteId]);
  assert.equal(db.notes.size, 0);
});
