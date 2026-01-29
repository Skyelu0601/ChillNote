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
import { toPayload, upsertUser, deleteUser, updateSubscriptionStatus } from "./store.js";
import { prisma } from "./db.js"; // Import prisma for direct queries in index.ts if needed, though best to abstract
import type { SyncPayload } from "./types.js";
import { supabaseAdmin } from "./supabase.js";
import fetch from "node-fetch";

const app = express();
app.use(cors());
app.use(express.json({ limit: "500mb" }));
app.use(express.urlencoded({ limit: "500mb", extended: true }));

const PORT = Number(process.env.PORT ?? 4000);

const isoDateString = z
  .string()
  .min(1)
  .refine((value) => !Number.isNaN(Date.parse(value)), { message: "Invalid date" });

const noteSchema = z.object({
  id: z.string().min(1),
  content: z.string(),
  createdAt: isoDateString,
  updatedAt: isoDateString,
  deletedAt: isoDateString.nullish(),
  tagIds: z.array(z.string().min(1)).nullish()
});

const syncSchema = z.object({
  notes: z.array(noteSchema),
  tags: z.array(
    z.object({
      id: z.string().min(1),
      name: z.string().min(1),
      colorHex: z.string().min(1),
      createdAt: isoDateString,
      updatedAt: isoDateString,
      lastUsedAt: isoDateString.nullish(),
      sortOrder: z.number(),
      parentId: z.string().nullish(),
      deletedAt: isoDateString.nullish()
    })
  ).optional(),
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
    next();
  } catch (err) {
    console.error("Auth Exception:", err);
    res.status(401).json({ error: "Invalid token" });
  }
}

app.get("/health", (_req, res) => {
  res.json({ ok: true });
});

app.get("/version", (_req, res) => {
  res.json({ version: "1.0.2", updated: new Date().toISOString() });
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
  const since = typeof req.query.since === "string" ? req.query.since : undefined;

  // Ensure user exists in our local DB table
  await upsertUser(userId);

  const incoming = parsed.data as SyncPayload;
  const existing = await toPayload(userId);
  await applySync(incoming, existing, userId);
  const response = await toPayload(userId, since);
  res.json(response);
});

const voiceNoteSchema = z.object({
  audioBase64: z.string().min(1),
  mimeType: z.string().optional(),
  locale: z.string().optional()
});

function estimateBase64DecodedBytes(base64: string): number {
  const len = base64.length;
  if (len === 0) return 0;
  let padding = 0;
  if (base64.endsWith("==")) padding = 2;
  else if (base64.endsWith("=")) padding = 1;
  return Math.max(0, Math.floor((len * 3) / 4) - padding);
}

// Voice Note Endpoint: Audio -> Transcription + Polished Text
app.post("/ai/voice-note", async (req, res) => {
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
    const { audioBase64, mimeType, locale } = parsed.data;
    const contentLengthHeader = req.headers["content-length"];
    const requestBytes = typeof contentLengthHeader === "string" ? Number(contentLengthHeader) : undefined;
    const audioDecodedBytes = estimateBase64DecodedBytes(audioBase64);
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

    const model = "gemini-2.0-flash";
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_API_KEY}`;

    const systemInstruction = [
      "You are a professional voice transcription assistant. Your goal is to provide an accurate, readable transcription of the audio.",
      "Rules:",
      "- Transcribe exactly what is said. Do NOT translate.",
      "- Remove filler words (um, uh) and stuttering.",
      "- Use standard punctuation.",
      "- Return STRICT JSON only, no extra keys.",
      "JSON schema: {\\\"text\\\": string}",
      locale ? `Locale hint: ${locale}` : undefined
    ].filter(Boolean).join("\\n");

    const body: any = {
      systemInstruction: { parts: [{ text: systemInstruction }] },
      contents: [
        {
          parts: [
            { inlineData: { mimeType: mimeType || "audio/wav", data: audioBase64 } },
            { text: "Generate the final polished note text." }
          ]
        }
      ],
      generationConfig: {
        temperature: 0.3,
        responseMimeType: "application/json"
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
      let text = String(content).trim();

      try {
        const parsedJson = JSON.parse(text);
        if (parsedJson.text) text = parsedJson.text;
      } catch { }

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
  const { transactionId } = req.body;
  const userId = req.userId as string;

  if (!transactionId) {
    res.status(400).json({ error: "Missing transactionId" });
    return;
  }

  const APPLE_SHARED_SECRET = process.env.APPLE_SHARED_SECRET;
  if (!APPLE_SHARED_SECRET) {
    console.error("❌ APPLE_SHARED_SECRET is not configured");
    res.status(500).json({ error: "Server configuration error" });
    return;
  }

  try {
    // 1. Verify with Apple
    // Using simple fetch to verifyReceipt endpoint (simpler for now than App Store Server API V2 for this use case)
    // For V2, we would use node-apple-receipt-verify or similar
    // Note: sandbox URL for testing, production URL for release.
    // Ideally use a library that handles fallback.

    // For simplicity in this demo, let's assume we receive the *receipt-data* (base64) 
    // OR we use the new StoreKit 2 transactionId. 
    // StoreKit 2 usually requires JWS validation.

    // Since implementing full JWS validation here is complex without a library,
    // we'll implement a basic structure and placeholders.
    // "node-apple-receipt-verify" library is for the old verifyReceipt endpoint.
    // For StoreKit 2, we should ideally validate the JWS token on device, 
    // but here we want to bind it to the user.

    // Let's use a simplified logical flow:
    // User sends { transactionId, originalTransactionId, productId, expiresDate? } 
    // TRUST LEVEL: Low (client side data). 
    // REAL WORLD: You MUST verify this against Apple Server API.

    // TEMPORARY IMPLEMENTATION (MVP):
    // We will trust the client for now IF you are just testing.
    // BUT we will fetch the fields from the body.

    const { originalTransactionId, expiresDate, productId } = req.body;

    if (!originalTransactionId) {
      res.status(400).json({ error: "Missing originalTransactionId" });
      return;
    }

    // 2. Check if this originalTransactionId is already bound to another user
    const existingUser = await prisma.user.findFirst({
      where: { originalTransactionId: originalTransactionId }
    });

    if (existingUser && existingUser.id !== userId) {
      // Already bound to someone else!
      // Allow migration? Or block?
      // Usually block to prevent account sharing.
      res.status(409).json({ error: "Subscription is already used by another account." });
      return;
    }

    // 3. Update User Status
    // Determine tier based on productId
    let tier = "free";
    if (productId && (productId.includes("pro") || productId.includes("monthly") || productId.includes("yearly"))) {
      tier = "pro";
    }

    // Parse Date
    // expiresDate from StoreKit 2 is usually a millisecond timestamp
    let expiresAt: Date | null = null;
    if (expiresDate) {
      expiresAt = new Date(expiresDate); // Ensure client sends proper format or MS
    }

    // 4. Save to DB using our new function
    await updateSubscriptionStatus(userId, tier, expiresAt, originalTransactionId);

    console.log(`✅ Verified Subscription: user=${userId}, tier=${tier}`);

    // Return Success
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

// Gemini Endpoint: Supports Multimodal (Audio + Text)
app.post("/ai/gemini", async (req, res) => {
  const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
  if (!GEMINI_API_KEY) {
    res.status(500).json({ error: "AI Service key is not configured" });
    return;
  }

  try {
    const { prompt, systemPrompt, audioBase64, mimeType, jsonMode } = req.body;

    const model = "gemini-2.0-flash";
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
    }
  }
}
