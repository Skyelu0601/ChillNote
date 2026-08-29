import assert from "node:assert/strict";
import test from "node:test";
import { normalizeNewSyncEntityId, pickLatestBySyncIdentity, syncIdentityKey } from "./syncIdentity.js";

test("UUID sync identity ignores letter casing", () => {
  const lower = "123e4567-e89b-42d3-a456-426614174000";
  const upper = lower.toUpperCase();

  assert.equal(syncIdentityKey(upper), lower);
  assert.equal(normalizeNewSyncEntityId(upper), lower);
});

test("legacy non-UUID IDs remain case-sensitive", () => {
  assert.equal(syncIdentityKey("Note-A"), "Note-A");
  assert.notEqual(syncIdentityKey("Note-A"), syncIdentityKey("note-a"));
});

test("case variants are deduplicated using the newest item", () => {
  const lower = "123e4567-e89b-42d3-a456-426614174000";
  const upper = lower.toUpperCase();
  const result = pickLatestBySyncIdentity(
    [{ id: lower, time: 1 }, { id: upper, time: 2 }],
    (item) => item.time
  );

  assert.equal(result.size, 1);
  assert.equal(result.get(lower)?.id, upper);
});
