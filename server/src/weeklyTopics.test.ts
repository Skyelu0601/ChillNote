import assert from "node:assert/strict";
import test from "node:test";
import {
  annotateSourceAvailability,
  scrubDeletedSourceSnapshots
} from "./weeklyTopics.js";
import { isProSubscriptionActive } from "./store.js";

const reportTopics = [{
  id: "topic-1",
  title: "A post idea",
  sources: [{
    noteId: "note-1",
    noteTitle: "Private source title",
    platformName: "YouTube",
    excerpt: "Private source excerpt"
  }]
}];

test("marks a soft-deleted source as trashed without losing its snapshot", () => {
  const result = annotateSourceAvailability(
    reportTopics,
    new Map([["note-1", "trashed"]])
  ) as typeof reportTopics & { availability?: string }[];

  assert.equal(result[0].sources[0].noteTitle, "Private source title");
  assert.equal(result[0].sources[0].excerpt, "Private source excerpt");
  assert.equal((result[0].sources[0] as any).availability, "trashed");
});

test("hides a missing source snapshot from API responses", () => {
  const result = annotateSourceAvailability(reportTopics, new Map()) as any[];
  const source = result[0].sources[0];

  assert.equal(source.availability, "deleted");
  assert.equal(source.noteTitle, "");
  assert.equal(source.platformName, null);
  assert.equal(source.excerpt, "");
});

test("scrubs persisted snapshots when a note is permanently deleted", () => {
  const result = scrubDeletedSourceSnapshots(reportTopics, "note-1");
  const source = (result.topics as any[])[0].sources[0];

  assert.equal(result.changed, true);
  assert.equal(source.noteId, "note-1");
  assert.equal(source.availability, "deleted");
  assert.equal(source.noteTitle, "");
  assert.equal(source.platformName, null);
  assert.equal(source.excerpt, "");
});

test("does not rewrite reports that do not reference the deleted note", () => {
  const result = scrubDeletedSourceSnapshots(reportTopics, "another-note");

  assert.equal(result.changed, false);
  assert.deepEqual(result.topics, reportTopics);
});

test("recognizes only an active Pro subscription", () => {
  const now = new Date("2026-08-02T12:00:00Z");

  assert.equal(isProSubscriptionActive("pro", null, now), true);
  assert.equal(
    isProSubscriptionActive("pro", new Date("2026-08-03T12:00:00Z"), now),
    true
  );
  assert.equal(
    isProSubscriptionActive("pro", new Date("2026-08-02T12:00:00Z"), now),
    false
  );
  assert.equal(isProSubscriptionActive("free", null, now), false);
});
