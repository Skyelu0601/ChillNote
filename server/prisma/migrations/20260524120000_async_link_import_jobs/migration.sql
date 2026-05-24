-- Add async link import state to notes.
ALTER TABLE "Note" ADD COLUMN "importStatus" TEXT;
ALTER TABLE "Note" ADD COLUMN "importJobId" TEXT;
ALTER TABLE "Note" ADD COLUMN "importErrorCode" TEXT;
ALTER TABLE "Note" ADD COLUMN "importStartedAt" TIMESTAMP(3);
ALTER TABLE "Note" ADD COLUMN "importCompletedAt" TIMESTAMP(3);

-- Persist background link import jobs so app shutdowns do not lose work.
CREATE TABLE "LinkImportJob" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "noteId" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "status" TEXT NOT NULL,
    "errorCode" TEXT,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "startedAt" TIMESTAMP(3),
    "completedAt" TIMESTAMP(3),

    CONSTRAINT "LinkImportJob_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "LinkImportJob_userId_status_idx" ON "LinkImportJob"("userId", "status");
CREATE INDEX "LinkImportJob_status_createdAt_idx" ON "LinkImportJob"("status", "createdAt");
CREATE UNIQUE INDEX "LinkImportJob_userId_noteId_key" ON "LinkImportJob"("userId", "noteId");

ALTER TABLE "LinkImportJob" ADD CONSTRAINT "LinkImportJob_noteId_fkey"
    FOREIGN KEY ("noteId") REFERENCES "Note"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "LinkImportJob" ADD CONSTRAINT "LinkImportJob_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
