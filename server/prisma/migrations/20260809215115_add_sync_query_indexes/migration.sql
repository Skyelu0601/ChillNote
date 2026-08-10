-- Prisma runs each migration inside a transaction, so these indexes must use
-- regular CREATE INDEX statements rather than CREATE INDEX CONCURRENTLY.
CREATE INDEX IF NOT EXISTS "Note_userId_idx" ON "Note"("userId");
CREATE INDEX IF NOT EXISTS "Tag_userId_idx" ON "Tag"("userId");
