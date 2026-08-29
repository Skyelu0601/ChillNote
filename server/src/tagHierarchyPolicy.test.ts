import assert from "node:assert/strict";
import test from "node:test";
import { sanitizeTagParentChanges } from "./tagHierarchyPolicy.js";

function sanitized(current: Array<[string, string | null]>, proposed: Array<[string, string | null]>) {
  return sanitizeTagParentChanges(
    current.map(([id, parentId]) => ({ id, parentId })),
    proposed.map(([id, parentId]) => ({ id, parentId }))
  );
}

test("self-parent and same-batch two/three-node cycles are broken deterministically", () => {
  const self = sanitized([["a", null]], [["a", "a"]]);
  assert.equal(self.parentByTagId.get("a"), null);
  assert.deepEqual([...self.adjustedTagIds], ["a"]);

  const two = sanitized([["a", null], ["b", null]], [["a", "b"], ["b", "a"]]);
  assert.equal(two.parentByTagId.get("a"), "b");
  assert.equal(two.parentByTagId.get("b"), null);

  const three = sanitized(
    [["a", null], ["b", null], ["c", null]],
    [["a", "b"], ["b", "c"], ["c", "a"]]
  );
  assert.equal(three.parentByTagId.get("c"), null);
});

test("a later request cannot close a cycle through an existing active path", () => {
  const result = sanitized(
    [["a", "b"], ["b", null], ["c", "a"]],
    [["b", "c"]]
  );
  assert.equal(result.parentByTagId.get("b"), null);
  assert.equal(result.adjustedTagIds.has("b"), true);
});

test("valid moves and edge reversals remain valid", () => {
  const move = sanitized(
    [["a", null], ["b", null], ["c", null]],
    [["a", "b"], ["b", "c"]]
  );
  assert.equal(move.parentByTagId.get("a"), "b");
  assert.equal(move.parentByTagId.get("b"), "c");
  assert.equal(move.adjustedTagIds.size, 0);

  const reverse = sanitized(
    [["a", "b"], ["b", null]],
    [["a", null], ["b", "a"]]
  );
  assert.equal(reverse.parentByTagId.get("a"), null);
  assert.equal(reverse.parentByTagId.get("b"), "a");
  assert.equal(reverse.adjustedTagIds.size, 0);
});
