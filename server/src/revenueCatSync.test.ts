import assert from "node:assert/strict";
import test from "node:test";
import type { PrismaClient } from "@prisma/client";
import { syncRevenueCatUsers } from "./revenueCatSync.js";
import type { RevenueCatCustomerResponse } from "./revenueCat.js";

function customer(active: boolean, transactionId: string | null = "transaction-1"): RevenueCatCustomerResponse {
  return { subscriber: { entitlements: active ? {
    pro: { product_identifier: "com.chillnote.pro.yearly", expires_date: "2099-01-01" }
  } : {}, subscriptions: { "com.chillnote.pro.yearly": {
    store: "app_store", store_transaction_id: transactionId
  } } } };
}

function fixture() {
  let rows: Record<string, any> = {};
  let users: Record<string, any> = {
    a: { id: "a", subscriptionProvider: "apple", subscriptionTier: "pro" },
    b: { id: "b", subscriptionProvider: "apple", subscriptionTier: "pro" },
    google: { id: "google", subscriptionProvider: "google_play", subscriptionTier: "pro" },
    creem: { id: "creem", subscriptionProvider: "creem", subscriptionTier: "pro" }
  };
  let tail = Promise.resolve();
  let lockHeld = false;
  let failWrite = false;
  const invalidated: string[] = [];
  const upstream: Record<string, RevenueCatCustomerResponse> = { a: customer(true), b: customer(false) };
  const matches = (row: any, where: any): boolean => Object.entries(where).every(([key, value]: [string, any]) => {
    if (value && typeof value === "object") {
      if ("not" in value) return row[key] !== value.not;
      if ("in" in value) return value.in.includes(row[key]);
    }
    return row[key] === value;
  });
  const database = {
    async $transaction(operation: (tx: any) => Promise<any>) {
      // Model a serializable transaction with rollback and the advisory lock.
      const previous = tail;
      let release!: () => void;
      tail = new Promise<void>((resolve) => { release = resolve; });
      await previous;
      const backupRows = structuredClone(rows), backupUsers = structuredClone(users);
      try {
        return await operation({
          $queryRaw: async () => { lockHeld = true; return [{ locked: 1 }]; },
          revenueCatEntitlement: {
            findMany: async ({ where }: any) => Object.values(rows).filter((row) => matches(row, where)),
            updateMany: async ({ where, data }: any) => {
              for (const row of Object.values(rows)) if (matches(row, where)) Object.assign(row, data);
            },
            upsert: async ({ create, update }: any) => {
              if (failWrite) throw new Error("database unavailable");
              const row = rows[create.userId] ? { ...rows[create.userId], ...update } : create;
              if (row.storeTransactionId && Object.values(rows).some((other) =>
                other.userId !== row.userId && other.store === row.store && other.storeTransactionId === row.storeTransactionId)) {
                throw new Error("unique transaction ownership violation");
              }
              rows[row.userId] = row;
            }
          },
          user: {
            updateMany: async ({ where, data }: any) => {
              for (const row of Object.values(users)) if (matches(row, where)) Object.assign(row, data);
            }
          }
        });
      } catch (error) {
        rows = backupRows; users = backupUsers;
        throw error;
      } finally { lockHeld = false; release(); }
    }
  } as unknown as PrismaClient;
  return {
    upstream, invalidated,
    get rows() { return rows; }, get users() { return users; },
    failNextWrite() { failWrite = true; },
    sync(userIds: string[]) {
      return syncRevenueCatUsers({
        userIds, entitlementId: "pro", database,
        fetchCustomer: async (userId) => {
          assert.equal(lockHeld, true, "lock must precede remote lookup");
          if (!upstream[userId]) throw new Error("RevenueCat unavailable");
          return upstream[userId];
        },
        invalidate: (userId) => invalidated.push(userId)
      });
    }
  };
}

test("restore claims one transaction and revokes the previous account before webhook arrival", async () => {
  const f = fixture();
  await f.sync(["a"]);
  f.upstream.a = customer(false); f.upstream.b = customer(true);
  f.invalidated.length = 0;
  await f.sync(["b"]);
  assert.equal(f.rows.a.isActive, false);
  assert.equal(f.rows.a.storeTransactionId, null);
  assert.equal(f.rows.b.isActive, true);
  assert.equal(f.users.a.subscriptionTier, "free");
  assert.deepEqual(new Set(f.invalidated), new Set(["a", "b"]));
  assert.equal(f.users.google.subscriptionTier, "pro");
  assert.equal(f.users.creem.subscriptionTier, "pro");
});

test("transfer updates both users when an older snapshot lacks transaction ID; replay stays idempotent", async () => {
  const f = fixture();
  f.upstream.b = customer(true, null);
  await f.sync(["b"]);
  f.upstream.b = customer(false); f.upstream.a = customer(true);
  for (let i = 0; i < 2; i++) await f.sync(["b", "a", "a"]);
  assert.equal(f.rows.a.isActive, true);
  assert.equal(f.rows.b.isActive, false);
  assert.equal(f.rows.a.expiresAt.toISOString(), "2099-01-01T00:00:00.000Z");
});

test("concurrent account syncs cannot leave two active owners for one transaction", async () => {
  const f = fixture();
  f.upstream.b = customer(true);
  await Promise.all([f.sync(["a"]), f.sync(["b"])]);
  assert.equal(Object.values(f.rows).filter((row) => row.isActive).length, 1);
});

test("a failed transfer rolls back revocation and does not invalidate committed cache", async () => {
  const f = fixture();
  await f.sync(["a"]);
  f.upstream.b = customer(true);
  f.invalidated.length = 0;
  f.failNextWrite();
  await assert.rejects(f.sync(["b"]), /database unavailable/);
  assert.equal(f.rows.a.isActive, true);
  assert.equal(f.rows.b, undefined);
  assert.deepEqual(f.invalidated, []);
});

test("an upstream failure for one transfer participant leaves the entire batch unchanged", async () => {
  const f = fixture();
  await f.sync(["a"]);
  f.upstream.a = customer(false);
  delete f.upstream.b;
  await assert.rejects(f.sync(["a", "b"]), /RevenueCat unavailable/);
  assert.equal(f.rows.a.isActive, true);
});

test("syncing inactive RevenueCat accounts retains independent Google and Creem membership", async () => {
  const f = fixture();
  f.upstream.google = customer(false);
  f.upstream.creem = customer(false);
  await f.sync(["google", "creem"]);
  assert.equal(f.users.google.subscriptionTier, "pro");
  assert.equal(f.users.creem.subscriptionTier, "pro");
});

test("uppercase legacy entitlement writes one canonical row and revokes on cross-account transfer", async () => {
  const f = fixture();
  const id = "c1a99945-082b-423f-bc09-eca9176b14f5";
  f.upstream[id] = customer(false);
  f.upstream[id.toUpperCase()] = customer(true);
  const result = await f.sync([id, id.toUpperCase()]);
  assert.equal(result.size, 1);
  assert.equal(result.get(id)?.active, true);
  assert.equal(f.rows[id.toUpperCase()], undefined);
  assert.equal(f.rows[id].isActive, true);
  f.upstream[id.toUpperCase()] = customer(false);
  f.upstream.b = customer(true);
  await f.sync([id.toUpperCase(), "b"]);
  assert.equal(f.rows[id].isActive, false);
  assert.equal(f.rows.b.isActive, true);
});

test("uppercase provider failure rolls back a previously active account", async () => {
  const f = fixture();
  const id = "c1a99945-082b-423f-bc09-eca9176b14f5";
  f.upstream[id] = customer(true);
  await f.sync([id]);
  f.upstream[id] = customer(false);
  await assert.rejects(f.sync([id]), /RevenueCat unavailable/);
  assert.equal(f.rows[id].isActive, true);
});
