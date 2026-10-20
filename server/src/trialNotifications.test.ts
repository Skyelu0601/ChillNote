import assert from "node:assert/strict";
import test from "node:test";
import type { Prisma } from "@prisma/client";
import { maskEmail, readTrialDetails, syncTrialNotification, trialInboxContent } from "./trialNotifications.js";

const now = new Date("2026-10-10T12:00:00Z");
const expiresAt = new Date("2026-10-17T12:00:00Z");
const details = { type: "trial" as const, expiresAt: expiresAt.toISOString(), productId: "yearly:annual", store: "play_store" as const, autoRenew: true };
const delivery = { status: "scheduled", scheduledAt: new Date("2026-10-15T12:00:00Z"), expectedExpiresAt: expiresAt, sentAt: null };
const params = { details, delivery, identity: { email: "creator@example.com", verified: true },
  activeTrial: true, emailConfigured: true, emailEnabled: true, suppressed: false, now };

test("only a matching 48-hour queue with a verified recipient confirms the schedule", () => {
  const content = trialInboxContent(params);
  assert.equal(content.reminderStatus, "scheduled");
  assert.equal(content.reminderAt, delivery.scheduledAt.toISOString());
  assert.equal(content.maskedEmail, "c***@example.com");
  assert.equal(content.manageSubscriptionURL, "https://play.google.com/store/account/subscriptions");
  for (const entry of [null, { ...delivery, expectedExpiresAt: new Date("2026-10-18T12:00:00Z") },
    { ...delivery, scheduledAt: new Date("2026-10-16T12:00:00Z") }]) {
    assert.equal(trialInboxContent({ ...params, delivery: entry }).reminderStatus, "pending");
  }
});

test("cancelled, skipped, failed and bounced queues never confirm a reminder", () => {
  for (const status of ["cancelled", "skipped", "failed"]) {
    assert.equal(trialInboxContent({ ...params, delivery: { ...delivery, status } }).reminderStatus, "unavailable");
  }
  assert.equal(trialInboxContent({ ...params, delivery: { ...delivery, bouncedAt: now } }).reminderStatus, "unavailable");
});

test("due and late jobs stay pending until SES accepts the email; sent copy cannot invent an old recipient", () => {
  const due = new Date("2026-10-15T12:05:00Z");
  assert.equal(trialInboxContent({ ...params, now: due }).reminderStatus, "pending");
  assert.equal(trialInboxContent({ ...params, now: due, delivery: null }).reminderStatus, "unavailable");
  const content = trialInboxContent({ ...params, now: due, delivery: { ...delivery, status: "sent", sentAt: due } });
  assert.equal(content.reminderStatus, "sent");
  assert.equal(content.reminderAt, due.toISOString());
  assert.equal(content.maskedEmail, null);
  assert.equal(trialInboxContent({ ...params, now: due,
    delivery: { ...delivery, status: "sent", sentAt: due, scheduledAt: due }
  }).reminderStatus, "sent", "a retry does not erase a successful send");
});

test("cancellation and expired or transferred trials supersede the original confirmation", () => {
  assert.equal(trialInboxContent({ ...params, details: { ...details, autoRenew: false } }).reminderStatus, "cancelled");
  assert.equal(trialInboxContent({ ...params, now: expiresAt }).reminderStatus, "ended");
  assert.equal(trialInboxContent({ ...params, activeTrial: false }).reminderStatus, "ended");
  assert.equal(trialInboxContent({ ...params, details: { ...details, store: "app_store" } }).manageSubscriptionURL,
    "https://apps.apple.com/account/subscriptions");
});

test("invalid metadata fails safely and email addresses are masked", () => {
  for (const value of [null, {}, { ...details, expiresAt: "broken" }, { ...details, store: "stripe" }]) {
    assert.equal(readTrialDetails(value), null);
  }
  assert.equal(maskEmail(" creator@example.com "), "c***@example.com");
  assert.equal(maskEmail("broken"), null);
});

test("trial refreshes and cancellation update the same persisted item without resetting read state", async () => {
  const records = new Map<string, any>();
  const tx = { appNotification: { upsert: async ({ create, update }: any) => {
    const key = `${create.userId}:${create.dedupeKey}`;
    if (records.has(key)) Object.assign(records.get(key), update);
    else records.set(key, { ...create, readAt: null });
  } } } as unknown as Pick<Prisma.TransactionClient, "appNotification">;
  const snapshot = { active: true, expiresAt, productId: "yearly:annual", store: "play_store", originalTransactionId: null,
    trial: { expiresAt, startedAt: now, productId: "yearly:annual", store: "play_store", autoRenew: true } };
  await syncTrialNotification(tx, "user-a", snapshot);
  const first = [...records.values()][0];
  first.readAt = now;
  await syncTrialNotification(tx, "user-a", snapshot);
  await syncTrialNotification(tx, "user-a", { ...snapshot, trial: { ...snapshot.trial, autoRenew: false } });
  assert.equal(records.size, 1);
  assert.equal(first.readAt, now);
  assert.equal(first.details.autoRenew, false);
  const extended = new Date(expiresAt.getTime() + 24 * 60 * 60_000);
  await syncTrialNotification(tx, "user-a", { ...snapshot, expiresAt: extended, trial: { ...snapshot.trial, expiresAt: extended } });
  assert.equal(records.size, 1);
  assert.equal(first.readAt, now);
  assert.equal(first.details.expiresAt, extended.toISOString());
  await syncTrialNotification(tx, "user-a", { ...snapshot, active: false });
  await syncTrialNotification(tx, "user-a", { ...snapshot, trial: undefined });
  assert.equal(records.size, 1);
  await syncTrialNotification(tx, "user-b", snapshot);
  assert.equal(records.size, 2);
});
