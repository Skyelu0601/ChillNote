import { createHmac, timingSafeEqual } from "node:crypto";

export type RevenueCatEntitlementSnapshot = {
  active: boolean;
  expiresAt: Date | null;
  productId: string | null;
  store: string | null;
  originalTransactionId: string | null;
};

type RevenueCatSubscription = {
  expires_date?: string | null;
  store?: string | null;
  original_transaction_id?: string | null;
};

export type RevenueCatCustomerResponse = {
  subscriber?: {
    entitlements?: Record<string, {
      expires_date?: string | null;
      product_identifier?: string | null;
    }>;
    subscriptions?: Record<string, RevenueCatSubscription>;
  };
};

export type RevenueCatWebhook = {
  api_version: string;
  event: {
    id: string;
    type: string;
    event_timestamp_ms: number;
    app_user_id?: string | null;
    original_app_user_id?: string | null;
    aliases?: string[] | null;
    app_id?: string | null;
    environment?: string | null;
  };
};

function validDate(value: string | null | undefined): Date | null {
  if (!value) return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function baseProductId(value: string): string {
  return value.split(":", 1)[0];
}

export function revenueCatEntitlementSnapshot(
  body: RevenueCatCustomerResponse,
  entitlementId: string,
  now = new Date()
): RevenueCatEntitlementSnapshot {
  const entitlement = body.subscriber?.entitlements?.[entitlementId];
  if (!entitlement) {
    return { active: false, expiresAt: null, productId: null, store: null, originalTransactionId: null };
  }

  const productId = entitlement.product_identifier?.trim() || null;
  const expiresAt = validDate(entitlement.expires_date);
  const active = expiresAt == null || expiresAt.getTime() > now.getTime();
  const subscriptions = body.subscriber?.subscriptions ?? {};
  const matchingSubscription = productId
    ? Object.entries(subscriptions).find(([candidate]) =>
        candidate === productId || baseProductId(candidate) === baseProductId(productId))?.[1]
    : undefined;

  return {
    active,
    expiresAt,
    productId,
    store: matchingSubscription?.store?.trim() || null,
    originalTransactionId: matchingSubscription?.original_transaction_id?.trim() || null
  };
}

export function revenueCatWebhookUserIds(event: RevenueCatWebhook["event"]): string[] {
  const candidates = [event.app_user_id, event.original_app_user_id, ...(event.aliases ?? [])];
  return [...new Set(candidates.filter((value): value is string => typeof value === "string" && value.length > 0))];
}

export function verifyRevenueCatWebhookSignature(
  rawBody: string,
  signatureHeader: string | string[] | undefined,
  secret: string,
  nowMs = Date.now(),
  toleranceMs = 5 * 60_000
): boolean {
  if (!secret || !signatureHeader || Array.isArray(signatureHeader)) return false;
  const fields = Object.fromEntries(
    signatureHeader.split(",").map((part) => part.trim().split("=", 2) as [string, string])
  );
  const timestampSeconds = Number(fields.t);
  const received = fields.v1;
  if (!Number.isFinite(timestampSeconds) || !received || !/^[a-f0-9]{64}$/i.test(received)) return false;
  if (Math.abs(nowMs - timestampSeconds * 1_000) > toleranceMs) return false;

  const expected = createHmac("sha256", secret)
    .update(`${timestampSeconds}.${rawBody}`)
    .digest("hex");
  const expectedBuffer = Buffer.from(expected, "hex");
  const receivedBuffer = Buffer.from(received, "hex");
  return expectedBuffer.length === receivedBuffer.length
    && timingSafeEqual(expectedBuffer, receivedBuffer);
}

export function effectiveSubscription(params: {
  legacyTier: string | null | undefined;
  legacyExpiresAt: Date | null | undefined;
  revenueCat?: RevenueCatEntitlementSnapshot | null;
  now?: Date;
}): { tier: "free" | "pro"; expiresAt: Date | null; source: "legacy" | "revenuecat" | null } {
  const now = params.now ?? new Date();
  const legacyActive = params.legacyTier === "pro"
    && (!params.legacyExpiresAt || params.legacyExpiresAt.getTime() > now.getTime());
  const revenueCatActive = params.revenueCat?.active === true
    && (!params.revenueCat.expiresAt || params.revenueCat.expiresAt.getTime() > now.getTime());
  if (!legacyActive && !revenueCatActive) return { tier: "free", expiresAt: null, source: null };

  if (legacyActive && !revenueCatActive) {
    return { tier: "pro", expiresAt: params.legacyExpiresAt ?? null, source: "legacy" };
  }
  if (revenueCatActive && !legacyActive) {
    return { tier: "pro", expiresAt: params.revenueCat?.expiresAt ?? null, source: "revenuecat" };
  }

  if (!params.legacyExpiresAt) return { tier: "pro", expiresAt: null, source: "legacy" };
  if (!params.revenueCat?.expiresAt) return { tier: "pro", expiresAt: null, source: "revenuecat" };
  return params.revenueCat.expiresAt.getTime() >= params.legacyExpiresAt.getTime()
    ? { tier: "pro", expiresAt: params.revenueCat.expiresAt, source: "revenuecat" }
    : { tier: "pro", expiresAt: params.legacyExpiresAt, source: "legacy" };
}
