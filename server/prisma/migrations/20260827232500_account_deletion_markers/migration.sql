CREATE TABLE "AccountDeletionMarker" (
  "userId" TEXT NOT NULL,
  "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "AccountDeletionMarker_pkey" PRIMARY KEY ("userId")
);

-- Markers are backend-only privacy controls and must never be exposed through
-- the public-schema Data API.
ALTER TABLE "AccountDeletionMarker" ENABLE ROW LEVEL SECURITY;

-- This database guard covers every current and future code path that might
-- insert a User outside the sync transaction. Taking the same per-account lock
-- closes the statement-snapshot race where an INSERT begins while deletion is
-- uncommitted, waits on the old User row, and otherwise recreates it afterwards.
CREATE FUNCTION "preventDeletedAccountRecreation"()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM pg_advisory_xact_lock(hashtextextended(NEW."id", 0));
  IF EXISTS (
    SELECT 1 FROM "AccountDeletionMarker" marker
    WHERE marker."userId" = NEW."id"
  ) THEN
    RAISE EXCEPTION 'sync.account_deleted' USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql VOLATILE;

CREATE TRIGGER "User_prevent_deleted_account_recreation"
BEFORE INSERT ON "User"
FOR EACH ROW EXECUTE FUNCTION "preventDeletedAccountRecreation"();
