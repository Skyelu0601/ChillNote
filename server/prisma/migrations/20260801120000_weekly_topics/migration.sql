CREATE TABLE "WeeklyTopicSettings" (
    "userId" TEXT NOT NULL,
    "enabled" BOOLEAN NOT NULL DEFAULT false,
    "weekday" INTEGER NOT NULL DEFAULT 1,
    "hour" INTEGER NOT NULL DEFAULT 9,
    "minute" INTEGER NOT NULL DEFAULT 0,
    "timeZone" TEXT NOT NULL DEFAULT 'UTC',
    "locale" TEXT NOT NULL DEFAULT 'en',
    "lastPeriodEnd" TIMESTAMP(3),
    "nextRunAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "WeeklyTopicSettings_pkey" PRIMARY KEY ("userId")
);

CREATE TABLE "WeeklyTopicReport" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "periodStart" TIMESTAMP(3) NOT NULL,
    "periodEnd" TIMESTAMP(3) NOT NULL,
    "sourceNoteCount" INTEGER NOT NULL,
    "language" TEXT NOT NULL,
    "topics" JSONB NOT NULL,
    "readAt" TIMESTAMP(3),
    "regenerationCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "WeeklyTopicReport_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "WeeklyTopicSettings_enabled_nextRunAt_idx"
ON "WeeklyTopicSettings"("enabled", "nextRunAt");

CREATE UNIQUE INDEX "WeeklyTopicReport_userId_periodEnd_key"
ON "WeeklyTopicReport"("userId", "periodEnd");

CREATE INDEX "WeeklyTopicReport_userId_periodEnd_idx"
ON "WeeklyTopicReport"("userId", "periodEnd");

ALTER TABLE "WeeklyTopicSettings"
ADD CONSTRAINT "WeeklyTopicSettings_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "WeeklyTopicReport"
ADD CONSTRAINT "WeeklyTopicReport_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "WeeklyTopicSettings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "WeeklyTopicReport" ENABLE ROW LEVEL SECURITY;
