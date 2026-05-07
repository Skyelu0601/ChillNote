ALTER TABLE "Note"
ADD COLUMN "sourceURL" TEXT,
ADD COLUMN "sourceTitle" TEXT,
ADD COLUMN "sourcePlatformID" TEXT,
ADD COLUMN "sourcePlatformName" TEXT,
ADD COLUMN "sourceHost" TEXT,
ADD COLUMN "sourceCapturedAt" TIMESTAMP(3);
