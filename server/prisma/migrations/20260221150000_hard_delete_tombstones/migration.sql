-- CreateTable
CREATE TABLE "HardDeleteTombstone" (
    "id" SERIAL NOT NULL,
    "userId" TEXT NOT NULL,
    "entityType" TEXT NOT NULL,
    "entityId" TEXT NOT NULL,
    "deletedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "HardDeleteTombstone_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "HardDeleteTombstone_userId_entityType_entityId_key"
ON "HardDeleteTombstone"("userId", "entityType", "entityId");

-- CreateIndex
CREATE INDEX "HardDeleteTombstone_userId_deletedAt_idx"
ON "HardDeleteTombstone"("userId", "deletedAt");
