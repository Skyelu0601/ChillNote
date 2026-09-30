import assert from "node:assert/strict";
import test from "node:test";
import {
  billingIssueEmailSchedules,
  cancelledTrialEmailSchedules,
  lifecycleEmailKindsToCancel,
  shouldCancelTrialEmails,
  trialEmailSchedules
} from "./emailLifecycle.js";
import type { RevenueCatWebhook } from "./revenueCat.js";

function event(overrides: Partial<RevenueCatWebhook["event"]> = {}): RevenueCatWebhook["event"] {
  return {
    id: "event-1",
    type: "INITIAL_PURCHASE",
    event_timestamp_ms: Date.parse("2026-09-21T00:00:00Z"),
    period_type: "TRIAL",
    expiration_at_ms: Date.parse("2026-09-28T00:00:00Z"),
    ...overrides
  };
}

test("schedules one trial reminder 48 hours before expiration", () => {
  const schedules = trialEmailSchedules(event(), new Date("2026-09-21T00:00:00Z"));
  assert.deepEqual(schedules.map((item) => [item.kind, item.scheduledAt.toISOString()]), [
    ["trial_ending_48h", "2026-09-26T00:00:00.000Z"]
  ]);
});

test("does not schedule non-trial or already elapsed reminders", () => {
  assert.deepEqual(trialEmailSchedules(event({ period_type: "NORMAL" })), []);
  const schedules = trialEmailSchedules(event(), new Date("2026-09-26T12:00:00Z"));
  assert.deepEqual(schedules, []);
});

test("cancellation and subscription completion cancel pending reminders", () => {
  assert.equal(shouldCancelTrialEmails(event({ type: "CANCELLATION" })), true);
  assert.equal(shouldCancelTrialEmails(event({ type: "RENEWAL" })), true);
  assert.equal(shouldCancelTrialEmails(event({ type: "EXPIRATION" })), true);
  assert.equal(shouldCancelTrialEmails(event()), false);
});

test("voluntary trial cancellation schedules one win-back near expiry", () => {
  const schedules = cancelledTrialEmailSchedules(event({
    type: "CANCELLATION",
    cancel_reason: "UNSUBSCRIBE"
  }), new Date("2026-09-21T00:00:00Z"));

  assert.deepEqual(schedules.map((item) => [item.kind, item.scheduledAt.toISOString()]), [
    ["trial_cancelled_winback", "2026-09-27T00:00:00.000Z"]
  ]);
  assert.deepEqual(cancelledTrialEmailSchedules(event({
    type: "CANCELLATION",
    cancel_reason: "BILLING_ERROR"
  })), []);
});

test("late voluntary cancellation schedules the win-back immediately", () => {
  const now = new Date("2026-09-27T12:00:00Z");
  const schedules = cancelledTrialEmailSchedules(event({
    type: "CANCELLATION",
    cancel_reason: "UNSUBSCRIBE"
  }), now);
  assert.equal(schedules[0]?.scheduledAt.toISOString(), now.toISOString());
});

test("billing issue schedules an immediate payment recovery email", () => {
  const now = new Date("2026-09-28T00:00:01Z");
  const schedules = billingIssueEmailSchedules(event({
    type: "BILLING_ISSUE",
    period_type: "NORMAL",
    grace_period_expiration_at_ms: Date.parse("2026-10-05T00:00:00Z")
  }), now);
  assert.equal(schedules[0]?.kind, "billing_issue");
  assert.equal(schedules[0]?.scheduledAt.toISOString(), now.toISOString());
  assert.equal(schedules[0]?.expectedExpiresAt.toISOString(), "2026-10-05T00:00:00.000Z");
});

test("lifecycle transitions cancel only incompatible messages", () => {
  assert.deepEqual(lifecycleEmailKindsToCancel(event({ type: "CANCELLATION" })), [
    "trial_ending_48h",
    "trial_ending_24h"
  ]);
  assert.deepEqual(lifecycleEmailKindsToCancel(event({ type: "UNCANCELLATION" })), [
    "trial_cancelled_winback"
  ]);
  assert.deepEqual(lifecycleEmailKindsToCancel(event({ type: "RENEWAL" })), [
    "trial_ending_48h",
    "trial_ending_24h",
    "trial_cancelled_winback",
    "billing_issue"
  ]);
});
