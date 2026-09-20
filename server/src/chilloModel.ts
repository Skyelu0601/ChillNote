import fetch from "node-fetch";
import { normalizeEmbedding, searchPlanSchema, type SearchPlan } from "./chilloCore.js";

export const CHILLO_EMBED_MODEL = "gemini-embedding-001";
const endpoint = "https://generativelanguage.googleapis.com/v1beta/models/";
const model = () => process.env.CHILLO_MODEL?.trim() || process.env.GEMINI_MODEL?.trim() || "gemini-3.1-flash-lite";

async function call(path: string, body: unknown): Promise<any> {
  const key = process.env.GEMINI_API_KEY?.trim();
  if (!key) throw new Error("MODEL_NOT_CONFIGURED");
  const response = await fetch(endpoint + path, {
    method: "POST", headers: { "Content-Type": "application/json", "x-goog-api-key": key },
    body: JSON.stringify(body), timeout: 60000
  });
  if (!response.ok) throw new Error(response.status === 429 ? "MODEL_BUSY" : "MODEL_ERROR");
  return response.json();
}

export async function generateChillo(system: string, prompt: string): Promise<SearchPlan> {
  const data = await call(`${encodeURIComponent(model())}:generateContent`, {
    systemInstruction: { parts: [{ text: system }] }, contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig: { temperature: 0.4, maxOutputTokens: 12000, responseMimeType: "application/json", responseSchema: {
      type: "OBJECT", required: ["queries", "section", "answer"], properties: {
        queries: { type: "ARRAY", items: { type: "STRING" } }, section: { type: "STRING", enum: ["all", "inbox", "drafts", "published"] },
        after: { type: "STRING", nullable: true }, before: { type: "STRING", nullable: true }, tag: { type: "STRING", nullable: true }, answer: { type: "STRING" }
      }
    } }
  });
  const candidate = data.candidates?.[0];
  if (candidate?.finishReason !== "STOP") throw new Error("INCOMPLETE_RESPONSE");
  const raw = (candidate?.content?.parts ?? []).filter((part: any) => !part.thought).map((part: any) => part.text ?? "").join("");
  return searchPlanSchema.parse(JSON.parse(raw));
}

export async function embedChillo(texts: string[], query = false): Promise<number[][]> {
  if (!texts.length) return [];
  const data = await call(`${CHILLO_EMBED_MODEL}:batchEmbedContents`, { requests: texts.map(text => ({
    model: `models/${CHILLO_EMBED_MODEL}`, content: { parts: [{ text }] },
    taskType: query ? "RETRIEVAL_QUERY" : "RETRIEVAL_DOCUMENT", outputDimensionality: 768
  })) });
  if (!Array.isArray(data.embeddings) || data.embeddings.length !== texts.length) throw new Error("INVALID_EMBEDDING");
  return data.embeddings.map((embedding: any) => {
    if (!Array.isArray(embedding.values) || embedding.values.length !== 768) throw new Error("INVALID_EMBEDDING");
    return normalizeEmbedding(embedding.values);
  });
}
