-- StoreKit original IDs and RevenueCat v1 store_transaction_id are different
-- identifiers. Keep both; never reinterpret the existing historical field.
ALTER TABLE "RevenueCatEntitlement" ADD COLUMN "storeTransactionId" TEXT;
CREATE UNIQUE INDEX "RevenueCatEntitlement_store_storeTransactionId_key"
ON "RevenueCatEntitlement"("store", "storeTransactionId");
