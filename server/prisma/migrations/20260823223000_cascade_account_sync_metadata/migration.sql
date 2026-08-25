-- Remove sync metadata left behind by account deletions that happened before
-- these tables were linked to User with cascading foreign keys.
DELETE FROM "SyncLog"
WHERE NOT EXISTS (
    SELECT 1 FROM "User" WHERE "User"."id" = "SyncLog"."userId"
);

DELETE FROM "HardDeleteTombstone"
WHERE NOT EXISTS (
    SELECT 1 FROM "User" WHERE "User"."id" = "HardDeleteTombstone"."userId"
);

ALTER TABLE "SyncLog"
ADD CONSTRAINT "SyncLog_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "HardDeleteTombstone"
ADD CONSTRAINT "HardDeleteTombstone_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
