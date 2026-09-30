BEGIN;
SET LOCAL lock_timeout = '15s';

ALTER TABLE "EmailDelivery"
  ADD COLUMN "providerStatus" TEXT,
  ADD COLUMN "providerEventAt" TIMESTAMP(3),
  ADD COLUMN "deliveredAt" TIMESTAMP(3),
  ADD COLUMN "bouncedAt" TIMESTAMP(3),
  ADD COLUMN "complainedAt" TIMESTAMP(3);

CREATE INDEX "EmailDelivery_providerMessageId_idx"
  ON "EmailDelivery"("providerMessageId");

CREATE TABLE "EmailEvent" (
  "id" TEXT NOT NULL,
  "deliveryId" TEXT NOT NULL,
  "providerMessageId" TEXT NOT NULL,
  "snsMessageId" TEXT NOT NULL,
  "eventType" TEXT NOT NULL,
  "eventTimestamp" TIMESTAMP(3),
  "details" JSONB,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "EmailEvent_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "EmailEvent_deliveryId_fkey" FOREIGN KEY ("deliveryId")
    REFERENCES "EmailDelivery"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "EmailEvent_snsMessageId_eventType_key"
  ON "EmailEvent"("snsMessageId", "eventType");
CREATE INDEX "EmailEvent_deliveryId_eventTimestamp_idx"
  ON "EmailEvent"("deliveryId", "eventTimestamp");
CREATE INDEX "EmailEvent_providerMessageId_idx"
  ON "EmailEvent"("providerMessageId");
CREATE INDEX "EmailEvent_eventType_eventTimestamp_idx"
  ON "EmailEvent"("eventType", "eventTimestamp");

ALTER TABLE "EmailEvent" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE "EmailEvent" FROM anon, authenticated;

COMMIT;
