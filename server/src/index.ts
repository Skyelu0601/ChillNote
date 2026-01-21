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
import jwt from "jsonwebtoken";
import { z } from "zod";
import { applySync } from "./sync.js";
import { toPayload, upsertUser } from "./store.js";
import type { AuthAppleRequest, AuthTokens, SyncPayload } from "./types.js";
import { verifyAppleIdentityToken } from "./apple.js";
import fetch from "node-fetch";

const app = express();
app.use(cors());
app.use(express.json({ limit: "500mb" }));
app.use(express.urlencoded({ limit: "500mb", extended: true }));

const PORT = Number(process.env.PORT ?? 4000);
const JWT_SECRET = process.env.JWT_SECRET ?? "dev-secret";
const APPLE_CLIENT_ID = process.env.APPLE_CLIENT_ID ?? "";

const isoDateString = z
  .string()
  .min(1)
  .refine((value) => !Number.isNaN(Date.parse(value)), { message: "Invalid date" });

const appleAuthSchema = z.object({
  userId: z.string().min(1),
  identityToken: z.string().min(1),
  authorizationCode: z.string().min(1)
});

const noteSchema = z.object({
  id: z.string().min(1),
  content: z.string(),
  createdAt: isoDateString,
  updatedAt: isoDateString,
  deletedAt: isoDateString.nullish()
});

const syncSchema = z.object({
  notes: z.array(noteSchema)
});

function signTokens(userId: string): AuthTokens {
  const accessToken = jwt.sign({ sub: userId }, JWT_SECRET, { expiresIn: "2h" });
  const refreshToken = jwt.sign({ sub: userId, type: "refresh" }, JWT_SECRET, { expiresIn: "30d" });
  return { userId, accessToken, refreshToken };
}

function requireAuth(req: express.Request, res: express.Response, next: express.NextFunction) {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    res.status(401).json({ error: "Missing token" });
    return;
  }
  try {
    const token = header.replace("Bearer ", "");
    const payload = jwt.verify(token, JWT_SECRET) as { sub: string };
    req.userId = payload.sub;
    next();
  } catch {
    res.status(401).json({ error: "Invalid token" });
  }
}

app.get("/health", (_req, res) => {
  res.json({ ok: true });
});

app.post("/auth/apple", async (req, res) => {
  const parsed = appleAuthSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Invalid payload" });
    return;
  }

  const payload: AuthAppleRequest = parsed.data;
  if (!payload.userId) {
    res.status(400).json({ error: "Missing userId" });
    return;
  }
  if (!APPLE_CLIENT_ID) {
    res.status(500).json({ error: "APPLE_CLIENT_ID is not configured" });
    return;
  }

  console.log("🍎 [Backend] Apple Sign In Request:");
  console.log("   User ID:", payload.userId);
  console.log("   Client ID (expected audience):", APPLE_CLIENT_ID);
  console.log("   Identity Token (first 50 chars):", payload.identityToken.substring(0, 50) + "...");

  try {
    const tokenPayload = await verifyAppleIdentityToken(payload.identityToken, APPLE_CLIENT_ID);
    console.log("✅ [Backend] Token verified successfully:");
    console.log("   Token subject (sub):", tokenPayload.sub);
    console.log("   Token issuer (iss):", tokenPayload.iss);
    console.log("   Token audience (aud):", tokenPayload.aud);
    console.log("   Token email:", tokenPayload.email || "not provided");

    if (tokenPayload.sub !== payload.userId) {
      console.log("❌ [Backend] User ID mismatch!");
      console.log("   Expected:", payload.userId);
      console.log("   Got:", tokenPayload.sub);
      res.status(401).json({ error: "User mismatch" });
      return;
    }

    await upsertUser(payload.userId);
  } catch (error) {
    console.error("❌ [Backend] Token verification failed:");
    console.error("   Error:", error);
    if (error instanceof Error) {
      console.error("   Message:", error.message);
      console.error("   Stack:", error.stack);
    }
    res.status(401).json({ error: "Invalid Apple token" });
    return;
  }

  const tokens = signTokens(payload.userId);
  console.log("✅ [Backend] Sign in successful, tokens generated");
  res.json(tokens);
});

app.post("/auth/refresh", async (req, res) => {
  const token = req.body?.refreshToken as string | undefined;
  if (!token) {
    res.status(400).json({ error: "Missing refreshToken" });
    return;
  }
  try {
    const payload = jwt.verify(token, JWT_SECRET) as { sub: string; type?: string };
    if (payload.type !== "refresh") {
      res.status(401).json({ error: "Invalid refresh token" });
      return;
    }
    await upsertUser(payload.sub);
    res.json(signTokens(payload.sub));
  } catch {
    res.status(401).json({ error: "Invalid refresh token" });
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
    res.status(500).json({ error: "GEMINI_API_KEY is not configured on server" });
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
        `🗣️ VoiceNote Rejected: audioDecoded=${audioDecodedMb.toFixed(2)}MB > max=${maxAudioMb}MB (content-length=${requestBytes ?? "unknown"})`
      );
      res.status(413).json({
        error: "Voice note too large",
        details: {
          maxAudioMb,
          audioDecodedMb: Number(audioDecodedMb.toFixed(2)),
          hint: "Reduce recording length/quality, or increase proxy/body limits (e.g. Nginx client_max_body_size 50m) and MAX_VOICE_NOTE_AUDIO_MB (e.g. 50)."
        }
      });
      return;
    }

    const audioBase64Kb = Math.round(audioBase64.length / 1024);
    const audioDecodedKb = Math.round(audioDecodedBytes / 1024);
    console.log(
      `🗣️ VoiceNote Request: requestSize=${requestBytes ? Math.round(requestBytes / 1024) : "unknown"}KB, audioBase64=${audioBase64Kb}KB, audioDecoded=${audioDecodedKb}KB, mimeType=${mimeType ?? "unknown"}, locale=${locale ?? "unknown"}`
    );

    // Gemini 2.0 Flash URL - Using experimental model which is currently reliable for 2.0 Flash features
    const model = "gemini-2.0-flash-exp";
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_API_KEY}`;

    const systemInstruction = [
      "You are a professional voice transcription assistant. Your goal is to provide an accurate, readable transcription of the audio.",
      "",
      "Rules:",
      "- Transcribe exactly what is said in the original language. Do NOT translate.",
      "- Remove filler words (um, uh, you know, 那个, 就是) and stuttering to make the text readable.",
      "- If the speaker corrects themselves (false starts), keep only the final intended phrase.",
      "- Use standard punctuation (periods, commas, question marks).",
      "- Do NOT apply special formatting (no bullet points, no markdown headers). Return a single block of plain text.",
      "- Do NOT attempt to interpret the intent (e.g. do not format as an email even if the user says 'write an email'). Just transcribe the words.",
      "- Return STRICT JSON only, no extra keys.",
      "JSON schema: {\\\"text\\\": string}",
      locale ? `Locale hint: ${locale}` : undefined
    ].filter(Boolean).join("\\n");

    const body: any = {
      systemInstruction: { parts: [{ text: systemInstruction }] },
      contents: [
        {
          parts: [
            {
              inlineData: {
                mimeType: mimeType || "audio/wav",
                data: audioBase64
              }
            },
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
        let errorPayload: any = { error: "Gemini API error", status: response.status };
        try {
          errorPayload = JSON.parse(errorText);
        } catch {
          errorPayload.body = errorText.slice(0, 2000);
        }
        console.error("❌ Gemini API Error:", JSON.stringify(errorPayload));
        res.status(response.status).json(errorPayload);
        return;
      }

      const data = await response.json() as any;
      const content = data.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
      const trimmed = String(content).trim();

      let text = trimmed;
      if (trimmed.startsWith("{")) {
        try {
          const parsedJson = JSON.parse(trimmed) as { text?: unknown };
          if (typeof parsedJson.text === "string") {
            text = parsedJson.text;
          }
        } catch {
          // Fall back to raw text if JSON parsing fails.
        }
      }

      console.log(`✅ VoiceNote Success: responseLength=${String(text).trim().length}`);
      res.json({ text: String(text).trim() });
    } catch (fetchError: any) {
      if (fetchError.name === "AbortError") {
        console.error(`❌ Gemini API Timeout (${timeoutMs}ms)`);
        res.status(504).json({ error: "Gemini API Timeout" });
      } else {
        throw fetchError;
      }
    }
  } catch (error) {
    console.error("❌ VoiceNote Proxy Error:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

// Gemini Endpoint: Supports Multimodal (Audio + Text)
app.post("/ai/gemini", async (req, res) => {
  const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
  if (!GEMINI_API_KEY) {
    console.error("❌ GEMINI_API_KEY is not configured");
    res.status(500).json({ error: "GEMINI_API_KEY is not configured on server" });
    return;
  }

  try {
    const { prompt, systemPrompt, audioBase64, mimeType, jsonMode } = req.body;

    console.log(`🤖 Gemini Request: prompt="${prompt?.substring(0, 50)}...", hasAudio=${!!audioBase64}, audioSize=${audioBase64 ? Math.round(audioBase64.length / 1024) : 0}KB`);

    // Gemini 2.0 Flash URL - Using experimental model which is currently reliable for 2.0 Flash features
    const model = "gemini-2.0-flash-exp";
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_API_KEY}`;

    const contentsParts: any[] = [];
    if (audioBase64) {
      contentsParts.push({
        inlineData: {
          mimeType: mimeType || "audio/wav",
          data: audioBase64
        }
      });
    }
    contentsParts.push({ text: prompt });

    const generationConfig: any = {
      temperature: 0.7
    };
    if (jsonMode) {
      generationConfig.responseMimeType = "application/json";
    }

    const body: any = {
      contents: [{ role: "user", parts: contentsParts }],
      generationConfig
    };

    if (systemPrompt) {
      body.systemInstruction = { parts: [{ text: systemPrompt }] };
    }

    const abortController = new AbortController();
    const timeoutId = setTimeout(() => abortController.abort(), 60000); // 60s timeout

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
        let errorPayload: any = { error: "Gemini API error", status: response.status };
        try {
          errorPayload = JSON.parse(errorText);
        } catch {
          errorPayload.body = errorText.slice(0, 2000);
        }
        console.error("❌ Gemini API Error:", JSON.stringify(errorPayload));
        res.status(response.status).json(errorPayload);
        return;
      }

      const data = await response.json() as any;
      const content = data.candidates?.[0]?.content?.parts?.[0]?.text ?? "";

      console.log(`✅ Gemini Success: responseLength=${content.length}`);
      res.json({ content: content });

    } catch (fetchError: any) {
      if (fetchError.name === 'AbortError') {
        console.error("❌ Gemini API Timeout (60s)");
        res.status(504).json({ error: "Gemini API Timeout" });
      } else {
        throw fetchError;
      }
    }

  } catch (error) {
    console.error("❌ Gemini Proxy Error:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

app.listen(PORT, () => {
  console.log(`ChillNote backend listening on :${PORT}`);
  console.log(`- Local (IPv4): http://127.0.0.1:${PORT}`);
  console.log(`- Local (IPv6): http://[::1]:${PORT}`);
  console.log(`- Network:      http://192.168.1.6:${PORT}`);
});


declare global {
  namespace Express {
    interface Request {
      userId?: string;
    }
  }
}
