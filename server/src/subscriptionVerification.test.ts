import assert from "node:assert/strict";
import test from "node:test";
import type { Express, Request, RequestHandler, Response } from "express";
import { registerSubscriptionVerificationRoutes } from "./subscriptionVerification.js";

function fixture(pro = false, unavailable = false) {
  const routes = new Map<string, RequestHandler>();
  const lookedUp: string[] = [];
  registerSubscriptionVerificationRoutes({
    post(path: string, _auth: RequestHandler, handler: RequestHandler) { routes.set(path, handler); }
  } as unknown as Express, (_req, _res, next) => next(), {
    upsertUser: async () => {},
    sync: async (userId) => {
      lookedUp.push(userId);
      if (unavailable) throw new Error("provider unavailable");
      return { active: pro, expiresAt: pro ? new Date("2030-01-01") : null,
        productId: pro ? "com.chillnote.pro.yearly" : null, store: "app_store", originalTransactionId: null };
    },
    effective: async () => ({ tier: pro ? "pro" : "free",
      expiresAt: pro ? new Date("2030-01-01") : null, source: pro ? "revenuecat" : null })
  });
  return {
    lookedUp,
    async call(path: string, body: unknown) {
      let status = 200;
      let response: any;
      const res = { status(code: number) { status = code; return res; }, json(value: unknown) { response = value; } };
      await routes.get(path)!({ userId: "authenticated-user", body } as Request, res as unknown as Response, () => {});
      return { status, response };
    }
  };
}

for (const path of ["/subscription/verify", "/subscription/revenuecat/sync"]) {
  test(`${path}: forged metadata, receipts and customer IDs cannot grant Pro`, async () => {
    const f = fixture();
    for (const expiresDate of ["2099-01-01", "not-a-date", "", null]) {
      const result = await f.call(path, { userId: "paid-victim", app_user_id: "paid-victim",
        productId: "com.chillnote.pro.yearly", originalTransactionId: "invented", receiptData: "fake", expiresDate });
      assert.equal(result.status, 200);
      assert.equal(result.response.tier, "free");
      assert.equal(result.response.expiresAt, null);
    }
    assert.deepEqual(f.lookedUp, Array(4).fill("authenticated-user"));
  });
  test(`${path}: shipped payload and empty sync return only verified expiry`, async () => {
    const f = fixture(true);
    for (const body of [{ transactionId: "old-client", expiresDate: "2099-01-01" }, undefined]) {
      const result = await f.call(path, body);
      assert.equal(result.response.tier, "pro");
      assert.equal(result.response.expiresAt, "2030-01-01T00:00:00.000Z");
    }
  });
  test(`${path}: verifier outage never falls back to client metadata`, async () => {
    const result = await fixture(false, true).call(path, { productId: "pro", expiresDate: "2099-01-01" });
    assert.equal(result.status, 503);
    assert.equal(result.response.tier, undefined);
  });
}
