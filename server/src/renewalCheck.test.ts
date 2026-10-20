import assert from "node:assert/strict";
import test from "node:test";
import type { RevenueCatSubscription } from "./revenueCat.js";
import { billingRecoveryKey, nextRenewalCheck, renewalCheckResult, renewalSubscription } from "./renewalCheck.js";

const due = new Date("2026-10-07T10:00:00Z");
const subscription: RevenueCatSubscription = {
  store: "play_store", purchase_date: "2026-09-07T10:00:00Z", expires_date: due.toISOString()
};

test("a renewal with no new payment confirmation receives a pending reminder on either store", () => {
  for (const store of ["play_store", "app_store"]) {
    assert.equal(renewalCheckResult({ ...subscription, store }, due), "pending");
  }
});

test("Google silent grace expiry extensions are not mistaken for successful payment", () => {
  assert.equal(renewalCheckResult({ ...subscription, expires_date: "2026-10-08T10:00:00Z" }, due), "pending");
  assert.equal(renewalCheckResult({
    ...subscription, expires_date: "2026-10-14T10:00:00Z", grace_period_expires_date: "2026-10-14T10:00:00Z"
  }, due), "pending");
});

test("a confirmed new billing period skips the reminder and schedules the following date", () => {
  const renewed = { ...subscription, purchase_date: due.toISOString(), expires_date: "2026-11-07T10:00:00Z" };
  assert.equal(renewalCheckResult(renewed, due), "renewed");
  assert.equal(nextRenewalCheck(renewed, due)?.toISOString(), "2026-11-07T10:00:00.000Z");
});

test("a historical grace deadline does not obscure a later successful billing period", () => {
  const renewed = {
    ...subscription, purchase_date: due.toISOString(), expires_date: "2026-11-07T10:00:00Z",
    grace_period_expires_date: "2026-10-05T10:00:00Z"
  };
  assert.equal(renewalCheckResult(renewed, due), "renewed");
  assert.equal(nextRenewalCheck(renewed, due)?.toISOString(), "2026-11-07T10:00:00.000Z");
});

test("confirmed billing errors take priority over store cancellation caused by payment failure", () => {
  assert.equal(renewalCheckResult({
    ...subscription, billing_issues_detected_at: due.toISOString(), unsubscribe_detected_at: due.toISOString()
  }, due), "billing_issue");
});

test("voluntary cancellation, refunds, pauses, family sharing, sandbox and unsupported stores never send", () => {
  for (const overrides of [
    { unsubscribe_detected_at: due.toISOString() }, { refunded_at: due.toISOString() },
    { auto_resume_date: "2026-11-07T10:00:00Z" }, { ownership_type: "FAMILY_SHARED" },
    { is_sandbox: true }, { store: "promotional" }, { store: "stripe" }
  ]) assert.equal(renewalCheckResult({ ...subscription, ...overrides }, due), "cancelled");
});

test("renewal checks follow only the entitlement's subscription including Google base-plan identifiers", () => {
  const body = { subscriber: {
    entitlements: { pro: { product_identifier: "com.chillnote.pro.yearly" } },
    subscriptions: { "unrelated": { store: "app_store" }, "com.chillnote.pro.yearly:yearly": subscription }
  } };
  assert.equal(renewalSubscription(body, "pro")?.subscription, subscription);
  assert.equal(renewalSubscription(body, "other"), null);
  assert.equal(renewalSubscription({ subscriber: { entitlements: body.subscriber.entitlements } }, "pro"), null);
});

test("invalid or indefinite expiry never creates a next billing date", () => {
  for (const expires_date of [null, "invalid", "2026-10-01T00:00:00Z"]) {
    assert.equal(nextRenewalCheck({ ...subscription, expires_date }, due), null);
  }
  assert.equal(renewalCheckResult({ ...subscription, purchase_date: "invalid" }, due), "pending");
});

test("webhook recovery and proactive reminder share the existing billing deduplication key", () => {
  assert.equal(billingRecoveryKey("user", due), "billing_issue:user:2026-10-07T10:00:00.000Z");
});
