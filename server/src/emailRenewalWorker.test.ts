import assert from "node:assert/strict";
import test from "node:test";
import type { RevenueCatCustomerResponse } from "./revenueCat.js";
import { billingRecoveryKey, RENEWAL_CHECK_DELAY_MS } from "./renewalCheck.js";

test("billing-day worker checks fresh status and sends at most one appropriate recovery reminder", async (t) => {
  // All external services below are replaced before invoking the worker.
  process.env.EMAIL_ENABLED = "true";
  process.env.SES_REGION = "us-east-1";
  process.env.SES_FROM_EMAIL = "test@example.invalid";
  process.env.SUPABASE_URL = "https://example.invalid";
  process.env.SUPABASE_SERVICE_ROLE_KEY = "test-only-key";
  const { prisma } = await import("./db.js");
  const { supabaseAdmin } = await import("./supabase.js");
  const { SESv2Client } = await import("@aws-sdk/client-sesv2");
  const { runEmailWorker, handleRevenueCatEmailLifecycle } = await import("./email.js");
  const stub = (target: any, name: string, implementation: (...args: any[]) => any) => {
    const original = target[name];
    target[name] = implementation;
    t.after(() => { target[name] = original; });
  };
  const db = prisma as any;
  const due = new Date(Date.now() - 70 * 60_000);
  const nextDue = new Date(due.getTime() + 7 * 24 * 60 * 60_000);
  let rows: any[] = [];
  let sent: any[] = [];
  let preferences: any = null;
  let confirmedEmail = true;
  let failLookup = false;
  let fetchCount = 0;
  let scannerCandidates = [{ userId: "user", expiresAt: due }];
  let body: RevenueCatCustomerResponse;
  const matches = (row: any, where: any): boolean => Object.entries(where ?? {}).every(([key, expected]: [string, any]) => {
    const value = row[key];
    if (expected && typeof expected === "object" && !(expected instanceof Date)) {
      if ("in" in expected && !expected.in.includes(value)) return false;
      if ("not" in expected && value === expected.not) return false;
      if ("gte" in expected && !(value >= expected.gte)) return false;
      if ("gt" in expected && !(value > expected.gt)) return false;
      if ("lte" in expected && !(value <= expected.lte)) return false;
      return true;
    }
    return value instanceof Date && expected instanceof Date ? +value === +expected : value === expected;
  });
  const upsert = ({ where, create, update }: any) => {
    const existing = rows.find((row) => row.dedupeKey === where.dedupeKey);
    if (existing) { Object.assign(existing, update); return existing; }
    const row = { id: `delivery-${rows.length}`, status: "scheduled", attempts: 0, ...create };
    rows.push(row);
    return row;
  };
  stub(db.emailDelivery, "upsert", async (args: any) => upsert(args));
  stub(db.emailDelivery, "update", async ({ where, data }: any) => Object.assign(rows.find((row) => row.id === where.id), data));
  stub(db.emailDelivery, "updateMany", async ({ where, data }: any) => {
    const matching = rows.filter((row) => matches(row, where));
    for (const row of matching) Object.assign(row, data);
    return { count: matching.length };
  });
  stub(db.emailDelivery, "findFirst", async ({ where }: any) => rows.find((row) => matches(row, where)) ?? null);
  stub(db.emailDelivery, "findUnique", async ({ where }: any) => rows.find((row) => row.id === where.id) ?? null);
  stub(db, "$queryRaw", async () => {
    const row = rows.find((row) => row.status === "scheduled" && row.scheduledAt <= new Date());
    if (!row) return [];
    row.status = "processing"; row.attempts++;
    return [{ ...row }];
  });
  stub(db.emailPreference, "findUnique", async () => preferences);
  stub(db.emailPreference, "findMany", async () => preferences ? [{ userId: "user", ...preferences }] : []);
  stub(db.emailPreference, "upsert", async () => ({}));
  stub(db.emailPreference, "updateMany", async () => ({ count: 1 }));
  stub(db.revenueCatWebhookEvent, "findFirst", async () => null);
  stub(db.revenueCatEntitlement, "findMany", async ({ where }: any) => where.userId ? [] : scannerCandidates);
  stub(db.revenueCatEntitlement, "findFirst", async () => ({
    isActive: true, expiresAt: due, store: "play_store", productId: "weekly"
  }));
  stub(db.user, "findUnique", async () => ({ subscriptionProvider: null, originalTransactionId: null }));
  stub(supabaseAdmin.auth.admin, "getUserById", async () => ({
    data: { user: { email: "test@example.invalid", email_confirmed_at: confirmedEmail ? "2026-01-01" : null } }, error: null
  }) as any);
  stub(SESv2Client.prototype, "send", async (command: any) => {
    sent.push(command.input);
    return { MessageId: "fake-message" };
  });
  const deps = { entitlementId: "pro", fetchCustomer: async () => {
    fetchCount++;
    if (failLookup) throw new Error("RevenueCat unavailable");
    return body;
  } };
  const reset = (overrides = {}) => {
    rows = []; sent = []; preferences = null; confirmedEmail = true; failLookup = false; fetchCount = 0;
    body = { subscriber: {
      entitlements: { pro: { product_identifier: "weekly", expires_date: due.toISOString() } },
      subscriptions: { weekly: {
        store: "play_store", purchase_date: new Date(due.getTime() - 7 * 24 * 60 * 60_000).toISOString(),
        expires_date: due.toISOString(), ...overrides
      } }
    } };
  };
  const seed = () => upsert({ where: { dedupeKey: billingRecoveryKey("user", due) }, create: {
    userId: "user", kind: "renewal_check", dedupeKey: billingRecoveryKey("user", due),
    expectedExpiresAt: due, scheduledAt: new Date(due.getTime() + RENEWAL_CHECK_DELAY_MS)
  }, update: {} });

  await t.test("scanner sends a billing issue email one hour after billing without waiting for a webhook", async () => {
    reset({ expires_date: nextDue.toISOString() }); // silent grace extension
    await runEmailWorker(deps);
    assert.equal(rows[0].scheduledAt.getTime(), due.getTime() + RENEWAL_CHECK_DELAY_MS);
    assert.equal(sent.length, 1);
    assert.equal(RENEWAL_CHECK_DELAY_MS, 60 * 60_000);
    assert.equal(sent[0].Content.Simple.Subject.Data, "Payment issue with your ChillScript Pro renewal");
    assert.match(sent[0].Content.Simple.Body.Text.Data, /There is a billing issue/);
    assert.equal(fetchCount, 1);
    scannerCandidates = [];
    await runEmailWorker(deps);
    assert.equal(sent.length, 1);
    await handleRevenueCatEmailLifecycle({
      id: "late-issue", type: "BILLING_ISSUE", event_timestamp_ms: +due,
      expiration_at_ms: +nextDue, grace_period_expiration_at_ms: +nextDue
    }, ["user"]);
    await runEmailWorker(deps);
    assert.equal(sent.length, 1, "delayed billing webhook must not duplicate the reminder");
  });

  await t.test("an old five-minute check is deferred until one hour has elapsed without querying or emailing", async () => {
    reset(); seed();
    const recentDue = new Date(Date.now() - 30 * 60_000);
    rows[0].expectedExpiresAt = recentDue;
    rows[0].scheduledAt = new Date(recentDue.getTime() + 5 * 60_000);
    await runEmailWorker(deps);
    assert.equal(sent.length, 0); assert.equal(fetchCount, 0);
    assert.equal(rows[0].status, "scheduled");
    assert.equal(rows[0].scheduledAt.getTime(), recentDue.getTime() + 60 * 60_000);
  });

  await t.test("fresh successful renewal cancels the old reminder and queues the next billing date", async () => {
    reset({ purchase_date: due.toISOString(), expires_date: nextDue.toISOString() }); seed();
    await runEmailWorker(deps);
    assert.equal(sent.length, 0);
    assert.equal(rows[0].lastError, "renewal_renewed");
    assert.equal(rows[1].expectedExpiresAt.getTime(), +nextDue);
  });

  await t.test("a confirmed billing error uses the recovery template even while Pro is active", async () => {
    reset({ billing_issues_detected_at: due.toISOString() }); seed();
    await runEmailWorker(deps);
    assert.equal(sent.length, 1);
    assert.equal(sent[0].Content.Simple.Subject.Data, "Payment issue with your ChillScript Pro renewal");
  });

  await t.test("cancelled subscriptions, category opt-outs, suppression and unconfirmed email do not send", async () => {
    reset({ unsubscribe_detected_at: due.toISOString() }); seed();
    await runEmailWorker(deps); assert.equal(sent.length, 0);
    for (const preference of [{ subscriptionBillingEmailsEnabled: false }, { serviceSuppressedAt: new Date() }]) {
      reset(); seed(); preferences = preference;
      await runEmailWorker(deps); assert.equal(sent.length, 0); assert.equal(fetchCount, 0);
    }
    reset(); seed(); confirmedEmail = false;
    await runEmailWorker(deps); assert.equal(sent.length, 0); assert.equal(rows[0].status, "skipped");
  });

  await t.test("API failure retries without sending; checks over a day old are cancelled", async () => {
    reset(); seed(); failLookup = true;
    await runEmailWorker(deps);
    assert.equal(sent.length, 0); assert.equal(rows[0].status, "scheduled");
    assert.ok(rows[0].scheduledAt > new Date());
    reset(); seed(); rows[0].expectedExpiresAt = new Date(Date.now() - 25 * 60 * 60_000);
    await runEmailWorker(deps);
    assert.equal(sent.length, 0); assert.equal(fetchCount, 0);
    assert.equal(rows[0].lastError, "renewal_check_too_late");
  });

  await t.test("missing ownership never sends or probes an uppercase ordinary account", async () => {
    reset(); seed(); body = { subscriber: { entitlements: {}, subscriptions: {} } };
    await runEmailWorker(deps);
    assert.equal(sent.length, 0); assert.equal(fetchCount, 1);
    assert.equal(rows[0].lastError, "renewal_subscription_changed");
  });

  await t.test("reaching a later grace deadline does not send another email for the same unpaid period", async () => {
    reset({
      purchase_date: new Date(+due - 14 * 24 * 60 * 60_000).toISOString(),
      billing_issues_detected_at: new Date(+due - 7 * 24 * 60 * 60_000).toISOString()
    }); seed();
    const previousDue = new Date(+due - 7 * 24 * 60 * 60_000);
    rows.push({
      id: "prior-reminder", userId: "user", kind: "renewal_check", status: "sent",
      expectedExpiresAt: previousDue, dedupeKey: billingRecoveryKey("user", previousDue)
    });
    await runEmailWorker(deps);
    assert.equal(sent.length, 0);
    assert.equal(rows[0].lastError, "renewal_already_reminded");
  });

  await t.test("a recovery reminder from an older paid period does not suppress a new billing date", async () => {
    const previousDue = new Date(+due - 7 * 24 * 60 * 60_000);
    reset({ purchase_date: previousDue.toISOString() }); seed();
    rows.push({
      id: "prior-reminder", userId: "user", kind: "renewal_check", status: "sent",
      expectedExpiresAt: previousDue, dedupeKey: billingRecoveryKey("user", previousDue)
    });
    await runEmailWorker(deps);
    assert.equal(sent.length, 1);
  });

  await t.test("voluntary cancellation stops the check and uncancellation can restore the same billing date", async () => {
    reset(); seed();
    const event = {
      id: "cancel", type: "CANCELLATION", cancel_reason: "UNSUBSCRIBE", period_type: "NORMAL",
      event_timestamp_ms: +due, expiration_at_ms: +due
    };
    await handleRevenueCatEmailLifecycle(event, ["user"]);
    assert.equal(rows[0].status, "cancelled");
    await runEmailWorker(deps); assert.equal(sent.length, 0);
    await handleRevenueCatEmailLifecycle({ ...event, id: "uncancel", type: "UNCANCELLATION" }, ["user"]);
    assert.equal(rows[0].status, "scheduled");
    await runEmailWorker(deps); assert.equal(sent.length, 1);
  });

  await t.test("a billing webhook promotes a queued check to an immediate recovery without a second row", async () => {
    reset(); seed(); rows[0].scheduledAt = nextDue;
    await handleRevenueCatEmailLifecycle({
      id: "issue", type: "BILLING_ISSUE", event_timestamp_ms: +due,
      expiration_at_ms: +due, grace_period_expiration_at_ms: +nextDue
    }, ["user"]);
    assert.equal(rows.length, 1);
    assert.equal(rows[0].kind, "billing_issue");
    await runEmailWorker(deps);
    assert.equal(sent.length, 1);
    assert.equal(sent[0].Content.Simple.Subject.Data, "Payment issue with your ChillScript Pro renewal");
  });
});
