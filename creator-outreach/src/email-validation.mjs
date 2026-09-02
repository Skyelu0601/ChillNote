import dns from "node:dns/promises";

const simpleEmailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function isValidEmailSyntax(email) {
  const value = email?.trim() || "";
  if (!simpleEmailPattern.test(value) || value.length > 254) return false;
  const [local, domain] = value.split("@");
  if (!local || local.length > 64 || local.startsWith(".") || local.endsWith(".")) {
    return false;
  }
  if (local.includes("..")) return false;
  const labels = domain.split(".");
  return labels.every(
    (label) =>
      label &&
      label.length <= 63 &&
      !label.startsWith("-") &&
      !label.endsWith("-") &&
      /^[a-z0-9-]+$/i.test(label),
  );
}

export function emailDomain(email) {
  return email.trim().toLowerCase().split("@").at(-1);
}

export async function checkMx(email) {
  if (!isValidEmailSyntax(email)) {
    return { status: "invalid", reason: "invalid email syntax", mx: [] };
  }

  const domain = emailDomain(email);
  try {
    const mx = await dns.resolveMx(domain);
    if (!mx.length) return { status: "invalid", reason: "domain has no MX record", mx: [] };
    return {
      status: "mx_only",
      reason: "syntax and MX passed; mailbox deliverability is not verified",
      mx: mx.sort((a, b) => a.priority - b.priority),
    };
  } catch (error) {
    const noMxCodes = new Set(["ENODATA", "ENOTFOUND"]);
    if (noMxCodes.has(error.code)) {
      return { status: "invalid", reason: `MX lookup failed: ${error.code}`, mx: [] };
    }
    return { status: "unknown", reason: `MX lookup error: ${error.code || error.message}`, mx: [] };
  }
}

export async function checkZeroBounce(email, apiKey) {
  const url = new URL("https://api.zerobounce.net/v2/validate");
  url.searchParams.set("api_key", apiKey);
  url.searchParams.set("email", email);
  url.searchParams.set("timeout", "20");

  const response = await fetch(url, {
    headers: { accept: "application/json" },
    signal: AbortSignal.timeout(25_000),
  });
  if (!response.ok) throw new Error(`ZeroBounce returned HTTP ${response.status}`);
  const result = await response.json();
  const rawStatus = String(result.status || "unknown").toLowerCase();

  const statusMap = {
    valid: "valid",
    invalid: "invalid",
    "catch-all": "catch_all",
    spamtrap: "risky",
    abuse: "risky",
    do_not_mail: "risky",
    unknown: "unknown",
  };

  return {
    status: statusMap[rawStatus] || "unknown",
    reason: [result.status, result.sub_status].filter(Boolean).join(": "),
    provider: "zerobounce",
  };
}

export async function validateEmail(email, apiKey = "") {
  const mxResult = await checkMx(email);
  if (mxResult.status !== "mx_only" || !apiKey) return mxResult;
  return checkZeroBounce(email, apiKey);
}
