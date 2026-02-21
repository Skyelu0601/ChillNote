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
import cors from "cors";
import { z } from "zod";
import { applySync } from "./sync.js";
import { getChangesSinceCursor, upsertUser, deleteUser, updateSubscriptionStatus } from "./store.js";
import { prisma } from "./db.js"; // Import prisma for direct queries in index.ts if needed, though best to abstract
import type { SyncPayload } from "./types.js";
import { supabaseAdmin } from "./supabase.js";
import { InviteError, bindInviteCode, getInviteConfig, getInviteMonthlyRewardCount, getOrCreateInviteCode } from "./invite.js";
import fetch from "node-fetch";

const app = express();
app.use(cors());

const defaultJsonParser = express.json({ limit: process.env.DEFAULT_JSON_LIMIT ?? "1mb" });
const defaultFormParser = express.urlencoded({
  limit: process.env.DEFAULT_FORM_LIMIT ?? "1mb",
  extended: true
});
const aiJsonParser = express.json({ limit: process.env.AI_JSON_LIMIT ?? "50mb" });

app.use((req, res, next) => {
  if (req.path.startsWith("/ai/")) {
    next();
    return;
  }
  defaultJsonParser(req, res, next);
});

app.use((req, res, next) => {
  if (req.path.startsWith("/ai/")) {
    next();
    return;
  }
  defaultFormParser(req, res, next);
});

const PORT = Number(process.env.PORT ?? 4000);

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
  lastModifiedByDeviceId: z.string().nullish()
});

const syncSchema = z.object({
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
      lastModifiedByDeviceId: z.string().nullish()
    })
  ).optional(),
  hardDeletedNoteIds: z.array(z.string().min(1)).nullish(),
  hardDeletedTagIds: z.array(z.string().min(1)).nullish(),
  preferences: z.record(z.string(), z.string()).optional()
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
    req.userCreatedAt = user.created_at;
    next();
  } catch (err) {
    console.error("Auth Exception:", err);
    res.status(401).json({ error: "Invalid token" });
  }
}

type RateLimitConfig = {
  windowMs: number;
  max: number;
  key: (req: express.Request) => string;
};

function createRateLimit(config: RateLimitConfig) {
  const buckets = new Map<string, { count: number; resetAt: number }>();
  return (req: express.Request, res: express.Response, next: express.NextFunction) => {
    const now = Date.now();
    const key = config.key(req);
    const current = buckets.get(key);

    if (!current || current.resetAt <= now) {
      buckets.set(key, { count: 1, resetAt: now + config.windowMs });
      next();
      return;
    }

    if (current.count >= config.max) {
      const retryAfter = Math.max(1, Math.ceil((current.resetAt - now) / 1000));
      res.setHeader("Retry-After", String(retryAfter));
      res.status(429).json({ error: "Too many requests" });
      return;
    }

    current.count += 1;
    next();
  };
}

type UserTier = "free" | "pro";
type TierRateLimitConfig = {
  windowMs: number;
  freeMax: number;
  proMax: number;
  key: (req: express.Request) => string;
};

const userTierCache = new Map<string, { tier: UserTier; expiresAt: number }>();
const USER_TIER_CACHE_TTL_MS = Number(process.env.AI_TIER_CACHE_TTL_MS ?? 60 * 1000);

async function resolveUserTier(userId?: string): Promise<UserTier> {
  if (!userId) return "free";

  const now = Date.now();
  const cached = userTierCache.get(userId);
  if (cached && cached.expiresAt > now) {
    return cached.tier;
  }

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { subscriptionTier: true, subscriptionExpiresAt: true }
  });

  let tier: UserTier = "free";
  if (user?.subscriptionTier === "pro") {
    if (!user.subscriptionExpiresAt || user.subscriptionExpiresAt.getTime() > now) {
      tier = "pro";
    } else {
      console.warn(
        `⚠️ Pro subscription expired for user=${userId}, ` +
        `expiresAt=${user.subscriptionExpiresAt.toISOString()}, now=${new Date(now).toISOString()}`
      );
    }
  }

  userTierCache.set(userId, {
    tier,
    expiresAt: now + Math.max(1_000, USER_TIER_CACHE_TTL_MS)
  });
  return tier;
}

function invalidateUserTierCache(userId: string): void {
  userTierCache.delete(userId);
}

function createTierRateLimit(config: TierRateLimitConfig) {
  const buckets = new Map<string, { count: number; resetAt: number }>();

  return async (req: express.Request, res: express.Response, next: express.NextFunction) => {
    try {
      const tier = await resolveUserTier(req.userId);
      const max = tier === "pro" ? config.proMax : config.freeMax;
      const now = Date.now();
      const key = `${config.key(req)}:${tier}`;
      const current = buckets.get(key);

      if (!current || current.resetAt <= now) {
        buckets.set(key, { count: 1, resetAt: now + config.windowMs });
        next();
        return;
      }

      if (current.count >= max) {
        const retryAfter = Math.max(1, Math.ceil((current.resetAt - now) / 1000));
        res.setHeader("Retry-After", String(retryAfter));
        res.status(429).json({ error: "Too many requests" });
        return;
      }

      current.count += 1;
      next();
    } catch (error) {
      console.error("Rate limit tier resolution failed:", error);
      res.status(500).json({ error: "Internal Server Error" });
    }
  };
}

const voiceNoteRateLimit = createTierRateLimit({
  windowMs: Number(process.env.AI_VOICE_RATE_LIMIT_WINDOW_MS ?? 10 * 60 * 1000),
  freeMax: Number(process.env.AI_VOICE_RATE_LIMIT_FREE_MAX ?? 6),
  proMax: Number(process.env.AI_VOICE_RATE_LIMIT_PRO_MAX ?? process.env.AI_VOICE_RATE_LIMIT_MAX ?? 120),
  key: (req) => `${req.userId ?? "anon"}:voice-note`
});

const geminiRateLimit = createTierRateLimit({
  windowMs: Number(process.env.AI_GEMINI_RATE_LIMIT_WINDOW_MS ?? 10 * 60 * 1000),
  freeMax: Number(process.env.AI_GEMINI_RATE_LIMIT_FREE_MAX ?? 20),
  proMax: Number(process.env.AI_GEMINI_RATE_LIMIT_PRO_MAX ?? process.env.AI_GEMINI_RATE_LIMIT_MAX ?? 600),
  key: (req) => `${req.userId ?? "anon"}:gemini`
});

type DailyQuotaFeature = "voice" | "tidy" | "agent_recipe" | "chat";
type DailyQuotaState = {
  feature: DailyQuotaFeature;
  tier: UserTier;
  allowed: boolean;
  used: number;
  remaining: number | null;
  limit: number | null;
};

const dailyQuotaFeatures = new Set<DailyQuotaFeature>(["voice", "tidy", "agent_recipe", "chat"]);
const freeDailyLimits: Record<DailyQuotaFeature, number> = {
  voice: Number(process.env.DAILY_VOICE_LIMIT_FREE ?? 5),
  tidy: Number(process.env.DAILY_TIDY_LIMIT_FREE ?? 5),
  agent_recipe: Number(process.env.DAILY_AGENT_RECIPE_LIMIT_FREE ?? 3),
  chat: Number(process.env.DAILY_CHAT_LIMIT_FREE ?? 10)
};

const quotaRequestSchema = z.object({
  feature: z.enum(["voice", "tidy", "agent_recipe", "chat"]),
  action: z.enum(["check", "consume"]).default("check")
});

const bindInviteSchema = z.object({
  code: z.string().trim().min(4).max(32)
});

function currentUtcDateKey(): string {
  return new Date().toISOString().slice(0, 10);
}

function dailyQuotaErrorMessage(feature: DailyQuotaFeature): string {
  switch (feature) {
    case "voice":
      return "Daily free voice limit reached";
    case "tidy":
      return "Daily free tidy limit reached";
    case "agent_recipe":
      return "Daily free agent recipe limit reached";
    case "chat":
      return "Daily free AI chat limit reached";
  }
}

async function ensureDailyUsageRow(userId: string, feature: DailyQuotaFeature, dateKey: string): Promise<void> {
  await prisma.$executeRaw`
    INSERT INTO "DailyUsage" ("userId", "dateKey", "feature", "count", "createdAt", "updatedAt")
    VALUES (${userId}, ${dateKey}, ${feature}, 0, NOW(), NOW())
    ON CONFLICT ("userId", "dateKey", "feature") DO NOTHING
  `;
}

async function readDailyUsageCount(userId: string, feature: DailyQuotaFeature, dateKey: string): Promise<number> {
  const rows = await prisma.$queryRaw<Array<{ count: number }>>`
    SELECT "count"
    FROM "DailyUsage"
    WHERE "userId" = ${userId} AND "dateKey" = ${dateKey} AND "feature" = ${feature}
    LIMIT 1
  `;
  return Number(rows[0]?.count ?? 0);
}

async function getDailyQuotaState(userId: string, feature: DailyQuotaFeature): Promise<DailyQuotaState> {
  await upsertUser(userId);
  const tier = await resolveUserTier(userId);

  if (tier === "pro") {
    return {
      feature,
      tier,
      allowed: true,
      used: 0,
      remaining: null,
      limit: null
    };
  }

  const dateKey = currentUtcDateKey();
  await ensureDailyUsageRow(userId, feature, dateKey);
  const used = await readDailyUsageCount(userId, feature, dateKey);
  const limit = Math.max(0, freeDailyLimits[feature]);
  const remaining = Math.max(0, limit - used);

  return {
    feature,
    tier,
    allowed: used < limit,
    used,
    remaining,
    limit
  };
}

async function consumeDailyQuota(userId: string, feature: DailyQuotaFeature): Promise<DailyQuotaState> {
  await upsertUser(userId);
  const tier = await resolveUserTier(userId);

  if (tier === "pro") {
    return {
      feature,
      tier,
      allowed: true,
      used: 0,
      remaining: null,
      limit: null
    };
  }

  const limit = Math.max(0, freeDailyLimits[feature]);
  const dateKey = currentUtcDateKey();

  return await prisma.$transaction(async (tx) => {
    await tx.$executeRaw`
      INSERT INTO "DailyUsage" ("userId", "dateKey", "feature", "count", "createdAt", "updatedAt")
      VALUES (${userId}, ${dateKey}, ${feature}, 0, NOW(), NOW())
      ON CONFLICT ("userId", "dateKey", "feature") DO NOTHING
    `;

    const rows = await tx.$queryRaw<Array<{ count: number }>>`
      SELECT "count"
      FROM "DailyUsage"
      WHERE "userId" = ${userId} AND "dateKey" = ${dateKey} AND "feature" = ${feature}
      LIMIT 1
    `;

    const used = Number(rows[0]?.count ?? 0);
    if (used >= limit) {
      return {
        feature,
        tier,
        allowed: false,
        used,
        remaining: 0,
        limit
      };
    }

    await tx.$executeRaw`
      UPDATE "DailyUsage"
      SET "count" = "count" + 1, "updatedAt" = NOW()
      WHERE "userId" = ${userId} AND "dateKey" = ${dateKey} AND "feature" = ${feature}
    `;

    const nextUsed = used + 1;
    return {
      feature,
      tier,
      allowed: true,
      used: nextUsed,
      remaining: Math.max(0, limit - nextUsed),
      limit
    };
  });
}

app.get("/health", (_req, res) => {
  res.json({ ok: true });
});

app.get("/version", (_req, res) => {
  res.json({ version: "1.0.2", updated: new Date().toISOString() });
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

// Delete Account: Deletes from both public DB and Supabase Auth
app.delete("/auth/account", requireAuth, async (req, res) => {
  const userId = req.userId;
  if (!userId) {
    res.status(401).json({ error: "Unauthorized" });
    return;
  }
  try {
    // 1. Delete user data provided by the user from public schema (Prisma)
    await deleteUser(userId);

    // 2. Delete user from Supabase Auth (requires service role)
    const { error } = await supabaseAdmin.auth.admin.deleteUser(userId);
    if (error) {
      console.error(`❌ [Backend] Failed to delete Supabase Auth user ${userId}:`, error);
      // We continue even if auth deletion fails, as data is gone. 
      // But practically we might want to alert/retry.
    } else {
      console.log(`🗑️ [Backend] Deleted user account: ${userId}`);
    }

    res.json({ success: true });
  } catch (error) {
    console.error(`❌ [Backend] Failed to delete user ${userId}:`, error);
    res.status(500).json({ error: "Failed to delete account" });
  }
});

app.post("/sync", requireAuth, async (req, res) => {
  const parsed = syncSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid payload" });
    return;
  }

  const userId = req.userId as string;
  const cursor = typeof parsed.data.cursor === "string" ? parsed.data.cursor : undefined;

  // Ensure user exists in our local DB table
  await upsertUser(userId);

  const incoming = parsed.data as SyncPayload;
  const {
    conflicts,
    forcedHardDeletedNoteIds,
    forcedHardDeletedTagIds
  } = await applySync(incoming, userId);
  const { changes, cursor: newCursor } = await getChangesSinceCursor(userId, cursor);
  const mergedHardDeletedNoteIds = Array.from(new Set([
    ...(changes.hardDeletedNoteIds ?? []),
    ...forcedHardDeletedNoteIds
  ]));
  const mergedHardDeletedTagIds = Array.from(new Set([
    ...(changes.hardDeletedTagIds ?? []),
    ...forcedHardDeletedTagIds
  ]));
  res.json({
    cursor: newCursor,
    changes: {
      ...changes,
      hardDeletedNoteIds: mergedHardDeletedNoteIds,
      hardDeletedTagIds: mergedHardDeletedTagIds
    },
    conflicts,
    serverTime: new Date().toISOString()
  });
});

app.post("/quota/daily", requireAuth, async (req, res) => {
  const parsed = quotaRequestSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid payload" });
    return;
  }

  const userId = req.userId as string;
  const { feature, action } = parsed.data;

  try {
    const state = action === "consume"
      ? await consumeDailyQuota(userId, feature)
      : await getDailyQuotaState(userId, feature);

    if (!state.allowed) {
      res.status(429).json({
        error: dailyQuotaErrorMessage(feature),
        feature,
        tier: state.tier,
        remaining: state.remaining,
        limit: state.limit
      });
      return;
    }

    res.json({
      success: true,
      feature,
      tier: state.tier,
      allowed: state.allowed,
      remaining: state.remaining,
      limit: state.limit
    });
  } catch (error) {
    console.error("❌ Daily Quota Error:", error);
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
app.post("/ai/voice-note", aiJsonParser, requireAuth, voiceNoteRateLimit, async (req, res) => {
  const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
  if (!GEMINI_API_KEY) {
    console.error("❌ GEMINI_API_KEY is not configured");
    res.status(500).json({ error: "AI Service key is not configured on server" });
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
      const quotaState = await consumeDailyQuota(req.userId as string, "voice");
      if (!quotaState.allowed) {
        console.warn(
          `🚫 VoiceNote Quota Denied: user=${req.userId}, tier=${quotaState.tier}, ` +
          `used=${quotaState.used}, limit=${quotaState.limit}, remaining=${quotaState.remaining}`
        );
        res.status(429).json({
          error: dailyQuotaErrorMessage("voice"),
          feature: "voice",
          tier: quotaState.tier,
          remaining: quotaState.remaining,
          limit: quotaState.limit
        });
        return;
      }
    }

    const audioDecodedBytes = Buffer.byteLength(audioBase64, "base64");
    const audioDecodedMb = audioDecodedBytes / 1024 / 1024;

    const maxAudioMb = Number(process.env.MAX_VOICE_NOTE_AUDIO_MB ?? 30);
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

    const model = "gemini-2.5-flash-lite";
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_API_KEY}`;

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
      await updateSubscriptionStatus(userId, tier, expiresAt, originalTransactionId);
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
    await updateSubscriptionStatus(userId, tier, expiresAt, originalTransactionId);
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

app.get("/subscription/status", requireAuth, async (req, res) => {
  const userId = req.userId as string;
  try {
    await upsertUser(userId);
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { subscriptionTier: true, subscriptionExpiresAt: true }
    });

    const now = Date.now();
    const expiresAt = user?.subscriptionExpiresAt ?? null;
    const isPro =
      user?.subscriptionTier === "pro" &&
      (!expiresAt || expiresAt.getTime() > now);
    const tier: UserTier = isPro ? "pro" : "free";

    res.json({
      success: true,
      tier,
      expiresAt: expiresAt?.toISOString() ?? null
    });
  } catch (error) {
    console.error("❌ Subscription Status Error:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

// Gemini Endpoint: Supports Multimodal (Audio + Text)
app.post("/ai/gemini", aiJsonParser, requireAuth, geminiRateLimit, async (req, res) => {
  const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
  if (!GEMINI_API_KEY) {
    res.status(500).json({ error: "AI Service key is not configured" });
    return;
  }

  try {
    const { prompt, systemPrompt, audioBase64, mimeType, jsonMode, usageType } = req.body;

    if (typeof usageType === "string" && dailyQuotaFeatures.has(usageType as DailyQuotaFeature)) {
      const feature = usageType as DailyQuotaFeature;
      const quotaState = await consumeDailyQuota(req.userId as string, feature);
      if (!quotaState.allowed) {
        res.status(429).json({
          error: dailyQuotaErrorMessage(feature),
          feature,
          tier: quotaState.tier,
          remaining: quotaState.remaining,
          limit: quotaState.limit
        });
        return;
      }
    }

    const model = "gemini-2.5-flash-lite";
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_API_KEY}`;

    const contentsParts: any[] = [];
    if (audioBase64) {
      contentsParts.push({
        inlineData: { mimeType: mimeType || "audio/wav", data: audioBase64 }
      });
    }
    contentsParts.push({ text: prompt });

    const generationConfig: any = { temperature: 0.7 };
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

app.listen(PORT, () => {
  console.log(`ChillNote backend listening on :${PORT}`);
});

declare global {
  namespace Express {
    interface Request {
      userId?: string;
      userCreatedAt?: string;
    }
  }
}
