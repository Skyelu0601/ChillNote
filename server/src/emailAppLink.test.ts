import assert from "node:assert/strict";
import test from "node:test";
import { runInNewContext } from "node:vm";
import type { Express } from "express";
import { emailAppOpenURL, registerEmailAppOpenRoute, renderEmailAppOpenPage } from "./emailAppLink.js";
import { renderMarketingWinbackEmail } from "./marketingEmailTemplates.js";

function openPage(userAgent: string, platform = "", maxTouchPoints = 0) {
  const button = { href: "chillnote://open", hidden: false, style: { display: "" } };
  const message = { textContent: "" };
  const location = { href: "" };
  const script = renderEmailAppOpenPage().match(/<script>([\s\S]*?)<\/script>/)![1];
  runInNewContext(script, {
    navigator: { userAgent, platform, maxTouchPoints }, window: { location },
    document: { getElementById: (id: string) => id === "open-app" ? button : message }
  });
  return { button, message, location };
}

test("iPhone and desktop-mode iPad open the existing scheme without recording", () => {
  for (const page of [openPage("iPhone"), openPage("Macintosh", "MacIntel", 5)]) {
    assert.equal(page.location.href, "chillnote://open");
    assert.equal(page.button.hidden, false);
  }
});

test("Android targets ChillScript with a Play Store fallback and a manual button", () => {
  const page = openPage("Mozilla/5.0 Android");
  assert.match(page.location.href, /^intent:\/\/open#Intent;scheme=chillnote;package=com\.sponteoai\.chillscript;/);
  const fallback = page.location.href.match(/S.browser_fallback_url=([^;]+)/)![1];
  assert.equal(decodeURIComponent(fallback), "https://play.google.com/store/apps/details?id=com.sponteoai.chillscript");
  assert.equal(page.button.href, page.location.href);
  assert.equal(page.button.hidden, false);
});

test("desktop does not attempt to open a mobile scheme", () => {
  const page = openPage("Macintosh", "MacIntel", 0);
  assert.equal(page.location.href, "");
  assert.equal(page.button.hidden, true);
  assert.match(page.message.textContent, /on your phone/);
});

test("all marketing CTAs use the HTTPS app-opening entry point", () => {
  const url = emailAppOpenURL("https://api.chillnoteai.com/");
  assert.equal(url, "https://api.chillnoteai.com/email/open-app");
  for (const kind of ["marketing_winback_1", "marketing_winback_2", "marketing_winback_3"] as const) {
    const email = renderMarketingWinbackEmail({ kind, callToActionURL: url, unsubscribeURL: "https://example.com/unsubscribe", postalAddress: "Test address" });
    assert.match(email.html, /href="https:\/\/api\.chillnoteai\.com\/email\/open-app"/);
    assert.match(email.text, /Open ChillScript: https:\/\/api\.chillnoteai\.com\/email\/open-app/);
  }
});

test("public route serves the static launch page without accepting redirect targets", () => {
  const headers: Record<string, string> = {};
  let body = "";
  const response = {
    setHeader: (key: string, value: string) => { headers[key] = value; },
    type: (type: string) => { assert.equal(type, "html"); return response; },
    send: (html: string) => { body = html; }
  };
  registerEmailAppOpenRoute({ get: (path: string, handler: Function) => {
    assert.equal(path, "/email/open-app");
    handler({ query: { redirect: "https://untrusted.example" } }, response);
  } } as unknown as Express);
  assert.equal(body, renderEmailAppOpenPage());
  assert.equal(headers["Cache-Control"], "no-store");
  assert.doesNotMatch(body, /untrusted\.example/);
});
