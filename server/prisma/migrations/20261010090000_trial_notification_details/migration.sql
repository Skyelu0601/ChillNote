-- Optional metadata preserves existing notification kinds and read state.
ALTER TABLE "AppNotification" ADD COLUMN "details" JSONB;
