-- A durable mutation identity lets clients distinguish their own committed
-- request with a lost HTTP response from a genuine edit made by another
-- device. Existing rows receive a deterministic baseline identity so the
-- first v4 client edit can name the exact state it observed.
ALTER TABLE "Note" ADD COLUMN "lastMutationId" TEXT;
ALTER TABLE "Tag" ADD COLUMN "lastMutationId" TEXT;

UPDATE "Note"
SET "lastMutationId" = 'legacy:' || md5(
  "userId" || ':' || "id" || ':' || "version"::text || ':' || "serverUpdatedAt"::text
);

UPDATE "Tag"
SET "lastMutationId" = 'legacy:' || md5(
  "userId" || ':' || "id" || ':' || "version"::text || ':' || "serverUpdatedAt"::text
);
