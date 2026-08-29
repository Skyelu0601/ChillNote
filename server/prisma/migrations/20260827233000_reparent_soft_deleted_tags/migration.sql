-- Historical clients could soft-delete a parent tag without clearing the
-- active children's parentId. Repair those rows once and emit ordinary sync
-- logs so devices with an existing cursor receive the hierarchy change.
WITH repaired AS (
  UPDATE "Tag" child
  SET "parentId" = NULL,
      "version" = child."version" + 1,
      "updatedAt" = NOW(),
      "serverUpdatedAt" = NOW(),
      "lastModifiedByDeviceId" = NULL,
      "lastMutationId" = 'server:' || md5(
        child."userId" || ':' || child."id" || ':' || child."version"::text || ':' || clock_timestamp()::text
      )
  FROM "Tag" parent
  WHERE child."parentId" = parent."id"
    AND child."userId" = parent."userId"
    AND (parent."deletedAt" IS NOT NULL OR parent."serverDeletedAt" IS NOT NULL)
  RETURNING child."userId", child."id", child."version", child."serverUpdatedAt", child."deletedAt"
)
INSERT INTO "SyncLog" (
  "userId", "entityType", "entityId", "version", "serverUpdatedAt", "operation"
)
SELECT
  repaired."userId",
  'tag',
  repaired."id",
  repaired."version",
  repaired."serverUpdatedAt",
  CASE WHEN repaired."deletedAt" IS NULL THEN 'upsert' ELSE 'delete' END
FROM repaired;
