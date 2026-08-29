BEGIN;

-- Preserve every row that will be removed by the historical UUID case repair.
-- The archive belongs to the same user and is deleted with the account.
CREATE TABLE "SyncIdentityDuplicateArchive" (
    "id" SERIAL NOT NULL,
    "userId" TEXT NOT NULL,
    "entityType" TEXT NOT NULL,
    "canonicalEntityId" TEXT NOT NULL,
    "archivedEntityId" TEXT NOT NULL,
    "winnerEntityId" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "dependencies" JSONB NOT NULL,
    "archivedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SyncIdentityDuplicateArchive_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "SyncIdentityDuplicateArchive_userId_entityType_archivedEntityId_key"
ON "SyncIdentityDuplicateArchive"("userId", "entityType", "archivedEntityId");

CREATE INDEX "SyncIdentityDuplicateArchive_userId_entityType_canonicalEntityId_idx"
ON "SyncIdentityDuplicateArchive"("userId", "entityType", "canonicalEntityId");

ALTER TABLE "SyncIdentityDuplicateArchive"
ADD CONSTRAINT "SyncIdentityDuplicateArchive_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- This recovery table is internal operator data. Keep it unreachable through
-- Supabase's public-schema Data API even if table grants change later.
ALTER TABLE "SyncIdentityDuplicateArchive" ENABLE ROW LEVEL SECURITY;

CREATE TEMP TABLE "_sync_note_case_aliases" ON COMMIT DROP AS
WITH ranked AS (
    SELECT
        n."id",
        n."userId",
        lower(n."id") AS "canonicalId",
        first_value(n."id") OVER (
            PARTITION BY n."userId", lower(n."id")
            ORDER BY n."serverUpdatedAt" DESC NULLS LAST,
                     n."updatedAt" DESC NULLS LAST,
                     n."version" DESC,
                     n."id" DESC
        ) AS "winnerId",
        count(*) OVER (PARTITION BY n."userId", lower(n."id")) AS "aliasCount"
    FROM "Note" n
    WHERE n."id" ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
)
SELECT "id" AS "archivedId", "userId", "canonicalId", "winnerId"
FROM ranked
WHERE "aliasCount" > 1 AND "id" <> "winnerId";

INSERT INTO "SyncIdentityDuplicateArchive" (
    "userId",
    "entityType",
    "canonicalEntityId",
    "archivedEntityId",
    "winnerEntityId",
    "payload",
    "dependencies"
)
SELECT
    aliases."userId",
    'note',
    aliases."canonicalId",
    aliases."archivedId",
    aliases."winnerId",
    to_jsonb(note_row),
    jsonb_build_object(
        'tagIds', COALESCE((
            SELECT jsonb_agg(note_tag."B" ORDER BY note_tag."B")
            FROM "_NoteToTag" note_tag
            WHERE note_tag."A" = aliases."archivedId"
        ), '[]'::jsonb),
        'linkImportJobs', COALESCE((
            SELECT jsonb_agg(to_jsonb(link_job) ORDER BY link_job."createdAt", link_job."id")
            FROM "LinkImportJob" link_job
            WHERE link_job."noteId" = aliases."archivedId"
        ), '[]'::jsonb)
    )
FROM "_sync_note_case_aliases" aliases
JOIN "Note" note_row ON note_row."id" = aliases."archivedId"
ON CONFLICT ("userId", "entityType", "archivedEntityId") DO NOTHING;

-- Keep every live tag association from the archived alias. The production
-- audit found no loser-side relations, but older clients can still create one
-- between the audit and this migration being applied.
INSERT INTO "_NoteToTag" ("A", "B")
SELECT aliases."winnerId", note_tag."B"
FROM "_sync_note_case_aliases" aliases
JOIN "_NoteToTag" note_tag ON note_tag."A" = aliases."archivedId"
ON CONFLICT DO NOTHING;

-- Existing production data has at most one loser-side import job per group.
-- Move it to the live winner when the winner does not already own a job. Any
-- future collision remains recoverable in the archive and is removed below.
UPDATE "LinkImportJob" link_job
SET "noteId" = aliases."winnerId",
    "updatedAt" = CURRENT_TIMESTAMP
FROM "_sync_note_case_aliases" aliases
WHERE link_job."noteId" = aliases."archivedId"
  AND NOT EXISTS (
      SELECT 1
      FROM "LinkImportJob" winner_job
      WHERE winner_job."userId" = link_job."userId"
        AND winner_job."noteId" = aliases."winnerId"
  );

DELETE FROM "LinkImportJob" link_job
USING "_sync_note_case_aliases" aliases
WHERE link_job."noteId" = aliases."archivedId";

-- Weekly topic snapshots store note IDs inside JSON. Replace exact UUID text
-- before deleting aliases so historical reports continue to open the winner.
UPDATE "WeeklyTopicReport" report
SET "topics" = replace(
    report."topics"::text,
    aliases."archivedId",
    aliases."winnerId"
)::jsonb
FROM "_sync_note_case_aliases" aliases
WHERE report."userId" = aliases."userId"
  AND report."topics"::text LIKE ('%' || aliases."archivedId" || '%');

-- Old log entries are retained for cursor continuity, but point at the live
-- physical row so an incremental reader never asks for a deleted alias.
UPDATE "SyncLog" sync_log
SET "entityId" = aliases."winnerId"
FROM "_sync_note_case_aliases" aliases
WHERE sync_log."userId" = aliases."userId"
  AND sync_log."entityType" = 'note'
  AND sync_log."entityId" = aliases."archivedId";

DELETE FROM "Note" note_row
USING "_sync_note_case_aliases" aliases
WHERE note_row."id" = aliases."archivedId"
  AND note_row."userId" = aliases."userId";

-- Tag aliases have not been observed in production, but repair them with the
-- same deterministic/archive-first policy so the invariant holds for all data.
CREATE TEMP TABLE "_sync_tag_case_aliases" ON COMMIT DROP AS
WITH ranked AS (
    SELECT
        t."id",
        t."userId",
        lower(t."id") AS "canonicalId",
        first_value(t."id") OVER (
            PARTITION BY t."userId", lower(t."id")
            ORDER BY t."serverUpdatedAt" DESC NULLS LAST,
                     t."updatedAt" DESC NULLS LAST,
                     t."version" DESC,
                     t."id" DESC
        ) AS "winnerId",
        count(*) OVER (PARTITION BY t."userId", lower(t."id")) AS "aliasCount"
    FROM "Tag" t
    WHERE t."id" ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
)
SELECT "id" AS "archivedId", "userId", "canonicalId", "winnerId"
FROM ranked
WHERE "aliasCount" > 1 AND "id" <> "winnerId";

INSERT INTO "SyncIdentityDuplicateArchive" (
    "userId",
    "entityType",
    "canonicalEntityId",
    "archivedEntityId",
    "winnerEntityId",
    "payload",
    "dependencies"
)
SELECT
    aliases."userId",
    'tag',
    aliases."canonicalId",
    aliases."archivedId",
    aliases."winnerId",
    to_jsonb(tag_row),
    jsonb_build_object(
        'noteIds', COALESCE((
            SELECT jsonb_agg(note_tag."A" ORDER BY note_tag."A")
            FROM "_NoteToTag" note_tag
            WHERE note_tag."B" = aliases."archivedId"
        ), '[]'::jsonb),
        'childIds', COALESCE((
            SELECT jsonb_agg(child."id" ORDER BY child."id")
            FROM "Tag" child
            WHERE child."parentId" = aliases."archivedId"
        ), '[]'::jsonb)
    )
FROM "_sync_tag_case_aliases" aliases
JOIN "Tag" tag_row ON tag_row."id" = aliases."archivedId"
ON CONFLICT ("userId", "entityType", "archivedEntityId") DO NOTHING;

-- Preserve graph connectivity when a historical tag alias is merged.
INSERT INTO "_NoteToTag" ("A", "B")
SELECT note_tag."A", aliases."winnerId"
FROM "_sync_tag_case_aliases" aliases
JOIN "_NoteToTag" note_tag ON note_tag."B" = aliases."archivedId"
ON CONFLICT DO NOTHING;

UPDATE "Tag" child
SET "parentId" = aliases."winnerId"
FROM "_sync_tag_case_aliases" aliases
WHERE child."parentId" = aliases."archivedId";

UPDATE "SyncLog" sync_log
SET "entityId" = aliases."winnerId"
FROM "_sync_tag_case_aliases" aliases
WHERE sync_log."userId" = aliases."userId"
  AND sync_log."entityType" = 'tag'
  AND sync_log."entityId" = aliases."archivedId";

DELETE FROM "Tag" tag_row
USING "_sync_tag_case_aliases" aliases
WHERE tag_row."id" = aliases."archivedId"
  AND tag_row."userId" = aliases."userId";

-- Merge any pre-existing case-variant tombstones before enforcing the same
-- logical UUID uniqueness at the database layer.
DELETE FROM "HardDeleteTombstone" older
USING "HardDeleteTombstone" newer
WHERE older."id" < newer."id"
  AND older."userId" = newer."userId"
  AND older."entityType" = newer."entityType"
  AND lower(older."entityId") = lower(newer."entityId")
  AND older."entityId" ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

-- Prevent a future uppercase/lowercase alias even though the historical
-- physical primary key remains case-sensitive for non-UUID legacy IDs.
CREATE UNIQUE INDEX "Note_uuid_sync_identity_key"
ON "Note" (lower("id"))
WHERE "id" ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

CREATE UNIQUE INDEX "Tag_uuid_sync_identity_key"
ON "Tag" (lower("id"))
WHERE "id" ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

COMMIT;
