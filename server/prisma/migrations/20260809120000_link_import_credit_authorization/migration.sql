-- Record whether a link-import job has already passed credit authorization.
-- Existing jobs are grandfathered so retries after deployment cannot charge
-- users for work that was created before server-side charging existed.
ALTER TABLE "LinkImportJob"
ADD COLUMN "creditAuthorizedAt" TIMESTAMP(3);

UPDATE "LinkImportJob"
SET "creditAuthorizedAt" = COALESCE("createdAt", CURRENT_TIMESTAMP);
