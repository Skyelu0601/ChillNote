import assert from "node:assert/strict";
import test from "node:test";
import type { Express, Request, RequestHandler, Response } from "express";
import { registerSubscriptionVerificationRoutes, type VerificationFailure } from "./subscriptionVerification.js";
import { RevenueCatLookupError } from "./subscriptionDiagnostics.js";

function fixture(pro = false, unavailable = false, billingIssue = false,
  failAt?: "account" | "revenuecat_sync" | "effective_subscription" | "billing_issue", failure?: unknown,
  loggerUnavailable = false) {
  const routes = new Map<string, RequestHandler>();
  const lookedUp: string[] = [];
  const failures: VerificationFailure[] = [];
  const fail = (stage: typeof failAt) => { if (stage === failAt) throw failure; };
  registerSubscriptionVerificationRoutes({
    post(path: string, _auth: RequestHandler, handler: RequestHandler) { routes.set(path, handler); }
  } as unknown as Express, (_req, _res, next) => next(), {
    upsertUser: async () => { fail("account"); },
    sync: async (userId) => {
      lookedUp.push(userId);
      fail("revenuecat_sync");
      if (unavailable) throw new Error("provider unavailable");
      return { active: pro, expiresAt: pro ? new Date("2030-01-01") : null,
        productId: pro ? "com.chillnote.pro.yearly" : null, store: "app_store", originalTransactionId: null };
    },
    effective: async () => {
      fail("effective_subscription");
      return { tier: pro ? "pro" : "free",
        expiresAt: pro ? new Date("2030-01-01") : null, source: pro ? "revenuecat" : null };
    },
    billingIssue: async () => {
      fail("billing_issue");
      return billingIssue ? { store: "app_store", productId: "com.chillnote.pro.yearly" } : null;
    },
    onFailure: failure => {
      if (loggerUnavailable) throw new Error("Logger unavailable");
      failures.push(failure);
    }
  });
  return {
    lookedUp,
    failures,
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
    assert.equal(f.failures.length, 0);
  });
  test(`${path}: verifier outage never falls back to client metadata`, async () => {
    const result = await fixture(false, true).call(path, { productId: "pro", expiresDate: "2099-01-01" });
    assert.equal(result.status, 503);
    assert.equal(result.response.tier, undefined);
  });
  test(`${path}: billing warning comes from server state, not request metadata`, async () => {
    const active = await fixture(true, false, true).call(path, { billingIssue: false });
    assert.deepEqual(active.response.billingIssue,
      { store: "app_store", productId: "com.chillnote.pro.yearly" });
    const clear = await fixture().call(path, { billingIssue: true });
    assert.equal(clear.response.billingIssue, null);
  });
  test(`${path}: failures identify the failed stage without changing old client responses or exposing payloads`, async () => {
    for (const stage of ["account", "revenuecat_sync", "effective_subscription", "billing_issue"] as const) {
      const f = fixture(true, false, false, stage, new RevenueCatLookupError("http", 429));
      const result = await f.call(path, { receiptData: "private-receipt", purchaseToken: "private-token" });
      assert.deepEqual(result, { status: 503, response: { code: "SUBSCRIPTION_VERIFICATION_UNAVAILABLE" } });
      assert.equal(f.failures.length, 1);
      const failure = f.failures[0];
      assert.match(failure.accountRef, /^[a-f0-9]{16}$/);
      assert.deepEqual(f.failures[0], {
        event: "subscription_verification_failed", stage,
        accountRef: failure.accountRef,
        elapsedMs: failure.elapsedMs,
        category: "revenuecat_http", upstreamStatus: 429
      });
      assert.ok(failure.elapsedMs >= 0);
      assert.doesNotMatch(JSON.stringify(f.failures), /authenticated-user|private-receipt|private-token/);
    }
  });
  test(`${path}: a diagnostic logger failure preserves the unavailable response`, async () => {
    const f = fixture(false, true, false, undefined, undefined, true);
    assert.deepEqual(await f.call(path, undefined), {
      status: 503, response: { code: "SUBSCRIPTION_VERIFICATION_UNAVAILABLE" }
    });
  });
}
