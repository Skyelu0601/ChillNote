import assert from "node:assert/strict";
import test from "node:test";
import { shouldReuseCompletedLinkImportJob } from "./linkImportPolicy.js";

test("a completed link import is an idempotent replay", () => {
  assert.equal(shouldReuseCompletedLinkImportJob("completed"), true);
  assert.equal(shouldReuseCompletedLinkImportJob("queued"), false);
  assert.equal(shouldReuseCompletedLinkImportJob("processing"), false);
  assert.equal(shouldReuseCompletedLinkImportJob("failed"), false);
  assert.equal(shouldReuseCompletedLinkImportJob(null), false);
});
