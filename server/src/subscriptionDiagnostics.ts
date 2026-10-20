import { createHash } from "node:crypto";

/** Carry provider status without copying response bodies, credentials or customer IDs. */
export class RevenueCatLookupError extends Error {
  constructor(readonly reason: "not_configured" | "http", readonly upstreamStatus?: number) {
    super(reason === "http" ? `RevenueCat customer lookup failed with HTTP ${upstreamStatus}`
      : "REVENUECAT_API_KEY is not configured");
    this.name = "RevenueCatLookupError";
  }
}

export function subscriptionAccountRef(userId: string): string {
  return createHash("sha256").update(userId).digest("hex").slice(0, 16);
}

/** Only allow known diagnostic values; never log raw messages, stacks or error objects. */
export function subscriptionErrorDetails(error: unknown): {
  category: string; code?: string; upstreamStatus?: number;
} {
  if (error instanceof RevenueCatLookupError) {
    return { category: `revenuecat_${error.reason}`, upstreamStatus: error.upstreamStatus };
  }
  if (typeof error !== "object" || error === null) return { category: "unknown" };
  const value = error as { name?: unknown; message?: unknown; code?: unknown; cause?: unknown };
  // The installed Auth SDK can throw this fixed message before returning claims.
  if (value.code === "ERR_JWT_EXPIRED" || value.message === "JWT has expired") {
    return { category: "token_expired" };
  }
  if (value.name === "AbortError" || value.name === "TimeoutError") return { category: "timeout" };
  if (typeof value.code === "string" && /^P\d{4}$/.test(value.code)) {
    return { category: "database", code: value.code };
  }
  const networkCodes = new Set(["ETIMEDOUT", "ECONNRESET", "ECONNREFUSED", "ENOTFOUND", "EAI_AGAIN"]);
  for (const candidate of [value, value.cause]) {
    if (typeof candidate !== "object" || candidate === null) continue;
    const code = (candidate as { code?: unknown }).code;
    if (typeof code === "string" && networkCodes.has(code)) return { category: "network", code };
  }
  if (value.name === "SyntaxError") return { category: "invalid_provider_response" };
  return { category: "unknown" };
}
