import assert from "node:assert/strict";
import test from "node:test";
import {
  GOOGLE_PLAY_STATUS,
  GooglePlayPublisherError,
  type ClaimGooglePlayPurchaseResult,
  type GooglePlayBillingDependencies,
  type GooglePlayBillingStore,
  type GooglePlayPublisher,
  type GooglePlaySubscription,
  type StoredGooglePlayPurchase,
  runGooglePlayBillingRetryBatch,
  verifyGooglePlayPurchase
} from "./googlePlayBilling.js";

type MemoryPurchase = StoredGooglePlayPurchase & {
  packageName: string;
  subscriptionState: string | null;
  latestOrderId: string | null;
  linkedPurchaseToken: string | null;
  processingId: string | null;
  processingStartedAt: Date | null;
  nextAttemptAt: Date | null;
  lastErrorCode: string | null;
};

class MemoryBillingStore implements GooglePlayBillingStore {
  readonly purchases = new Map<string, MemoryPurchase>();
  readonly entitlements = new Map<string, Date>();
  grantCount = 0;

  async findByToken(purchaseToken: string): Promise<StoredGooglePlayPurchase | null> {
    return this.purchases.get(purchaseToken) ?? null;
  }

  async claimPurchase(input: {
    purchaseToken: string;
    userId: string;
    productId: string;
    packageName: string;
    now: Date;
  }): Promise<ClaimGooglePlayPurchaseResult> {
    const existing = this.purchases.get(input.purchaseToken);
    if (existing?.userId !== undefined && existing.userId !== input.userId) {
      return { kind: "owner_conflict", ownerUserId: existing.userId };
    }
    if (existing?.productId !== undefined && existing.productId !== input.productId) {
      return { kind: "product_conflict", productId: existing.productId };
    }
    if (existing) return { kind: "claimed", purchase: existing };

    const created: MemoryPurchase = {
      purchaseToken: input.purchaseToken,
      userId: input.userId,
      productId: input.productId,
      packageName: input.packageName,
      status: GOOGLE_PLAY_STATUS.received,
      expiresAt: null,
      acknowledgementState: null,
      ackAttempts: 0,
      subscriptionState: null,
      latestOrderId: null,
      linkedPurchaseToken: null,
      processingId: null,
      processingStartedAt: null,
      nextAttemptAt: input.now,
      lastErrorCode: null
    };
    this.purchases.set(input.purchaseToken, created);
    return { kind: "claimed", purchase: created };
  }

  async saveVerification(input: {
    purchaseToken: string;
    userId: string;
    subscriptionState: string;
    acknowledgementState: string;
    latestOrderId: string | null;
    linkedPurchaseToken: string | null;
    expiresAt: Date;
    verifiedAt: Date;
    nextAttemptAt: Date | null;
  }): Promise<void> {
    const purchase = this.required(input.purchaseToken, input.userId);
    purchase.subscriptionState = input.subscriptionState;
    purchase.acknowledgementState = input.acknowledgementState;
    purchase.latestOrderId = input.latestOrderId;
    purchase.linkedPurchaseToken = input.linkedPurchaseToken;
    purchase.expiresAt = input.expiresAt;
    purchase.nextAttemptAt = input.nextAttemptAt;
    purchase.lastErrorCode = null;
  }

  async beginProcessing(input: {
    purchaseToken: string;
    userId: string;
    processingId: string;
    startedAt: Date;
    staleBefore: Date;
    incrementAckAttempts: boolean;
  }): Promise<{ acquired: boolean; ackAttempts: number }> {
    const purchase = this.required(input.purchaseToken, input.userId);
    const leaseIsFresh =
      purchase.status === GOOGLE_PLAY_STATUS.processing &&
      purchase.processingStartedAt != null &&
      purchase.processingStartedAt.getTime() > input.staleBefore.getTime();
    if (leaseIsFresh) return { acquired: false, ackAttempts: purchase.ackAttempts };
    purchase.status = GOOGLE_PLAY_STATUS.processing;
    purchase.processingId = input.processingId;
    purchase.processingStartedAt = input.startedAt;
    purchase.nextAttemptAt = null;
    if (input.incrementAckAttempts) purchase.ackAttempts += 1;
    return { acquired: true, ackAttempts: purchase.ackAttempts };
  }

  async grantEntitlement(input: {
    purchaseToken: string;
    userId: string;
    processingId: string;
    expiresAt: Date;
    acknowledgedAt: Date;
  }): Promise<boolean> {
    const purchase = this.required(input.purchaseToken, input.userId);
    if (
      purchase.status !== GOOGLE_PLAY_STATUS.processing ||
      purchase.processingId !== input.processingId
    ) return false;
    purchase.status = GOOGLE_PLAY_STATUS.entitled;
    purchase.acknowledgementState = "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED";
    purchase.expiresAt = input.expiresAt;
    purchase.processingId = null;
    purchase.processingStartedAt = null;
    purchase.nextAttemptAt = null;
    this.entitlements.set(input.userId, input.expiresAt);
    this.grantCount += 1;
    return true;
  }

  async markInactive(input: {
    purchaseToken: string;
    userId: string;
    subscriptionState: string;
    acknowledgementState: string | null;
    latestOrderId: string | null;
    linkedPurchaseToken: string | null;
    expiresAt: Date | null;
    verifiedAt: Date;
  }): Promise<boolean> {
    const purchase = this.required(input.purchaseToken, input.userId);
    const previousStatus = purchase.status;
    const previousExpiry = purchase.expiresAt;
    purchase.status = GOOGLE_PLAY_STATUS.inactive;
    purchase.subscriptionState = input.subscriptionState;
    purchase.acknowledgementState = input.acknowledgementState;
    purchase.latestOrderId = input.latestOrderId;
    purchase.linkedPurchaseToken = input.linkedPurchaseToken;
    purchase.expiresAt = input.expiresAt;
    purchase.processingId = null;
    purchase.processingStartedAt = null;
    purchase.nextAttemptAt = null;
    const currentEntitlement = this.entitlements.get(input.userId);
    if (
      previousStatus !== GOOGLE_PLAY_STATUS.entitled ||
      !previousExpiry ||
      currentEntitlement?.getTime() !== previousExpiry.getTime()
    ) return false;
    const fallback = [...this.purchases.values()]
      .filter((candidate) =>
        candidate.userId === input.userId &&
        candidate.status === GOOGLE_PLAY_STATUS.entitled &&
        candidate.expiresAt != null &&
        candidate.expiresAt.getTime() > input.verifiedAt.getTime()
      )
      .sort((left, right) => (right.expiresAt?.getTime() ?? 0) - (left.expiresAt?.getTime() ?? 0))[0];
    if (fallback?.expiresAt) this.entitlements.set(input.userId, fallback.expiresAt);
    else this.entitlements.delete(input.userId);
    return true;
  }

  async finishProcessingFailure(input: {
    purchaseToken: string;
    userId: string;
    processingId: string;
    errorCode: string;
    retryable: boolean;
    nextAttemptAt: Date | null;
  }): Promise<void> {
    const purchase = this.required(input.purchaseToken, input.userId);
    if (purchase.processingId !== input.processingId) return;
    purchase.status = input.retryable ? GOOGLE_PLAY_STATUS.ackRetry : GOOGLE_PLAY_STATUS.ackBlocked;
    purchase.processingId = null;
    purchase.processingStartedAt = null;
    purchase.nextAttemptAt = input.nextAttemptAt;
    purchase.lastErrorCode = input.errorCode;
  }

  async deferExistingPurchase(input: {
    purchaseToken: string;
    userId: string;
    errorCode: string;
    nextAttemptAt: Date | null;
  }): Promise<void> {
    const purchase = this.required(input.purchaseToken, input.userId);
    if (purchase.status === GOOGLE_PLAY_STATUS.processing) return;
    purchase.nextAttemptAt = input.nextAttemptAt;
    purchase.lastErrorCode = input.errorCode;
  }

  async listDuePurchases(input: {
    now: Date;
    staleBefore: Date;
    limit: number;
  }): Promise<Array<{ purchaseToken: string; userId: string; productId: string }>> {
    return [...this.purchases.values()]
      .filter((purchase) => {
        const due =
          purchase.nextAttemptAt != null &&
          purchase.nextAttemptAt.getTime() <= input.now.getTime() &&
          purchase.status !== GOOGLE_PLAY_STATUS.inactive &&
          purchase.status !== GOOGLE_PLAY_STATUS.ackBlocked;
        const stale =
          purchase.status === GOOGLE_PLAY_STATUS.processing &&
          purchase.processingStartedAt != null &&
          purchase.processingStartedAt.getTime() <= input.staleBefore.getTime();
        return due || stale;
      })
      .slice(0, input.limit)
      .map(({ purchaseToken, userId, productId }) => ({ purchaseToken, userId, productId }));
  }

  private required(purchaseToken: string, userId: string): MemoryPurchase {
    const purchase = this.purchases.get(purchaseToken);
    assert.ok(purchase, "purchase must exist");
    assert.equal(purchase.userId, userId);
    return purchase;
  }
}

class FakePublisher implements GooglePlayPublisher {
  getCalls = 0;
  acknowledgeCalls = 0;
  getResponses: GooglePlaySubscription[] = [];
  acknowledgeErrors: unknown[] = [];

  async getSubscription(): Promise<GooglePlaySubscription> {
    const response = this.getResponses[Math.min(this.getCalls, this.getResponses.length - 1)];
    this.getCalls += 1;
    assert.ok(response, "test must provide a Google subscription response");
    return structuredClone(response);
  }

  async acknowledge(): Promise<void> {
    const error = this.acknowledgeErrors[this.acknowledgeCalls];
    this.acknowledgeCalls += 1;
    if (error) throw error;
  }
}

const productId = "com.chillnote.pro.weekly";
const purchaseToken = "test-purchase-token-that-is-long-enough";
const start = new Date("2026-08-23T12:00:00.000Z");
const expiry = new Date("2026-09-23T12:00:00.000Z");

function subscription(userId: string, acknowledged: boolean): GooglePlaySubscription {
  return {
    subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
    acknowledgementState: acknowledged
      ? "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED"
      : "ACKNOWLEDGEMENT_STATE_PENDING",
    latestOrderId: "GPA.1234-5678-9012-34567",
    externalAccountIdentifiers: { obfuscatedExternalAccountId: `account-${userId}` },
    lineItems: [{ productId, expiryTime: expiry.toISOString() }]
  };
}

function dependencies(
  store: MemoryBillingStore,
  publisher: FakePublisher,
  now: () => Date = () => start
): GooglePlayBillingDependencies {
  let processingSequence = 0;
  return {
    store,
    publisher,
    packageName: "com.sponteoai.chillscript",
    accountIdForUser: (userId) => `account-${userId}`,
    now,
    random: () => 0,
    newProcessingId: () => `processing-${++processingSequence}`
  };
}

test("ack failure is persisted and never grants or reports Pro", async () => {
  const store = new MemoryBillingStore();
  const publisher = new FakePublisher();
  publisher.getResponses = [subscription("user-1", false), subscription("user-1", false)];
  publisher.acknowledgeErrors = [new GooglePlayPublisherError("NETWORK", true)];

  const result = await verifyGooglePlayPurchase(
    { userId: "user-1", productId, purchaseToken },
    dependencies(store, publisher)
  );

  assert.deepEqual(result, {
    ok: false,
    httpStatus: 502,
    code: "ACKNOWLEDGEMENT_FAILED",
    retryable: true
  });
  assert.equal(store.entitlements.has("user-1"), false);
  assert.equal(store.grantCount, 0);
  assert.equal(store.purchases.get(purchaseToken)?.status, GOOGLE_PLAY_STATUS.ackRetry);
  assert.equal(store.purchases.get(purchaseToken)?.ackAttempts, 1);
  assert.equal(store.purchases.get(purchaseToken)?.nextAttemptAt?.toISOString(), "2026-08-23T12:00:30.000Z");
});

test("the same token for the same user is idempotent", async () => {
  const store = new MemoryBillingStore();
  const publisher = new FakePublisher();
  publisher.getResponses = [subscription("user-1", true), subscription("user-1", true)];
  const deps = dependencies(store, publisher);

  const first = await verifyGooglePlayPurchase({ userId: "user-1", productId, purchaseToken }, deps);
  const duplicate = await verifyGooglePlayPurchase({ userId: "user-1", productId, purchaseToken }, deps);

  assert.equal(first.ok, true);
  assert.equal(duplicate.ok, true);
  assert.equal(store.purchases.size, 1);
  assert.equal(store.grantCount, 1);
  assert.equal(publisher.acknowledgeCalls, 0);
});

test("a token can never be reused by another user", async () => {
  const store = new MemoryBillingStore();
  const publisher = new FakePublisher();
  publisher.getResponses = [subscription("user-1", true)];
  const deps = dependencies(store, publisher);
  await verifyGooglePlayPurchase({ userId: "user-1", productId, purchaseToken }, deps);

  const result = await verifyGooglePlayPurchase(
    { userId: "user-2", productId, purchaseToken },
    deps
  );

  assert.deepEqual(result, {
    ok: false,
    httpStatus: 409,
    code: "PURCHASE_TOKEN_OWNED_BY_ANOTHER_USER",
    retryable: false
  });
  assert.equal(publisher.getCalls, 1, "ownership conflict must be rejected before calling Google");
  assert.equal(store.entitlements.has("user-2"), false);
});

test("the retry worker eventually acknowledges and grants exactly once", async () => {
  const store = new MemoryBillingStore();
  const publisher = new FakePublisher();
  publisher.getResponses = [
    subscription("user-1", false),
    subscription("user-1", false),
    subscription("user-1", false)
  ];
  publisher.acknowledgeErrors = [new GooglePlayPublisherError("PUBLISHER_UNAVAILABLE", true)];
  let currentTime = start;
  const deps = dependencies(store, publisher, () => currentTime);

  const first = await verifyGooglePlayPurchase({ userId: "user-1", productId, purchaseToken }, deps);
  assert.equal(first.ok, false);
  assert.equal(store.grantCount, 0);

  currentTime = new Date(start.getTime() + 30_000);
  await runGooglePlayBillingRetryBatch(deps);

  assert.equal(publisher.acknowledgeCalls, 2);
  assert.equal(store.purchases.get(purchaseToken)?.status, GOOGLE_PLAY_STATUS.entitled);
  assert.equal(store.grantCount, 1);
  assert.equal(store.entitlements.get("user-1")?.toISOString(), expiry.toISOString());
});

test("a terminal acknowledgement error is persisted without an infinite worker retry", async () => {
  const store = new MemoryBillingStore();
  const publisher = new FakePublisher();
  publisher.getResponses = [subscription("user-1", false), subscription("user-1", false)];
  publisher.acknowledgeErrors = [new GooglePlayPublisherError("PUBLISHER_AUTH", false)];
  let currentTime = start;
  const deps = dependencies(store, publisher, () => currentTime);

  const result = await verifyGooglePlayPurchase(
    { userId: "user-1", productId, purchaseToken },
    deps
  );
  assert.equal(result.ok, false);
  assert.equal(result.ok ? true : result.retryable, false);
  assert.equal(store.purchases.get(purchaseToken)?.status, GOOGLE_PLAY_STATUS.ackBlocked);
  assert.equal(store.purchases.get(purchaseToken)?.nextAttemptAt, null);

  currentTime = new Date("2026-08-30T12:00:00.000Z");
  await runGooglePlayBillingRetryBatch(deps);
  assert.equal(publisher.acknowledgeCalls, 1);
  assert.equal(store.grantCount, 0);
});

test("a lost ack response converges when the follow-up GET says acknowledged", async () => {
  const store = new MemoryBillingStore();
  const publisher = new FakePublisher();
  publisher.getResponses = [subscription("user-1", false), subscription("user-1", true)];
  publisher.acknowledgeErrors = [new GooglePlayPublisherError("TIMEOUT", true)];

  const result = await verifyGooglePlayPurchase(
    { userId: "user-1", productId, purchaseToken },
    dependencies(store, publisher)
  );

  assert.equal(result.ok, true);
  assert.equal(store.grantCount, 1);
  assert.equal(store.purchases.get(purchaseToken)?.status, GOOGLE_PLAY_STATUS.entitled);
});

test("a later inactive verification removes only the matching Google entitlement", async () => {
  const store = new MemoryBillingStore();
  const publisher = new FakePublisher();
  const inactive = subscription("user-1", true);
  inactive.subscriptionState = "SUBSCRIPTION_STATE_EXPIRED";
  publisher.getResponses = [subscription("user-1", true), inactive];
  const deps = dependencies(store, publisher);

  const activeResult = await verifyGooglePlayPurchase(
    { userId: "user-1", productId, purchaseToken },
    deps
  );
  const inactiveResult = await verifyGooglePlayPurchase(
    { userId: "user-1", productId, purchaseToken },
    deps
  );

  assert.equal(activeResult.ok, true);
  assert.equal(inactiveResult.ok, false);
  assert.equal(inactiveResult.ok ? "" : inactiveResult.code, "SUBSCRIPTION_INACTIVE");
  assert.equal(store.entitlements.has("user-1"), false);
  assert.equal(store.purchases.get(purchaseToken)?.status, GOOGLE_PLAY_STATUS.inactive);
});
