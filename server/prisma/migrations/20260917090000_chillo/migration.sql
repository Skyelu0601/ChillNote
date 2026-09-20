ALTER TABLE "User" ADD COLUMN "chilloConsentVersion" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "chilloConsentAt" TIMESTAMP(3), ADD COLUMN "chilloIndexCheckedAt" TIMESTAMP(3);
CREATE INDEX "User_chilloConsentVersion_chilloIndexCheckedAt_idx" ON "User"("chilloConsentVersion", "chilloIndexCheckedAt");
ALTER TABLE "Note" ADD COLUMN "isChilloDraft" BOOLEAN NOT NULL DEFAULT false, ADD COLUMN "chilloIndexRetryAt" TIMESTAMP(3);
CREATE INDEX "Note_userId_id_idx" ON "Note"("userId", "id");
CREATE TABLE "ChilloConversation" (
  "id" TEXT PRIMARY KEY, "userId" TEXT NOT NULL REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  "title" TEXT NOT NULL, "excludedIds" TEXT[] NOT NULL DEFAULT '{}', "pinnedIds" TEXT[] NOT NULL DEFAULT '{}',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, "updatedAt" TIMESTAMP(3) NOT NULL
);
CREATE INDEX "ChilloConversation_userId_updatedAt_idx" ON "ChilloConversation"("userId", "updatedAt");
CREATE TABLE "ChilloTurn" (
  "id" TEXT PRIMARY KEY, "conversationId" TEXT NOT NULL REFERENCES "ChilloConversation"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  "request" TEXT NOT NULL, "locale" TEXT NOT NULL DEFAULT 'en', "status" TEXT NOT NULL DEFAULT 'queued',
  "answer" TEXT NOT NULL DEFAULT '', "sources" JSONB NOT NULL DEFAULT '[]', "errorCode" TEXT,
  "leaseId" TEXT, "leaseExpiresAt" TIMESTAMP(3), "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "completedAt" TIMESTAMP(3)
);
CREATE INDEX "ChilloTurn_conversationId_createdAt_idx" ON "ChilloTurn"("conversationId", "createdAt");
CREATE INDEX "ChilloTurn_status_leaseExpiresAt_idx" ON "ChilloTurn"("status", "leaseExpiresAt");
CREATE TABLE "ChilloChunk" (
  "id" TEXT PRIMARY KEY, "noteId" TEXT NOT NULL REFERENCES "Note"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  "hash" TEXT NOT NULL, "start" INTEGER NOT NULL, "end" INTEGER NOT NULL,
  "embedding" DOUBLE PRECISION[] NOT NULL DEFAULT '{}', "model" TEXT NOT NULL
);
CREATE INDEX "ChilloChunk_noteId_model_idx" ON "ChilloChunk"("noteId", "model");
CREATE TABLE "ChilloDraft" (
  "id" TEXT PRIMARY KEY, "turnId" TEXT NOT NULL UNIQUE REFERENCES "ChilloTurn"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  "noteId" TEXT UNIQUE REFERENCES "Note"("id") ON DELETE SET NULL ON UPDATE CASCADE, "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
-- Backend-only tables: no direct Data API access, even for authenticated clients.
-- The trusted backend uses the same privileged database connection as existing workers.
ALTER TABLE "ChilloConversation" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "ChilloTurn" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "ChilloChunk" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "ChilloDraft" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE "ChilloConversation", "ChilloTurn", "ChilloChunk", "ChilloDraft" FROM PUBLIC;
DO $$
DECLARE client_role TEXT;
BEGIN
  FOR client_role IN SELECT rolname FROM pg_roles WHERE rolname IN ('anon', 'authenticated') LOOP
    EXECUTE format('REVOKE ALL ON TABLE "ChilloConversation", "ChilloTurn", "ChilloChunk", "ChilloDraft" FROM %I', client_role);
  END LOOP;
END;
$$;
-- Invalidate derived embeddings in the same transaction as edits or soft deletion,
-- including changes made through older clients or import workers.
CREATE FUNCTION chillo_invalidate_note_index() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW."content" IS DISTINCT FROM OLD."content" OR NEW."deletedAt" IS DISTINCT FROM OLD."deletedAt" THEN
    DELETE FROM "ChilloChunk" WHERE "noteId" = NEW."id";
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER chillo_note_changed AFTER UPDATE OF "content", "deletedAt" ON "Note"
FOR EACH ROW EXECUTE FUNCTION chillo_invalidate_note_index();
