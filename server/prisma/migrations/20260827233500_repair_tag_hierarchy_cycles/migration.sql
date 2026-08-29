-- Flatten every active historical cycle before the protocol starts enforcing
-- an acyclic tag graph. All repaired tags receive a new version/mutation and a
-- SyncLog row so existing cursors learn the change.
WITH RECURSIVE tag_walk AS (
  SELECT
    tag."userId",
    tag."id" AS "currentId",
    tag."parentId",
    ARRAY[tag."id"]::TEXT[] AS path,
    FALSE AS cycle
  FROM "Tag" tag
  WHERE tag."deletedAt" IS NULL AND tag."serverDeletedAt" IS NULL

  UNION ALL

  SELECT
    walk."userId",
    parent."id" AS "currentId",
    parent."parentId",
    walk.path || parent."id",
    parent."id" = ANY(walk.path) AS cycle
  FROM tag_walk walk
  JOIN "Tag" parent
    ON parent."id" = walk."parentId"
   AND parent."userId" = walk."userId"
   AND parent."deletedAt" IS NULL
   AND parent."serverDeletedAt" IS NULL
  WHERE NOT walk.cycle
),
cycle_members AS (
  SELECT DISTINCT
    cyclic."userId",
    unnest(
      cyclic.path[
        array_position(cyclic.path, cyclic."currentId"):
        cardinality(cyclic.path) - 1
      ]
    ) AS "id"
  FROM tag_walk cyclic
  WHERE cyclic.cycle
),
repaired AS (
  UPDATE "Tag" tag
  SET "parentId" = NULL,
      "version" = tag."version" + 1,
      "updatedAt" = NOW(),
      "serverUpdatedAt" = NOW(),
      "lastModifiedByDeviceId" = NULL,
      "lastMutationId" = 'server:' || md5(
        tag."userId" || ':' || tag."id" || ':' || tag."version"::text || ':' || clock_timestamp()::text
      )
  FROM cycle_members member
  WHERE tag."userId" = member."userId" AND tag."id" = member."id"
  RETURNING tag."userId", tag."id", tag."version", tag."serverUpdatedAt"
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
  'upsert'
FROM repaired;
