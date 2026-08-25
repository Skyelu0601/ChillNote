CREATE TABLE "GooglePlayPurchase" (
    "purchaseToken" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "productId" TEXT NOT NULL,
    "packageName" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'RECEIVED',
    "subscriptionState" TEXT,
    "acknowledgementState" TEXT,
    "latestOrderId" TEXT,
    "linkedPurchaseToken" TEXT,
    "expiresAt" TIMESTAMP(3),
    "verifiedAt" TIMESTAMP(3),
    "acknowledgedAt" TIMESTAMP(3),
    "entitlementGrantedAt" TIMESTAMP(3),
    "ackAttempts" INTEGER NOT NULL DEFAULT 0,
    "lastAckAttemptAt" TIMESTAMP(3),
    "nextAckAttemptAt" TIMESTAMP(3),
    "processingStartedAt" TIMESTAMP(3),
    "processingId" TEXT,
    "lastErrorCode" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "GooglePlayPurchase_pkey" PRIMARY KEY ("purchaseToken")
);

CREATE INDEX "GooglePlayPurchase_userId_status_idx"
ON "GooglePlayPurchase"("userId", "status");

CREATE INDEX "GooglePlayPurchase_status_nextAckAttemptAt_idx"
ON "GooglePlayPurchase"("status", "nextAckAttemptAt");

CREATE INDEX "GooglePlayPurchase_status_processingStartedAt_idx"
ON "GooglePlayPurchase"("status", "processingStartedAt");

ALTER TABLE "GooglePlayPurchase"
ADD CONSTRAINT "GooglePlayPurchase_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Purchase tokens are server-only credentials. Do not expose them through the
-- Supabase data API; the backend database role is responsible for access.
ALTER TABLE "GooglePlayPurchase" ENABLE ROW LEVEL SECURITY;
