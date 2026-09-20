import assert from "node:assert/strict";
import test from "node:test";
import { readFileSync } from "node:fs";

const migration = readFileSync(new URL("../prisma/migrations/20260917090000_chillo/migration.sql", import.meta.url), "utf8");
const hardening = readFileSync(new URL("../prisma/migrations/20260917093000_chillo_function_search_path/migration.sql", import.meta.url), "utf8");

test("Chillo trigger uses a fixed search path with temporary schemas last", () => {
  assert.match(hardening, /ALTER FUNCTION public\.chillo_invalidate_note_index\(\)/);
  assert.match(hardening, /SET search_path = pg_catalog, public, pg_temp/);
  assert.doesNotMatch(hardening, /GRANT|SECURITY DEFINER/);
});

test("Chillo migration blocks direct client access to every backend-only table", () => {
  for (const table of ["ChilloConversation", "ChilloTurn", "ChilloChunk", "ChilloDraft"]) {
    assert.ok(migration.includes(`ALTER TABLE "${table}" ENABLE ROW LEVEL SECURITY;`));
  }
  assert.match(migration, /REVOKE ALL ON TABLE .* FROM PUBLIC;/);
  assert.match(migration, /rolname IN \('anon', 'authenticated'\)/);
  assert.match(migration, /REVOKE ALL ON TABLE .* FROM %I/);
  assert.doesNotMatch(migration, /CREATE POLICY/i);
});
test("existing notes survive migration and source edits invalidate derived vectors", () => {
  assert.doesNotMatch(migration, /DROP TABLE|DELETE FROM "Note"/i);
  assert.match(migration, /AFTER UPDATE OF "content", "deletedAt" ON "Note"/);
  assert.match(migration, /DELETE FROM "ChilloChunk" WHERE "noteId" = NEW\."id"/);
  assert.match(migration, /"noteId" TEXT UNIQUE REFERENCES "Note"\("id"\) ON DELETE SET NULL/);
});
