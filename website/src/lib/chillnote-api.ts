import { webConfig } from "./config";
import { getOrCreateDeviceId, newClientId } from "./chillnote-model";

export type NoteDTO = {
  id: string;
  content: string;
  createdAt: string;
  updatedAt?: string | null;
  deletedAt?: string | null;
  pinnedAt?: string | null;
  tagIds?: string[] | null;
  version?: number | null;
  baseVersion?: number | null;
  clientUpdatedAt?: string | null;
  lastModifiedByDeviceId?: string | null;
  sourceURL?: string | null;
  sourceTitle?: string | null;
  sourcePlatformID?: string | null;
  sourcePlatformName?: string | null;
  sourceHost?: string | null;
  sourceCapturedAt?: string | null;
  section?: "inbox" | "drafts" | "published" | string | null;
};

export type TagDTO = {
  id: string;
  name: string;
  colorHex: string;
  createdAt: string;
  updatedAt?: string | null;
  lastUsedAt?: string | null;
  sortOrder: number;
  parentId?: string | null;
  deletedAt?: string | null;
  version?: number | null;
  baseVersion?: number | null;
  clientUpdatedAt?: string | null;
  lastModifiedByDeviceId?: string | null;
};

type SyncResponse = {
  cursor: string;
  changes: {
    notes: NoteDTO[];
    tags?: TagDTO[] | null;
    hardDeletedNoteIds?: string[] | null;
    hardDeletedTagIds?: string[] | null;
  };
  serverTime: string;
};

export type SubscriptionStatus = {
  success: boolean;
  tier: "free" | "pro";
  expiresAt: string | null;
};

export type DailyQuotaFeature = "voice" | "agent_recipe" | "chat";

export type DailyQuotaState = {
  success: boolean;
  feature: DailyQuotaFeature;
  tier: "free" | "pro";
  allowed: boolean;
  remaining: number | null;
  limit: number | null;
};

function authHeaders(token: string) {
  return {
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json",
  };
}

async function parseResponse<T>(response: Response): Promise<T> {
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message =
      typeof body?.error === "string" ? body.error : `Request failed with ${response.status}`;
    throw new Error(message);
  }
  return body as T;
}

export async function syncNotes(token: string, payload: {
  cursor?: string | null;
  deviceId?: string | null;
  notes?: NoteDTO[];
  tags?: TagDTO[];
  hardDeletedNoteIds?: string[];
  hardDeletedTagIds?: string[];
}) {
  const response = await fetch(`${webConfig.apiBaseUrl}/sync`, {
    method: "POST",
    headers: authHeaders(token),
    body: JSON.stringify({
      cursor: payload.cursor ?? null,
      deviceId: payload.deviceId ?? getOrCreateDeviceId(),
      notes: payload.notes ?? [],
      tags: payload.tags ?? [],
      hardDeletedNoteIds: payload.hardDeletedNoteIds ?? null,
      hardDeletedTagIds: payload.hardDeletedTagIds ?? null,
      preferences: {},
    }),
  });
  return parseResponse<SyncResponse>(response);
}

export async function getSubscriptionStatus(token: string) {
  const response = await fetch(`${webConfig.apiBaseUrl}/subscription/status`, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });
  return parseResponse<SubscriptionStatus>(response);
}

export async function createCreemCheckout(token: string, plan: "monthly" | "yearly") {
  const response = await fetch(`${webConfig.apiBaseUrl}/billing/creem/checkout`, {
    method: "POST",
    headers: authHeaders(token),
    body: JSON.stringify({ plan }),
  });
  return parseResponse<{ checkoutUrl: string; checkoutId: string | null }>(response);
}

export async function checkDailyQuota(token: string, feature: DailyQuotaFeature, action: "check" | "consume" = "check") {
  const response = await fetch(`${webConfig.apiBaseUrl}/quota/daily`, {
    method: "POST",
    headers: authHeaders(token),
    body: JSON.stringify({ feature, action }),
  });
  return parseResponse<DailyQuotaState>(response);
}

export async function transcribeAudio(
  token: string,
  audioBase64: string,
  mimeType: string,
  countUsage = true,
  preferences?: { spokenLanguageMode?: "auto" | "prefer"; spokenLanguageHint?: string | null }
) {
  const response = await fetch(`${webConfig.apiBaseUrl}/ai/voice-note`, {
    method: "POST",
    headers: authHeaders(token),
    body: JSON.stringify({
      audioBase64,
      mimeType,
      spokenLanguageMode: preferences?.spokenLanguageMode ?? "auto",
      spokenLanguageHint: preferences?.spokenLanguageHint ?? undefined,
      countUsage,
    }),
  });
  const body = await parseResponse<{ content?: string; text?: string }>(response);
  return body.content ?? body.text ?? "";
}

export async function runAgentRecipe(token: string, prompt: string, systemPrompt: string) {
  const response = await fetch(`${webConfig.apiBaseUrl}/ai/gemini`, {
    method: "POST",
    headers: authHeaders(token),
    body: JSON.stringify({
      usageType: "agent_recipe",
      prompt,
      systemPrompt,
    }),
  });
  const body = await parseResponse<{ content: string }>(response);
  return body.content.trim();
}

export async function refineVoiceTranscript(token: string, transcript: string) {
  const trimmed = transcript.trim();
  if (!trimmed) return trimmed;
  const isShortInput = trimmed.length < 30;
  const systemPrompt = `You are a voice-to-text optimizer called "chillnote". Your job is to transform raw speech transcripts into polished, ready-to-use notes.

STRICT RULES:
- PRIMARY OBJECTIVE: Preserve the user's intent, meaning, and factual content exactly.
- LANGUAGE FIDELITY (STRICT):
  - Preserve every word and phrase in the exact language it appears in.
  - If the text contains multiple languages (code-switching), keep each segment in its original language.
  - Do NOT translate any word, phrase, or segment unless the user explicitly requests a translation in the transcript itself.
  - Keep proper nouns, brand names, technical terms, and idiomatic expressions in the language they appear in.
- ALLOWED EDITS ONLY:
  - Remove obvious filler words and accidental repetitions.
  - Resolve explicit self-corrections to the user's final intended wording.
  - Light grammar and punctuation cleanup for readability.
- FORBIDDEN EDITS:
  - Do NOT add new facts, assumptions, dates, names, or commitments.
  - Do NOT delete key information, constraints, conditions, or action items.
  - Do NOT change the meaning, priority, or certainty level of statements.
- TONE ADAPTATION: Disabled by default. Keep the user's original tone and register.
- If any part is ambiguous or uncertain, keep the original wording for that part instead of guessing.
- For short inputs (under 30 characters): use MINIMAL-EDIT mode and keep wording nearly verbatim.
  - Current input short mode: ${isShortInput ? "ON" : "OFF"}
- IMPLICIT STRUCTURING:
  - If structure is clearly implied: split into clean paragraphs, and optionally add short one-line subheadings.
  - If structure is weak: do light paragraphing only, avoid forced headings.
- TODO / CHECKLIST:
  - If content is task-oriented, format tasks as Markdown checklist items: - [ ] Task
  - For mixed content, keep short context notes first, then one blank line, then checklist.
  - Do NOT invent tasks; only convert/reorganize user-provided intent.
- SHORT-INPUT SAFETY:
  - If short mode is ON, do not force structuring or checklist conversion.
- NO EXPLANATIONS: Return ONLY the processed note text.`;

  const response = await fetch(`${webConfig.apiBaseUrl}/ai/gemini`, {
    method: "POST",
    headers: authHeaders(token),
    body: JSON.stringify({
      prompt: `Process this voice transcript into clean, directly usable text.\n\nVoice transcript:\n${trimmed}`,
      systemPrompt,
    }),
  });
  const body = await parseResponse<{ content: string }>(response);
  return body.content.trim();
}

export function makeEmptyNote(userId: string): NoteDTO {
  const now = new Date().toISOString();
  return {
    id: newClientId(),
    content: "",
    createdAt: now,
    updatedAt: now,
    deletedAt: null,
    pinnedAt: null,
    tagIds: [],
    version: 1,
    baseVersion: 1,
    clientUpdatedAt: now,
    lastModifiedByDeviceId: getOrCreateDeviceId(),
    section: "inbox",
  };
}

export function prepareNoteForSave(note: NoteDTO): NoteDTO {
  const now = new Date().toISOString();
  const version = note.version ?? 1;
  return {
    ...note,
    updatedAt: note.updatedAt ?? now,
    clientUpdatedAt: now,
    lastModifiedByDeviceId: getOrCreateDeviceId(),
    version,
    baseVersion: version,
    tagIds: note.tagIds ?? [],
    section: note.section ?? "inbox",
  };
}

export function makeTag(userId: string, name: string, colorHex: string, sortOrder: number, parentId?: string | null): TagDTO {
  const now = new Date().toISOString();
  return {
    id: newClientId(),
    name,
    colorHex,
    createdAt: now,
    updatedAt: now,
    lastUsedAt: now,
    sortOrder,
    parentId: parentId ?? null,
    deletedAt: null,
    version: 1,
    baseVersion: 1,
    clientUpdatedAt: now,
    lastModifiedByDeviceId: getOrCreateDeviceId(),
  };
}

export function prepareTagForSave(tag: TagDTO): TagDTO {
  const now = new Date().toISOString();
  const version = tag.version ?? 1;
  return {
    ...tag,
    colorHex: tag.colorHex,
    updatedAt: tag.updatedAt ?? now,
    clientUpdatedAt: now,
    lastModifiedByDeviceId: getOrCreateDeviceId(),
    version,
    baseVersion: version,
  };
}
