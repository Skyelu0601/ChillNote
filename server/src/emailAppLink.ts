import type { Express } from "express";

export const EMAIL_APP_OPEN_PATH = "/email/open-app";
const APP_SCHEME_URL = "chillnote://open";
const APP_STORE_URL = "https://apps.apple.com/app/id6758427839";
const PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=com.sponteoai.chillscript";
const ANDROID_INTENT_URL = `intent://open#Intent;scheme=chillnote;package=com.sponteoai.chillscript;S.browser_fallback_url=${encodeURIComponent(PLAY_STORE_URL)};end`;

export function emailAppOpenURL(publicBaseURL: string): string {
  return `${publicBaseURL.replace(/\/$/, "")}${EMAIL_APP_OPEN_PATH}`;
}

// An HTTPS entry point survives email link rewriting. The explicit button remains
// available when a browser requires a fresh user gesture before opening an app.
export function renderEmailAppOpenPage(): string {
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex"><title>Open ChillScript</title>
<style>body{margin:0;background:#FAF8F3;color:#17181B;font-family:system-ui,sans-serif}main{max-width:420px;margin:12vh auto;padding:32px}h1{font-size:32px}p{line-height:1.6;color:#55575E}.button{display:inline-block;background:#176BCB;color:white;padding:16px 24px;border-radius:8px;text-decoration:none;font-weight:700}nav{display:flex;gap:20px;flex-wrap:wrap}nav a{color:#176BCB}</style></head>
<body><main><h1>Open ChillScript</h1><p id="message">Continue in the app. If it doesn't open automatically, tap below.</p>
<a id="open-app" class="button" href="${APP_SCHEME_URL}">Open ChillScript</a>
<p>Need to install or update ChillScript?</p><nav><a href="${APP_STORE_URL}">App Store</a><a href="${PLAY_STORE_URL}">Google Play</a></nav>
<noscript><p>On Android, update ChillScript if the app doesn't open.</p></noscript></main>
<script>
const android = /Android/i.test(navigator.userAgent);
const ios = /iPhone|iPad|iPod/i.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
const button = document.getElementById('open-app');
if (android) button.href = ${JSON.stringify(ANDROID_INTENT_URL)};
if (android || ios) {
  window.location.href = button.href;
} else {
  document.getElementById('message').textContent = 'Open this email on your phone to continue in ChillScript.';
  button.hidden = true;
  button.style.display = 'none';
}
</script></body></html>`;
}

export function registerEmailAppOpenRoute(app: Express): void {
  app.get(EMAIL_APP_OPEN_PATH, (_req, res) => {
    res.setHeader("Cache-Control", "no-store");
    res.setHeader("Referrer-Policy", "no-referrer");
    res.setHeader("X-Content-Type-Options", "nosniff");
    res.setHeader("Content-Security-Policy", "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'");
    res.type("html").send(renderEmailAppOpenPage());
  });
}
