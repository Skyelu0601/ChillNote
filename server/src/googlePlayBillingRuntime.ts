import type { PrismaClient } from "@prisma/client";
import { prisma } from "./db.js";
import {
  GOOGLE_PLAY_STATUS,
  GooglePlayPublisherError,
  type ClaimGooglePlayPurchaseResult,
  type GooglePlayBillingDependencies,
  type GooglePlayBillingStore,
  type GooglePlayPublisher,
  type GooglePlaySubscription,
  type StoredGooglePlayPurchase,
  runGooglePlayBillingRetryBatch
} from "./googlePlayBilling.js";

type FetchImplementation = typeof fetch;

type GooglePlayPurchaseRecord = {
  purchaseToken: string;
  userId: string;
  productId: string;
  status: string;
  expiresAt: Date | null;
  acknowledgementState: string | null;
  ackAttempts: number;
};

function storedPurchase(record: GooglePlayPurchaseRecord): StoredGooglePlayPurchase {
  return {
    purchaseToken: record.purchaseToken,
    userId: record.userId,
    productId: record.productId,
    status: record.status,
    expiresAt: record.expiresAt,
    acknowledgementState: record.acknowledgementState,
    ackAttempts: record.ackAttempts
  };
}

function isUniqueConstraintError(error: unknown): boolean {
  return typeof error === "object" && error != null && "code" in error && error.code === "P2002";
}

export function createPrismaGooglePlayBillingStore(
  database: PrismaClient = prisma
): GooglePlayBillingStore {
  return {
    async findByToken(purchaseToken) {
      const record = await database.googlePlayPurchase.findUnique({ where: { purchaseToken } });
      return record ? storedPurchase(record) : null;
    },

    async claimPurchase(input): Promise<ClaimGooglePlayPurchaseResult> {
      const existing = await database.googlePlayPurchase.findUnique({
        where: { purchaseToken: input.purchaseToken }
      });
      if (existing) {
        if (existing.userId !== input.userId) {
          return { kind: "owner_conflict", ownerUserId: existing.userId };
        }
        if (existing.productId !== input.productId) {
          return { kind: "product_conflict", productId: existing.productId };
        }
        return { kind: "claimed", purchase: storedPurchase(existing) };
      }

      try {
        const created = await database.googlePlayPurchase.create({
          data: {
            purchaseToken: input.purchaseToken,
            userId: input.userId,
            productId: input.productId,
            packageName: input.packageName,
            status: GOOGLE_PLAY_STATUS.received,
            nextAckAttemptAt: input.now
          }
        });
        return { kind: "claimed", purchase: storedPurchase(created) };
      } catch (error) {
        if (!isUniqueConstraintError(error)) throw error;
        const winner = await database.googlePlayPurchase.findUnique({
          where: { purchaseToken: input.purchaseToken }
        });
        if (!winner) throw error;
        if (winner.userId !== input.userId) {
          return { kind: "owner_conflict", ownerUserId: winner.userId };
        }
        if (winner.productId !== input.productId) {
          return { kind: "product_conflict", productId: winner.productId };
        }
        return { kind: "claimed", purchase: storedPurchase(winner) };
      }
    },

    async saveVerification(input) {
      await database.googlePlayPurchase.updateMany({
        where: { purchaseToken: input.purchaseToken, userId: input.userId },
        data: {
          subscriptionState: input.subscriptionState,
          acknowledgementState: input.acknowledgementState,
          latestOrderId: input.latestOrderId,
          linkedPurchaseToken: input.linkedPurchaseToken,
          expiresAt: input.expiresAt,
          verifiedAt: input.verifiedAt,
          nextAckAttemptAt: input.nextAttemptAt,
          lastErrorCode: null
        }
      });
    },

    async beginProcessing(input) {
      const updated = await database.googlePlayPurchase.updateMany({
        where: {
          purchaseToken: input.purchaseToken,
          userId: input.userId,
          OR: [
            { status: { not: GOOGLE_PLAY_STATUS.processing } },
            { processingStartedAt: null },
            { processingStartedAt: { lte: input.staleBefore } }
          ]
        },
        data: {
          status: GOOGLE_PLAY_STATUS.processing,
          processingId: input.processingId,
          processingStartedAt: input.startedAt,
          nextAckAttemptAt: null,
          lastAckAttemptAt: input.incrementAckAttempts ? input.startedAt : undefined,
          ackAttempts: input.incrementAckAttempts ? { increment: 1 } : undefined
        }
      });
      const record = await database.googlePlayPurchase.findUnique({
        where: { purchaseToken: input.purchaseToken },
        select: { ackAttempts: true }
      });
      return { acquired: updated.count === 1, ackAttempts: record?.ackAttempts ?? 1 };
    },

    async grantEntitlement(input) {
      return database.$transaction(async (transaction) => {
        const purchase = await transaction.googlePlayPurchase.updateMany({
          where: {
            purchaseToken: input.purchaseToken,
            userId: input.userId,
            status: GOOGLE_PLAY_STATUS.processing,
            processingId: input.processingId
          },
          data: {
            status: GOOGLE_PLAY_STATUS.entitled,
            acknowledgementState: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
            expiresAt: input.expiresAt,
            acknowledgedAt: input.acknowledgedAt,
            entitlementGrantedAt: input.acknowledgedAt,
            processingId: null,
            processingStartedAt: null,
            nextAckAttemptAt: null,
            lastErrorCode: null
          }
        });
        if (purchase.count !== 1) return false;

        // Do not shorten a longer entitlement from another purchase/provider.
        // Google state remains authoritative in GooglePlayPurchase either way.
        await transaction.user.updateMany({
          where: {
            id: input.userId,
            OR: [
              { subscriptionTier: { not: "pro" } },
              { subscriptionExpiresAt: { lt: input.expiresAt } }
            ]
          },
          data: {
            subscriptionTier: "pro",
            subscriptionExpiresAt: input.expiresAt,
            subscriptionProvider: "google_play"
          }
        });
        return true;
      });
    },

    async markInactive(input) {
      return database.$transaction(async (transaction) => {
        const previous = await transaction.googlePlayPurchase.findUnique({
          where: { purchaseToken: input.purchaseToken },
          select: { status: true, expiresAt: true }
        });
        await transaction.googlePlayPurchase.updateMany({
          where: { purchaseToken: input.purchaseToken, userId: input.userId },
          data: {
            status: GOOGLE_PLAY_STATUS.inactive,
            subscriptionState: input.subscriptionState,
            acknowledgementState: input.acknowledgementState,
            latestOrderId: input.latestOrderId,
            linkedPurchaseToken: input.linkedPurchaseToken,
            expiresAt: input.expiresAt,
            verifiedAt: input.verifiedAt,
            processingId: null,
            processingStartedAt: null,
            nextAckAttemptAt: null,
            lastErrorCode: null
          }
        });

        if (previous?.status !== GOOGLE_PLAY_STATUS.entitled || !previous.expiresAt) return false;
        const fallback = await transaction.googlePlayPurchase.findFirst({
          where: {
            userId: input.userId,
            status: GOOGLE_PLAY_STATUS.entitled,
            expiresAt: { gt: input.verifiedAt }
          },
          select: { expiresAt: true },
          orderBy: { expiresAt: "desc" }
        });
        const changed = await transaction.user.updateMany({
          where: {
            id: input.userId,
            subscriptionProvider: "google_play",
            subscriptionExpiresAt: previous.expiresAt
          },
          data: fallback?.expiresAt
            ? {
                subscriptionTier: "pro",
                subscriptionExpiresAt: fallback.expiresAt,
                subscriptionProvider: "google_play"
              }
            : {
                subscriptionTier: "free",
                subscriptionExpiresAt: null,
                subscriptionProvider: null
              }
        });
        return changed.count === 1;
      });
    },

    async finishProcessingFailure(input) {
      await database.googlePlayPurchase.updateMany({
        where: {
          purchaseToken: input.purchaseToken,
          userId: input.userId,
          status: GOOGLE_PLAY_STATUS.processing,
          processingId: input.processingId
        },
        data: {
          status: input.retryable ? GOOGLE_PLAY_STATUS.ackRetry : GOOGLE_PLAY_STATUS.ackBlocked,
          processingId: null,
          processingStartedAt: null,
          nextAckAttemptAt: input.nextAttemptAt,
          lastErrorCode: input.errorCode
        }
      });
    },

    async deferExistingPurchase(input) {
      await database.googlePlayPurchase.updateMany({
        where: {
          purchaseToken: input.purchaseToken,
          userId: input.userId,
          status: { not: GOOGLE_PLAY_STATUS.processing }
        },
        data: {
          nextAckAttemptAt: input.nextAttemptAt,
          lastErrorCode: input.errorCode
        }
      });
    },

    async listDuePurchases(input) {
      return database.googlePlayPurchase.findMany({
        where: {
          OR: [
            {
              nextAckAttemptAt: { lte: input.now },
              status: { notIn: [GOOGLE_PLAY_STATUS.inactive, GOOGLE_PLAY_STATUS.ackBlocked] }
            },
            {
              status: GOOGLE_PLAY_STATUS.processing,
              processingStartedAt: { lte: input.staleBefore }
            }
          ]
        },
        select: { purchaseToken: true, userId: true, productId: true },
        orderBy: { nextAckAttemptAt: "asc" },
        take: input.limit
      });
    }
  };
}

function publisherErrorForStatus(status: number): GooglePlayPublisherError {
  if (status === 400 || status === 404) {
    return new GooglePlayPublisherError("INVALID_PURCHASE", false, status);
  }
  if (status === 401 || status === 403) {
    return new GooglePlayPublisherError("PUBLISHER_AUTH", false, status);
  }
  if (status === 408 || status === 429) {
    return new GooglePlayPublisherError(status === 429 ? "RATE_LIMITED" : "TIMEOUT", true, status);
  }
  if (status >= 500) {
    return new GooglePlayPublisherError("PUBLISHER_UNAVAILABLE", true, status);
  }
  return new GooglePlayPublisherError("UNKNOWN", false, status);
}

export function createGooglePlayPublisher(input: {
  packageName: string;
  getAccessToken(forceRefresh?: boolean): Promise<string>;
  fetchImpl?: FetchImplementation;
  timeoutMs?: number;
}): GooglePlayPublisher {
  const fetchImpl = input.fetchImpl ?? fetch;
  const timeoutMs = input.timeoutMs ?? 15_000;

  async function request(url: string, init: RequestInit): Promise<Response> {
    for (let attempt = 0; attempt < 2; attempt += 1) {
      let accessToken: string;
      try {
        accessToken = await input.getAccessToken(attempt > 0);
      } catch (error) {
        if (error instanceof GooglePlayPublisherError) throw error;
        throw new GooglePlayPublisherError("PUBLISHER_UNAVAILABLE", true);
      }
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), timeoutMs);
      try {
        const response = await fetchImpl(url, {
          ...init,
          signal: controller.signal,
          headers: {
            Authorization: `Bearer ${accessToken}`,
            Accept: "application/json",
            ...init.headers
          }
        });
        if (response.ok) return response;
        await response.text().catch(() => undefined);
        if (response.status === 401 && attempt === 0) continue;
        throw publisherErrorForStatus(response.status);
      } catch (error) {
        if (error instanceof GooglePlayPublisherError) throw error;
        if (error instanceof Error && error.name === "AbortError") {
          throw new GooglePlayPublisherError("TIMEOUT", true);
        }
        throw new GooglePlayPublisherError("NETWORK", true);
      } finally {
        clearTimeout(timeout);
      }
    }
    throw new GooglePlayPublisherError("PUBLISHER_AUTH", false, 401);
  }

  return {
    async getSubscription(purchaseToken): Promise<GooglePlaySubscription> {
      const url =
        `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(input.packageName)}` +
        `/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
      const response = await request(url, { method: "GET" });
      try {
        return await response.json() as GooglePlaySubscription;
      } catch {
        throw new GooglePlayPublisherError("UNKNOWN", true, response.status);
      }
    },

    async acknowledge(productId, purchaseToken): Promise<void> {
      const url =
        `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(input.packageName)}` +
        `/purchases/subscriptions/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`;
      await request(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: "{}"
      });
    }
  };
}

let workerTimer: ReturnType<typeof setInterval> | null = null;
let workerRunning = false;

export function scheduleGooglePlayBillingWorker(
  dependencies: GooglePlayBillingDependencies,
  intervalMs = Number(process.env.GOOGLE_PLAY_BILLING_WORKER_INTERVAL_MS ?? 60_000)
): void {
  if (workerTimer) return;
  const safeIntervalMs = Number.isFinite(intervalMs) && intervalMs > 0
    ? Math.max(30_000, intervalMs)
    : 60_000;
  const run = async () => {
    if (workerRunning) return;
    workerRunning = true;
    try {
      await runGooglePlayBillingRetryBatch(dependencies);
    } catch (error) {
      const code = error instanceof GooglePlayPublisherError ? error.code : "UNKNOWN";
      console.error(`Google Play billing retry worker failed: ${code}`);
    } finally {
      workerRunning = false;
    }
  };
  void run();
  workerTimer = setInterval(() => void run(), safeIntervalMs);
  workerTimer.unref?.();
}
