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

const appleAuthSchema = z.object({
  userId: z.string().min(1),
  identityToken: z.string().min(1),
  authorizationCode: z.string().min(1)
});

const syncSchema = z.object({
  notes: z.array(z.any())
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

  try {
    const tokenPayload = await verifyAppleIdentityToken(payload.identityToken, APPLE_CLIENT_ID);
    if (tokenPayload.sub !== payload.userId) {
      res.status(401).json({ error: "User mismatch" });
      return;
    }

    await upsertUser(payload.userId);
  } catch (error) {
    res.status(401).json({ error: "Invalid Apple token" });
    return;
  }

  const tokens = signTokens(payload.userId);
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
    const audioKb = Math.round(audioBase64.length / 1024);
    console.log(`🗣️ VoiceNote Request: audioSize=${audioKb}KB, mimeType=${mimeType ?? "unknown"}, locale=${locale ?? "unknown"}`);

    // Gemini 2.0 Flash URL - Using experimental model which is currently reliable for 2.0 Flash features
    const model = "gemini-2.0-flash-exp";
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_API_KEY}`;

    const systemInstruction = [
      "You are a professional voice transcription assistant. Produce clean, polished transcriptions that preserve the speaker's original meaning, tone, and intent.",
      "",
      "Capabilities:",
      "1) Removes filler: Automatically remove filler words and disfluencies while keeping all real content intact.",
      "2) Removes repetition: Detect and remove unnecessary repetitions, including short-range repeats within the same clause or sentence, while preserving intentional emphasis.",
      "3) Auto-edits corrections: When the speaker changes their mind mid-sentence, keep only the final intended message.",
      "4) Auto-formats: If the speaker uses ordinal or step markers, normalize the content into an ordered list format. Otherwise keep plain paragraphs.",
      "5) Finds the right words: Lightly improve word choice for clarity without changing sentence structure or meaning. Keep changes minimal.",
      "",
      "Rules:",
      "- Do NOT translate; keep the original language spoken.",
      "- Do NOT summarize or invent content.",
      "- When in doubt, keep the original wording.",
      "- Return STRICT JSON only, no markdown, no extra keys.",
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
        const error = await response.json();
        console.error("❌ Gemini API Error:", JSON.stringify(error));
        res.status(response.status).json(error);
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

      res.json({ text: String(text).trim() });
    } catch (fetchError: any) {
      if (fetchError.name === "AbortError") {
        console.error("❌ Gemini API Timeout (60s)");
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
        const error = await response.json();
        console.error("❌ Gemini API Error:", JSON.stringify(error));
        res.status(response.status).json(error);
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
