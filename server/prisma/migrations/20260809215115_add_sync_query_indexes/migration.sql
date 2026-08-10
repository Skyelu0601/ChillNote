-- Add indexes used by bootstrap sync without blocking note or tag writes while
-- PostgreSQL builds them on the production database.
CREATE INDEX CONCURRENTLY IF NOT EXISTS "Note_userId_idx" ON "Note"("userId");
CREATE INDEX CONCURRENTLY IF NOT EXISTS "Tag_userId_idx" ON "Tag"("userId");
