export type TrialEndingTemplateInput = {
  expiresAt: Date;
  hoursRemaining: 24 | 48;
  manageSubscriptionURL: string;
  emailChoicesURL?: string;
};

export type CancelledTrialTemplateInput = {
  expiresAt: Date;
  manageSubscriptionURL: string;
  emailChoicesURL?: string;
};

export type BillingIssueTemplateInput = {
  manageSubscriptionURL: string;
  emailChoicesURL?: string;
};

export type RenderedEmail = {
  subject: string;
  html: string;
  text: string;
};

type LifecycleTemplateContent = {
  subject: string;
  preheader: string;
  badge: string;
  heading: string;
  headingAccent: string;
  intro: string;
  accent: string;
  panelLabel: string;
  panelValue: string;
  paragraphs: string[];
  valueTitle?: string;
  values?: string[];
  buttonLabel: string;
  manageSubscriptionURL: string;
  serviceNote: string;
  emailChoicesURL?: string;
};

function escapeHTML(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function formatExpiry(date: Date): string {
  return new Intl.DateTimeFormat("en", {
    year: "numeric",
    month: "long",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
    timeZone: "UTC",
    timeZoneName: "short"
  }).format(date);
}

function renderLifecycleEmail(content: LifecycleTemplateContent): RenderedEmail {
  const manageURL = escapeHTML(content.manageSubscriptionURL);
  const emailChoicesURL = content.emailChoicesURL ? escapeHTML(content.emailChoicesURL) : null;
  const paragraphs = content.paragraphs
    .map((paragraph) => `<p style="margin:0;padding-top:14px;color:#3F4148;font-size:15px;line-height:24px">${escapeHTML(paragraph)}</p>`)
    .join("");
  const valueRows = content.values?.map((value, index) => `
    <tr>
      <td style="padding:${index === 0 ? "13px 0" : "13px 0"};border-top:1px solid #DDD8CF;color:#22242A;font-size:14px;line-height:21px;font-weight:650">
        ${escapeHTML(value)}
      </td>
    </tr>`).join("") ?? "";
  const valueSection = content.values?.length ? `
    <tr>
      <td style="padding-top:30px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="width:100%;border-bottom:1px solid #DDD8CF">
          <tr><td style="padding:0 0 11px;color:#74757B;font-size:10px;line-height:14px;font-weight:800;letter-spacing:1.5px;text-transform:uppercase">${escapeHTML(content.valueTitle ?? "With Pro")}</td></tr>
          ${valueRows}
        </table>
      </td>
    </tr>` : "";

  const text = [
    `${content.heading} ${content.headingAccent}`,
    "",
    content.intro,
    `${content.panelLabel}: ${content.panelValue}`,
    ...content.paragraphs,
    ...(content.values?.length ? ["", content.valueTitle ?? "With Pro", ...content.values] : []),
    "",
    `${content.buttonLabel}: ${content.manageSubscriptionURL}`,
    "",
    content.serviceNote,
    ...(content.emailChoicesURL ? [`Email choices: ${content.emailChoicesURL}`] : []),
    "Questions? Reply to this email or contact support@chillnoteai.com.",
    "",
    "Keep creating,",
    "The ChillScript Team"
  ].join("\n");

  return {
    subject: content.subject,
    text,
    html: `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="color-scheme" content="light">
  <meta name="supported-color-schemes" content="light">
  <title>${escapeHTML(content.subject)}</title>
  <style>
    @media only screen and (max-width: 620px) {
      .email-shell { padding: 0 20px 32px !important; }
      .email-content { padding: 42px 0 0 !important; }
      .email-heading { font-size: 38px !important; line-height: 42px !important; letter-spacing: -1.5px !important; }
      .email-button { display: block !important; text-align: center !important; }
    }
  </style>
</head>
<body style="margin:0;background:#FAF8F3;color:#17181B;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif;-webkit-font-smoothing:antialiased">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent">${escapeHTML(content.preheader)}</div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="width:100%;background:#FAF8F3">
    <tr>
      <td class="email-shell" align="center" style="padding:0 24px 48px">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="width:100%;max-width:600px">
          <tr><td style="height:6px;background:#2F86FF;font-size:0;line-height:0">&nbsp;</td></tr>
          <tr>
            <td style="padding:42px 0 0">
              <table role="presentation" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="padding-right:12px;vertical-align:middle"><img src="https://www.chillnoteai.com/assets/chillscript-logo.png" width="42" height="42" alt="" style="display:block;width:42px;height:42px;border:0;border-radius:10px"></td>
                  <td style="vertical-align:middle;color:#17181B;font-size:22px;font-weight:800;letter-spacing:-0.8px;white-space:nowrap">Chill<span style="color:#2F86FF">Script</span></td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td class="email-content" style="padding:58px 0 0">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                <tr><td style="color:#6B6D73;font-size:11px;line-height:15px;font-weight:800;letter-spacing:1.8px;text-transform:uppercase">${escapeHTML(content.badge)}</td></tr>
                <tr><td style="padding-top:16px"><h1 class="email-heading" style="margin:0;color:#17181B;font-size:48px;line-height:51px;letter-spacing:-2.4px;font-weight:830">${escapeHTML(content.heading)}<br><span style="color:${content.accent}">${escapeHTML(content.headingAccent)}</span></h1></td></tr>
                <tr><td style="padding-top:22px;color:#55575E;font-size:17px;line-height:27px">${escapeHTML(content.intro)}</td></tr>
                <tr>
                  <td style="padding-top:34px">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="width:100%;background:#FFFDF8;border-top:3px solid ${content.accent};border-bottom:1px solid #DED8CD;box-shadow:0 10px 24px rgba(45,40,32,0.07)">
                      <tr>
                        <td style="padding:24px 28px 27px">
                          <div style="color:${content.accent};font-family:Georgia,'Times New Roman',serif;font-size:18px;line-height:24px;font-style:italic;font-weight:700">${escapeHTML(content.panelLabel)}</div>
                          <div style="padding-top:9px;color:#272930;font-family:Georgia,'Times New Roman',serif;font-size:20px;line-height:30px;font-style:italic">${escapeHTML(content.panelValue)}</div>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
                <tr><td>${paragraphs}</td></tr>
                ${valueSection}
                <tr>
                  <td style="padding-top:34px">
                    <table role="presentation" cellpadding="0" cellspacing="0">
                      <tr>
                        <td bgcolor="${content.accent}" style="border-radius:8px"><a class="email-button" href="${manageURL}" style="display:inline-block;padding:16px 24px;color:#FFFFFF;text-decoration:none;font-size:15px;line-height:20px;font-weight:800">${escapeHTML(content.buttonLabel)}&nbsp;&nbsp;&rarr;</a></td>
                      </tr>
                    </table>
                  </td>
                </tr>
                <tr><td style="padding-top:38px;color:#42444A;font-family:Georgia,'Times New Roman',serif;font-size:15px;line-height:23px">Keep creating,<br><em>The ChillScript Team</em></td></tr>
                <tr>
                  <td style="padding-top:40px">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="width:100%;border-top:1px solid #D8D2C8">
                      <tr><td style="padding-top:20px;color:#74757B;font-size:11px;line-height:18px">${escapeHTML(content.serviceNote)}</td></tr>
                      ${emailChoicesURL ? `<tr><td style="padding-top:10px;color:#74757B;font-size:11px;line-height:18px"><a href="${emailChoicesURL}" style="color:#5E6066;text-decoration:underline">Choose which ChillScript emails you receive</a>.</td></tr>` : ""}
                      <tr><td style="padding-top:10px;color:#74757B;font-size:11px;line-height:18px">Questions? Reply to this email or contact <a href="mailto:support@chillnoteai.com" style="color:#176BCB;text-decoration:underline">support@chillnoteai.com</a>.</td></tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`
  };
}

export function renderTrialEndingEmail(input: TrialEndingTemplateInput): RenderedEmail {
  const expiry = formatExpiry(input.expiresAt);
  const isFinalReminder = input.hoursRemaining === 24;
  return renderLifecycleEmail({
    subject: isFinalReminder
      ? "Your ChillScript Pro trial ends tomorrow"
      : "Your ChillScript Pro trial ends in 2 days",
    preheader: "Your paid subscription starts automatically unless you cancel through your store.",
    badge: "Trial reminder",
    heading: "Your Pro trial",
    headingAccent: isFinalReminder ? "ends tomorrow." : "ends in 2 days.",
    intro: "Your paid subscription will begin automatically after your trial unless you cancel through the App Store or Google Play.",
    accent: isFinalReminder ? "#B86F12" : "#176BCB",
    panelLabel: "Trial ends",
    panelValue: expiry,
    paragraphs: [
      "Want to keep Pro? No action is needed.",
      "To cancel, open your subscription settings and check your store's cancellation deadline. You can also review your plan and price there."
    ],
    buttonLabel: "Manage subscription",
    manageSubscriptionURL: input.manageSubscriptionURL,
    emailChoicesURL: input.emailChoicesURL,
    serviceNote: "This is a reminder about your ChillScript Pro trial. Billing and cancellation are managed by the App Store or Google Play."
  });
}

export function renderCancelledTrialEmail(input: CancelledTrialTemplateInput): RenderedEmail {
  const expiry = formatExpiry(input.expiresAt);
  return renderLifecycleEmail({
    subject: "Your next video could start with a saved idea",
    preheader: "Your Pro trial is still active. Try a saved note, a new hook, and the teleprompter.",
    badge: "Make something with Pro",
    heading: "Put a saved idea",
    headingAccent: "to work.",
    intro: "Your Pro trial is still active. Open a saved note in ChillScript and use Hook to find an opening for your next video.",
    accent: "#258C86",
    panelLabel: "You can keep using Pro until",
    panelValue: expiry,
    paragraphs: [
      "Build on that opening with your own take, then use the teleprompter to read your script as you film.",
      "Not sure which note to start with? Ask Chillo to find a video idea in your saved notes.",
      "Want to keep creating with Pro after your trial? Review your plan in the App Store or Google Play and turn renewal back on."
    ],
    buttonLabel: "Review renewal options",
    manageSubscriptionURL: input.manageSubscriptionURL,
    emailChoicesURL: input.emailChoicesURL,
    serviceNote: "Automatic renewal is currently off. Pro access ends on the date above unless you choose to renew. Subscription changes are managed by the App Store or Google Play."
  });
}

export function renderBillingIssueEmail(input: BillingIssueTemplateInput): RenderedEmail {
  return renderLifecycleEmail({
    subject: "Payment issue with your ChillScript Pro renewal",
    preheader: "Check your payment details in the App Store or Google Play.",
    badge: "Payment issue",
    heading: "Your Pro renewal",
    headingAccent: "couldn't be completed.",
    intro: "There is a billing issue with your ChillScript Pro renewal. Please review your subscription and payment method in the App Store or Google Play.",
    accent: "#B94A36",
    panelLabel: "What to do next",
    panelValue: "Open your store's subscription settings and follow the instructions to check or update your payment method.",
    paragraphs: [
      "The store may retry the payment. Your Pro access may be interrupted if the renewal remains unpaid.",
      "If you've already resolved this in your store, no further action is needed. It may take time for the update to reach ChillScript."
    ],
    buttonLabel: "Review subscription",
    manageSubscriptionURL: input.manageSubscriptionURL,
    emailChoicesURL: input.emailChoicesURL,
    serviceNote: "Payments and retries are managed by the App Store or Google Play. ChillScript does not receive your card details."
  });
}
