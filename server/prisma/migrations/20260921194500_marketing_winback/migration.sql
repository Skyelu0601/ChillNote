BEGIN;
SET LOCAL lock_timeout = '15s';

ALTER TABLE "EmailPreference"
  ADD COLUMN "billingIssueAt" TIMESTAMP(3);

ALTER TABLE "EmailDelivery"
  ADD COLUMN "activityAnchorAt" TIMESTAMP(3);

CREATE INDEX "EmailDelivery_userId_kind_activityAnchorAt_idx"
  ON "EmailDelivery"("userId", "kind", "activityAnchorAt");

-- The account owner confirmed that existing users consented to marketing email.
-- Preserve explicit opt-outs and record this backfill source for auditability.
INSERT INTO "EmailPreference" (
  "userId",
  "marketingStatus",
  "marketingConsentedAt",
  "marketingConsentSource",
  "createdAt",
  "updatedAt"
)
SELECT
  "id",
  'subscribed',
  CURRENT_TIMESTAMP,
  'owner_confirmed_existing_users_2026_09_21',
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
FROM "User"
ON CONFLICT ("userId") DO UPDATE SET
  "marketingStatus" = 'subscribed',
  "marketingConsentedAt" = CURRENT_TIMESTAMP,
  "marketingConsentSource" = 'owner_confirmed_existing_users_2026_09_21',
  "updatedAt" = CURRENT_TIMESTAMP
WHERE "EmailPreference"."marketingStatus" = 'unknown';

COMMIT;
