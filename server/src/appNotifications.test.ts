import assert from "node:assert/strict";
import test from "node:test";
import type { Express, RequestHandler } from "express";
import type { PrismaClient } from "@prisma/client";
import { registerAppNotificationRoutes } from "./appNotifications.js";

const notificationID = "00000000-0000-4000-8000-000000000001";
function fixture(options: { tier?: string; eligible?: boolean; amount?: number | null; balance?: number; oldAuth?: boolean; fail?: boolean } = {}) {
  const now = new Date();
  let tier = options.tier ?? "free";
  let grant: { balance: number; initialGrantAmount: number | null } | null = options.amount !== undefined
    ? { balance: options.balance ?? 2, initialGrantAmount: options.amount } : null;
  const messages: Array<{ id: string; userId: string; dedupeKey: string; kind: string; amount: number | null; readAt: Date | null; createdAt: Date }> = [];
  const methods = new Map<string, RequestHandler>();
  const auth: RequestHandler = (_req, _res, next) => next();
  const register = (path: string, middleware: RequestHandler, handler: RequestHandler) => {
    assert.equal(middleware, auth, "all inbox endpoints require authentication");
    methods.set(path, handler);
  };
  const db = {
    user: { findUniqueOrThrow: async () => ({ welcomeNotificationEligible: options.eligible ?? true, createdAt: now }) },
    userCredits: { upsert: async ({ create }: any) => grant ??= create },
    appNotification: {
      findUnique: async () => messages.find(m => m.userId === "user-a") ?? null,
      upsert: async ({ create }: any) => {
        const found = messages.find(m => m.userId === create.userId && m.dedupeKey === create.dedupeKey);
        if (!found) messages.push({ id: notificationID, readAt: null, createdAt: now, ...create });
      },
      updateMany: async ({ where, data }: any) => {
        if (options.fail) throw new Error("database unavailable");
        for (const message of messages) {
          if (message.userId !== where.userId) continue;
          if (where.kind && message.kind !== where.kind) continue;
          if (where.id && !where.id.in.includes(message.id)) continue;
          if (where.readAt === null && message.readAt !== null) continue;
          Object.assign(message, data);
        }
      },
      findMany: async ({ where }: any) => messages.filter(m => m.userId === where.userId).map(m => ({ ...m })),
    },
    $transaction: async (body: (db: unknown) => Promise<unknown>) => body(db),
  };
  registerAppNotificationRoutes({ get: register, post: register } as unknown as Express, auth, {
    prisma: db as unknown as PrismaClient,
    upsertUser: async () => {},
    resolveTier: async () => { if (options.fail) throw new Error("subscription unavailable"); return tier; },
    initialCredits: 50,
  });
  async function call(path = "/notifications", body: unknown = undefined, userId = "user-a") {
    let status = 200;
    let json: any;
    const response = { status: (code: number) => { status = code; return response; }, json: (value: unknown) => { json = value; } };
    await methods.get(path)!({ userId, userCreatedAt: options.oldAuth ? "2020-01-01T00:00:00Z" : now.toISOString(), body } as any, response as any, () => {});
    return { status, json };
  }
  return { call, messages, grant: () => grant, setTier: (value: string) => { tier = value; } };
}

test("free welcome is issued once with actual credited amount, not remaining balance", async () => {
  const f = fixture({ amount: 75, balance: 2 });
  assert.equal((await f.call()).json.notifications[0].amount, 75);
  await f.call();
  assert.equal(f.messages.length, 1);
  assert.equal(f.grant()?.balance, 2);
});
test("new free account atomically creates grant before announcement", async () => {
  const f = fixture();
  assert.equal((await f.call()).json.notifications[0].amount, 50);
  assert.equal(f.grant()?.balance, 50);
});
test("prepaid new users receive welcome without creating free credits", async () => {
  const f = fixture({ tier: "pro" });
  const item = (await f.call()).json.notifications[0];
  assert.equal(item.kind, "welcome_pro");
  assert.equal(item.amount, null);
  assert.equal(f.grant(), null);
});
test("existing accounts and historical unknown grants never get a false gift", async () => {
  for (const options of [{ eligible: false }, { oldAuth: true }, { amount: null }]) {
    const f = fixture(options);
    assert.deepEqual((await f.call()).json.notifications, []);
  }
});
test("upgrade replaces welcome content but preserves its identity and read state", async () => {
  const f = fixture();
  await f.call();
  await f.call("/notifications/read", { ids: [notificationID] });
  const readAt = f.messages[0].readAt;
  f.setTier("pro");
  await f.call();
  assert.equal(f.messages.length, 1);
  assert.equal(f.messages[0].kind, "welcome_pro");
  assert.equal(f.messages[0].readAt, readAt);
  f.setTier("free");
  await f.call();
  assert.equal(f.messages[0].kind, "welcome_pro", "expiration does not create another gift");
});
test("read is account-scoped, idempotent and survives fetching again", async () => {
  const f = fixture();
  await f.call();
  await f.call("/notifications/read", { ids: [notificationID] }, "user-b");
  assert.equal(f.messages[0].readAt, null);
  await f.call("/notifications/read", { ids: [notificationID] });
  const readAt = f.messages[0].readAt;
  await f.call("/notifications/read", { ids: [notificationID] });
  assert.equal((await f.call()).json.notifications[0].readAt, readAt);
});
test("malformed read bodies fail without acknowledging anything", async () => {
  const f = fixture();
  await f.call();
  for (const body of [undefined, {}, { ids: [] }, { ids: ["not-a-uuid"] }]) {
    assert.equal((await f.call("/notifications/read", body)).status, 400);
  }
  assert.equal(f.messages[0].readAt, null);
});
test("subscription and database failures do not fabricate successful responses", async () => {
  const f = fixture({ fail: true });
  assert.equal((await f.call()).status, 503);
  assert.equal((await f.call("/notifications/read", { ids: [notificationID] })).status, 503);
  assert.deepEqual(f.messages, []);
});
