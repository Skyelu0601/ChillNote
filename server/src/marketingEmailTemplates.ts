import type { MarketingWinbackKind } from "./emailMarketing.js";
import type { RenderedEmail } from "./emailTemplates.js";

type MarketingTemplateInput = {
  kind: MarketingWinbackKind;
  callToActionURL: string;
  unsubscribeURL: string;
  postalAddress: string;
};

type MarketingCopy = {
  subject: string;
  preheader: string;
  eyebrow: string;
  heading: string;
  headingAccent: string;
  intro: string;
  noteLabel: string;
  note: string;
  body: string;
  button: string;
};

const COPY: Record<MarketingWinbackKind, MarketingCopy> = {
  marketing_winback_1: {
    subject: "Never lose a content idea.",
    preheader: "Save inspiration from TikTok, Instagram, and YouTube in one place.",
    eyebrow: "Save your inspiration",
    heading: "Never lose",
    headingAccent: "a content idea.",
    intro: "Ever see a video you want to come back to, then forget where you found it? Save content from TikTok, Instagram, and YouTube in ChillScript so you can find it when you need it.",
    noteLabel: "Keep what sparked the idea",
    note: "Save the video, then add a note about what you'd like to try in your own content.",
    body: "When it's time to create, you'll have a place to start.",
    button: "Open ChillScript"
  },
  marketing_winback_2: {
    subject: "Turn a saved idea into your next video.",
    preheader: "Find your opening with Hook, then film with the teleprompter.",
    eyebrow: "Create from your saved notes",
    heading: "You saved the idea.",
    headingAccent: "Now make it yours.",
    intro: "Open a saved note in ChillScript and use Hook to explore different opening lines. Pick one, then build your script around your own take on the topic.",
    noteLabel: "Ready to film?",
    note: "Open your script in the teleprompter and read along as you record your video.",
    body: "Your saved inspiration can become something your audience hears from you.",
    button: "Open ChillScript"
  },
  marketing_winback_3: {
    subject: "Ask Chillo what to make from your notes",
    preheader: "Find a topic in your saved notes and work it into a draft with Chillo.",
    eyebrow: "Meet Chillo",
    heading: "What could you make",
    headingAccent: "from your notes?",
    intro: "Chillo is your AI assistant in ChillScript. Ask it to find ideas in your saved notes or connect things you've written about.",
    noteLabel: "Try asking Chillo",
    note: "Find an idea in my notes that I could turn into a short video.",
    body: "Found a topic you like? Ask Chillo to draft a script, then keep chatting to refine it.",
    button: "Open ChillScript"
  }
};

function escapeHTML(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

export function renderMarketingWinbackEmail(input: MarketingTemplateInput): RenderedEmail {
  const copy = COPY[input.kind];
  const callToActionURL = escapeHTML(input.callToActionURL);
  const unsubscribeURL = escapeHTML(input.unsubscribeURL);
  const postalAddress = escapeHTML(input.postalAddress);
  const text = [
    `${copy.heading} ${copy.headingAccent}`,
    "",
    copy.intro,
    "",
    `${copy.noteLabel}: ${copy.note}`,
    "",
    copy.body,
    "",
    `${copy.button}: ${input.callToActionURL}`,
    "",
    "Keep creating,",
    "The ChillScript Team",
    "",
    "You received this because you agreed to receive ChillScript product and marketing emails.",
    input.postalAddress,
    `Manage email choices: ${input.unsubscribeURL}`
  ].join("\n");

  return {
    subject: copy.subject,
    text,
    html: `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="color-scheme" content="light">
  <meta name="supported-color-schemes" content="light">
  <title>${escapeHTML(copy.subject)}</title>
  <style>
    @media only screen and (max-width:620px) {
      .email-shell { padding:0 20px 32px !important; }
      .email-heading { font-size:38px !important; line-height:42px !important; letter-spacing:-1.5px !important; }
      .email-button { display:block !important; text-align:center !important; }
    }
  </style>
</head>
<body style="margin:0;background:#FAF8F3;color:#17181B;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif;-webkit-font-smoothing:antialiased">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent">${escapeHTML(copy.preheader)}</div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="width:100%;background:#FAF8F3">
    <tr><td class="email-shell" align="center" style="padding:0 24px 48px">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="width:100%;max-width:600px">
        <tr><td style="height:6px;background:#2F86FF;font-size:0;line-height:0">&nbsp;</td></tr>
        <tr><td style="padding:42px 0 0">
          <table role="presentation" cellpadding="0" cellspacing="0"><tr>
            <td style="padding-right:12px;vertical-align:middle"><img src="https://www.chillnoteai.com/assets/chillscript-logo.png" width="42" height="42" alt="" style="display:block;width:42px;height:42px;border:0;border-radius:10px"></td>
            <td style="vertical-align:middle;color:#17181B;font-size:22px;font-weight:800;letter-spacing:-0.8px;white-space:nowrap">Chill<span style="color:#2F86FF">Script</span></td>
          </tr></table>
        </td></tr>
        <tr><td style="padding:58px 0 0">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
            <tr><td style="color:#6B6D73;font-size:11px;line-height:15px;font-weight:800;letter-spacing:1.8px;text-transform:uppercase">${escapeHTML(copy.eyebrow)}</td></tr>
            <tr><td style="padding-top:16px"><h1 class="email-heading" style="margin:0;color:#17181B;font-size:48px;line-height:51px;letter-spacing:-2.4px;font-weight:830">${escapeHTML(copy.heading)}<br><span style="color:#176BCB">${escapeHTML(copy.headingAccent)}</span></h1></td></tr>
            <tr><td style="padding-top:22px;color:#55575E;font-size:17px;line-height:27px">${escapeHTML(copy.intro)}</td></tr>
            <tr><td style="padding-top:34px">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="width:100%;background:#FFFDF8;border-top:3px solid #176BCB;border-bottom:1px solid #DED8CD;box-shadow:0 10px 24px rgba(45,40,32,0.07)">
                <tr><td style="padding:24px 28px 27px">
                  <div style="color:#176BCB;font-family:Georgia,'Times New Roman',serif;font-size:18px;line-height:24px;font-style:italic;font-weight:700">${escapeHTML(copy.noteLabel)}</div>
                  <div style="padding-top:9px;color:#272930;font-family:Georgia,'Times New Roman',serif;font-size:20px;line-height:30px;font-style:italic">${escapeHTML(copy.note)}</div>
                </td></tr>
              </table>
            </td></tr>
            <tr><td style="padding-top:20px;color:#3F4148;font-size:15px;line-height:24px">${escapeHTML(copy.body)}</td></tr>
            <tr><td style="padding-top:34px">
              <table role="presentation" cellpadding="0" cellspacing="0"><tr>
                <td bgcolor="#176BCB" style="border-radius:8px"><a class="email-button" href="${callToActionURL}" style="display:inline-block;padding:16px 24px;color:#FFFFFF;text-decoration:none;font-size:15px;line-height:20px;font-weight:800">${escapeHTML(copy.button)}&nbsp;&nbsp;&rarr;</a></td>
              </tr></table>
            </td></tr>
            <tr><td style="padding-top:38px;color:#42444A;font-family:Georgia,'Times New Roman',serif;font-size:15px;line-height:23px">Keep creating,<br><em>The ChillScript Team</em></td></tr>
            <tr><td style="padding-top:40px">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="width:100%;border-top:1px solid #D8D2C8">
                <tr><td style="padding-top:20px;color:#74757B;font-size:11px;line-height:18px">You received this because you agreed to receive ChillScript product and marketing emails.</td></tr>
                <tr><td style="padding-top:8px;color:#74757B;font-size:11px;line-height:18px">${postalAddress}</td></tr>
                <tr><td style="padding-top:8px;color:#74757B;font-size:11px;line-height:18px"><a href="${unsubscribeURL}" style="color:#5E6066;text-decoration:underline">Manage email choices</a> or unsubscribe from marketing emails.</td></tr>
                <tr><td style="padding-top:8px;color:#74757B;font-size:11px;line-height:18px">Questions? Reply to this email or contact <a href="mailto:support@chillnoteai.com" style="color:#176BCB;text-decoration:underline">support@chillnoteai.com</a>.</td></tr>
              </table>
            </td></tr>
          </table>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`
  };
}
