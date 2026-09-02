import path from "node:path";
import { fileURLToPath } from "node:url";
import dotenv from "dotenv";

const sourceDir = path.dirname(fileURLToPath(import.meta.url));
export const toolRoot = path.resolve(sourceDir, "..");
export const workspaceRoot = path.resolve(toolRoot, "..");
export const leadsPath = path.join(toolRoot, "data", "leads.csv");
export const templatePath = path.join(toolRoot, "templates", "creator-partner.txt");
export const htmlTemplatePath = path.join(toolRoot, "templates", "creator-partner.html");
export const partnerCodeTemplatePath = path.join(toolRoot, "templates", "creator-partner-code.txt");
export const previewDir = path.join(toolRoot, "previews");
export const syncStatePath = path.join(toolRoot, "data", "sync-state.json");
export const sendingPausePath = path.join(toolRoot, "data", "SENDING_PAUSED");
export const offerCodeAssignmentsPath = path.join(toolRoot, "data", "offer-code-assignments.json");
export const offerCodesDir = path.join(toolRoot, "data", "offer-codes");
export const partnerOfferProductId = "com.chillnote.pro.yearly";

dotenv.config({
  path: path.join(workspaceRoot, ".env.local"),
  quiet: true,
});

export const affiliateSignupLink =
  process.env.GOMARKETME_AFFILIATE_LINK?.trim() ||
  "https://gomarketme.net/m/chillscript/c/bb07f6e3-2194-4d8b-89ba-e816fa99e22e/signup";
if (new URL(affiliateSignupLink).protocol !== "https:") {
  throw new Error("GOMARKETME_AFFILIATE_LINK must be an HTTPS URL.");
}

function required(name) {
  const value = process.env[name]?.trim();
  if (!value || value.includes("PASTE_NEW_")) {
    throw new Error(`${name} is missing from ${path.join(workspaceRoot, ".env.local")}`);
  }
  return value;
}

export function mailConfig() {
  return {
    user: required("ALI_MAIL_USER"),
    password: required("ALI_MAIL_APP_PASSWORD"),
    smtp: {
      host: process.env.ALI_SMTP_HOST?.trim() || "smtp.qiye.aliyun.com",
      port: Number(process.env.ALI_SMTP_PORT || 465),
      secure: true,
    },
    imap: {
      host: process.env.ALI_IMAP_HOST?.trim() || "imap.qiye.aliyun.com",
      port: Number(process.env.ALI_IMAP_PORT || 993),
      secure: true,
    },
  };
}

export function apifyConfig() {
  return {
    token: required("APIFY_TOKEN"),
  };
}

export const outreachSubject = "A creator tool you might like";
