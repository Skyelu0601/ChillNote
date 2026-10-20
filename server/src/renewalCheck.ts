import type { RevenueCatCustomerResponse, RevenueCatSubscription } from "./revenueCat.js";

export const RENEWAL_CHECK_DELAY_MS = 60 * 60_000;
export const RENEWAL_CHECK_WINDOW_MS = 24 * 60 * 60_000;

function date(value: string | null | undefined): Date | null {
  const parsed = value ? new Date(value) : null;
  return parsed && Number.isFinite(parsed.getTime()) ? parsed : null;
}

export function renewalSubscription(body: RevenueCatCustomerResponse, entitlementId: string): {
  productId: string;
  subscription: RevenueCatSubscription;
} | null {
  const productId = body.subscriber?.entitlements?.[entitlementId]?.product_identifier;
  if (!productId) return null;
  const match = Object.entries(body.subscriber?.subscriptions ?? {}).find(([id]) =>
    id === productId || id.split(":", 1)[0] === productId.split(":", 1)[0]);
  if (!match) return null;
  return { productId, subscription: match[1] };
}

export function nextRenewalCheck(subscription: RevenueCatSubscription, now = new Date()): Date | null {
  if (!eligible(subscription) || subscription.unsubscribe_detected_at
    || subscription.billing_issues_detected_at) return null;
  const graceExpiresAt = date(subscription.grace_period_expires_date);
  const purchasedAt = date(subscription.purchase_date);
  if (graceExpiresAt && (!purchasedAt || graceExpiresAt > purchasedAt)) return null;
  const expiresAt = date(subscription.expires_date);
  return expiresAt && expiresAt > now ? expiresAt : null;
}

function eligible(subscription: RevenueCatSubscription): boolean {
  return (subscription.store === "app_store" || subscription.store === "play_store")
    && subscription.is_sandbox !== true && !subscription.refunded_at
    && !subscription.auto_resume_date && subscription.ownership_type !== "FAMILY_SHARED";
}

export type RenewalCheckResult = "renewed" | "cancelled" | "billing_issue" | "pending";

export function renewalCheckResult(
  subscription: RevenueCatSubscription,
  expectedRenewalAt: Date
): RenewalCheckResult {
  if (!eligible(subscription)) return "cancelled";
  if (subscription.billing_issues_detected_at) return "billing_issue";
  if (subscription.unsubscribe_detected_at) return "cancelled";
  const purchasedAt = date(subscription.purchase_date);
  const expiresAt = date(subscription.expires_date);
  const graceExpiresAt = date(subscription.grace_period_expires_date);
  // A grace period can extend expiry without a successful charge. Require a
  // new paid/trial-conversion period, not merely a future entitlement expiry.
  if (purchasedAt && purchasedAt.getTime() >= expectedRenewalAt.getTime() - 60_000
    && expiresAt && expiresAt > expectedRenewalAt
    && (!graceExpiresAt || graceExpiresAt <= purchasedAt)) return "renewed";
  return "pending";
}

// Both early checks and later webhooks use the same key for this billing date.
export function billingRecoveryKey(userId: string, billingDate: Date): string {
  return `billing_issue:${userId}:${billingDate.toISOString()}`;
}
