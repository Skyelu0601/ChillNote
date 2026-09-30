BEGIN;
SET LOCAL lock_timeout = '15s';

ALTER TABLE "EmailPreference"
  ADD COLUMN "subscriptionBillingEmailsEnabled" BOOLEAN NOT NULL DEFAULT true;

COMMIT;
