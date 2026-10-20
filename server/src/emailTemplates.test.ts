import assert from "node:assert/strict";
import test from "node:test";
import { renderBillingIssueEmail, renderCancelledTrialEmail, renderTrialEndingEmail } from "./emailTemplates.js";

test("48-hour trial reminder renders branded HTML and text with a safe subscription link", () => {
  const email = renderTrialEndingEmail({
    expiresAt: new Date("2026-09-28T12:00:00Z"),
    hoursRemaining: 48,
    manageSubscriptionURL: "https://apps.apple.com/account/subscriptions?test=<unsafe>",
    emailChoicesURL: "https://api.chillnoteai.com/email/unsubscribe?token=test"
  });
  assert.equal(email.subject, "Your ChillScript Pro trial ends in 2 days");
  assert.match(email.text, /September 28, 2026/);
  assert.match(email.text, /12:00 PM UTC/);
  assert.match(email.text, /paid subscription will begin automatically/i);
  assert.match(email.text, /apps\.apple\.com\/account\/subscriptions/);
  assert.match(email.html, /ends in 2 days/);
  assert.match(email.html, /chillscript-logo\.png/);
  assert.match(email.html, /Manage subscription/);
  assert.match(email.text, /cancellation deadline/);
  assert.match(email.text, /review your plan and price/);
  assert.match(email.html, /background:#FAF8F3/);
  assert.match(email.html, /font-family:Georgia/);
  assert.doesNotMatch(email.html, /border-radius:26px/);
  assert.doesNotMatch(email.html, /border-radius:999px/);
  assert.doesNotMatch(email.html, /<unsafe>/);
  assert.match(email.html, /test=&lt;unsafe&gt;/);
  assert.match(email.html, /Choose which ChillScript emails you receive/);
  assert.match(email.text, /Email choices: https:\/\/api\.chillnoteai\.com/);
});

test("24-hour trial reminder uses the final-reminder wording and urgency style", () => {
  const email = renderTrialEndingEmail({
    expiresAt: new Date("2026-09-28T12:00:00Z"),
    hoursRemaining: 24,
    manageSubscriptionURL: "https://play.google.com/store/account/subscriptions"
  });

  assert.equal(email.subject, "Your ChillScript Pro trial ends tomorrow");
  assert.match(email.text, /paid subscription will begin automatically/i);
  assert.match(email.html, /ends tomorrow/);
  assert.match(email.text, /September 28, 2026/);
  assert.match(email.text, /unless you cancel/);
  assert.match(email.html, /#B86F12/);
  assert.match(email.html, /Google Play/);
});

test("cancelled trial email invites creation while keeping renewal status and expiry clear", () => {
  const email = renderCancelledTrialEmail({
    expiresAt: new Date("2026-09-28T12:00:00Z"),
    manageSubscriptionURL: "https://apps.apple.com/account/subscriptions"
  });

  assert.equal(email.subject, "Your next video could start with a saved idea");
  assert.match(email.text, /Automatic renewal is currently off/);
  assert.match(email.text, /You can keep using Pro until: September 28, 2026/);
  assert.match(email.text, /trial is still active/);
  assert.match(email.text, /Hook/);
  assert.match(email.text, /teleprompter/);
  assert.match(email.text, /Chillo/);
  assert.match(email.html, /Review renewal options/);
  assert.match(email.html, /href="https:\/\/apps\.apple\.com\/account\/subscriptions"/);
});

test("billing issue email focuses on payment recovery without claiming cancellation", () => {
  const email = renderBillingIssueEmail({
    manageSubscriptionURL: "https://play.google.com/store/account/subscriptions"
  });

  assert.equal(email.subject, "Payment issue with your ChillScript Pro renewal");
  assert.match(email.html, /Payment issue/);
  assert.match(email.text, /There is a billing issue/);
  assert.doesNotMatch(email.text, /reported a payment issue|awaiting confirmation/);
  assert.match(email.text, /check or update your payment method/);
  assert.match(email.text, /access may be interrupted/);
  assert.match(email.html, /Review subscription/);
  assert.match(email.text, /may retry the payment/);
  assert.doesNotMatch(email.text, /set not to renew/);
});
