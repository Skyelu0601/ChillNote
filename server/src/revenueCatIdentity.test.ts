import assert from "node:assert/strict";
import test from "node:test";
import { accountRevenueCatSnapshot, canonicalRevenueCatUserId, revenueCatWebhookUserIds, type RevenueCatCustomerResponse } from "./revenueCat.js";

const lower = "c1a99945-082b-423f-bc09-eca9176b14f5";
const upper = lower.toUpperCase();
const inactive: RevenueCatCustomerResponse = { subscriber: { entitlements: {} } };
const active = (store = "app_store"): RevenueCatCustomerResponse => ({ subscriber: {
  entitlements: { pro: { product_identifier: "yearly", expires_date: "2099-01-01" } },
  subscriptions: { yearly: { store, store_transaction_id: "verified-transaction" } }
} });

test("canonicalizes UUIDs only, preserving opaque and anonymous IDs", () => {
  assert.equal(canonicalRevenueCatUserId(upper), lower);
  for (const id of ["$RCAnonymousID:AbC", "CustomAccount", "not-a-uuid", " " + upper]) {
    assert.equal(canonicalRevenueCatUserId(id), id);
  }
});

test("webhooks collapse uppercase aliases and transfer participants to one database user", () => {
  assert.deepEqual(revenueCatWebhookUserIds({ id: "event", type: "TRANSFER", event_timestamp_ms: 1,
    transferred_from: [upper, "$RCAnonymousID:AbC"], transferred_to: [lower], aliases: [upper]
  }), [lower, "$RCAnonymousID:AbC"]);
});

test("canonical active identity wins without querying the legacy customer", async () => {
  const calls: string[] = [];
  const result = await accountRevenueCatSnapshot(upper, "pro", async id => { calls.push(id); return active(); });
  assert.equal(result.active, true);
  assert.deepEqual(calls, [lower]);
});

test("legacy uppercase Apple entitlement supports old apps without receipt transfer", async () => {
  const calls: string[] = [];
  const result = await accountRevenueCatSnapshot(lower, "pro", async id => {
    calls.push(id); return id === upper ? active() : inactive;
  });
  assert.equal(result.active, true);
  assert.equal(result.storeTransactionId, "verified-transaction");
  assert.deepEqual(calls, [lower, upper]);
});

test("expired/absent identities remain free and other stores cannot use Apple fallback", async () => {
  assert.equal((await accountRevenueCatSnapshot(lower, "pro", async () => inactive)).active, false);
  assert.equal((await accountRevenueCatSnapshot(lower, "pro", async id => id === upper ? active("play_store") : inactive)).active, false);
  const expired = active(); expired.subscriber!.entitlements!.pro.expires_date = "2000-01-01";
  assert.equal((await accountRevenueCatSnapshot(lower, "pro", async id => id === upper ? expired : inactive)).active, false);
});

test("provider errors propagate instead of revoking membership or trusting metadata", async () => {
  await assert.rejects(accountRevenueCatSnapshot(lower, "pro", async id => {
    if (id === upper) throw Error("provider unavailable"); return inactive;
  }), /provider unavailable/);
});

test("custom non-UUID accounts never trigger uppercase lookup", async () => {
  const calls: string[] = [];
  await accountRevenueCatSnapshot("CaseSensitiveUser", "pro", async id => { calls.push(id); return inactive; });
  assert.deepEqual(calls, ["CaseSensitiveUser"]);
});
