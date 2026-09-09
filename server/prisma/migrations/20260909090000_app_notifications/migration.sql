BEGIN;
SET LOCAL lock_timeout = '15s';
-- Existing accounts must not receive a new-user gift announcement.
ALTER TABLE "User" ADD COLUMN "welcomeNotificationEligible" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "User" ALTER COLUMN "welcomeNotificationEligible" SET DEFAULT true;
-- Unknown historical grants stay NULL; never infer the grant from the current balance.
ALTER TABLE "UserCredits" ADD COLUMN "initialGrantAmount" INTEGER;
CREATE TABLE "AppNotification" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "dedupeKey" TEXT NOT NULL,
  "kind" TEXT NOT NULL,
  "amount" INTEGER,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "readAt" TIMESTAMP(3),
  CONSTRAINT "AppNotification_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "AppNotification_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "AppNotification_userId_dedupeKey_key" ON "AppNotification"("userId", "dedupeKey");
CREATE INDEX "AppNotification_userId_createdAt_idx" ON "AppNotification"("userId", "createdAt");

-- Only the authenticated backend accesses this inbox; no direct client Data API access.
ALTER TABLE "AppNotification" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE "AppNotification" FROM anon, authenticated;
COMMIT;
