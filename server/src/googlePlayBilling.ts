import { randomUUID } from "node:crypto";

export const GOOGLE_PLAY_STATUS = {
  received: "RECEIVED",
  processing: "PROCESSING",
  ackRetry: "ACK_RETRY",
  ackBlocked: "ACK_BLOCKED",
  entitled: "ENTITLED",
  inactive: "INACTIVE"
} as const;

const ACKNOWLEDGED = "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED";
const ACK_PENDING = "ACKNOWLEDGEMENT_STATE_PENDING";
const ENTITLED_SUBSCRIPTION_STATES = new Set([
  "SUBSCRIPTION_STATE_ACTIVE",
  "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
  "SUBSCRIPTION_STATE_CANCELED"
]);

export type GooglePlayPublisherErrorCode =
  | "INVALID_PURCHASE"
  | "PUBLISHER_AUTH"
  | "RATE_LIMITED"
  | "PUBLISHER_UNAVAILABLE"
  | "NETWORK"
  | "TIMEOUT"
  | "UNKNOWN";

export class GooglePlayPublisherError extends Error {
  constructor(
    public readonly code: GooglePlayPublisherErrorCode,
    public readonly retryable: boolean,
    public readonly status?: number
  ) {
    super(code);
    this.name = "GooglePlayPublisherError";
  }
}

export type GooglePlaySubscription = {
  subscriptionState?: string | null;
  acknowledgementState?: string | null;
  latestOrderId?: string | null;
  linkedPurchaseToken?: string | null;
  externalAccountIdentifiers?: {
    obfuscatedExternalAccountId?: string | null;
  } | null;
  lineItems?: Array<{
    productId?: string | null;
    expiryTime?: string | null;
  }> | null;
};

export interface GooglePlayPublisher {
  getSubscription(purchaseToken: string): Promise<GooglePlaySubscription>;
  acknowledge(productId: string, purchaseToken: string): Promise<void>;
}

export type StoredGooglePlayPurchase = {
  purchaseToken: string;
  userId: string;
  productId: string;
  status: string;
  expiresAt: Date | null;
  acknowledgementState: string | null;
  ackAttempts: number;
};

export type ClaimGooglePlayPurchaseResult =
  | { kind: "claimed"; purchase: StoredGooglePlayPurchase }
  | { kind: "owner_conflict"; ownerUserId: string }
  | { kind: "product_conflict"; productId: string };

export interface GooglePlayBillingStore {
  findByToken(purchaseToken: string): Promise<StoredGooglePlayPurchase | null>;
  claimPurchase(input: {
    purchaseToken: string;
    userId: string;
    productId: string;
    packageName: string;
    now: Date;
  }): Promise<ClaimGooglePlayPurchaseResult>;
  saveVerification(input: {
    purchaseToken: string;
    userId: string;
    subscriptionState: string;
    acknowledgementState: string;
    latestOrderId: string | null;
    linkedPurchaseToken: string | null;
    expiresAt: Date;
    verifiedAt: Date;
    nextAttemptAt: Date | null;
  }): Promise<void>;
  beginProcessing(input: {
    purchaseToken: string;
    userId: string;
    processingId: string;
    startedAt: Date;
    staleBefore: Date;
    incrementAckAttempts: boolean;
  }): Promise<{ acquired: boolean; ackAttempts: number }>;
  grantEntitlement(input: {
    purchaseToken: string;
    userId: string;
    processingId: string;
    expiresAt: Date;
    acknowledgedAt: Date;
  }): Promise<boolean>;
  markInactive(input: {
    purchaseToken: string;
    userId: string;
    subscriptionState: string;
    acknowledgementState: string | null;
    latestOrderId: string | null;
    linkedPurchaseToken: string | null;
    expiresAt: Date | null;
    verifiedAt: Date;
  }): Promise<boolean>;
  finishProcessingFailure(input: {
    purchaseToken: string;
    userId: string;
    processingId: string;
    errorCode: string;
    retryable: boolean;
    nextAttemptAt: Date | null;
  }): Promise<void>;
  deferExistingPurchase(input: {
    purchaseToken: string;
    userId: string;
    errorCode: string;
    nextAttemptAt: Date | null;
  }): Promise<void>;
  listDuePurchases(input: {
    now: Date;
    staleBefore: Date;
    limit: number;
  }): Promise<Array<{ purchaseToken: string; userId: string; productId: string }>>;
}

export type GooglePlayVerificationResult =
  | { ok: true; tier: "pro"; expiresAt: Date }
  | {
      ok: false;
      httpStatus: 400 | 409 | 502 | 503;
      code:
        | "INVALID_PURCHASE"
        | "PURCHASE_ACCOUNT_MISMATCH"
        | "PURCHASE_TOKEN_OWNED_BY_ANOTHER_USER"
        | "PURCHASE_TOKEN_PRODUCT_MISMATCH"
        | "SUBSCRIPTION_INACTIVE"
        | "ACKNOWLEDGEMENT_FAILED"
        | "PROCESSING_IN_PROGRESS"
        | "PUBLISHER_UNAVAILABLE";
      retryable: boolean;
      subscriptionState?: string;
      expiresAt?: Date | null;
    };

type GooglePlayVerificationFailure = Exclude<GooglePlayVerificationResult, { ok: true }>;

export type VerifyGooglePlayPurchaseInput = {
  userId: string;
  productId: string;
  purchaseToken: string;
};

export type GooglePlayBillingDependencies = {
  publisher: GooglePlayPublisher;
  store: GooglePlayBillingStore;
  packageName: string;
  accountIdForUser(userId: string): string;
  now?: () => Date;
  newProcessingId?: () => string;
  random?: () => number;
  processingLeaseMs?: number;
  onEntitlementChanged?: (userId: string) => void;
};

type ValidatedPurchase = {
  subscriptionState: string;
  acknowledgementState: string;
  latestOrderId: string | null;
  linkedPurchaseToken: string | null;
  expiresAt: Date;
  entitled: boolean;
};

function publisherFailure(error: unknown): GooglePlayVerificationFailure {
  if (error instanceof GooglePlayPublisherError && error.code === "INVALID_PURCHASE") {
    return { ok: false, httpStatus: 400, code: "INVALID_PURCHASE", retryable: false };
  }
  return {
    ok: false,
    httpStatus: 503,
    code: "PUBLISHER_UNAVAILABLE",
    retryable: error instanceof GooglePlayPublisherError ? error.retryable : true
  };
}

function errorCode(error: unknown): string {
  return error instanceof GooglePlayPublisherError ? error.code : "UNKNOWN";
}

function isRetryable(error: unknown): boolean {
  return error instanceof GooglePlayPublisherError ? error.retryable : true;
}

export function googlePlayRetryDelayMs(attempt: number, random = Math.random): number {
  const baseMs = 30_000;
  const cappedExponent = Math.min(Math.max(attempt - 1, 0), 9);
  const withoutJitter = Math.min(baseMs * 2 ** cappedExponent, 6 * 60 * 60 * 1_000);
  return Math.round(withoutJitter * (1 + Math.max(0, Math.min(1, random())) * 0.2));
}

function validatedPurchase(
  purchase: GooglePlaySubscription,
  productId: string,
  expectedAccountId: string,
  now: Date
): ValidatedPurchase | GooglePlayVerificationFailure {
  const boundAccountId = purchase.externalAccountIdentifiers?.obfuscatedExternalAccountId?.trim();
  // Android always sends this binding for new purchases. A missing binding is
  // not safe to claim for the first account that happens to submit the token.
  if (!boundAccountId || boundAccountId !== expectedAccountId) {
    return {
      ok: false,
      httpStatus: 409,
      code: "PURCHASE_ACCOUNT_MISMATCH",
      retryable: false
    };
  }

  const matchingExpiries = (purchase.lineItems ?? [])
    .filter((line) => line.productId === productId && line.expiryTime)
    .map((line) => new Date(line.expiryTime as string))
    .filter((date) => !Number.isNaN(date.getTime()));
  const expiresAt = matchingExpiries.sort((left, right) => right.getTime() - left.getTime())[0];
  if (!expiresAt) {
    return { ok: false, httpStatus: 400, code: "INVALID_PURCHASE", retryable: false };
  }

  const subscriptionState = purchase.subscriptionState ?? "SUBSCRIPTION_STATE_UNSPECIFIED";
  const acknowledgementState = purchase.acknowledgementState ?? "ACKNOWLEDGEMENT_STATE_UNSPECIFIED";
  if (acknowledgementState !== ACKNOWLEDGED && acknowledgementState !== ACK_PENDING) {
    return { ok: false, httpStatus: 400, code: "INVALID_PURCHASE", retryable: false };
  }

  return {
    subscriptionState,
    acknowledgementState,
    latestOrderId: purchase.latestOrderId ?? null,
    linkedPurchaseToken: purchase.linkedPurchaseToken ?? null,
    expiresAt,
    entitled: ENTITLED_SUBSCRIPTION_STATES.has(subscriptionState) && expiresAt.getTime() > now.getTime()
  };
}

function isFailure(
  value: ValidatedPurchase | GooglePlayVerificationFailure
): value is GooglePlayVerificationFailure {
  return "ok" in value && value.ok === false;
}

async function ownedByAnotherUser(
  store: GooglePlayBillingStore,
  purchaseToken: string | null,
  userId: string
): Promise<boolean> {
  if (!purchaseToken) return false;
  const linked = await store.findByToken(purchaseToken);
  return linked != null && linked.userId !== userId;
}

async function successfulOrInProgress(
  store: GooglePlayBillingStore,
  purchaseToken: string,
  userId: string,
  now: Date
): Promise<GooglePlayVerificationResult> {
  const current = await store.findByToken(purchaseToken);
  if (
    current?.userId === userId &&
    current.status === GOOGLE_PLAY_STATUS.entitled &&
    current.expiresAt != null &&
    current.expiresAt.getTime() > now.getTime()
  ) {
    return { ok: true, tier: "pro", expiresAt: current.expiresAt };
  }
  return {
    ok: false,
    httpStatus: 503,
    code: "PROCESSING_IN_PROGRESS",
    retryable: true
  };
}

export async function verifyGooglePlayPurchase(
  input: VerifyGooglePlayPurchaseInput,
  dependencies: GooglePlayBillingDependencies
): Promise<GooglePlayVerificationResult> {
  const now = dependencies.now?.() ?? new Date();
  const processingLeaseMs = dependencies.processingLeaseMs ?? 5 * 60_000;
  const existing = await dependencies.store.findByToken(input.purchaseToken);
  if (existing && existing.userId !== input.userId) {
    return {
      ok: false,
      httpStatus: 409,
      code: "PURCHASE_TOKEN_OWNED_BY_ANOTHER_USER",
      retryable: false
    };
  }
  if (existing && existing.productId !== input.productId) {
    return {
      ok: false,
      httpStatus: 409,
      code: "PURCHASE_TOKEN_PRODUCT_MISMATCH",
      retryable: false
    };
  }

  let purchase: GooglePlaySubscription;
  try {
    purchase = await dependencies.publisher.getSubscription(input.purchaseToken);
  } catch (error) {
    if (existing) {
      const retryable = isRetryable(error);
      await dependencies.store.deferExistingPurchase({
        purchaseToken: input.purchaseToken,
        userId: input.userId,
        errorCode: errorCode(error),
        nextAttemptAt: retryable
          ? new Date(now.getTime() + googlePlayRetryDelayMs(existing.ackAttempts + 1, dependencies.random))
          : null
      });
    }
    return publisherFailure(error);
  }

  const validation = validatedPurchase(
    purchase,
    input.productId,
    dependencies.accountIdForUser(input.userId),
    now
  );
  if (isFailure(validation)) return validation;

  if (await ownedByAnotherUser(dependencies.store, validation.linkedPurchaseToken, input.userId)) {
    return {
      ok: false,
      httpStatus: 409,
      code: "PURCHASE_TOKEN_OWNED_BY_ANOTHER_USER",
      retryable: false
    };
  }

  const claim = await dependencies.store.claimPurchase({
    purchaseToken: input.purchaseToken,
    userId: input.userId,
    productId: input.productId,
    packageName: dependencies.packageName,
    now
  });
  if (claim.kind === "owner_conflict") {
    return {
      ok: false,
      httpStatus: 409,
      code: "PURCHASE_TOKEN_OWNED_BY_ANOTHER_USER",
      retryable: false
    };
  }
  if (claim.kind === "product_conflict") {
    return {
      ok: false,
      httpStatus: 409,
      code: "PURCHASE_TOKEN_PRODUCT_MISMATCH",
      retryable: false
    };
  }

  if (!validation.entitled) {
    const projectionChanged = await dependencies.store.markInactive({
      purchaseToken: input.purchaseToken,
      userId: input.userId,
      subscriptionState: validation.subscriptionState,
      acknowledgementState: validation.acknowledgementState,
      latestOrderId: validation.latestOrderId,
      linkedPurchaseToken: validation.linkedPurchaseToken,
      expiresAt: validation.expiresAt,
      verifiedAt: now
    });
    if (projectionChanged) dependencies.onEntitlementChanged?.(input.userId);
    return {
      ok: false,
      httpStatus: 409,
      code: "SUBSCRIPTION_INACTIVE",
      retryable: false,
      subscriptionState: validation.subscriptionState,
      expiresAt: validation.expiresAt
    };
  }

  const alreadyEntitledExpiresAt =
    existing?.status === GOOGLE_PLAY_STATUS.entitled &&
    existing.acknowledgementState === ACKNOWLEDGED &&
    validation.acknowledgementState === ACKNOWLEDGED &&
    existing.expiresAt != null &&
    existing.expiresAt.getTime() >= validation.expiresAt.getTime()
      ? existing.expiresAt
      : null;

  await dependencies.store.saveVerification({
    purchaseToken: input.purchaseToken,
    userId: input.userId,
    subscriptionState: validation.subscriptionState,
    acknowledgementState: validation.acknowledgementState,
    latestOrderId: validation.latestOrderId,
    linkedPurchaseToken: validation.linkedPurchaseToken,
    expiresAt: validation.expiresAt,
    verifiedAt: now,
    nextAttemptAt: alreadyEntitledExpiresAt ? null : now
  });

  if (alreadyEntitledExpiresAt) {
    return { ok: true, tier: "pro", expiresAt: alreadyEntitledExpiresAt };
  }

  const processingId = dependencies.newProcessingId?.() ?? randomUUID();
  const processing = await dependencies.store.beginProcessing({
    purchaseToken: input.purchaseToken,
    userId: input.userId,
    processingId,
    startedAt: now,
    staleBefore: new Date(now.getTime() - processingLeaseMs),
    incrementAckAttempts: validation.acknowledgementState === ACK_PENDING
  });
  if (!processing.acquired) {
    return successfulOrInProgress(dependencies.store, input.purchaseToken, input.userId, now);
  }

  if (validation.acknowledgementState === ACKNOWLEDGED) {
    const granted = await dependencies.store.grantEntitlement({
      purchaseToken: input.purchaseToken,
      userId: input.userId,
      processingId,
      expiresAt: validation.expiresAt,
      acknowledgedAt: now
    });
    if (granted) dependencies.onEntitlementChanged?.(input.userId);
    return granted
      ? { ok: true, tier: "pro", expiresAt: validation.expiresAt }
      : successfulOrInProgress(dependencies.store, input.purchaseToken, input.userId, now);
  }

  try {
    await dependencies.publisher.acknowledge(input.productId, input.purchaseToken);
    const granted = await dependencies.store.grantEntitlement({
      purchaseToken: input.purchaseToken,
      userId: input.userId,
      processingId,
      expiresAt: validation.expiresAt,
      acknowledgedAt: now
    });
    if (granted) dependencies.onEntitlementChanged?.(input.userId);
    return granted
      ? { ok: true, tier: "pro", expiresAt: validation.expiresAt }
      : successfulOrInProgress(dependencies.store, input.purchaseToken, input.userId, now);
  } catch (ackError) {
    // A request may reach Google even when its response is lost. Re-read the
    // purchase before declaring the acknowledgement failed.
    try {
      const refreshedPurchase = await dependencies.publisher.getSubscription(input.purchaseToken);
      const refreshed = validatedPurchase(
        refreshedPurchase,
        input.productId,
        dependencies.accountIdForUser(input.userId),
        now
      );
      if (!isFailure(refreshed)) {
        if (!refreshed.entitled) {
          const projectionChanged = await dependencies.store.markInactive({
            purchaseToken: input.purchaseToken,
            userId: input.userId,
            subscriptionState: refreshed.subscriptionState,
            acknowledgementState: refreshed.acknowledgementState,
            latestOrderId: refreshed.latestOrderId,
            linkedPurchaseToken: refreshed.linkedPurchaseToken,
            expiresAt: refreshed.expiresAt,
            verifiedAt: now
          });
          if (projectionChanged) dependencies.onEntitlementChanged?.(input.userId);
          return {
            ok: false,
            httpStatus: 409,
            code: "SUBSCRIPTION_INACTIVE",
            retryable: false,
            subscriptionState: refreshed.subscriptionState,
            expiresAt: refreshed.expiresAt
          };
        }
        await dependencies.store.saveVerification({
          purchaseToken: input.purchaseToken,
          userId: input.userId,
          subscriptionState: refreshed.subscriptionState,
          acknowledgementState: refreshed.acknowledgementState,
          latestOrderId: refreshed.latestOrderId,
          linkedPurchaseToken: refreshed.linkedPurchaseToken,
          expiresAt: refreshed.expiresAt,
          verifiedAt: now,
          nextAttemptAt: now
        });
        if (refreshed.acknowledgementState === ACKNOWLEDGED) {
          const granted = await dependencies.store.grantEntitlement({
            purchaseToken: input.purchaseToken,
            userId: input.userId,
            processingId,
            expiresAt: refreshed.expiresAt,
            acknowledgedAt: now
          });
          if (granted) {
            dependencies.onEntitlementChanged?.(input.userId);
            return { ok: true, tier: "pro", expiresAt: refreshed.expiresAt };
          }
        }
      }
    } catch {
      // The original acknowledgement classification controls retry policy.
    }

    const retryable = isRetryable(ackError);
    const nextAttemptAt = retryable
      ? new Date(now.getTime() + googlePlayRetryDelayMs(processing.ackAttempts, dependencies.random))
      : null;
    await dependencies.store.finishProcessingFailure({
      purchaseToken: input.purchaseToken,
      userId: input.userId,
      processingId,
      errorCode: errorCode(ackError),
      retryable,
      nextAttemptAt
    });
    return {
      ok: false,
      httpStatus: 502,
      code: "ACKNOWLEDGEMENT_FAILED",
      retryable
    };
  }
}

export async function runGooglePlayBillingRetryBatch(
  dependencies: GooglePlayBillingDependencies,
  limit = 10
): Promise<void> {
  const now = dependencies.now?.() ?? new Date();
  const processingLeaseMs = dependencies.processingLeaseMs ?? 5 * 60_000;
  const purchases = await dependencies.store.listDuePurchases({
    now,
    staleBefore: new Date(now.getTime() - processingLeaseMs),
    limit
  });
  const outcomes = await Promise.allSettled(
    purchases.map((purchase) => verifyGooglePlayPurchase(purchase, dependencies))
  );
  const failedCount = outcomes.filter((outcome) => outcome.status === "rejected").length;
  if (failedCount > 0) {
    console.error(`Google Play billing retry batch had ${failedCount} internal failure(s)`);
  }
}
