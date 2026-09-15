// Run from server/ with its configured environment. All fixture writes are
// rolled back; no real account, import worker or external provider is invoked.
// Optional argument: absolute path to a staged sync.js before deployment.
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import dotenv from "dotenv";

dotenv.config();
const moduleURL = pathToFileURL(resolve(process.argv[2] ?? "dist/sync.js"));
const { applySync } = await import(moduleURL.href);
const { prisma } = await import(new URL("./db.js", moduleURL).href);
const { acquireUserSyncTransactionLock, getChangesSinceCursor, getLatestSyncLogId } =
  await import(new URL("./store.js", moduleURL).href);
const rollback = new Error("ROLLBACK_IMPORT_SYNC_VERIFICATION");
const userId = randomUUID();
let checks = 0;

try {
  try {
    await prisma.$transaction(async (tx) => {
      await tx.$executeRawUnsafe("SET LOCAL statement_timeout = '15000ms'");
      await acquireUserSyncTransactionLock(userId, tx);
      await tx.user.create({ data: { id: userId, welcomeNotificationEligible: false } });
      for (const protocolVersion of [2, 3, 4]) {
        const noteId = randomUUID();
        const jobId = randomUUID();
        const now = new Date();
        const content = "Synthetic import placeholder";
        const sourceURL = "https://example.invalid/import-verification";
        await tx.note.create({ data: {
          id: noteId, userId, content, sourceURL, section: "inbox",
          createdAt: now, updatedAt: now, version: 7, importStatus: "queued", importJobId: jobId,
          lastMutationId: randomUUID()
        } });
        await tx.linkImportJob.create({ data: {
          id: jobId, userId, noteId, url: sourceURL, status: "queued"
        } });
        const incoming = {
          id: noteId, content, sourceURL, section: "inbox", createdAt: now.toISOString(),
          importStatus: "queued", importJobId: jobId, importStartedAt: now.toISOString(),
          baseVersion: 0, mutationId: randomUUID(), tagIds: []
        };
        async function sync(note) {
          const cursor = String(await getLatestSyncLogId(userId, tx));
          const applied = await applySync({ protocolVersion, notes: [note], tags: [] }, userId, tx);
          const downloaded = await getChangesSinceCursor(userId, cursor, tx, { protocolVersion, ...applied });
          return { ...applied, ...downloaded };
        }

        for (const status of ["queued", "processing", "completed", "failed"]) {
          const resultContent = ["completed", "failed"].includes(status) ? "Synthetic terminal result" : content;
          await tx.note.update({ where: { id: noteId }, data: { importStatus: status, content: resultContent } });
          const response = await sync(incoming);
          assert.deepEqual(response.conflicts, []);
          assert.deepEqual(response.forcedNoteIds, [noteId]);
          assert.equal(response.changes.notes[0].content, resultContent);
          assert.equal(response.changes.notes[0].importStatus, status);
          assert.equal(response.changes.notes[0].version, 7);
          checks++;
        }
        await tx.note.update({ where: { id: noteId }, data: { importStatus: "processing", content } });
        const earlyResponse = await sync({ ...incoming, importJobId: undefined });
        assert.deepEqual(earlyResponse.conflicts, []);
        assert.deepEqual(earlyResponse.forcedNoteIds, [noteId]);
        checks++;

        const cloneId = randomUUID();
        const cloneUpload = { ...incoming, id: cloneId, section: "drafts", content: "Synthetic user idea", mutationId: randomUUID() };
        const cloneResponse = await sync(cloneUpload);
        assert.deepEqual(cloneResponse.conflicts, []);
        assert.deepEqual(cloneResponse.forcedNoteIds, [cloneId]);
        const clone = await tx.note.findUniqueOrThrow({ where: { id: cloneId } });
        assert.equal(clone.content, cloneUpload.content);
        assert.equal(clone.section, "drafts");
        for (const field of ["importStatus", "importJobId", "importErrorCode", "importStartedAt", "importCompletedAt"]) {
          assert.equal(clone[field], null);
          assert.equal(cloneResponse.changes.notes[0][field], null);
        }
        assert.equal((await tx.linkImportJob.findUniqueOrThrow({ where: { id: jobId } })).noteId, noteId);
        checks++;
        const retry = await sync(cloneUpload);
        assert.deepEqual(retry.conflicts, []);
        assert.deepEqual(retry.forcedNoteIds, [cloneId]);
        assert.equal((await tx.note.findUniqueOrThrow({ where: { id: cloneId } })).version, 1);
        checks++;

        if (protocolVersion >= 3) {
          const edited = await sync({ ...incoming, content: "Synthetic concurrent edit" });
          assert.equal(edited.conflicts[0]?.message, "sync.conflict.version");
          assert.equal((await tx.note.findUniqueOrThrow({ where: { id: noteId } })).content, content);
          checks++;
        }
      }
      throw rollback;
    }, { maxWait: 10000, timeout: 90000 });
  } catch (error) {
    if (error !== rollback) throw error;
  }
  const remaining = await Promise.all([
    prisma.user.count({ where: { id: userId } }),
    prisma.note.count({ where: { userId } }),
    prisma.linkImportJob.count({ where: { userId } }),
    prisma.syncLog.count({ where: { userId } })
  ]);
  assert.deepEqual(remaining, [0, 0, 0, 0]);
  console.log(JSON.stringify({ ok: true, checks, rolledBack: true, remainingFixtureRows: 0 }));
} finally {
  await prisma.$disconnect();
}
