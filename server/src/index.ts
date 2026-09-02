// Polyfill for Node.js 16 - provides minimal Headers API for jose library
if (typeof globalThis.Headers === 'undefined') {
  // @ts-ignore
  globalThis.Headers = class Headers {
    private headers: Record<string, string> = {};
    constructor(init?: Record<string, string>) {
      if (init) {
        Object.entries(init).forEach(([key, value]) => {
          this.headers[key.toLowerCase()] = value;
        });
      }
    }
    get(name: string): string | null {
      return this.headers[name.toLowerCase()] || null;
    }
    set(name: string, value: string): void {
      this.headers[name.toLowerCase()] = value;
    }
    has(name: string): boolean {
      return name.toLowerCase() in this.headers;
    }
    delete(name: string): void {
      delete this.headers[name.toLowerCase()];
    }
    *entries(): IterableIterator<[string, string]> {
      for (const [key, value] of Object.entries(this.headers)) {
        yield [key, value];
      }
    }
    *keys(): IterableIterator<string> {
      for (const key of Object.keys(this.headers)) {
        yield key;
      }
    }
    *values(): IterableIterator<string> {
      for (const value of Object.values(this.headers)) {
        yield value;
      }
    }
    forEach(callback: (value: string, key: string, parent: any) => void): void {
      for (const [key, value] of Object.entries(this.headers)) {
        callback(value, key, this);
      }
    }
  };
}

import "dotenv/config";
import express from "express";
import compression from "compression";
import cors from "cors";
import { z } from "zod";
import { createHash, createHmac, randomUUID, timingSafeEqual } from "crypto";
import { importPKCS8, SignJWT } from "jose";
import { applySync } from "./sync.js";
import {
  acquireUserSyncTransactionLock,
  getChangesSinceCursor,
  getLatestSyncLogId,
  hasActiveProSubscription,
  getEffectiveSubscription,
  upsertUser,
  deleteUser,
  updateCreemSubscriptionStatus,
  updateSubscriptionStatus
} from "./store.js";
import {
  revenueCatEntitlementSnapshot,
  revenueCatWebhookUserIds,
  verifyRevenueCatWebhookSignature,
  type RevenueCatCustomerResponse,
  type RevenueCatWebhook
} from "./revenueCat.js";
import {
  DURABLE_MUTATION_PROTOCOL_VERSION,
  AccountDeletedError,
  isAccountDeletedDatabaseError,
  isPrismaUniqueConstraintError,
  SyncOwnershipError,
  SyncReferenceError
} from "./syncPolicy.js";
import { prisma } from "./db.js"; // Import prisma for direct queries in index.ts if needed, though best to abstract
import type { SyncPayload } from "./types.js";
import { supabaseAdmin } from "./supabase.js";
import { InviteError, bindInviteCode, getInviteConfig, getInviteMonthlyRewardCount, getOrCreateInviteCode } from "./invite.js";
import {
  isSupportedMediaLinkURL,
  isHandledTikTokTranscriptError,
  isTikTokURL,
  transcribeMediaLinkURL,
  transcribeTikTokURL
} from "./tiktokTranscript.js";
import {
  enqueueLinkImportJob,
  LinkImportInsufficientCreditsError,
  makeInitialLinkSource,
  scheduleLinkImportWorker
} from "./linkImportJobs.js";
import { preferredLanguageFromHeader } from "./linkImportLocalization.js";
import {
  deactivatePushDevice,
  registerPushDevice,
  scheduleNotificationWorker
} from "./pushNotifications.js";
import { pushDeviceDeleteSchema, pushDeviceSchema } from "./pushDeviceSchemas.js";
import { handleAccountDeletion } from "./accountDeletion.js";
import {
  GooglePlayPublisherError,
  verifyGooglePlayPurchase
} from "./googlePlayBilling.js";
import {
  createGooglePlayPublisher,
  createPrismaGooglePlayBillingStore,
  scheduleGooglePlayBillingWorker
} from "./googlePlayBillingRuntime.js";
import {
  getWeeklyTopicDashboard,
  getWeeklyTopicReport,
  listWeeklyTopicReports,
  markWeeklyTopicReportRead,
  regenerateWeeklyTopicReport,
  scheduleWeeklyTopicWorker,
  updateWeeklyTopicSettings,
  weeklyTopicSettingsInputSchema
} from "./weeklyTopics.js";
import fetch from "node-fetch";

const app = express();
app.use(compression());
app.use(cors());

const defaultJsonParser = express.json({ limit: process.env.DEFAULT_JSON_LIMIT ?? "1mb" });
const syncJsonParser = express.json({ limit: process.env.SYNC_JSON_LIMIT ?? "10mb" });
const defaultFormParser = express.urlencoded({
  limit: process.env.DEFAULT_FORM_LIMIT ?? "1mb",
  extended: true
});
const aiJsonParser = express.json({ limit: process.env.AI_JSON_LIMIT ?? "150mb" });

app.use((req, res, next) => {
  if (req.path === "/sync") {
    syncJsonParser(req, res, next);
    return;
  }
  if (req.path.startsWith("/ai/") || req.path === "/webhooks/creem" || req.path === "/webhooks/revenuecat") {
    next();
    return;
  }
  defaultJsonParser(req, res, next);
});

app.use((req, res, next) => {
  if (req.path.startsWith("/ai/") || req.path === "/webhooks/creem" || req.path === "/webhooks/revenuecat") {
    next();
    return;
  }
  defaultFormParser(req, res, next);
});

const PORT = Number(process.env.PORT ?? 4000);
const GEMINI_MODEL = process.env.GEMINI_MODEL?.trim() || "gemini-3.1-flash-lite";
const GEMINI_API_KEY = process.env.GEMINI_API_KEY?.trim() || "";
const CREEM_API_KEY = process.env.CREEM_API_KEY?.trim() || "";
const CREEM_WEBHOOK_SECRET = process.env.CREEM_WEBHOOK_SECRET?.trim() || "";
const CREEM_API_BASE_URL = process.env.CREEM_API_BASE_URL?.trim()
  || (process.env.CREEM_TEST_MODE === "true" ? "https://test-api.creem.io" : "https://api.creem.io");
const CREEM_MONTHLY_PRODUCT_ID = process.env.CREEM_MONTHLY_PRODUCT_ID?.trim() || "";
const CREEM_YEARLY_PRODUCT_ID = process.env.CREEM_YEARLY_PRODUCT_ID?.trim() || "";
const REVENUECAT_API_KEY = process.env.REVENUECAT_API_KEY?.trim() || "";
const REVENUECAT_ENTITLEMENT_ID = process.env.REVENUECAT_ENTITLEMENT_ID?.trim() || "pro";
const REVENUECAT_WEBHOOK_AUTHORIZATION = process.env.REVENUECAT_WEBHOOK_AUTHORIZATION?.trim() || "";
const REVENUECAT_WEBHOOK_HMAC_SECRET = process.env.REVENUECAT_WEBHOOK_HMAC_SECRET?.trim() || "";
const REVENUECAT_ALLOWED_APP_IDS = new Set(
  (process.env.REVENUECAT_ALLOWED_APP_IDS ?? "")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean)
);
const WEB_APP_BASE_URL = process.env.WEB_APP_BASE_URL?.trim() || "https://www.chillnoteai.com";
const GOOGLE_PLAY_PACKAGE_NAME = process.env.GOOGLE_PLAY_PACKAGE_NAME?.trim() || "com.sponteoai.chillscript";
const GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL?.trim() || "";
const GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY = (process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY ?? "").replace(/\\n/g, "\n");
const GOOGLE_PLAY_PRODUCT_IDS = new Set([
  "com.chillnote.pro.weekly",
  "com.chillnote.pro.yearly",
  // Keep verifying renewals/restores for customers on the retired monthly plan.
  "com.chillnote.pro.monthly"
]);

let googlePlayAccessTokenCache: { token: string; expiresAt: number } | null = null;

async function googlePlayAccessToken(forceRefresh = false): Promise<string> {
  if (forceRefresh) googlePlayAccessTokenCache = null;
  const now = Date.now();
  if (googlePlayAccessTokenCache && googlePlayAccessTokenCache.expiresAt > now + 60_000) {
    return googlePlayAccessTokenCache.token;
  }
  if (!GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL || !GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY) {
    throw new GooglePlayPublisherError("PUBLISHER_AUTH", false);
  }
  let privateKey;
  try {
    privateKey = await importPKCS8(GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY, "RS256");
  } catch {
    throw new GooglePlayPublisherError("PUBLISHER_AUTH", false);
  }
  const issuedAt = Math.floor(now / 1000);
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/androidpublisher"
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(issuedAt)
    .setExpirationTime(issuedAt + 3600)
    .sign(privateKey);
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15_000);
  let response;
  try {
    response = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion
      }).toString(),
      signal: controller.signal
    });
  } catch (error) {
    throw new GooglePlayPublisherError(
      error instanceof Error && error.name === "AbortError" ? "TIMEOUT" : "NETWORK",
      true
    );
  } finally {
    clearTimeout(timeout);
  }
  const body = await response.json() as { access_token?: string; expires_in?: number; error?: string };
  if (!response.ok || !body.access_token) {
    if (response.status === 429 || response.status >= 500) {
      throw new GooglePlayPublisherError(
        response.status === 429 ? "RATE_LIMITED" : "PUBLISHER_UNAVAILABLE",
        true,
        response.status
      );
    }
    throw new GooglePlayPublisherError("PUBLISHER_AUTH", false, response.status);
  }
  googlePlayAccessTokenCache = {
    token: body.access_token,
    expiresAt: now + (body.expires_in ?? 3600) * 1000
  };
  return body.access_token;
}

function googlePlayAccountId(userId: string): string {
  return createHash("sha256").update(userId).digest("hex");
}

const googlePlayBillingDependencies = {
  publisher: createGooglePlayPublisher({
    packageName: GOOGLE_PLAY_PACKAGE_NAME,
    getAccessToken: googlePlayAccessToken,
    fetchImpl: fetch as unknown as typeof globalThis.fetch
  }),
  store: createPrismaGooglePlayBillingStore(),
  packageName: GOOGLE_PLAY_PACKAGE_NAME,
  accountIdForUser: googlePlayAccountId,
  onEntitlementChanged: invalidateUserTierCache
};

function buildGeminiGenerateContentURL(model: string): string {
  const encodedModel = encodeURIComponent(model);
  const encodedApiKey = encodeURIComponent(GEMINI_API_KEY);
  return `https://generativelanguage.googleapis.com/v1beta/models/${encodedModel}:generateContent?key=${encodedApiKey}`;
}

const isoDateString = z
  .string()
  .min(1)
  .refine((value) => !Number.isNaN(Date.parse(value)), { message: "Invalid date" });

const noteSchema = z.object({
  id: z.string().min(1),
  content: z.string(),
  createdAt: isoDateString,
  updatedAt: isoDateString.optional(),
  deletedAt: isoDateString.nullish(),
  pinnedAt: isoDateString.nullish(),
  tagIds: z.array(z.string().min(1)).nullish(),
  version: z.number().int().optional(),
  baseVersion: z.number().int().optional(),
  clientUpdatedAt: isoDateString.nullish(),
  lastModifiedByDeviceId: z.string().nullish(),
  mutationId: z.string().min(1).max(128).nullish(),
  previousMutationId: z.string().min(1).max(128).nullish(),
  sourceURL: z.string().nullish(),
  sourceTitle: z.string().nullish(),
  sourcePlatformID: z.string().nullish(),
  sourcePlatformName: z.string().nullish(),
  sourceHost: z.string().nullish(),
  sourceAuthorName: z.string().nullish(),
  sourceAuthorHandle: z.string().nullish(),
  sourceCapturedAt: isoDateString.nullish(),
  section: z.enum(["inbox", "drafts", "published"]).nullish(),
  importStatus: z.enum(["queued", "processing", "completed", "failed"]).nullish(),
  importJobId: z.string().nullish(),
  importErrorCode: z.string().nullish(),
  importStartedAt: isoDateString.nullish(),
  importCompletedAt: isoDateString.nullish()
});

const syncSchema = z.object({
  protocolVersion: z.number().int().nonnegative().optional(),
  cursor: z.string().nullish(),
  deviceId: z.string().nullish(),
  notes: z.array(noteSchema),
  tags: z.array(
    z.object({
      id: z.string().min(1),
      name: z.string().min(1),
      colorHex: z.string().min(1),
      createdAt: isoDateString,
      updatedAt: isoDateString.optional(),
      lastUsedAt: isoDateString.nullish(),
      sortOrder: z.number(),
      parentId: z.string().nullish(),
      deletedAt: isoDateString.nullish(),
      version: z.number().int().optional(),
      baseVersion: z.number().int().optional(),
      clientUpdatedAt: isoDateString.nullish(),
      lastModifiedByDeviceId: z.string().nullish(),
      mutationId: z.string().min(1).max(128).nullish(),
      previousMutationId: z.string().min(1).max(128).nullish()
    })
  ).optional(),
  hardDeletedNoteIds: z.array(z.string().min(1)).nullish(),
  hardDeletedTagIds: z.array(z.string().min(1)).nullish(),
  preferences: z.record(z.string(), z.string()).optional()
}).superRefine((payload, context) => {
  if ((payload.protocolVersion ?? 0) < DURABLE_MUTATION_PROTOCOL_VERSION) return;
  payload.notes.forEach((note, index) => {
    if (!note.mutationId) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["notes", index, "mutationId"],
        message: "protocol v4 requires mutationId"
      });
    }
  });
  (payload.tags ?? []).forEach((tag, index) => {
    if (!tag.mutationId) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        path: ["tags", index, "mutationId"],
        message: "protocol v4 requires mutationId"
      });
    }
  });
});

const linkImportJobSchema = z.object({
  noteId: z.string().min(1),
  url: z.string().url(),
  placeholderContent: z.string().min(1).max(10_000),
  source: z.object({
    url: z.string().url(),
    title: z.string().min(1),
    platformID: z.string().min(1),
    platformName: z.string().min(1),
    host: z.string(),
    authorName: z.string().nullish(),
    authorHandle: z.string().nullish()
  }).optional(),
  section: z.enum(["inbox", "drafts", "published"]).nullish(),
  contentLocale: z.string().trim().min(1).max(64).optional(),
  mediaLinkSections: z.object({
    showDescription: z.boolean(),
    showAuthor: z.boolean(),
    showHook: z.boolean(),
    showTranscript: z.boolean()
  }).optional()
});

// Middleware to validate Supabase Auth Header
async function requireAuth(req: express.Request, res: express.Response, next: express.NextFunction) {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    res.status(401).json({ error: "Missing token" });
    return;
  }
  const token = header.replace("Bearer ", "");

  try {
    const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);

    if (error || !user) {
      console.error("Auth check failed:", error);
      res.status(401).json({ error: "Invalid token" });
      return;
    }

    req.userId = user.id;
    req.userEmail = user.email ?? undefined;
    req.userCreatedAt = user.created_at;
    next();
  } catch (err) {
    console.error("Auth Exception:", err);
    res.status(401).json({ error: "Invalid token" });
  }
}

type UserTier = "free" | "pro";

const userTierCache = new Map<string, { tier: UserTier; expiresAt: number }>();
const USER_TIER_CACHE_TTL_MS = Number(process.env.AI_TIER_CACHE_TTL_MS ?? 60 * 1000);

async function resolveUserTier(userId?: string): Promise<UserTier> {
  if (!userId) return "free";

  const now = Date.now();
  const cached = userTierCache.get(userId);
  if (cached && cached.expiresAt > now) {
    return cached.tier;
  }

  const tier = (await getEffectiveSubscription(userId, new Date(now), REVENUECAT_ENTITLEMENT_ID)).tier;

  userTierCache.set(userId, {
    tier,
    expiresAt: now + Math.max(1_000, USER_TIER_CACHE_TTL_MS)
  });
  return tier;
}

function invalidateUserTierCache(userId: string): void {
  userTierCache.delete(userId);
}

const bindInviteSchema = z.object({
  code: z.string().trim().min(4).max(32)
});

const creemCheckoutSchema = z.object({
  plan: z.enum(["monthly", "yearly"]).default("monthly")
});

function verifyCreemSignature(payload: string, signature: string | string[] | undefined): boolean {
  if (!CREEM_WEBHOOK_SECRET || !signature || Array.isArray(signature)) {
    return false;
  }

  const computed = createHmac("sha256", CREEM_WEBHOOK_SECRET)
    .update(payload)
    .digest("hex");

  const received = signature.includes("=") ? signature.split("=").pop() ?? "" : signature;
  const computedBuffer = Buffer.from(computed, "hex");
  const receivedBuffer = Buffer.from(received, "hex");
  return computedBuffer.length === receivedBuffer.length
    && timingSafeEqual(computedBuffer, receivedBuffer);
}

function constantTimeStringEqual(left: string, right: string): boolean {
  const leftBuffer = Buffer.from(left, "utf8");
  const rightBuffer = Buffer.from(right, "utf8");
  return leftBuffer.length === rightBuffer.length && timingSafeEqual(leftBuffer, rightBuffer);
}

async function fetchRevenueCatCustomer(appUserId: string): Promise<RevenueCatCustomerResponse> {
  if (!REVENUECAT_API_KEY) throw new Error("REVENUECAT_API_KEY is not configured");
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15_000);
  try {
    const response = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`,
      {
        headers: {
          Authorization: `Bearer ${REVENUECAT_API_KEY}`,
          Accept: "application/json"
        },
        signal: controller.signal
      }
    );
    if (!response.ok) {
      throw new Error(`RevenueCat customer lookup failed with HTTP ${response.status}`);
    }
    return await response.json() as RevenueCatCustomerResponse;
  } finally {
    clearTimeout(timeout);
  }
}

async function syncRevenueCatEntitlement(userId: string, lastEventId: string | null = null) {
  const customer = await fetchRevenueCatCustomer(userId);
  const snapshot = revenueCatEntitlementSnapshot(customer, REVENUECAT_ENTITLEMENT_ID);
  await prisma.revenueCatEntitlement.upsert({
    where: {
      userId_entitlementId: { userId, entitlementId: REVENUECAT_ENTITLEMENT_ID }
    },
    create: {
      userId,
      entitlementId: REVENUECAT_ENTITLEMENT_ID,
      isActive: snapshot.active,
      expiresAt: snapshot.expiresAt,
      productId: snapshot.productId,
      store: snapshot.store,
      originalTransactionId: snapshot.originalTransactionId,
      lastEventId,
      lastSyncedAt: new Date()
    },
    update: {
      isActive: snapshot.active,
      expiresAt: snapshot.expiresAt,
      productId: snapshot.productId,
      store: snapshot.store,
      originalTransactionId: snapshot.originalTransactionId,
      lastEventId: lastEventId ?? undefined,
      lastSyncedAt: new Date()
    }
  });
  invalidateUserTierCache(userId);
  return snapshot;
}

function creemProductIdForPlan(plan: "monthly" | "yearly"): string {
  return plan === "yearly" ? CREEM_YEARLY_PRODUCT_ID : CREEM_MONTHLY_PRODUCT_ID;
}

function creemSubscriptionExpiry(object: any): Date | null {
  const raw =
    object?.current_period_end_date
    ?? object?.current_period_end
    ?? object?.period_end_date
    ?? object?.subscription?.current_period_end_date
    ?? object?.subscription?.current_period_end
    ?? null;
  if (!raw) return null;
  const parsed = new Date(raw);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function creemMetadata(object: any): Record<string, unknown> {
  return object?.metadata ?? object?.subscription?.metadata ?? object?.checkout?.metadata ?? {};
}

function creemCustomerId(object: any): string | null {
  return object?.customer?.id ?? object?.customer_id ?? object?.subscription?.customer?.id ?? null;
}

function creemSubscriptionId(object: any): string | null {
  return object?.subscription?.id ?? object?.subscription_id ?? object?.id ?? null;
}

type CreditFeature = "voice" | "agent_recipe" | "chat" | "import";

type CreditConsumeResult = {
  allowed: boolean;
  balance: number | null;
  tier: UserTier;
  cost: number;
};

function positiveIntegerFromEnv(name: string, fallback: number): number {
  const configuredValue = Number(process.env[name]);
  return Number.isInteger(configuredValue) && configuredValue > 0
    ? configuredValue
    : fallback;
}

// Keep enough free usage to reach the product's core value, while making the
// paid boundary reachable. Environment overrides let us tune this without an
// app release after observing real conversion data.
const CREDIT_COSTS: Record<CreditFeature, number> = {
  voice: positiveIntegerFromEnv("CREDIT_COST_VOICE", 8),
  agent_recipe: positiveIntegerFromEnv("CREDIT_COST_AGENT_RECIPE", 5),
  import: positiveIntegerFromEnv("CREDIT_COST_IMPORT", 10),
  chat: positiveIntegerFromEnv("CREDIT_COST_CHAT", 2)
};

const INITIAL_CREDITS = positiveIntegerFromEnv("INITIAL_FREE_CREDITS", 30);

const creditFeatureSchema = z.object({
  feature: z.enum(["voice", "agent_recipe", "chat", "import"])
});

function isCreditFeature(value: unknown): value is CreditFeature {
  return typeof value === "string" && value in CREDIT_COSTS;
}

async function getOrCreateCredits(userId: string): Promise<{ balance: number }> {
  const existing = await prisma.userCredits.findUnique({ where: { userId } });
  if (existing) return existing;
  return prisma.userCredits.create({
    data: { userId, balance: INITIAL_CREDITS }
  });
}

async function consumeCreditsForUser(userId: string, feature: CreditFeature): Promise<CreditConsumeResult> {
  const cost = CREDIT_COSTS[feature];
  const tier = await resolveUserTier(userId);
  if (tier === "pro") {
    return { allowed: true, balance: null, tier, cost };
  }

  await upsertUser(userId);

  const result = await prisma.$transaction(async (tx) => {
    await tx.$executeRaw`
      INSERT INTO "UserCredits" ("userId", "balance", "createdAt", "updatedAt")
      VALUES (${userId}, ${INITIAL_CREDITS}, NOW(), NOW())
      ON CONFLICT ("userId") DO NOTHING
    `;

    const rows = await tx.$queryRaw<Array<{ balance: number }>>`
      SELECT "balance" FROM "UserCredits" WHERE "userId" = ${userId} LIMIT 1
    `;
    const balance = Number(rows[0]?.balance ?? 0);

    if (balance < cost) {
      return { allowed: false, balance };
    }

    const updated = await tx.$queryRaw<Array<{ balance: number }>>`
      UPDATE "UserCredits"
      SET "balance" = "balance" - ${cost}, "updatedAt" = NOW()
      WHERE "userId" = ${userId} AND "balance" >= ${cost}
      RETURNING "balance"
    `;

    if (!updated.length) {
      const current = await tx.$queryRaw<Array<{ balance: number }>>`
        SELECT "balance" FROM "UserCredits" WHERE "userId" = ${userId} LIMIT 1
      `;
      return { allowed: false, balance: Number(current[0]?.balance ?? 0) };
    }

    const newBalance = Number(updated[0].balance);
    console.log(
      `💳 Credit consumed: user=${userId} feature=${feature} cost=${cost} balance=${balance}->${newBalance}`
    );
    return { allowed: true, balance: newBalance };
  });

  return { ...result, tier, cost };
}

async function checkCreditsForUser(userId: string, feature: CreditFeature): Promise<CreditConsumeResult> {
  const cost = CREDIT_COSTS[feature];
  const tier = await resolveUserTier(userId);
  if (tier === "pro") {
    return { allowed: true, balance: null, tier, cost };
  }

  await upsertUser(userId);
  const record = await getOrCreateCredits(userId);
  return {
    allowed: record.balance >= cost,
    balance: record.balance,
    tier,
    cost
  };
}

app.get("/health", (_req, res) => {
  res.json({ ok: true });
});

app.get("/version", (_req, res) => {
  res.json({ version: "1.1.4", updated: new Date().toISOString() });
});

app.post("/billing/creem/checkout", requireAuth, async (req, res) => {
  if (!CREEM_API_KEY) {
    res.status(500).json({ error: "CREEM_API_KEY is not configured" });
    return;
  }

  const parsed = creemCheckoutSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid payload" });
    return;
  }

  const productId = creemProductIdForPlan(parsed.data.plan);
  if (!productId) {
    res.status(500).json({ error: "Creem product ID is not configured" });
    return;
  }

  const userId = req.userId as string;
  const successUrl = `${WEB_APP_BASE_URL.replace(/\/$/, "")}/app?checkout=success`;

  try {
    await upsertUser(userId);
    const response = await fetch(`${CREEM_API_BASE_URL.replace(/\/$/, "")}/v1/checkouts`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": CREEM_API_KEY
      },
      body: JSON.stringify({
        product_id: productId,
        request_id: `chillnote-${userId}-${randomUUID()}`,
        units: 1,
        success_url: successUrl,
        customer: req.userEmail ? { email: req.userEmail } : undefined,
        metadata: {
          userId,
          plan: parsed.data.plan,
          provider: "creem"
        }
      })
    });

    const body = await response.json().catch(() => ({})) as any;
    if (!response.ok) {
      console.error("❌ Creem checkout failed:", body);
      res.status(response.status).json({ error: "Creem checkout failed" });
      return;
    }

    res.json({
      checkoutUrl: body.checkout_url ?? body.checkoutUrl,
      checkoutId: body.id ?? null
    });
  } catch (error) {
    console.error("❌ Creem Checkout Error:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

app.post("/webhooks/creem", express.raw({ type: "application/json", limit: "1mb" }), async (req, res) => {
  const rawBody = Buffer.isBuffer(req.body) ? req.body.toString("utf8") : "";
  const signature = req.headers["creem-signature"];

  if (!verifyCreemSignature(rawBody, signature)) {
    res.status(401).json({ error: "Invalid signature" });
    return;
  }

  let event: any;
  try {
    event = JSON.parse(rawBody);
  } catch {
    res.status(400).json({ error: "Invalid JSON" });
    return;
  }

  const eventType = event.eventType ?? event.type;
  const object = event.object ?? event.data?.object ?? event.data ?? {};
  const metadata = creemMetadata(object);
  const userId = typeof metadata.userId === "string"
    ? metadata.userId
    : typeof metadata.referenceId === "string"
      ? metadata.referenceId
      : null;

  if (!userId) {
    console.warn("⚠️ Creem webhook missing userId metadata:", eventType);
    res.json({ received: true, ignored: true });
    return;
  }

  try {
    await upsertUser(userId);

    if (["subscription.active", "subscription.trialing", "subscription.paid", "checkout.completed"].includes(eventType)) {
      await updateCreemSubscriptionStatus({
        userId,
        tier: "pro",
        expiresAt: creemSubscriptionExpiry(object),
        customerId: creemCustomerId(object),
        subscriptionId: creemSubscriptionId(object)
      });
      invalidateUserTierCache(userId);
    } else if (["subscription.canceled", "subscription.expired"].includes(eventType)) {
      await updateCreemSubscriptionStatus({
        userId,
        tier: "free",
        expiresAt: creemSubscriptionExpiry(object),
        customerId: creemCustomerId(object),
        subscriptionId: creemSubscriptionId(object)
      });
      invalidateUserTierCache(userId);
    }

    res.json({ received: true });
  } catch (error) {
    console.error("❌ Creem Webhook Error:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

app.post("/webhooks/revenuecat", express.raw({ type: "application/json", limit: "1mb" }), async (req, res) => {
  const rawBody = Buffer.isBuffer(req.body) ? req.body.toString("utf8") : "";
  if (!REVENUECAT_WEBHOOK_AUTHORIZATION) {
    res.status(503).json({ error: "RevenueCat webhook authorization is not configured" });
    return;
  }
  const authorization = typeof req.headers.authorization === "string" ? req.headers.authorization : "";
  if (!constantTimeStringEqual(authorization, REVENUECAT_WEBHOOK_AUTHORIZATION)) {
    res.status(401).json({ error: "Invalid authorization" });
    return;
  }
  if (REVENUECAT_WEBHOOK_HMAC_SECRET && !verifyRevenueCatWebhookSignature(
    rawBody,
    req.headers["x-revenuecat-webhook-signature"],
    REVENUECAT_WEBHOOK_HMAC_SECRET
  )) {
    res.status(401).json({ error: "Invalid signature" });
    return;
  }

  let webhook: RevenueCatWebhook;
  try {
    webhook = JSON.parse(rawBody) as RevenueCatWebhook;
  } catch {
    res.status(400).json({ error: "Invalid JSON" });
    return;
  }
  const event = webhook.event;
  if (
    webhook.api_version !== "1.0" ||
    !event ||
    typeof event.id !== "string" ||
    typeof event.type !== "string" ||
    !Number.isFinite(event.event_timestamp_ms)
  ) {
    res.status(400).json({ error: "Invalid RevenueCat webhook" });
    return;
  }
  if (REVENUECAT_ALLOWED_APP_IDS.size > 0 && event.app_id && !REVENUECAT_ALLOWED_APP_IDS.has(event.app_id)) {
    res.status(403).json({ error: "Unexpected RevenueCat app" });
    return;
  }

  try {
    const existing = await prisma.revenueCatWebhookEvent.findUnique({ where: { id: event.id } });
    if (existing) {
      res.json({ received: true, duplicate: true });
      return;
    }
    if (event.type === "TEST") {
      await prisma.revenueCatWebhookEvent.create({
        data: {
          id: event.id,
          type: event.type,
          appUserId: event.app_user_id ?? null,
          environment: event.environment ?? null,
          eventTimestampAt: new Date(event.event_timestamp_ms)
        }
      });
      res.json({ received: true, test: true });
      return;
    }

    const candidateUserIds = revenueCatWebhookUserIds(event);
    const user = candidateUserIds.length > 0
      ? await prisma.user.findFirst({ where: { id: { in: candidateUserIds } }, select: { id: true } })
      : null;
    if (!user) {
      console.warn(`RevenueCat webhook has no matching ChillScript user: event=${event.id}`);
      res.json({ received: true, ignored: true });
      return;
    }

    await syncRevenueCatEntitlement(user.id, event.id);
    await prisma.revenueCatWebhookEvent.create({
      data: {
        id: event.id,
        type: event.type,
        appUserId: user.id,
        environment: event.environment ?? null,
        eventTimestampAt: new Date(event.event_timestamp_ms)
      }
    });
    res.json({ received: true });
  } catch (error) {
    if (isPrismaUniqueConstraintError(error)) {
      res.json({ received: true, duplicate: true });
      return;
    }
    console.error("RevenueCat webhook processing failed:", error instanceof Error ? error.message : "UnknownError");
    res.status(503).json({ error: "RevenueCat webhook processing unavailable" });
  }
});

app.get("/invite/me", requireAuth, async (req, res) => {
  const userId = req.userId as string;

  try {
    await upsertUser(userId);
    const [code, monthlyRewardedCount] = await Promise.all([
      getOrCreateInviteCode(userId),
      getInviteMonthlyRewardCount(userId)
    ]);
    const inviteConfig = getInviteConfig();

    res.json({
      code,
      monthlyRewardedCount,
      monthlyCap: inviteConfig.monthlyCap,
      rewardDays: inviteConfig.rewardDays,
      bindWindowDays: inviteConfig.bindWindowDays
    });
  } catch (error) {
    console.error("❌ Invite Me Error:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

app.post("/invite/bind", requireAuth, async (req, res) => {
  const parsed = bindInviteSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid payload" });
    return;
  }

  const userId = req.userId as string;
  const userCreatedAt = req.userCreatedAt;
  if (!userCreatedAt) {
    res.status(400).json({ error: "Missing user create time" });
    return;
  }

  const createdAt = new Date(userCreatedAt);
  if (Number.isNaN(createdAt.getTime())) {
    res.status(400).json({ error: "Invalid user create time" });
    return;
  }

  try {
    await upsertUser(userId);
    const result = await bindInviteCode({
      inviteeId: userId,
      inviteeCreatedAt: createdAt,
      code: parsed.data.code
    });

    res.json({
      success: true,
      inviteId: result.inviteId,
      inviterRewardDays: result.rewardDays,
      inviteeRewardDays: result.rewardDays,
      inviterNewExpiresAt: result.inviterNewExpiresAt,
      inviteeNewExpiresAt: result.inviteeNewExpiresAt,
      monthlyCap: result.monthlyCap
    });
  } catch (error: unknown) {
    if (error instanceof InviteError) {
      res.status(error.statusCode).json({ error: error.message, code: error.code });
      return;
    }

    console.error("❌ Invite Bind Error:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

// Waitlist Signup
const waitlistSchema = z.object({
  email: z.string().email(),
  source: z.string().optional()
});

app.post("/waitlist", async (req, res) => {
  const parsed = waitlistSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Please provide a valid email address." });
    return;
  }

  const { email, source } = parsed.data;

  try {
    const existing = await prisma.waitlist.findUnique({
      where: { email }
    });

    if (existing) {
      res.json({ success: true, alreadyExists: true });
      return;
    }

    await prisma.waitlist.create({
      data: {
        email,
        source: source || "website"
      }
    });

    console.log(`✨ New Waitlist Signup: ${email} (${source || "website"})`);
    res.json({ success: true });
  } catch (error) {
    console.error("❌ Waitlist Signup Error:", error);
    res.status(500).json({ error: "Failed to join waitlist. Please try again later." });
  }
});

// Delete Account: Deletes from both public DB and Supabase Auth.
app.delete("/auth/account", requireAuth, (req, res) => handleAccountDeletion(req, res, {
  deleteBusinessData: deleteUser,
  deleteAuthUser: (userId) => supabaseAdmin.auth.admin.deleteUser(userId),
  onBusinessDataDeleted: invalidateUserTierCache
}));

app.post("/sync", requireAuth, async (req, res) => {
  const parsed = syncSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid payload" });
    return;
  }

  const userId = req.userId as string;
  const cursor = typeof parsed.data.cursor === "string" ? parsed.data.cursor : undefined;

  const incoming = parsed.data as SyncPayload;
  try {
    const result = await prisma.$transaction(async (transaction) => {
      // Serialize sync batches for one account. READ COMMITTED is intentional:
      // a request waiting for the advisory lock must see the previous holder's
      // committed writes in the statements that follow this lock acquisition.
      await acquireUserSyncTransactionLock(userId, transaction);
      await upsertUser(userId, transaction);

      // Validate every client's cursor against this user's checkpoint before
      // this request appends its own logs; otherwise an old global/future cursor
      // could be made to look valid and permanently skip account history.
      const maximumAcceptedCursor = await getLatestSyncLogId(userId, transaction);
      const applied = await applySync(incoming, userId, transaction);
      const downloaded = await getChangesSinceCursor(userId, cursor, transaction, {
        protocolVersion: incoming.protocolVersion,
        maximumAcceptedCursor,
        forcedNoteIds: applied.forcedNoteIds,
        forcedTagIds: applied.forcedTagIds,
        forcedHardDeletedNoteIds: applied.forcedHardDeletedNoteIds,
        forcedHardDeletedTagIds: applied.forcedHardDeletedTagIds
      });
      return {
        ...downloaded,
        conflicts: applied.conflicts,
        forcedNoteIds: applied.forcedNoteIds,
        forcedTagIds: applied.forcedTagIds
      };
    }, {
      maxWait: 10_000,
      timeout: 30_000
    });

    res.json({
      cursor: result.cursor,
      changes: result.changes,
      conflicts: result.conflicts,
      forcedNoteIds: result.forcedNoteIds,
      forcedTagIds: result.forcedTagIds,
      serverTime: new Date().toISOString()
    });
  } catch (error) {
    if (error instanceof AccountDeletedError || isAccountDeletedDatabaseError(error)) {
      res.status(410).json({ error: "sync.account_deleted" });
      return;
    }
    if (error instanceof SyncOwnershipError || isPrismaUniqueConstraintError(error)) {
      res.status(409).json({
        error: error instanceof SyncOwnershipError ? error.message : "sync.identity_unavailable"
      });
      return;
    }
    if (error instanceof SyncReferenceError) {
      res.status(400).json({ error: error.message });
      return;
    }
    console.error("Sync transaction failed:", error);
    res.status(500).json({ error: "sync.failed" });
  }
});

app.post("/link-import-jobs", requireAuth, async (req, res) => {
  const parsed = linkImportJobSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid payload" });
    return;
  }

  const userId = req.userId as string;

  try {
    const source = parsed.data.source ?? makeInitialLinkSource(parsed.data.url);
    const tier = await resolveUserTier(userId);
    const job = await enqueueLinkImportJob({
      userId,
      noteId: parsed.data.noteId,
      url: parsed.data.url,
      placeholderContent: parsed.data.placeholderContent,
      source,
      section: parsed.data.section,
      contentLocale: parsed.data.contentLocale
        ?? preferredLanguageFromHeader(req.headers["accept-language"]),
      mediaLinkSections: parsed.data.mediaLinkSections,
      creditAuthorization: {
        tier,
        cost: CREDIT_COSTS.import,
        initialCredits: INITIAL_CREDITS
      }
    });
    res.status(202).json(job);
  } catch (error) {
    if (error instanceof AccountDeletedError || isAccountDeletedDatabaseError(error)) {
      res.status(410).json({ error: "sync.account_deleted" });
      return;
    }
    if (error instanceof LinkImportInsufficientCreditsError) {
      res.status(402).json({
        error: "Insufficient credits",
        balance: error.balance,
        cost: error.cost,
        feature: "import"
      });
      return;
    }
    if (error instanceof SyncOwnershipError || isPrismaUniqueConstraintError(error)) {
      res.status(409).json({
        error: error instanceof SyncOwnershipError ? error.message : "sync.identity_unavailable"
      });
      return;
    }
    console.error("❌ Link Import Job Error:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

app.post("/push-devices", requireAuth, async (req, res) => {
  const parsed = pushDeviceSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid payload" });
    return;
  }

  const userId = req.userId as string;
  try {
    await upsertUser(userId);
    await registerPushDevice({ userId, ...parsed.data });
    res.status(204).send();
  } catch (error) {
    if (error instanceof AccountDeletedError || isAccountDeletedDatabaseError(error)) {
      res.status(410).json({ error: "sync.account_deleted" });
      return;
    }
    console.error("Push device registration failed:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

app.delete("/push-devices", requireAuth, async (req, res) => {
  const parsed = pushDeviceDeleteSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid payload" });
    return;
  }

  try {
    await deactivatePushDevice(req.userId as string, parsed.data.token);
    res.status(204).send();
  } catch (error) {
    console.error("Push device deactivation failed:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

app.get("/weekly-topics/dashboard", requireAuth, async (req, res) => {
  try {
    res.json(await getWeeklyTopicDashboard(req.userId as string));
  } catch (error) {
    console.error("Weekly topics dashboard failed:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

app.put("/weekly-topics/settings", requireAuth, async (req, res) => {
  const parsed = weeklyTopicSettingsInputSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid payload" });
    return;
  }
  try {
    const userId = req.userId as string;
    await upsertUser(userId);
    if (parsed.data.enabled && !(await hasActiveProSubscription(userId))) {
      res.status(403).json({ error: "Pro subscription required" });
      return;
    }
    res.json(await updateWeeklyTopicSettings(userId, parsed.data));
  } catch (error) {
    console.error("Weekly topics settings update failed:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

app.get("/weekly-topics/reports", requireAuth, async (req, res) => {
  const rawLimit = Number(req.query.limit ?? 30);
  const limit = Number.isFinite(rawLimit) ? rawLimit : 30;
  try {
    res.json({ reports: await listWeeklyTopicReports(req.userId as string, limit) });
  } catch (error) {
    console.error("Weekly topics history failed:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

app.get("/weekly-topics/reports/:reportId", requireAuth, async (req, res) => {
  try {
    const report = await getWeeklyTopicReport(req.userId as string, req.params.reportId);
    if (!report) {
      res.status(404).json({ error: "Not found" });
      return;
    }
    res.json(report);
  } catch (error) {
    console.error("Weekly topics report failed:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

app.post("/weekly-topics/reports/:reportId/read", requireAuth, async (req, res) => {
  try {
    await markWeeklyTopicReportRead(req.userId as string, req.params.reportId);
    res.status(204).send();
  } catch (error) {
    console.error("Weekly topics read receipt failed:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

app.post("/weekly-topics/reports/:reportId/regenerate", requireAuth, async (req, res) => {
  try {
    const result = await regenerateWeeklyTopicReport(req.userId as string, req.params.reportId);
    if (result.kind === "not_found") {
      res.status(404).json({ error: "Not found" });
      return;
    }
    if (result.kind === "limit_reached") {
      res.status(409).json({ error: "Regeneration limit reached" });
      return;
    }
    if (result.kind === "not_enough_sources") {
      res.status(409).json({ error: "Not enough source notes" });
      return;
    }
    if (result.kind === "forbidden") {
      res.status(403).json({ error: "Pro subscription required" });
      return;
    }
    res.json(result.report);
  } catch (error) {
    console.error("Weekly topics regeneration failed:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

const voiceNoteSchema = z.object({
  audioBase64: z.string().min(1),
  mimeType: z.string().optional(),
  locale: z.string().optional(),
  spokenLanguageMode: z.enum(["auto", "prefer"]).optional(),
  spokenLanguageHint: z.string().optional(),
  countUsage: z.boolean().optional()
});

const tiktokTranscriptSchema = z.object({
  url: z.string().url()
});

function extractFirstJSONObjectSnippet(raw: string): string | null {
  const start = raw.indexOf("{");
  if (start < 0) return null;

  let depth = 0;
  let inString = false;
  let escaped = false;

  for (let i = start; i < raw.length; i += 1) {
    const ch = raw[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch === "\\") {
        escaped = true;
      } else if (ch === "\"") {
        inString = false;
      }
      continue;
    }

    if (ch === "\"") {
      inString = true;
      continue;
    }
    if (ch === "{") {
      depth += 1;
      continue;
    }
    if (ch === "}") {
      depth -= 1;
      if (depth === 0) {
        return raw.slice(start, i + 1);
      }
      continue;
    }
  }
  return null;
}

function tryParseTranscriptText(candidate: string): string | null {
  try {
    const parsed = JSON.parse(candidate);
    if (
      parsed &&
      typeof parsed === "object" &&
      "text" in parsed &&
      typeof (parsed as any).text === "string"
    ) {
      return (parsed as any).text;
    }
  } catch { }
  return null;
}

function extractLooseTextField(raw: string): string | null {
  const match = raw.match(/"text"\s*:\s*"((?:\\.|[^"\\])*)"/s);
  if (!match) return null;

  try {
    return JSON.parse(`"${match[1]}"`);
  } catch {
    return match[1];
  }
}

function parseVoiceNoteModelOutput(raw: string): { text: string; parsed: boolean } {
  const trimmed = String(raw ?? "").trim();
  if (!trimmed) return { text: "", parsed: true };

  const direct = tryParseTranscriptText(trimmed);
  if (direct != null) return { text: direct.trim(), parsed: true };

  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  if (fenced?.[1]) {
    const fencedParsed = tryParseTranscriptText(fenced[1].trim());
    if (fencedParsed != null) return { text: fencedParsed.trim(), parsed: true };
  }

  const firstJSONObject = extractFirstJSONObjectSnippet(trimmed);
  if (firstJSONObject) {
    const objectParsed = tryParseTranscriptText(firstJSONObject);
    if (objectParsed != null) return { text: objectParsed.trim(), parsed: true };
  }

  const loose = extractLooseTextField(trimmed);
  if (loose != null) return { text: loose.trim(), parsed: true };

  return { text: trimmed, parsed: false };
}

async function postVerifyReceipt(
  url: string,
  receiptData: string,
  sharedSecret: string
): Promise<any> {
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      "receipt-data": receiptData,
      password: sharedSecret,
      "exclude-old-transactions": true
    })
  });

  const data = await response.json().catch(() => ({}));
  return { status: response.status, data };
}

async function verifyReceiptWithApple(receiptData: string, sharedSecret: string): Promise<any> {
  const productionUrl = "https://buy.itunes.apple.com/verifyReceipt";
  const sandboxUrl = "https://sandbox.itunes.apple.com/verifyReceipt";

  const prodResult = await postVerifyReceipt(productionUrl, receiptData, sharedSecret);
  // 21007: sandbox receipt sent to production
  if (prodResult.data?.status === 21007) {
    const sandboxResult = await postVerifyReceipt(sandboxUrl, receiptData, sharedSecret);
    return sandboxResult.data;
  }

  return prodResult.data;
}

// Voice Note Endpoint: Audio -> Raw transcript only (no intent rewrite)
app.post("/ai/voice-note", aiJsonParser, requireAuth, async (req, res) => {
  if (!GEMINI_API_KEY) {
    console.error("❌ GEMINI_API_KEY is not configured");
    res.status(500).json({ error: "GEMINI_API_KEY is not configured on server" });
    return;
  }

  const parsed = voiceNoteSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid payload" });
    return;
  }

  try {
    const { audioBase64, mimeType, locale, spokenLanguageMode, spokenLanguageHint, countUsage } = parsed.data;
    const shouldCountUsage = countUsage !== false;
    if (shouldCountUsage) {
      const creditState = await consumeCreditsForUser(req.userId as string, "voice");
      if (!creditState.allowed) {
        console.warn(
          `🚫 VoiceNote Credits Denied: user=${req.userId}, ` +
          `tier=${creditState.tier}, balance=${creditState.balance}, cost=${creditState.cost}`
        );
        res.status(402).json({
          error: "Insufficient credits",
          feature: "voice",
          tier: creditState.tier,
          balance: creditState.balance,
          cost: creditState.cost
        });
        return;
      }
    }

    const audioDecodedBytes = Buffer.byteLength(audioBase64, "base64");
    const audioDecodedMb = audioDecodedBytes / 1024 / 1024;

    const maxAudioMb = Number(process.env.MAX_VOICE_NOTE_AUDIO_MB ?? 100);
    if (Number.isFinite(maxAudioMb) && maxAudioMb > 0 && audioDecodedMb > maxAudioMb) {
      console.warn(
        `🗣️ VoiceNote Rejected: audioDecoded=${audioDecodedMb.toFixed(2)}MB > max=${maxAudioMb}MB`
      );
      res.status(413).json({
        error: "Voice note too large",
        details: { maxAudioMb, audioDecodedMb: Number(audioDecodedMb.toFixed(2)) }
      });
      return;
    }

    const audioBase64Kb = Math.round(audioBase64.length / 1024);
    const audioDecodedKb = Math.round(audioDecodedBytes / 1024);
    console.log(
      `🗣️ VoiceNote Request: audioBase64=${audioBase64Kb}KB, audioDecoded=${audioDecodedKb}KB`
    );

    const url = buildGeminiGenerateContentURL(GEMINI_MODEL);

    const normalizedLanguageHint = spokenLanguageHint?.trim();
    const hasPreferredLanguageHint =
      spokenLanguageMode === "prefer" && !!normalizedLanguageHint;

    const localeConstraint = hasPreferredLanguageHint
      ? `- Preferred primary language hint: "${normalizedLanguageHint}". Treat this as a soft preference only; preserve all spoken languages exactly as heard.`
      : (locale
        ? `- Optional hint: client locale is "${locale}". This may reflect UI/device settings and MAY NOT match spoken language. Use audio content as source of truth.`
        : "- No language hint provided. Infer language from audio only.");

    const systemInstruction = [
      "You are a professional voice transcription assistant. Your ONLY job is to transcribe audio faithfully in the ORIGINAL spoken language.",
      "",
      "STRICT RULES:",
      localeConstraint,
      "- CRITICAL: Keep transcript in the ORIGINAL spoken language(s). Do NOT translate to any other language.",
      "- Preserve multilingual/code-switched speech exactly (for example, mixed Spanish + English).",
      "- Do NOT transliterate or romanize. Keep native script when the speaker uses a native script.",
      "- Transcribe exactly what is said, word for word.",
      "- Keep fillers, repetitions, and self-corrections as spoken.",
      "- Do NOT include timestamps, speaker labels, or line numbers.",
      "- Do NOT summarize, rewrite, polish, or restructure the content.",
      "- Output format: STRICT JSON only, no extra keys.",
      "- JSON schema: {\"text\": string}"
    ].join("\n");

    const userPrompt = [
      "Transcribe the audio verbatim in the original spoken language(s). Do NOT translate. Do NOT include timestamps.",
      hasPreferredLanguageHint
        ? `Primary language is likely ${normalizedLanguageHint}, but keep words from all spoken languages exactly as heard.`
        : undefined,
      "Preserve code-switching and fillers exactly as spoken."
    ].filter(Boolean).join("\n");

    const body: any = {
      systemInstruction: { parts: [{ text: systemInstruction }] },
      contents: [
        {
          parts: [
            { inlineData: { mimeType: mimeType || "audio/wav", data: audioBase64 } },
            { text: userPrompt }
          ]
        }
      ],
      generationConfig: {
        temperature: 0,
        responseMimeType: "application/json",
        responseSchema: {
          type: "OBJECT",
          required: ["text"],
          properties: {
            text: { type: "STRING" }
          }
        }
      }
    };

    const abortController = new AbortController();
    const timeoutMs = Number(process.env.VOICE_NOTE_TIMEOUT_MS ?? 180000);
    const timeoutId = setTimeout(() => abortController.abort(), timeoutMs);

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
        signal: abortController.signal as any
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        const errorText = await response.text();
        console.error("❌ Gemini API Error:", errorText);
        res.status(response.status).json({ error: "AI Provider Error" });
        return;
      }

      const data = await response.json() as any;
      const content = data.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
      const parsedResult = parseVoiceNoteModelOutput(content);
      const text = parsedResult.text;
      if (!parsedResult.parsed && String(content).includes("\"text\"")) {
        console.warn("⚠️ VoiceNote JSON parse fallback used; returning raw model output.");
      }

      console.log(`✅ VoiceNote Success: ${text.length} chars`);
      res.json({ text });
    } catch (fetchError: any) {
      if (fetchError.name === "AbortError") {
        res.status(504).json({ error: "AI Service Timeout" });
      } else {
        throw fetchError;
      }
    }
  } catch (error) {
    console.error("❌ VoiceNote Error:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

app.post("/ai/media-link-transcript", aiJsonParser, requireAuth, async (req, res) => {
  if (!GEMINI_API_KEY) {
    console.error("❌ GEMINI_API_KEY is not configured");
    res.status(500).json({ error: "GEMINI_API_KEY is not configured on server" });
    return;
  }

  const parsed = tiktokTranscriptSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid payload" });
    return;
  }

  const { url } = parsed.data;
  if (!isSupportedMediaLinkURL(url)) {
    res.status(400).json({ error: "Only TikTok, YouTube, and Instagram URLs are supported" });
    return;
  }

  try {
    const creditState = await consumeCreditsForUser(req.userId as string, "import");
    if (!creditState.allowed) {
      console.warn(
        `🚫 Media Link Transcript Credits Denied: user=${req.userId}, ` +
        `tier=${creditState.tier}, balance=${creditState.balance}, cost=${creditState.cost}`
      );
      res.status(200).json({
        available: false,
        text: null,
        reason: "insufficient_credits"
      });
      return;
    }

    const startedAt = Date.now();
    const result = await transcribeMediaLinkURL(url);
    console.log(
      `✅ Media Link Transcript: user=${req.userId}, available=${result.available}, ` +
      `elapsedMs=${Date.now() - startedAt}, resolvedURL=${result.metadata?.resolvedURL ?? url}`
    );
    res.json(result);
  } catch (error) {
    if (isHandledTikTokTranscriptError(error)) {
      console.warn(
        `⚠️ Media Link Transcript Unavailable: user=${req.userId}, url=${url}, ` +
        `reason=${error.reason}, message=${error.message}`
      );
      res.status(200).json({
        available: false,
        text: null,
        reason: error.reason,
        metadata: error.metadata
      });
      return;
    }

    console.error("❌ Media Link Transcript Error:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

app.post("/ai/tiktok-transcript", aiJsonParser, requireAuth, async (req, res) => {
  if (!GEMINI_API_KEY) {
    console.error("❌ GEMINI_API_KEY is not configured");
    res.status(500).json({ error: "GEMINI_API_KEY is not configured on server" });
    return;
  }

  const parsed = tiktokTranscriptSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid payload" });
    return;
  }

  const { url } = parsed.data;
  if (!isTikTokURL(url)) {
    res.status(400).json({ error: "Only TikTok URLs are supported" });
    return;
  }

  try {
    const creditState = await consumeCreditsForUser(req.userId as string, "import");
    if (!creditState.allowed) {
      res.status(200).json({
        available: false,
        text: null,
        reason: "insufficient_credits"
      });
      return;
    }

    const result = await transcribeTikTokURL(url);
    res.json(result);
  } catch (error) {
    if (isHandledTikTokTranscriptError(error)) {
      res.status(200).json({
        available: false,
        text: null,
        reason: error.reason
      });
      return;
    }

    console.error("❌ TikTok Transcript Error:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

const googlePlayVerifySchema = z.object({
  productId: z.string().min(1),
  purchaseToken: z.string().min(20).max(2048)
});

app.post("/subscription/google/verify", requireAuth, async (req, res) => {
  const parsed = googlePlayVerifySchema.safeParse(req.body);
  if (!parsed.success || !GOOGLE_PLAY_PRODUCT_IDS.has(parsed.data.productId)) {
    res.status(400).json({ error: "Invalid Google Play purchase payload" });
    return;
  }
  const userId = req.userId as string;
  const { productId, purchaseToken } = parsed.data;
  try {
    await upsertUser(userId);
    const result = await verifyGooglePlayPurchase(
      { userId, productId, purchaseToken },
      googlePlayBillingDependencies
    );
    if (!result.ok) {
      res.status(result.httpStatus).json({
        error: "Google Play purchase could not be completed",
        code: result.code,
        retryable: result.retryable,
        subscriptionState: result.subscriptionState ?? null,
        expiresAt: result.expiresAt?.toISOString() ?? null
      });
      return;
    }
    invalidateUserTierCache(userId);
    console.log(`Google Play subscription activated: user=${userId}, product=${productId}`);
    res.json({
      success: true,
      tier: result.tier,
      expiresAt: result.expiresAt.toISOString(),
      activeProductId: productId
    });
  } catch (error) {
    console.error(
      "Google Play subscription verification internal failure:",
      error instanceof Error ? error.name : "UnknownError"
    );
    res.status(500).json({ error: "Google Play verification unavailable" });
  }
});

// Subscription Verification Endpoint
app.post("/subscription/verify", requireAuth, async (req, res) => {
  const {
    transactionId,
    receiptData,
    productId: bodyProductId,
    originalTransactionId: bodyOriginalTransactionId,
    expiresDate: bodyExpiresDate
  } = req.body;
  const userId = req.userId as string;

  if (!bodyProductId) {
    res.status(400).json({ error: "Missing productId" });
    return;
  }

  try {
    // ── Path A: Legacy receipt verification (pre-iOS 18) ──
    if (receiptData) {
      const APPLE_SHARED_SECRET = process.env.APPLE_SHARED_SECRET;
      if (!APPLE_SHARED_SECRET) {
        console.error("❌ APPLE_SHARED_SECRET is not configured");
        res.status(500).json({ error: "Server configuration error" });
        return;
      }

      // 1) Verify receipt with Apple (production with sandbox fallback)
      const verification = await verifyReceiptWithApple(receiptData, APPLE_SHARED_SECRET);
      if (!verification || verification.status !== 0) {
        console.error("❌ Receipt verification failed:", verification?.status);
        res.status(400).json({ error: "Invalid receipt", details: verification?.status });
        return;
      }

      const receiptInfos: any[] =
        verification.latest_receipt_info ??
        verification.receipt?.in_app ??
        [];

      const matching = receiptInfos.filter((entry) => entry.product_id === bodyProductId);
      if (matching.length === 0) {
        res.status(400).json({ error: "Receipt does not contain product" });
        return;
      }

      const latest = matching.reduce((acc, cur) => {
        const accMs = Number(acc.expires_date_ms ?? 0);
        const curMs = Number(cur.expires_date_ms ?? 0);
        return curMs > accMs ? cur : acc;
      }, matching[0]);

      const originalTransactionId =
        latest.original_transaction_id ??
        bodyOriginalTransactionId ??
        null;

      if (!originalTransactionId) {
        res.status(400).json({ error: "Missing originalTransactionId" });
        return;
      }

      // 2) Migrate subscription if bound to another user
      const existingUser = await prisma.user.findFirst({
        where: { originalTransactionId }
      });

      if (existingUser && existingUser.id !== userId) {
        // Detach this Apple subscription from the old user, but preserve
        // their tier/expiresAt so invite-reward Pro isn't wiped.
        // resolveUserTier will naturally downgrade them if their only
        // source of Pro was this Apple subscription (once it expires).
        await prisma.user.update({
          where: { id: existingUser.id },
          data: { originalTransactionId: null }
        });
        invalidateUserTierCache(existingUser.id);
        console.log(
          `🔄 Subscription migrated from user=${existingUser.id} to user=${userId} (originalTxn=${originalTransactionId})`
        );
      }

      // 3) Determine tier and expiration from Apple receipt
      let tier = "free";
      const expiresMs = Number(latest.expires_date_ms ?? 0);
      const expiresAt = Number.isFinite(expiresMs) && expiresMs > 0 ? new Date(expiresMs) : null;
      if (bodyProductId && (bodyProductId.includes("pro") || bodyProductId.includes("monthly") || bodyProductId.includes("yearly"))) {
        if (!expiresAt || expiresAt > new Date()) {
          tier = "pro";
        }
      }

      // 4) Save to DB
      await updateSubscriptionStatus(userId, tier, expiresAt, originalTransactionId, "apple");
      invalidateUserTierCache(userId);

      console.log(`✅ Verified Subscription (receipt): user=${userId}, tier=${tier}, transactionId=${transactionId ?? "n/a"}`);

      res.json({
        success: true,
        tier,
        expiresAt: expiresAt?.toISOString()
      });
      return;
    }

    // ── Path B: StoreKit 2 metadata verification (iOS 18+) ──
    // On iOS 18+ the legacy app receipt is unavailable. The client sends
    // transaction metadata that was already verified locally by StoreKit 2's
    // checkVerified(). We trust this because:
    //   - The request is authenticated (requireAuth middleware).
    //   - StoreKit 2 transactions are cryptographically signed by Apple and
    //     verified client-side before being sent here.
    // For production hardening, consider using Apple's App Store Server API
    // to verify the transactionId server-side.

    const originalTransactionId = bodyOriginalTransactionId ?? null;
    if (!originalTransactionId) {
      res.status(400).json({ error: "Missing originalTransactionId" });
      return;
    }

    // Migrate subscription if bound to another user
    const existingUser = await prisma.user.findFirst({
      where: { originalTransactionId }
    });

    if (existingUser && existingUser.id !== userId) {
      // Detach this Apple subscription from the old user, but preserve
      // their tier/expiresAt so invite-reward Pro isn't wiped.
      await prisma.user.update({
        where: { id: existingUser.id },
        data: { originalTransactionId: null }
      });
      invalidateUserTierCache(existingUser.id);
      console.log(
        `🔄 Subscription migrated from user=${existingUser.id} to user=${userId} (originalTxn=${originalTransactionId})`
      );
    }

    // Determine tier and expiration from client-provided metadata
    let tier = "free";
    let expiresAt: Date | null = null;

    if (bodyExpiresDate) {
      const parsed = new Date(bodyExpiresDate);
      if (!Number.isNaN(parsed.getTime())) {
        expiresAt = parsed;
      }
    }

    if (bodyProductId && (bodyProductId.includes("pro") || bodyProductId.includes("monthly") || bodyProductId.includes("yearly"))) {
      if (!expiresAt || expiresAt > new Date()) {
        tier = "pro";
      }
    }

    // Save to DB
    await updateSubscriptionStatus(userId, tier, expiresAt, originalTransactionId, "apple");
    invalidateUserTierCache(userId);

    console.log(`✅ Verified Subscription (StoreKit2): user=${userId}, tier=${tier}, originalTxn=${originalTransactionId}, transactionId=${transactionId ?? "n/a"}`);

    res.json({
      success: true,
      tier,
      expiresAt: expiresAt?.toISOString()
    });

  } catch (error) {
    console.error("❌ Subscription Verify Error:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

app.post("/subscription/revenuecat/sync", requireAuth, async (req, res) => {
  const userId = req.userId as string;
  try {
    await upsertUser(userId);
    const revenueCat = await syncRevenueCatEntitlement(userId);
    const effective = await getEffectiveSubscription(userId, new Date(), REVENUECAT_ENTITLEMENT_ID);
    res.json({
      success: true,
      tier: effective.tier,
      expiresAt: effective.expiresAt?.toISOString() ?? null,
      activeProductId: effective.source === "revenuecat" ? revenueCat.productId : null
    });
  } catch (error) {
    console.error("RevenueCat subscription sync failed:", error instanceof Error ? error.message : "UnknownError");
    res.status(503).json({ error: "RevenueCat subscription sync unavailable" });
  }
});

app.get("/subscription/status", requireAuth, async (req, res) => {
  const userId = req.userId as string;
  try {
    await upsertUser(userId);
    const [effective, user] = await Promise.all([
      getEffectiveSubscription(userId, new Date(), REVENUECAT_ENTITLEMENT_ID),
      prisma.user.findUnique({
      where: { id: userId },
      select: {
        subscriptionProvider: true,
        googlePlayPurchases: {
          where: { status: "ENTITLED" },
          select: { productId: true },
          orderBy: { expiresAt: "desc" },
          take: 1
        }
      }
      })
    ]);

    res.json({
      success: true,
      tier: effective.tier,
      expiresAt: effective.expiresAt?.toISOString() ?? null,
      activeProductId: effective.source === "revenuecat"
        ? effective.productId
        : effective.tier === "pro" && user?.subscriptionProvider === "google_play"
          ? user.googlePlayPurchases[0]?.productId ?? null
          : null
    });
  } catch (error) {
    console.error("❌ Subscription Status Error:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

// Gemini Endpoint: Supports Multimodal (Audio/Image + Text)
app.post("/ai/gemini", aiJsonParser, requireAuth, async (req, res) => {
  if (!GEMINI_API_KEY) {
    res.status(500).json({ error: "GEMINI_API_KEY is not configured on server" });
    return;
  }

  try {
    const { prompt, systemPrompt, audioBase64, imageBase64, mimeType, imageMimeType, jsonMode, usageType } = req.body;

    if (isCreditFeature(usageType)) {
      const creditState = await consumeCreditsForUser(req.userId as string, usageType);
      if (!creditState.allowed) {
        res.status(402).json({
          error: "Insufficient credits",
          feature: usageType,
          tier: creditState.tier,
          balance: creditState.balance,
          cost: creditState.cost
        });
        return;
      }
    }

    const usesImageOCRModel = Boolean(imageBase64) && !audioBase64;
    const url = buildGeminiGenerateContentURL(GEMINI_MODEL);

    const contentsParts: any[] = [];
    if (audioBase64) {
      contentsParts.push({
        inlineData: { mimeType: mimeType || "audio/wav", data: audioBase64 }
      });
    }
    if (imageBase64) {
      contentsParts.push({
        inlineData: { mimeType: imageMimeType || mimeType || "image/jpeg", data: imageBase64 }
      });
    }
    contentsParts.push({ text: prompt });

    const generationConfig: any = { temperature: usesImageOCRModel ? 0.1 : 0.7 };
    if (jsonMode) generationConfig.responseMimeType = "application/json";

    const body: any = {
      contents: [{ role: "user", parts: contentsParts }],
      generationConfig
    };

    if (systemPrompt) body.systemInstruction = { parts: [{ text: systemPrompt }] };

    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body)
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error("❌ Gemini API Error:", {
        status: response.status,
        statusText: response.statusText,
        model: GEMINI_MODEL,
        hasAudio: Boolean(audioBase64),
        hasImage: Boolean(imageBase64),
        jsonMode: Boolean(jsonMode),
        usageType: typeof usageType === "string" ? usageType : undefined,
        body: errorText.slice(0, 2000)
      });
      res.status(response.status).json({ error: "AI Provider Error" });
      return;
    }

    const data = await response.json() as any;
    const content = data.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    res.json({ content });
  } catch (error) {
    console.error("❌ Gemini Error:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

app.get("/credits/balance", requireAuth, async (req, res) => {
  try {
    const userId = req.userId as string;
    const tier = await resolveUserTier(userId);
    if (tier === "pro") {
      res.json({ balance: null, tier: "pro" });
      return;
    }

    await upsertUser(userId);
    const record = await getOrCreateCredits(userId);
    res.json({ balance: record.balance });
  } catch (error) {
    console.error("❌ Credits Balance Error:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

app.post("/credits/consume", requireAuth, async (req, res) => {
  try {
    const parsed = creditFeatureSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: "Invalid feature" });
      return;
    }

    const userId = req.userId as string;
    const { feature } = parsed.data;
    // Older app versions preflight link imports through this endpoint before
    // creating a job. The job endpoint is now the single place that actually
    // deducts import credits, which prevents old clients from being double charged.
    const result = feature === "import"
      ? await checkCreditsForUser(userId, feature)
      : await consumeCreditsForUser(userId, feature);

    if (!result.allowed) {
      res.status(402).json({
        error: "Insufficient credits",
        balance: result.balance,
        cost: result.cost,
        feature
      });
      return;
    }

    res.json({ balance: result.balance, tier: result.tier });
  } catch (error) {
    console.error("❌ Credits Consume Error:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

app.listen(PORT, () => {
  console.log(`ChillScript backend listening on :${PORT}`);
  scheduleLinkImportWorker();
  scheduleNotificationWorker();
  scheduleWeeklyTopicWorker();
  scheduleGooglePlayBillingWorker(googlePlayBillingDependencies);
});

declare global {
  namespace Express {
    interface Request {
      userId?: string;
      userEmail?: string;
      userCreatedAt?: string;
    }
  }
}
