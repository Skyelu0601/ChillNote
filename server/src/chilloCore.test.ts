import assert from "node:assert/strict";
import test from "node:test";
import { chilloRequest, chilloScope, contentHash, finalizeCitations, lexicalScore, normalizeEmbedding, parseSources, similarity, sourceAvailability, splitNote, stripCitations, tokens, type SourceNote } from "./chilloCore.js";

const content = "A saved note about thoughtful creation.";
const note: SourceNote = { id: "note", content, deletedAt: null, importStatus: null, sourceTitle: null, sourcePlatformName: null, sourceURL: null, section: "inbox", updatedAt: new Date() };
const ref = { number: 1, noteId: note.id, hash: contentHash(content), start: 0, end: content.length };

test("turn requests canonicalize UUIDs and reject empty/oversized messages", () => {
  const id = "A76BC912-8371-4BD0-9680-5288257C2921";
  assert.equal(chilloRequest.parse({ id, message: " hi " }).id, id.toLowerCase());
  assert.equal(chilloRequest.parse({ id, message: " hi " }).message, "hi");
  for (const message of [" ", "x".repeat(16001)]) assert.equal(chilloRequest.safeParse({ id, message }).success, false);
  assert.equal(chilloRequest.safeParse({ id: "../another-account", message: "hi" }).success, false);
});
test("scope bounds prevent unbounded account lookups", () => {
  assert.equal(chilloScope.safeParse({ pinnedIds: Array(21).fill("n"), excludedIds: [] }).success, false);
  assert.equal(chilloScope.safeParse({ pinnedIds: [], excludedIds: Array(201).fill("n") }).success, false);
});
test("long notes retain exact source offsets beyond the old prompt cutoff", () => {
  const long = "first paragraph\n".repeat(1000) + "late rare insight";
  const chunks = splitNote(long);
  assert.ok(chunks.length > 8);
  assert.ok(chunks.at(-1)!.text.endsWith("late rare insight"));
  for (const chunk of chunks) { assert.equal(chunk.text, long.slice(chunk.start, chunk.end)); assert.ok(chunk.text.length <= 1600); }
  for (let i = 1; i < chunks.length; i++) assert.ok(chunks[i].start < chunks[i - 1].end);
});
test("text retrieval supports Chinese phrases and normalized Latin text", () => {
  assert.ok(tokens("寻找创作素材").includes("创作"));
  assert.ok(lexicalScore("创作素材", "这里有适合创作的素材") > 0);
  assert.ok(lexicalScore("CREATION", "creation") > lexicalScore("creation", "unrelated"));
});
test("embeddings are normalized and invalid dimensions do not match", () => {
  const vector = normalizeEmbedding([3, 4]);
  assert.ok(Math.abs(similarity(vector, vector) - 1) < 1e-9);
  assert.equal(similarity(vector, [1]), 0);
  for (const invalid of [[], [0, 0], [NaN, 1], [Infinity, 1]]) assert.throws(() => normalizeEmbedding(invalid));
});
test("source changes, pending imports, soft and hard deletion never expose stale excerpts", () => {
  assert.equal(sourceAvailability(ref, note), "active");
  assert.equal(sourceAvailability(ref, { ...note, content: "replacement" }), "changed");
  assert.equal(sourceAvailability(ref, { ...note, deletedAt: new Date() }), "unavailable");
  assert.equal(sourceAvailability(ref, { ...note, importStatus: "processing" }), "unavailable");
  assert.equal(sourceAvailability(ref), "unavailable");
  assert.equal(sourceAvailability({ ...ref, end: content.length + 1 }, note), "changed");
});
test("unknown citations are removed and unused sources are not presented as evidence", () => {
  const finalized = finalizeCitations("A fact [1]. Fiction [999].", [ref, { ...ref, number: 2 }]);
  assert.equal(finalized.answer, "A fact. Fiction.");
  assert.deepEqual(finalized.sources, [ref]);
  assert.deepEqual(parseSources({ bogus: true }), []);
  assert.deepEqual(parseSources([{ ...ref, start: -1 }]), []);
});

test("internal citation links are normalized before answers are persisted", () => {
  const finalized = finalizeCitations("A fact [1](chillo-source://1).", [ref]);
  assert.equal(finalized.answer, "A fact.");
  assert.deepEqual(finalized.sources, [ref]);
});

test("grouped citations retain only real sources and map every displayed number", () => {
  const third = { ...ref, number: 3, noteId: "note-3" };
  const finalized = finalizeCitations("Supported [1, 3, 999].", [ref, third]);
  assert.equal(finalized.answer, "Supported.");
  assert.deepEqual(finalized.sources, [ref, third]);
  assert.equal(stripCitations("Draft [1, 3] and [2]."), "Draft and.");
});
