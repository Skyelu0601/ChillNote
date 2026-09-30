import assert from "node:assert/strict";
import test from "node:test";
import { renderMarketingWinbackEmail } from "./marketingEmailTemplates.js";

const unsubscribeURL = "https://api.chillnoteai.com/email/unsubscribe?token=test-token";

test("all win-back templates contain one CTA and a real unsubscribe URL", () => {
  const expectations = [
    ["marketing_winback_1", "Never lose a content idea."],
    ["marketing_winback_2", "Turn a saved idea into your next video."],
    ["marketing_winback_3", "Ask Chillo what to make from your notes"]
  ] as const;

  for (const [kind, subject] of expectations) {
    const email = renderMarketingWinbackEmail({
      kind,
      callToActionURL: "https://www.chillnoteai.com",
      unsubscribeURL,
      postalAddress: "ChillScript, 123 Test Street, Test City"
    });
    assert.equal(email.subject, subject);
    assert.match(email.html, /#FAF8F3/);
    assert.match(email.html, /Manage email choices/);
    assert.match(email.html, /test-token/);
    assert.match(email.text, /Manage email choices: https:\/\/api\.chillnoteai\.com/);
  }
});

test("marketing URLs are HTML escaped", () => {
  const email = renderMarketingWinbackEmail({
    kind: "marketing_winback_1",
    callToActionURL: "https://example.com/?a=1&b=<unsafe>",
    unsubscribeURL: "https://example.com/unsubscribe?a=1&b=<unsafe>",
    postalAddress: "123 Test Street & <unsafe>"
  });
  assert.doesNotMatch(email.html, /<unsafe>/);
  assert.match(email.html, /&amp;b=&lt;unsafe&gt;/);
});
