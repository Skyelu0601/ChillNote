export type UnsubscribeCategory = "marketing" | "subscription_billing";

export type CategoryPreference = {
  marketingStatus?: string | null;
  subscriptionBillingEmailsEnabled?: boolean | null;
} | null;

// The account owner confirmed Marketing is enabled by default. A missing or
// legacy "unknown" preference is eligible until the user explicitly opts out.
export function marketingEmailsEnabled(preference: CategoryPreference): boolean {
  return preference?.marketingStatus !== "unsubscribed";
}

export function categoryForEmailKind(kind: string): UnsubscribeCategory | null {
  if (kind.startsWith("marketing_winback_") || kind === "trial_cancelled_winback") return "marketing";
  if (kind === "trial_ending_48h" || kind === "trial_ending_24h" || kind === "billing_issue" || kind === "renewal_check") {
    return "subscription_billing";
  }
  return null;
}

export function categoryAllowsEmail(kind: string, preference: CategoryPreference): boolean {
  switch (categoryForEmailKind(kind)) {
    case "marketing": return marketingEmailsEnabled(preference);
    case "subscription_billing": return preference?.subscriptionBillingEmailsEnabled !== false;
    default: return false;
  }
}

export function parseUnsubscribeCategories(value: unknown): UnsubscribeCategory[] | null {
  if (value === undefined) return [];
  const values = Array.isArray(value) ? value : [value];
  if (values.length > 2 || values.some((item) =>
    item !== "marketing" && item !== "subscription_billing"
  )) return null;
  return [...new Set(values)] as UnsubscribeCategory[];
}

function escapeHTML(value: string): string {
  return value.replaceAll("&", "&amp;").replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll("'", "&#39;");
}

export function renderEmailChoicesPage(
  token: string,
  preference: CategoryPreference,
  state: "form" | "saved" | "empty" | "invalid" = "form"
): string {
  const invalid = state === "invalid";
  const action = `/email/unsubscribe/choices?token=${encodeURIComponent(token)}`;
  const categories: Array<{ id: UnsubscribeCategory; title: string; off: boolean }> = [
    {
      id: "marketing",
      title: "Marketing",
      off: !marketingEmailsEnabled(preference)
    },
    {
      id: "subscription_billing",
      title: "Subscription and billing",
      off: preference?.subscriptionBillingEmailsEnabled === false
    }
  ];
  const rows = categories.map((category) => `
    <label class="choice"><input type="checkbox" name="unsubscribe" value="${category.id}"${category.off ? " checked disabled" : ""}>
      <span><strong>${escapeHTML(category.title)}</strong>${category.off ? '<em>Unsubscribed</em>' : ""}</span>
    </label>`).join("");
  const content = invalid
    ? "<h1>This link doesn't work.</h1><p>Try the link in a more recent ChillScript email.</p>"
    : `<h1>Which emails would you like to stop?</h1><p>Check the ones you don't want. We'll leave the rest alone.</p>
      ${state === "saved" ? '<p class="notice" role="status">Done. We have stopped the emails you selected.</p>' : ""}
      ${state === "empty" ? '<p class="notice" role="status">Choose at least one email type to stop.</p>' : ""}
      <form method="post" action="${escapeHTML(action)}">${rows}<button type="submit">Stop these emails</button></form>
      <p class="fine">Unsubscribing from subscription and billing emails does not cancel your subscription or stop charges from the App Store or Google Play. To subscribe again, contact <a href="mailto:support@chillnoteai.com">support@chillnoteai.com</a>.</p>`;
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Email choices | ChillScript</title><style>
    *{box-sizing:border-box}body{margin:0;background:#FAF8F3;color:#17181B;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif}.shell{max-width:620px;margin:0 auto;padding:0 22px 56px}.rule{height:6px;background:#2F86FF}.brand{padding-top:38px;font-size:23px;font-weight:800;letter-spacing:-.7px}.brand span{color:#176BCB}h1{font-size:clamp(32px,7vw,46px);line-height:1.06;letter-spacing:-1.8px;margin:55px 0 15px}p{color:#5A5C63;line-height:1.6;margin:0 0 24px}.choice{display:flex;gap:16px;padding:20px 0;border-top:1px solid #DDD8CF;cursor:pointer}.choice:last-of-type{border-bottom:1px solid #DDD8CF}.choice input{width:20px;height:20px;accent-color:#176BCB;margin:2px 0 0;flex:none}.choice strong{display:block;font-size:17px}.choice small{display:block;color:#64666D;line-height:1.5;font-size:14px;margin-top:5px}.choice em{display:block;color:#176BCB;font-size:12px;font-style:normal;font-weight:700;margin-top:7px}button{margin-top:28px;background:#176BCB;border:0;border-radius:8px;color:white;padding:15px 22px;font:700 15px inherit;cursor:pointer}.fine{font-size:12px;margin-top:30px}.notice{padding:15px 18px;background:#E9F4EC;color:#1D6337;border-left:3px solid #2C9B55}
  </style></head><body><main class="shell"><div class="rule"></div><div class="brand">Chill<span>Script</span></div>${content}</main></body></html>`;
}
