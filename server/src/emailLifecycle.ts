import type { RevenueCatWebhook } from "./revenueCat.js";

export type LifecycleEmailKind =
  | "trial_ending_48h"
  | "trial_ending_24h"
  | "trial_cancelled_winback"
  | "billing_issue";

export type LifecycleEmailSchedule = {
  kind: LifecycleEmailKind;
  scheduledAt: Date;
  expectedExpiresAt: Date;
};

const TRIAL_ENDING_TYPES = new Set(["trial_ending_48h", "trial_ending_24h"]);
const LIFECYCLE_EMAIL_TYPES = new Set<LifecycleEmailKind>([
  "trial_ending_48h",
  "trial_ending_24h",
  "trial_cancelled_winback",
  "billing_issue"
]);

export function trialEmailSchedules(
  event: RevenueCatWebhook["event"],
  now = new Date()
): LifecycleEmailSchedule[] {
  if (event.period_type !== "TRIAL" || !Number.isFinite(event.expiration_at_ms)) return [];
  if (event.type !== "INITIAL_PURCHASE" && event.type !== "UNCANCELLATION") return [];

  const expectedExpiresAt = new Date(event.expiration_at_ms!);
  if (Number.isNaN(expectedExpiresAt.getTime()) || expectedExpiresAt <= now) return [];

  return ([
    ["trial_ending_48h", 48]
  ] as const).flatMap(([kind, hours]) => {
    const scheduledAt = new Date(expectedExpiresAt.getTime() - hours * 60 * 60 * 1000);
    return scheduledAt > now ? [{ kind, scheduledAt, expectedExpiresAt }] : [];
  });
}

export function cancelledTrialEmailSchedules(
  event: RevenueCatWebhook["event"],
  now = new Date()
): LifecycleEmailSchedule[] {
  if (event.type !== "CANCELLATION" || event.period_type !== "TRIAL" || event.cancel_reason !== "UNSUBSCRIBE") {
    return [];
  }
  if (!Number.isFinite(event.expiration_at_ms)) return [];
  const expectedExpiresAt = new Date(event.expiration_at_ms!);
  if (Number.isNaN(expectedExpiresAt.getTime()) || expectedExpiresAt <= now) return [];

  const dayBeforeExpiry = new Date(expectedExpiresAt.getTime() - 24 * 60 * 60 * 1000);
  return [{
    kind: "trial_cancelled_winback",
    scheduledAt: dayBeforeExpiry > now ? dayBeforeExpiry : now,
    expectedExpiresAt
  }];
}

export function billingIssueEmailSchedules(
  event: RevenueCatWebhook["event"],
  now = new Date()
): LifecycleEmailSchedule[] {
  if (event.type !== "BILLING_ISSUE") return [];
  const deadlineMs = Number.isFinite(event.grace_period_expiration_at_ms)
    ? event.grace_period_expiration_at_ms!
    : Number.isFinite(event.expiration_at_ms) ? event.expiration_at_ms! : event.event_timestamp_ms;
  const expectedExpiresAt = new Date(deadlineMs);
  return Number.isNaN(expectedExpiresAt.getTime()) ? [] : [{
    kind: "billing_issue",
    scheduledAt: now,
    expectedExpiresAt
  }];
}

export function lifecycleEmailSchedules(
  event: RevenueCatWebhook["event"],
  now = new Date()
): LifecycleEmailSchedule[] {
  return [
    ...trialEmailSchedules(event, now),
    ...cancelledTrialEmailSchedules(event, now),
    ...billingIssueEmailSchedules(event, now)
  ];
}

export function lifecycleEmailKindsToCancel(event: RevenueCatWebhook["event"]): LifecycleEmailKind[] {
  if (event.type === "TRANSFER") return [...LIFECYCLE_EMAIL_TYPES];
  if (event.type === "RENEWAL") {
    return ["trial_ending_48h", "trial_ending_24h", "trial_cancelled_winback", "billing_issue"];
  }
  if (event.type === "CANCELLATION") return ["trial_ending_48h", "trial_ending_24h"];
  if (event.type === "UNCANCELLATION") return ["trial_cancelled_winback"];
  if (event.type === "EXPIRATION") return ["trial_ending_48h", "trial_ending_24h", "trial_cancelled_winback"];
  return [];
}

export function shouldCancelTrialEmails(event: RevenueCatWebhook["event"]): boolean {
  const kinds = lifecycleEmailKindsToCancel(event);
  return kinds.includes("trial_ending_48h") || kinds.includes("trial_ending_24h");
}

export function isTrialEndingKind(value: string): value is "trial_ending_48h" | "trial_ending_24h" {
  return TRIAL_ENDING_TYPES.has(value);
}

export function isLifecycleEmailKind(value: string): value is LifecycleEmailKind {
  return LIFECYCLE_EMAIL_TYPES.has(value as LifecycleEmailKind);
}
