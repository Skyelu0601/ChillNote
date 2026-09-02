import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import test from "node:test";
import {
  effectiveSubscription,
  revenueCatEntitlementSnapshot,
  revenueCatWebhookUserIds,
  verifyRevenueCatWebhookSignature
} from "./revenueCat.js";

test("parses an active RevenueCat entitlement and matching subscription", () => {
  const snapshot = revenueCatEntitlementSnapshot({ subscriber: {
    entitlements: { pro: {
      expires_date: "2026-10-01T00:00:00Z",
      product_identifier: "com.chillnote.pro.yearly"
    } },
    subscriptions: { "com.chillnote.pro.yearly": {
      store: "app_store",
      original_transaction_id: "original-1"
    } }
  } }, "pro", new Date("2026-09-01T00:00:00Z"));

  assert.deepEqual(snapshot, {
    active: true,
    expiresAt: new Date("2026-10-01T00:00:00Z"),
    productId: "com.chillnote.pro.yearly",
    store: "app_store",
    originalTransactionId: "original-1"
  });
});

test("missing RevenueCat entitlement is inactive without revoking legacy Pro", () => {
  const snapshot = revenueCatEntitlementSnapshot({}, "pro");
  const effective = effectiveSubscription({
    legacyTier: "pro",
    legacyExpiresAt: new Date("2026-10-01T00:00:00Z"),
    revenueCat: snapshot,
    now: new Date("2026-09-01T00:00:00Z")
  });
  assert.equal(effective.tier, "pro");
  assert.equal(effective.source, "legacy");
});

test("RevenueCat renewal extends the effective subscription", () => {
  const effective = effectiveSubscription({
    legacyTier: "pro",
    legacyExpiresAt: new Date("2026-09-10T00:00:00Z"),
    revenueCat: {
      active: true,
      expiresAt: new Date("2027-09-10T00:00:00Z"),
      productId: "yearly",
      store: "app_store",
      originalTransactionId: "original"
    },
    now: new Date("2026-09-01T00:00:00Z")
  });
  assert.equal(effective.source, "revenuecat");
  assert.equal(effective.expiresAt?.toISOString(), "2027-09-10T00:00:00.000Z");
});

test("deduplicates all RevenueCat webhook user identifiers", () => {
  assert.deepEqual(revenueCatWebhookUserIds({
    id: "event",
    type: "RENEWAL",
    event_timestamp_ms: 1,
    app_user_id: "user-1",
    original_app_user_id: "$RCAnonymousID:1",
    aliases: ["user-1", "user-2"]
  }), ["user-1", "$RCAnonymousID:1", "user-2"]);
});

test("verifies RevenueCat webhook HMAC and rejects stale timestamps", () => {
  const raw = JSON.stringify({ api_version: "1.0", event: { id: "event" } });
  const secret = "test-secret";
  const timestamp = 1_800_000_000;
  const signature = createHmac("sha256", secret).update(`${timestamp}.${raw}`).digest("hex");
  const header = `t=${timestamp},v1=${signature}`;
  assert.equal(verifyRevenueCatWebhookSignature(raw, header, secret, timestamp * 1_000), true);
  assert.equal(verifyRevenueCatWebhookSignature(raw, header, secret, timestamp * 1_000 + 600_000), false);
});
