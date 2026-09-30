BEGIN;
SET LOCAL lock_timeout = '15s';

CREATE TABLE "EmailPreference" (
  "userId" TEXT NOT NULL,
  "marketingStatus" TEXT NOT NULL DEFAULT 'unknown',
  "marketingConsentedAt" TIMESTAMP(3),
  "marketingConsentSource" TEXT,
  "marketingUnsubscribedAt" TIMESTAMP(3),
  "serviceSuppressedAt" TIMESTAMP(3),
  "suppressionReason" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "EmailPreference_pkey" PRIMARY KEY ("userId"),
  CONSTRAINT "EmailPreference_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE "EmailDelivery" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "kind" TEXT NOT NULL,
  "dedupeKey" TEXT NOT NULL,
  "scheduledAt" TIMESTAMP(3) NOT NULL,
  "expectedExpiresAt" TIMESTAMP(3),
  "status" TEXT NOT NULL DEFAULT 'scheduled',
  "attempts" INTEGER NOT NULL DEFAULT 0,
  "sentAt" TIMESTAMP(3),
  "providerMessageId" TEXT,
  "lastError" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "EmailDelivery_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "EmailDelivery_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "EmailPreference_marketingStatus_idx" ON "EmailPreference"("marketingStatus");
CREATE UNIQUE INDEX "EmailDelivery_dedupeKey_key" ON "EmailDelivery"("dedupeKey");
CREATE INDEX "EmailDelivery_status_scheduledAt_idx" ON "EmailDelivery"("status", "scheduledAt");
CREATE INDEX "EmailDelivery_userId_kind_idx" ON "EmailDelivery"("userId", "kind");

-- Email addresses stay in Supabase Auth. These backend-only tables contain
-- preferences and delivery state and are never exposed through the Data API.
ALTER TABLE "EmailPreference" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "EmailDelivery" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE "EmailPreference" FROM anon, authenticated;
REVOKE ALL ON TABLE "EmailDelivery" FROM anon, authenticated;

COMMIT;
