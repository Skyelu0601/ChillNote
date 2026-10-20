import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import test from "node:test";
import {
  effectiveSubscription,
  revenueCatEntitlementSnapshot,
  revenueCatWebhookUserIds,
  verifyRevenueCatWebhookSignature
} from "./revenueCat.js";
import type { RevenueCatSubscription } from "./revenueCat.js";

test("only active mobile store trial periods create confirmation metadata, including cancelled trials", () => {
  const parse = (subscription: RevenueCatSubscription) => revenueCatEntitlementSnapshot({ subscriber: {
    entitlements: { pro: { product_identifier: "pro_yearly:annual", expires_date: "2026-10-17T12:00:00Z" } },
    subscriptions: { "pro_yearly:annual": subscription }
  } }, "pro", new Date("2026-10-10T12:00:00Z"));
  const trial = { store: "play_store", period_type: "trial" };
  assert.equal(parse(trial).trial?.autoRenew, true);
  assert.equal(parse({ ...trial, unsubscribe_detected_at: "2026-10-10T12:00:00Z" }).trial?.autoRenew, false);
  for (const subscription of [{ ...trial, period_type: "normal" }, { ...trial, period_type: "intro" },
    { store: "app_store" }, { ...trial, store: "stripe" }, { ...trial, billing_issues_detected_at: "2026-10-10" },
    { ...trial, grace_period_expires_date: "2026-10-20" }, { ...trial, refunded_at: "2026-10-10" },
    { ...trial, ownership_type: "FAMILY_SHARED" }, { ...trial, expires_date: "2026-10-01T12:00:00Z" }]) {
    assert.equal(parse(subscription).trial, undefined);
  }
});

test("an older trial on another Google base plan cannot replace the exact paid subscription", () => {
  const snapshot = revenueCatEntitlementSnapshot({ subscriber: {
    entitlements: { pro: { product_identifier: "yearly:annual", expires_date: "2099-01-01" } },
    subscriptions: {
      "yearly:old-plan": { store: "play_store", period_type: "trial", expires_date: "2026-01-01" },
      "yearly:annual": { store: "play_store", period_type: "normal", expires_date: "2099-01-01", store_transaction_id: "paid" }
    }
  } }, "pro");
  assert.equal(snapshot.trial, undefined);
  assert.equal(snapshot.storeTransactionId, "paid");
});

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
    originalTransactionId: "original-1",
    storeTransactionId: null
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

test("Apple metadata cannot keep Pro after a transfer, expiry or fabricated unlimited grant", () => {
  for (const expiresAt of [null, new Date("2099-01-01")]) {
    assert.equal(effectiveSubscription({
      legacyTier: "pro", legacyExpiresAt: expiresAt, legacyProvider: "apple",
      revenueCat: revenueCatEntitlementSnapshot({}, "pro")
    }).tier, "free");
  }
});

test("revoking Apple does not revoke another payment provider", () => {
  for (const provider of ["google_play", "creem"]) {
    assert.equal(effectiveSubscription({
      legacyTier: "pro", legacyExpiresAt: new Date("2099-01-01"), legacyProvider: provider,
      revenueCat: revenueCatEntitlementSnapshot({}, "pro")
    }).tier, "pro");
  }
});

test("a TRANSFER without app_user_id refreshes both sides and every alias", () => {
  assert.deepEqual(revenueCatWebhookUserIds({
    id: "transfer", type: "TRANSFER", event_timestamp_ms: 1,
    transferred_from: ["old-user", "old-alias"],
    transferred_to: ["new-user", "new-alias", "new-user"]
  }), ["old-user", "old-alias", "new-user", "new-alias"]);
});

test("reads RevenueCat v1 store transaction IDs without confusing them with original IDs", () => {
  const snapshot = revenueCatEntitlementSnapshot({ subscriber: {
    entitlements: { pro: { product_identifier: "yearly", expires_date: "2099-01-01" } },
    subscriptions: { yearly: { store: "app_store", store_transaction_id: "current-renewal" } }
  } }, "pro");
  assert.equal(snapshot.storeTransactionId, "current-renewal");
  assert.equal(snapshot.originalTransactionId, null);
});
