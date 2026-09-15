-- RevenueCat entitlement state is managed exclusively by the backend.
-- Keep it inaccessible through Supabase's client-facing database roles.
ALTER TABLE "RevenueCatEntitlement" ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE "RevenueCatEntitlement" FROM anon, authenticated;
