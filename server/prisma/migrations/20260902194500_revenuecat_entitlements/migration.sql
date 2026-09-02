CREATE TABLE "RevenueCatEntitlement" (
    "userId" TEXT NOT NULL,
    "entitlementId" TEXT NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT false,
    "expiresAt" TIMESTAMP(3),
    "productId" TEXT,
    "store" TEXT,
    "originalTransactionId" TEXT,
    "lastEventId" TEXT,
    "lastSyncedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "RevenueCatEntitlement_pkey" PRIMARY KEY ("userId", "entitlementId")
);

CREATE TABLE "RevenueCatWebhookEvent" (
    "id" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "appUserId" TEXT,
    "environment" TEXT,
    "eventTimestampAt" TIMESTAMP(3) NOT NULL,
    "processedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RevenueCatWebhookEvent_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "RevenueCatEntitlement_userId_isActive_expiresAt_idx"
ON "RevenueCatEntitlement"("userId", "isActive", "expiresAt");

CREATE INDEX "RevenueCatWebhookEvent_appUserId_processedAt_idx"
ON "RevenueCatWebhookEvent"("appUserId", "processedAt");

ALTER TABLE "RevenueCatEntitlement"
ADD CONSTRAINT "RevenueCatEntitlement_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
