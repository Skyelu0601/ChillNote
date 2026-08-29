import "dotenv/config";

import { readFile } from "node:fs/promises";
import { createPrivateKey, sign } from "node:crypto";
import { PrismaClient } from "@prisma/client";

const APP_BUNDLE_ID = "com.sponteoai.chillnote";
const APPLE_KEY_ID = "TF4BTQB85R";
const APPLE_ISSUER_ID = "457129c5-26ac-400b-b9bc-dca88b17bd5d";
const REVENUECAT_RECEIPTS_URL = "https://api.revenuecat.com/v1/receipts";
const REVENUECAT_SUBSCRIBERS_URL = "https://api.revenuecat.com/v1/subscribers";
const ALLOWED_PRODUCT_IDS = new Set([
  "com.chillnote.pro.monthly",
  "com.chillnote.pro.yearly"
]);

type AppleEnvironment = "production" | "sandbox";

type AppleTransaction = {
  transactionId?: string;
  originalTransactionId?: string;
  bundleId?: string;
  productId?: string;
  purchaseDate?: number;
  environment?: string;
};

type SignedTransaction = {
  signedTransaction: string;
  payload: AppleTransaction;
};

type HistoryResult = {
  environment: AppleEnvironment;
  transactions: SignedTransaction[];
};

type MigrationSummary = {
  databaseMappings: number;
  appleCustomersFound: number;
  productionCustomers: number;
  sandboxCustomers: number;
  missingFromApple: number;
  invalidTransactions: number;
  signedTransactions: number;
  uniqueTransactions: number;
  importedTransactions: number;
  failedImports: number;
  verifiedCustomers: number;
  failedCustomerVerifications: number;
  productCounts: Record<string, number>;
  oldestPurchaseAt: string | null;
  latestPurchaseAt: string | null;
};

const prisma = new PrismaClient();

function encodeBase64URL(value: string | Buffer): string {
  return Buffer.from(value).toString("base64url");
}

function createAppleJWT(privateKeyPEM: string): string {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "ES256", kid: APPLE_KEY_ID, typ: "JWT" };
  const payload = {
    iss: APPLE_ISSUER_ID,
    iat: now,
    exp: now + 10 * 60,
    aud: "appstoreconnect-v1",
    bid: APP_BUNDLE_ID
  };
  const signingInput = `${encodeBase64URL(JSON.stringify(header))}.${encodeBase64URL(JSON.stringify(payload))}`;
  const signature = sign("sha256", Buffer.from(signingInput), {
    key: createPrivateKey(privateKeyPEM),
    dsaEncoding: "ieee-p1363"
  });
  return `${signingInput}.${signature.toString("base64url")}`;
}

function decodeJWSPayload(signedTransaction: string): AppleTransaction | null {
  const parts = signedTransaction.split(".");
  if (parts.length !== 3) return null;
  try {
    return JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8")) as AppleTransaction;
  } catch {
    return null;
  }
}

async function wait(milliseconds: number): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function fetchWithRetry(url: string, init: RequestInit, attempts = 5): Promise<Response> {
  let lastResponse: Response | null = null;
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    const response = await fetch(url, init);
    lastResponse = response;
    if (response.status !== 429 && response.status < 500) return response;
    const retryAfterSeconds = Number(response.headers.get("retry-after") ?? 0);
    const delay = retryAfterSeconds > 0
      ? retryAfterSeconds * 1_000
      : Math.min(500 * 2 ** attempt, 8_000);
    await wait(delay);
  }
  if (!lastResponse) throw new Error("Request failed before receiving a response");
  return lastResponse;
}

function appleHistoryBaseURL(environment: AppleEnvironment): string {
  return environment === "production"
    ? "https://api.storekit.apple.com"
    : "https://api.storekit-sandbox.apple.com";
}

async function fetchHistoryFromEnvironment(
  originalTransactionId: string,
  environment: AppleEnvironment,
  privateKeyPEM: string
): Promise<HistoryResult | null> {
  const transactions: SignedTransaction[] = [];
  let revision: string | null = null;

  do {
    const url = new URL(
      `/inApps/v2/history/${encodeURIComponent(originalTransactionId)}`,
      appleHistoryBaseURL(environment)
    );
    url.searchParams.set("sort", "ASCENDING");
    if (revision) url.searchParams.set("revision", revision);

    const response = await fetchWithRetry(url.toString(), {
      headers: { Authorization: `Bearer ${createAppleJWT(privateKeyPEM)}` }
    });
    if (response.status === 404) return null;
    if (!response.ok) {
      throw new Error(`Apple ${environment} history request failed with HTTP ${response.status}`);
    }

    const body = await response.json() as {
      signedTransactions?: string[];
      revision?: string;
      hasMore?: boolean;
    };
    for (const signedTransaction of body.signedTransactions ?? []) {
      const payload = decodeJWSPayload(signedTransaction);
      if (payload) transactions.push({ signedTransaction, payload });
    }
    revision = body.hasMore ? body.revision ?? null : null;
    if (body.hasMore && !revision) {
      throw new Error(`Apple ${environment} history response is missing its revision token`);
    }
  } while (revision);

  return { environment, transactions };
}

async function fetchAppleHistory(
  originalTransactionId: string,
  privateKeyPEM: string
): Promise<HistoryResult | null> {
  const production = await fetchHistoryFromEnvironment(
    originalTransactionId,
    "production",
    privateKeyPEM
  );
  if (production) return production;
  return fetchHistoryFromEnvironment(originalTransactionId, "sandbox", privateKeyPEM);
}

async function readRequiredFile(environmentName: string): Promise<string> {
  const path = process.env[environmentName];
  if (!path) throw new Error(`${environmentName} must point to a readable file`);
  return (await readFile(path, "utf8")).trim();
}

async function postTransactionToRevenueCat(
  appUserId: string,
  signedTransaction: string,
  apiKey: string
): Promise<boolean> {
  const response = await fetchWithRetry(REVENUECAT_RECEIPTS_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      "X-Platform": "ios"
    },
    body: JSON.stringify({ app_user_id: appUserId, fetch_token: signedTransaction })
  });
  return response.ok;
}

async function verifyRevenueCatCustomer(appUserId: string, apiKey: string): Promise<boolean> {
  const response = await fetchWithRetry(
    `${REVENUECAT_SUBSCRIBERS_URL}/${encodeURIComponent(appUserId)}`,
    {
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "X-Platform": "ios"
      }
    }
  );
  if (!response.ok) return false;
  const body = await response.json() as {
    subscriber?: { subscriptions?: Record<string, unknown> };
  };
  const subscriptions = body.subscriber?.subscriptions ?? {};
  return Object.keys(subscriptions).some((productId) => ALLOWED_PRODUCT_IDS.has(productId));
}

function parseLimit(): number | null {
  const argument = process.argv.find((value) => value.startsWith("--limit="));
  if (!argument) return null;
  const limit = Number(argument.slice("--limit=".length));
  if (!Number.isInteger(limit) || limit <= 0) {
    throw new Error("--limit must be a positive integer");
  }
  return limit;
}

function updatePurchaseDateRange(summary: MigrationSummary, purchaseDate?: number): void {
  if (!purchaseDate || !Number.isFinite(purchaseDate)) return;
  const value = new Date(purchaseDate).toISOString();
  if (!summary.oldestPurchaseAt || value < summary.oldestPurchaseAt) summary.oldestPurchaseAt = value;
  if (!summary.latestPurchaseAt || value > summary.latestPurchaseAt) summary.latestPurchaseAt = value;
}

async function main(): Promise<void> {
  const commit = process.argv.includes("--commit");
  const limit = parseLimit();
  const privateKeyPEM = await readRequiredFile("APPLE_IAP_KEY_PATH");
  const revenueCatAPIKey = commit
    ? await readRequiredFile("REVENUECAT_PUBLIC_API_KEY_FILE")
    : null;

  const allMappings = await prisma.user.findMany({
    where: { originalTransactionId: { not: null } },
    select: { id: true, originalTransactionId: true },
    orderBy: { createdAt: "asc" }
  });
  const mappings = limit ? allMappings.slice(0, limit) : allMappings;
  const summary: MigrationSummary = {
    databaseMappings: mappings.length,
    appleCustomersFound: 0,
    productionCustomers: 0,
    sandboxCustomers: 0,
    missingFromApple: 0,
    invalidTransactions: 0,
    signedTransactions: 0,
    uniqueTransactions: 0,
    importedTransactions: 0,
    failedImports: 0,
    verifiedCustomers: 0,
    failedCustomerVerifications: 0,
    productCounts: {},
    oldestPurchaseAt: null,
    latestPurchaseAt: null
  };

  for (const mapping of mappings) {
    const originalTransactionId = mapping.originalTransactionId;
    if (!originalTransactionId) continue;
    const history = await fetchAppleHistory(originalTransactionId, privateKeyPEM);
    if (!history) {
      summary.missingFromApple += 1;
      continue;
    }

    summary.appleCustomersFound += 1;
    if (history.environment === "production") summary.productionCustomers += 1;
    else summary.sandboxCustomers += 1;
    summary.signedTransactions += history.transactions.length;

    const uniqueTransactions = new Map<string, SignedTransaction>();
    for (const transaction of history.transactions) {
      const { payload } = transaction;
      if (
        !payload.transactionId ||
        payload.bundleId !== APP_BUNDLE_ID ||
        !payload.productId ||
        !ALLOWED_PRODUCT_IDS.has(payload.productId)
      ) {
        summary.invalidTransactions += 1;
        continue;
      }
      uniqueTransactions.set(payload.transactionId, transaction);
      summary.productCounts[payload.productId] = (summary.productCounts[payload.productId] ?? 0) + 1;
      updatePurchaseDateRange(summary, payload.purchaseDate);
    }
    summary.uniqueTransactions += uniqueTransactions.size;

    if (!commit || !revenueCatAPIKey) continue;
    for (const transaction of uniqueTransactions.values()) {
      const imported = await postTransactionToRevenueCat(
        mapping.id,
        transaction.signedTransaction,
        revenueCatAPIKey
      );
      if (imported) summary.importedTransactions += 1;
      else summary.failedImports += 1;
      await wait(150);
    }

    const verified = await verifyRevenueCatCustomer(mapping.id, revenueCatAPIKey);
    if (verified) summary.verifiedCustomers += 1;
    else summary.failedCustomerVerifications += 1;
  }

  console.log(JSON.stringify({ mode: commit ? "commit" : "dry-run", summary }, null, 2));
  if (summary.missingFromApple > 0 || summary.invalidTransactions > 0) process.exitCode = 2;
  if (commit && (summary.failedImports > 0 || summary.failedCustomerVerifications > 0)) {
    process.exitCode = 1;
  }
}

main()
  .catch((error) => {
    console.error(error instanceof Error ? error.message : "Unknown migration error");
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
