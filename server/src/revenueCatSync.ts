import type { PrismaClient } from "@prisma/client";
import {
  accountRevenueCatSnapshot,
  canonicalRevenueCatUserId,
  type RevenueCatCustomerResponse,
  type RevenueCatEntitlementSnapshot
} from "./revenueCat.js";

export async function syncRevenueCatUsers(params: {
  userIds: string[];
  entitlementId: string;
  lastEventId?: string | null;
  database: PrismaClient;
  fetchCustomer(userId: string): Promise<RevenueCatCustomerResponse>;
  invalidate(userId: string): void;
}): Promise<Map<string, RevenueCatEntitlementSnapshot>> {
  const userIds = [...new Set(params.userIds.map(canonicalRevenueCatUserId))].sort();
  const affected = new Set(userIds);
  const snapshots = await params.database.$transaction(async (tx) => {
    // Lock before fetching, so a slow pre-transfer response cannot overwrite a
    // newer snapshot. Shared across server processes and all subscription routes.
    await tx.$queryRaw`
      SELECT 1::int AS locked
      FROM pg_advisory_xact_lock(hashtextextended('revenuecat-entitlement-sync', 0))
    `;
    const entries = await Promise.all(userIds.map(async (userId) => [
      userId,
      await accountRevenueCatSnapshot(userId, params.entitlementId, params.fetchCustomer)
    ] as const));

    // Write inactive participants first so a transfer releases its unique key
    // before the new owner claims it, regardless of the users' lexical order.
    for (const [userId, snapshot] of [...entries].sort((a, b) => Number(a[1].active) - Number(b[1].active))) {
      if (snapshot.active && snapshot.store && snapshot.storeTransactionId) {
        const previous = await tx.revenueCatEntitlement.findMany({
          where: {
            store: snapshot.store, storeTransactionId: snapshot.storeTransactionId,
            userId: { not: userId }
          },
          select: { userId: true }
        });
        for (const owner of previous) affected.add(owner.userId);
        await tx.revenueCatEntitlement.updateMany({
          where: {
            store: snapshot.store, storeTransactionId: snapshot.storeTransactionId,
            userId: { not: userId }
          },
          data: { isActive: false, storeTransactionId: null, lastSyncedAt: new Date() }
        });
        await tx.user.updateMany({
          where: { id: { in: previous.map((owner) => owner.userId) }, subscriptionProvider: "apple" },
          data: { subscriptionTier: "free", subscriptionExpiresAt: null }
        });
      }
      // Reconcile every transfer participant in the same commit. This also
      // handles v1 responses without an original transaction ID.
      const data = {
        isActive: snapshot.active,
        expiresAt: snapshot.expiresAt,
        productId: snapshot.productId,
        store: snapshot.store,
        originalTransactionId: snapshot.originalTransactionId,
        storeTransactionId: snapshot.active ? snapshot.storeTransactionId ?? null : null,
        lastEventId: params.lastEventId ?? undefined,
        lastSyncedAt: new Date()
      };
      await tx.revenueCatEntitlement.upsert({
        where: { userId_entitlementId: { userId, entitlementId: params.entitlementId } },
        create: { userId, entitlementId: params.entitlementId, ...data },
        update: data
      });
      // Old Apple projections came from unverified client metadata and cannot
      // remain an independent grant after a verified sync or a transfer.
      // Google Play and Creem projections belong to separate payment sources.
      await tx.user.updateMany({
        where: { id: userId, subscriptionProvider: "apple" },
        data: { subscriptionTier: "free", subscriptionExpiresAt: null }
      });
    }
    return new Map(entries);
  }, { maxWait: 20_000, timeout: 25_000 });
  for (const userId of affected) params.invalidate(userId);
  return snapshots;
}
