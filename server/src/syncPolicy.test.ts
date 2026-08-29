import assert from "node:assert/strict";
import test from "node:test";
import {
  decideSyncMutation,
  hasForeignSyncIdentityOwner,
  isAccountDeletedDatabaseError,
  requireOwnedSyncCursor,
  resolveSyncCursor,
  usesDurableSyncMutations,
  usesStrictSyncVersioning
} from "./syncPolicy.js";

test("only sync protocol v3 and newer use strict server versions", () => {
  assert.equal(usesStrictSyncVersioning(undefined), false);
  assert.equal(usesStrictSyncVersioning(2), false);
  assert.equal(usesStrictSyncVersioning(3), true);
  assert.equal(usesDurableSyncMutations(3), false);
  assert.equal(usesDurableSyncMutations(4), true);
});

test("database trigger account-deletion errors are recognized without matching unrelated failures", () => {
  assert.equal(isAccountDeletedDatabaseError(new Error("sync.account_deleted")), true);
  assert.equal(isAccountDeletedDatabaseError({ meta: { database_error: "ERROR: sync.account_deleted" } }), true);
  assert.equal(isAccountDeletedDatabaseError({ code: "P2010", message: "other raw query failure" }), false);
});

test("protocol v4 recovers only the exact mutation whose acknowledgement was lost", () => {
  const common = {
    protocolVersion: 4,
    hasExisting: true,
    baseVersion: 3,
    serverVersion: 4,
    serverMutationId: "mutation-a1"
  };

  assert.equal(decideSyncMutation({
    ...common,
    mutationId: "mutation-a1",
    previousMutationId: "mutation-before-a1"
  }), "idempotent");
  assert.equal(decideSyncMutation({
    ...common,
    mutationId: "mutation-a2",
    previousMutationId: "mutation-a1"
  }), "apply");
  assert.equal(decideSyncMutation({
    ...common,
    serverVersion: 5,
    serverMutationId: "mutation-ios-b",
    mutationId: "mutation-a2",
    previousMutationId: "mutation-a1"
  }), "conflict");
});

test("protocol v4 accepts an exact base, rejects missing mutation identity, and creates new rows", () => {
  assert.equal(decideSyncMutation({
    protocolVersion: 4,
    hasExisting: true,
    baseVersion: 5,
    serverVersion: 5,
    mutationId: "mutation-next",
    serverMutationId: "mutation-current"
  }), "apply");
  assert.equal(decideSyncMutation({
    protocolVersion: 4,
    hasExisting: true,
    baseVersion: 5,
    serverVersion: 5
  }), "conflict");
  assert.equal(decideSyncMutation({
    protocolVersion: 4,
    hasExisting: false,
    baseVersion: 0,
    mutationId: "mutation-new"
  }), "apply");
});

test("protocol v4 recovers a newly created note or tag whose first acknowledgement was lost", () => {
  assert.equal(decideSyncMutation({
    protocolVersion: 4,
    hasExisting: true,
    baseVersion: null,
    serverVersion: 1,
    mutationId: "new-local-edit-2",
    previousMutationId: "new-local-edit-1",
    serverMutationId: "new-local-edit-1"
  }), "apply");
  assert.equal(decideSyncMutation({
    protocolVersion: 4,
    hasExisting: true,
    baseVersion: 0,
    serverVersion: 1,
    mutationId: "new-local-tag-edit-2",
    previousMutationId: "new-local-tag-edit-1",
    serverMutationId: "new-local-tag-edit-1"
  }), "apply");
});

test("legacy clients keep last-write-wins while v3 requires an exact base version", () => {
  assert.equal(decideSyncMutation({ protocolVersion: 2, hasExisting: true, baseVersion: 4, serverVersion: 5 }), "apply");
  assert.equal(decideSyncMutation({ protocolVersion: 3, hasExisting: true, baseVersion: 5, serverVersion: 5 }), "apply");
  assert.equal(decideSyncMutation({ protocolVersion: 3, hasExisting: true, baseVersion: 4, serverVersion: 5 }), "conflict");
  assert.equal(decideSyncMutation({ protocolVersion: 3, hasExisting: true, serverVersion: 5 }), "conflict");
  assert.equal(decideSyncMutation({ protocolVersion: 3, hasExisting: false, serverVersion: 0 }), "apply");
});

test("hard delete and persisted tombstones take precedence over uploads", () => {
  assert.equal(decideSyncMutation({ protocolVersion: 3, hardDeleteRequested: true, hasTombstone: true }), "hard_delete");
  assert.equal(decideSyncMutation({ protocolVersion: 2, hasTombstone: true }), "tombstoned");
  assert.equal(decideSyncMutation({ protocolVersion: 3, hasTombstone: true, baseVersion: 99, serverVersion: 99 }), "tombstoned");
});

test("invalid and future cursors bootstrap for every protocol", () => {
  assert.equal(resolveSyncCursor("12", 3, 12), 12);
  assert.equal(resolveSyncCursor("13", 3, 12), null);
  assert.equal(resolveSyncCursor("-1", 3, 12), null);
  assert.equal(resolveSyncCursor("1.5", 3, 12), null);
  assert.equal(resolveSyncCursor("not-a-cursor", 3, 12), null);
  assert.equal(resolveSyncCursor("13", 2, 12), null);
  assert.equal(resolveSyncCursor("-1", undefined, 12), null);
  assert.equal(resolveSyncCursor("1.5", undefined, 12), null);
  assert.equal(resolveSyncCursor("not-a-cursor", 2, 12), null);
});

test("a global cursor from another user bootstraps even when below this user's max", () => {
  const otherUsersGlobalCursor = resolveSyncCursor("100", 2, 200);
  assert.equal(otherUsersGlobalCursor, 100);
  assert.equal(requireOwnedSyncCursor(otherUsersGlobalCursor, false), null);
  assert.equal(requireOwnedSyncCursor(otherUsersGlobalCursor, true), 100);
  assert.equal(requireOwnedSyncCursor(0, false), 0);
});

test("a logical sync ID is unavailable when any live row or tombstone has another owner", () => {
  assert.equal(hasForeignSyncIdentityOwner("user-a", []), false);
  assert.equal(hasForeignSyncIdentityOwner("user-a", ["user-a"]), false);
  assert.equal(hasForeignSyncIdentityOwner("user-a", ["user-a", "user-b"]), true);
});
