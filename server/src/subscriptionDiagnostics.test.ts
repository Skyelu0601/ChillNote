import assert from "node:assert/strict";
import test from "node:test";
import { RevenueCatLookupError, subscriptionAccountRef, subscriptionErrorDetails } from "./subscriptionDiagnostics.js";

test("subscription diagnostics distinguish upstream, network, timeout, expiry and database failures", () => {
  assert.deepEqual(subscriptionErrorDetails(new RevenueCatLookupError("http", 503)),
    { category: "revenuecat_http", upstreamStatus: 503 });
  assert.deepEqual(subscriptionErrorDetails(new RevenueCatLookupError("not_configured")),
    { category: "revenuecat_not_configured", upstreamStatus: undefined });
  assert.deepEqual(subscriptionErrorDetails({ name: "AbortError" }), { category: "timeout" });
  assert.deepEqual(subscriptionErrorDetails(new Error("JWT has expired")), { category: "token_expired" });
  assert.deepEqual(subscriptionErrorDetails({ code: "P2028", message: "private query" }),
    { category: "database", code: "P2028" });
  assert.deepEqual(subscriptionErrorDetails(new Error("private url", { cause: { code: "ECONNRESET" } })),
    { category: "network", code: "ECONNRESET" });
});

test("diagnostic output omits raw credentials, error messages and account IDs", () => {
  const secret = "private-purchase-token";
  for (const error of [secret, new Error(secret), { name: secret, code: secret, message: secret, stack: secret }]) {
    assert.deepEqual(subscriptionErrorDetails(error), { category: "unknown" });
    assert.ok(!JSON.stringify(subscriptionErrorDetails(error)).includes(secret));
  }
  assert.match(subscriptionAccountRef(secret), /^[a-f0-9]{16}$/);
  assert.equal(subscriptionAccountRef(secret), subscriptionAccountRef(secret));
  assert.notEqual(subscriptionAccountRef(secret), subscriptionAccountRef("other-account"));
});
