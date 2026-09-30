import assert from "node:assert/strict";
import test from "node:test";
import {
  categoryAllowsEmail,
  categoryForEmailKind,
  marketingEmailsEnabled,
  parseUnsubscribeCategories,
  renderEmailChoicesPage
} from "./emailPreferences.js";

test("each active email kind belongs to exactly one choice", () => {
  assert.equal(categoryForEmailKind("marketing_winback_1"), "marketing");
  assert.equal(categoryForEmailKind("marketing_winback_3"), "marketing");
  assert.equal(categoryForEmailKind("trial_ending_48h"), "subscription_billing");
  assert.equal(categoryForEmailKind("trial_cancelled_winback"), "marketing");
  assert.equal(categoryForEmailKind("billing_issue"), "subscription_billing");
  assert.equal(categoryForEmailKind("unknown"), null);
});

test("a category opt-out stops only that category", () => {
  const preference = {
    marketingStatus: "subscribed",
    subscriptionBillingEmailsEnabled: false
  };
  assert.equal(categoryAllowsEmail("marketing_winback_1", preference), true);
  assert.equal(categoryAllowsEmail("trial_ending_48h", preference), false);
  assert.equal(categoryAllowsEmail("trial_cancelled_winback", preference), true);
  assert.equal(categoryAllowsEmail("billing_issue", preference), false);
  assert.equal(categoryAllowsEmail("marketing_winback_1", null), true);
  assert.equal(categoryAllowsEmail("billing_issue", null), true);
  assert.equal(categoryAllowsEmail("trial_cancelled_winback", null), true);
  assert.equal(categoryAllowsEmail("marketing_winback_1", { marketingStatus: "unknown" }), true);
  assert.equal(categoryAllowsEmail("marketing_winback_1", { marketingStatus: "unsubscribed" }), false);
  assert.equal(marketingEmailsEnabled(null), true);
});

test("form accepts only known choices and never interprets missing boxes as opt-in", () => {
  assert.deepEqual(parseUnsubscribeCategories(["marketing", "subscription_billing"]), ["marketing", "subscription_billing"]);
  assert.deepEqual(parseUnsubscribeCategories("marketing"), ["marketing"]);
  assert.deepEqual(parseUnsubscribeCategories(undefined), []);
  assert.equal(parseUnsubscribeCategories("all"), null);
  assert.equal(parseUnsubscribeCategories({ marketing: true }), null);
});

test("choices page marks existing opt-outs and escapes the token", () => {
  const page = renderEmailChoicesPage("abc&\"<", {
    marketingStatus: "unsubscribed",
    subscriptionBillingEmailsEnabled: false
  });
  assert.match(page, /value="marketing" checked disabled/);
  assert.match(page, /value="subscription_billing" checked disabled/);
  assert.match(page, /<strong>Marketing<\/strong>/);
  assert.match(page, /<strong>Subscription and billing<\/strong>/);
  assert.doesNotMatch(page, /value="trial"|value="billing"|win-back|product updates/i);
  assert.match(page, /token=abc%26%22%3C/);
  assert.doesNotMatch(page, /abc&"</);
});

test("choices page treats missing preferences as subscribed until opt-out", () => {
  const page = renderEmailChoicesPage("token", null);
  assert.doesNotMatch(page, /value="marketing" checked disabled/);
  assert.match(page, /value="marketing"/);
});
