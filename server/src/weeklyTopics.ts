import fetch from "node-fetch";
import type { Prisma } from "@prisma/client";
import { z } from "zod";
import { prisma } from "./db.js";
import { hasActiveProSubscription } from "./store.js";

const GEMINI_MODEL = process.env.GEMINI_MODEL?.trim() || "gemini-3.1-flash-lite";
const GEMINI_API_KEY = process.env.GEMINI_API_KEY?.trim() || "";
const WORKER_POLL_MS = Number(process.env.WEEKLY_TOPICS_POLL_MS ?? 60_000);
const MINIMUM_SOURCE_NOTES = 1;
const MAX_NOTE_CHARACTERS = 12_000;
const MAX_TOTAL_CHARACTERS = 100_000;

let workerTimer: NodeJS.Timeout | null = null;
let workerRunning = false;

export const weeklyTopicSettingsInputSchema = z.object({
  enabled: z.boolean(),
  weekday: z.number().int().min(1).max(7),
  hour: z.number().int().min(0).max(23),
  minute: z.number().int().min(0).max(59),
  timeZone: z.string().min(1).max(100),
  locale: z.string().min(1).max(35)
});

const generatedTopicsSchema = z.object({
  topics: z.array(z.object({
    title: z.string().trim().min(1).max(160),
    sources: z.array(z.object({
      noteId: z.string().min(1),
      excerpt: z.string().trim().max(600).default("")
    })).min(1)
  })).min(1).max(40)
});

type SourceNote = {
  id: string;
  content: string;
  sourceTitle: string | null;
  sourcePlatformName: string | null;
};

type TopicSource = {
  noteId: string;
  noteTitle: string;
  platformName: string | null;
  excerpt: string;
  availability?: SourceAvailability;
};

type SourceAvailability = "active" | "trashed" | "deleted";

type WeeklyTopic = {
  id: string;
  title: string;
  sources: TopicSource[];
};

export function scheduleWeeklyTopicWorker(): void {
  if (workerTimer) return;
  workerTimer = setInterval(() => void runWeeklyTopicWorker(), Math.max(15_000, WORKER_POLL_MS));
  workerTimer.unref();
  void runWeeklyTopicWorker();
}

export async function getWeeklyTopicDashboard(userId: string) {
  const [settings, latestReport] = await Promise.all([
    prisma.weeklyTopicSettings.findUnique({ where: { userId } }),
    prisma.weeklyTopicReport.findFirst({
      where: { userId },
      orderBy: { periodEnd: "desc" }
    })
  ]);

  const now = new Date();
  const periodStart = settings?.lastPeriodEnd
    ?? new Date((settings?.nextRunAt ?? now).getTime() - 7 * 24 * 60 * 60 * 1000);
  const currentSourceCount = await prisma.note.count({
    where: eligibleNotesWhere(userId, periodStart, now)
  });

  return {
    settings: settings ? serializeSettings(settings) : defaultSettings(),
    latestReport: latestReport ? await serializeReportWithAvailability(userId, latestReport) : null,
    hasUnreadReport: Boolean(latestReport && !latestReport.readAt),
    currentSourceCount,
    minimumSourceCount: MINIMUM_SOURCE_NOTES
  };
}

export async function updateWeeklyTopicSettings(
  userId: string,
  input: z.infer<typeof weeklyTopicSettingsInputSchema>
) {
  const timeZone = normalizedTimeZone(input.timeZone);
  const locale = normalizedLocale(input.locale);
  const existing = await prisma.weeklyTopicSettings.findUnique({ where: { userId } });
  const scheduleChanged = !existing
    || existing.weekday !== input.weekday
    || existing.hour !== input.hour
    || existing.minute !== input.minute
    || existing.timeZone !== timeZone;
  const nextRunAt = input.enabled
    ? (scheduleChanged || !existing?.nextRunAt
      ? nextOccurrence(new Date(), input.weekday, input.hour, input.minute, timeZone)
      : existing.nextRunAt)
    : null;

  const settings = await prisma.weeklyTopicSettings.upsert({
    where: { userId },
    create: {
      userId,
      enabled: input.enabled,
      weekday: input.weekday,
      hour: input.hour,
      minute: input.minute,
      timeZone,
      locale,
      nextRunAt
    },
    update: {
      enabled: input.enabled,
      weekday: input.weekday,
      hour: input.hour,
      minute: input.minute,
      timeZone,
      locale,
      nextRunAt
    }
  });
  return serializeSettings(settings);
}

export async function listWeeklyTopicReports(userId: string, limit = 30) {
  const reports = await prisma.weeklyTopicReport.findMany({
    where: { userId },
    orderBy: { periodEnd: "desc" },
    take: Math.min(Math.max(limit, 1), 52)
  });
  return serializeReportsWithAvailability(userId, reports);
}

export async function getWeeklyTopicReport(userId: string, reportId: string) {
  const report = await prisma.weeklyTopicReport.findFirst({
    where: { id: reportId, userId }
  });
  return report ? serializeReportWithAvailability(userId, report) : null;
}

export async function markWeeklyTopicReportRead(userId: string, reportId: string) {
  const updated = await prisma.weeklyTopicReport.updateMany({
    where: { id: reportId, userId, readAt: null },
    data: { readAt: new Date() }
  });
  return updated.count > 0;
}

export async function regenerateWeeklyTopicReport(userId: string, reportId: string) {
  if (!(await hasActiveProSubscription(userId))) {
    return { kind: "forbidden" as const };
  }

  const report = await prisma.weeklyTopicReport.findFirst({
    where: { id: reportId, userId }
  });
  if (!report) return { kind: "not_found" as const };
  if (report.regenerationCount >= 1) return { kind: "limit_reached" as const };

  const notes = await loadEligibleNotes(userId, report.periodStart, report.periodEnd);
  if (notes.length < MINIMUM_SOURCE_NOTES) return { kind: "not_enough_sources" as const };
  const topics = await generateTopics(notes, report.language);
  const updated = await prisma.weeklyTopicReport.update({
    where: { id: report.id },
    data: {
      topics,
      sourceNoteCount: notes.length,
      readAt: null,
      regenerationCount: { increment: 1 }
    }
  });
  return {
    kind: "ok" as const,
    report: await serializeReportWithAvailability(userId, updated)
  };
}

export async function hardDeleteNoteWithWeeklyTopicCleanup(
  userId: string,
  noteId: string,
  database?: Prisma.TransactionClient
): Promise<{ version: number } | null> {
  const operation = async (transaction: Prisma.TransactionClient) => {
    const existing = await transaction.note.findFirst({
      where: { id: noteId, userId },
      select: { version: true }
    });

    const reports = await transaction.weeklyTopicReport.findMany({
      where: { userId },
      select: { id: true, topics: true }
    });

    for (const report of reports) {
      const scrubbed = scrubDeletedSourceSnapshots(report.topics, noteId);
      if (!scrubbed.changed) continue;
      await transaction.weeklyTopicReport.update({
        where: { id: report.id },
        data: { topics: scrubbed.topics as Prisma.InputJsonValue }
      });
    }

    if (existing) {
      await transaction.note.delete({ where: { id: noteId } });
    }
    return existing;
  };
  return database ? operation(database) : prisma.$transaction(operation);
}

async function runWeeklyTopicWorker(): Promise<void> {
  if (workerRunning) return;
  workerRunning = true;
  try {
    const dueSettings = await prisma.weeklyTopicSettings.findMany({
      where: { enabled: true, nextRunAt: { lte: new Date() } },
      orderBy: { nextRunAt: "asc" },
      take: 10
    });
    for (const settings of dueSettings) {
      try {
        await generateScheduledReport(settings);
      } catch (error) {
        console.error(`Weekly topics generation failed for user=${settings.userId}:`, safeError(error));
      }
    }
  } catch (error) {
    console.error("Weekly topics worker failed:", safeError(error));
  } finally {
    workerRunning = false;
  }
}

async function generateScheduledReport(settings: {
  userId: string;
  weekday: number;
  hour: number;
  minute: number;
  timeZone: string;
  locale: string;
  lastPeriodEnd: Date | null;
  nextRunAt: Date | null;
}): Promise<void> {
  guardDate(settings.nextRunAt);
  const periodEnd = settings.nextRunAt;
  const followingRun = nextOccurrence(
    new Date(periodEnd.getTime() + 60_000),
    settings.weekday,
    settings.hour,
    settings.minute,
    settings.timeZone
  );

  if (!(await hasActiveProSubscription(settings.userId))) {
    await prisma.weeklyTopicSettings.update({
      where: { userId: settings.userId },
      data: { lastPeriodEnd: periodEnd, nextRunAt: followingRun }
    });
    return;
  }

  const periodStart = settings.lastPeriodEnd
    ?? new Date(periodEnd.getTime() - 7 * 24 * 60 * 60 * 1000);
  const notes = await loadEligibleNotes(settings.userId, periodStart, periodEnd);

  if (notes.length < MINIMUM_SOURCE_NOTES) {
    await prisma.weeklyTopicSettings.update({
      where: { userId: settings.userId },
      data: { lastPeriodEnd: periodEnd, nextRunAt: followingRun }
    });
    return;
  }

  const existing = await prisma.weeklyTopicReport.findUnique({
    where: { userId_periodEnd: { userId: settings.userId, periodEnd } }
  });
  if (!existing) {
    const topics = await generateTopics(notes, settings.locale);
    const report = await prisma.weeklyTopicReport.create({
      data: {
        userId: settings.userId,
        periodStart,
        periodEnd,
        sourceNoteCount: notes.length,
        language: settings.locale,
        topics
      }
    });
    await prisma.notificationDelivery.upsert({
      where: { dedupeKey: `weekly_topics_ready:${settings.userId}:${report.id}` },
      create: {
        userId: settings.userId,
        kind: "weekly_topics_ready",
        dedupeKey: `weekly_topics_ready:${settings.userId}:${report.id}`,
        scheduledAt: new Date()
      },
      update: {}
    });
  }

  await prisma.weeklyTopicSettings.update({
    where: { userId: settings.userId },
    data: { lastPeriodEnd: periodEnd, nextRunAt: followingRun }
  });
}

async function loadEligibleNotes(userId: string, start: Date, end: Date): Promise<SourceNote[]> {
  return prisma.note.findMany({
    where: eligibleNotesWhere(userId, start, end),
    orderBy: { createdAt: "asc" },
    select: {
      id: true,
      content: true,
      sourceTitle: true,
      sourcePlatformName: true
    }
  });
}

function eligibleNotesWhere(userId: string, start: Date, end: Date) {
  return {
    userId,
    deletedAt: null,
    section: "inbox",
    createdAt: { gte: start, lt: end },
    content: { not: "" }
  } as const;
}

async function generateTopics(notes: SourceNote[], locale: string): Promise<WeeklyTopic[]> {
  if (!GEMINI_API_KEY) throw new Error("GEMINI_API_KEY is not configured");
  const noteMap = new Map(notes.map((note) => [note.id, note]));
  let usedCharacters = 0;
  const sourceBlocks: string[] = [];
  for (const note of notes) {
    const remaining = MAX_TOTAL_CHARACTERS - usedCharacters;
    if (remaining <= 0) break;
    const content = note.content.trim().slice(0, Math.min(MAX_NOTE_CHARACTERS, remaining));
    usedCharacters += content.length;
    sourceBlocks.push([
      `<note id="${note.id}">`,
      `Title: ${note.sourceTitle?.trim() || firstUsefulLine(content)}`,
      `Platform: ${note.sourcePlatformName?.trim() || "Personal note"}`,
      content,
      "</note>"
    ].join("\n"));
  }

  const body = {
    systemInstruction: {
      parts: [{ text: weeklyTopicsSystemPrompt(locale) }]
    },
    contents: [{
      role: "user",
      parts: [{ text: sourceBlocks.join("\n\n") }]
    }],
    generationConfig: {
      temperature: 0.25,
      responseMimeType: "application/json",
      responseSchema: {
        type: "OBJECT",
        required: ["topics"],
        properties: {
          topics: {
            type: "ARRAY",
            items: {
              type: "OBJECT",
              required: ["title", "sources"],
              properties: {
                title: { type: "STRING" },
                sources: {
                  type: "ARRAY",
                  items: {
                    type: "OBJECT",
                    required: ["noteId", "excerpt"],
                    properties: {
                      noteId: { type: "STRING" },
                      excerpt: { type: "STRING" }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  };

  const response = await fetch(geminiURL(), {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
    timeout: 120_000
  });
  if (!response.ok) {
    throw new Error(`Gemini weekly topics request failed: ${response.status}`);
  }
  const payload = await response.json() as any;
  const raw = String(payload.candidates?.[0]?.content?.parts?.[0]?.text ?? "");
  const parsed = generatedTopicsSchema.parse(JSON.parse(raw));

  const result: WeeklyTopic[] = [];
  parsed.topics.forEach((topic, index) => {
    const seen = new Set<string>();
    const sources: TopicSource[] = [];
    for (const generatedSource of topic.sources) {
      const note = noteMap.get(generatedSource.noteId);
      if (!note || seen.has(note.id)) continue;
      seen.add(note.id);
      sources.push({
        noteId: note.id,
        noteTitle: note.sourceTitle?.trim() || firstUsefulLine(note.content),
        platformName: note.sourcePlatformName,
        excerpt: verifiedExcerpt(note.content, generatedSource.excerpt)
      });
    }
    if (sources.length === 0) return;
    result.push({
      id: `topic-${index + 1}`,
      title: topic.title.trim(),
      sources
    });
  });
  return result;
}

function weeklyTopicsSystemPrompt(locale: string): string {
  return `
You are an editorial assistant turning a creator's private saved notes into a concise weekly topic list.

Output language: ${locale}.
Use only the supplied notes. Never browse, add facts, or invent claims.
Extract every concrete topic that could be discussed or explored in future content.
The number of topics must follow the source material; never force a fixed count.
Merge topics only when they address the same specific question. Do not merge merely because they share a broad category.
A single note may support multiple topics.
Each title must be one concise, specific line. Avoid vague labels, motivational language, clickbait, summaries, explanations, and recommendations.
For every topic, cite all supporting note IDs and include a short verbatim excerpt from each note. Excerpts must exist exactly in the supplied note.
`.trim();
}

function verifiedExcerpt(content: string, requested: string): string {
  const clean = requested.trim();
  if (clean && content.includes(clean)) return clean.slice(0, 420);
  const compact = content.trim().replace(/\s+/g, " ");
  return compact.slice(0, 280);
}

function firstUsefulLine(content: string): string {
  const line = content
    .split(/\r?\n/)
    .map((value) => value.replace(/^#{1,6}\s*/, "").trim())
    .find(Boolean);
  return (line || "Saved note").slice(0, 120);
}

function serializeSettings(settings: {
  enabled: boolean;
  weekday: number;
  hour: number;
  minute: number;
  timeZone: string;
  locale: string;
  lastPeriodEnd: Date | null;
  nextRunAt: Date | null;
}) {
  return {
    enabled: settings.enabled,
    weekday: settings.weekday,
    hour: settings.hour,
    minute: settings.minute,
    timeZone: settings.timeZone,
    locale: settings.locale,
    lastPeriodEnd: settings.lastPeriodEnd?.toISOString() ?? null,
    nextRunAt: settings.nextRunAt?.toISOString() ?? null
  };
}

function defaultSettings() {
  return {
    enabled: false,
    weekday: 1,
    hour: 9,
    minute: 0,
    timeZone: "UTC",
    locale: "en",
    lastPeriodEnd: null,
    nextRunAt: null
  };
}

type WeeklyTopicReportRecord = {
  id: string;
  periodStart: Date;
  periodEnd: Date;
  sourceNoteCount: number;
  language: string;
  topics: unknown;
  readAt: Date | null;
  regenerationCount: number;
  createdAt: Date;
};

async function serializeReportWithAvailability(
  userId: string,
  report: WeeklyTopicReportRecord
) {
  const [serialized] = await serializeReportsWithAvailability(userId, [report]);
  return serialized;
}

async function serializeReportsWithAvailability(
  userId: string,
  reports: WeeklyTopicReportRecord[]
) {
  const noteIds = new Set<string>();
  for (const report of reports) {
    collectSourceNoteIds(report.topics, noteIds);
  }
  const notes = noteIds.size === 0
    ? []
    : await prisma.note.findMany({
      where: { userId, id: { in: Array.from(noteIds) } },
      select: { id: true, deletedAt: true }
    });
  const availabilityByNoteId = new Map<string, SourceAvailability>(
    notes.map((note) => [note.id, note.deletedAt ? "trashed" : "active"])
  );
  return reports.map((report) => serializeReport(report, availabilityByNoteId));
}

function serializeReport(
  report: WeeklyTopicReportRecord,
  availabilityByNoteId: Map<string, SourceAvailability>
) {
  return {
    id: report.id,
    periodStart: report.periodStart.toISOString(),
    periodEnd: report.periodEnd.toISOString(),
    sourceNoteCount: report.sourceNoteCount,
    language: report.language,
    topics: annotateSourceAvailability(report.topics, availabilityByNoteId),
    readAt: report.readAt?.toISOString() ?? null,
    regenerationCount: report.regenerationCount,
    createdAt: report.createdAt.toISOString()
  };
}

function collectSourceNoteIds(topics: unknown, noteIds: Set<string>): void {
  if (!Array.isArray(topics)) return;
  for (const topic of topics) {
    if (!isRecord(topic) || !Array.isArray(topic.sources)) continue;
    for (const source of topic.sources) {
      if (isRecord(source) && typeof source.noteId === "string") {
        noteIds.add(source.noteId);
      }
    }
  }
}

export function annotateSourceAvailability(
  topics: unknown,
  availabilityByNoteId: Map<string, SourceAvailability>
): unknown {
  if (!Array.isArray(topics)) return topics;
  return topics.map((topic) => {
    if (!isRecord(topic) || !Array.isArray(topic.sources)) return topic;
    return {
      ...topic,
      sources: topic.sources.map((source) => {
        if (!isRecord(source) || typeof source.noteId !== "string") return source;
        const availability = availabilityByNoteId.get(source.noteId) ?? "deleted";
        if (availability !== "deleted") return { ...source, availability };
        return {
          ...source,
          noteTitle: "",
          platformName: null,
          excerpt: "",
          availability
        };
      })
    };
  });
}

export function scrubDeletedSourceSnapshots(
  topics: unknown,
  noteId: string
): { topics: unknown; changed: boolean } {
  if (!Array.isArray(topics)) return { topics, changed: false };
  let changed = false;
  const scrubbedTopics = topics.map((topic) => {
    if (!isRecord(topic) || !Array.isArray(topic.sources)) return topic;
    const sources = topic.sources.map((source) => {
      if (!isRecord(source) || source.noteId !== noteId) return source;
      changed = true;
      return {
        ...source,
        noteTitle: "",
        platformName: null,
        excerpt: "",
        availability: "deleted"
      };
    });
    return { ...topic, sources };
  });
  return { topics: scrubbedTopics, changed };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function nextOccurrence(
  after: Date,
  weekday: number,
  hour: number,
  minute: number,
  timeZone: string
): Date {
  const local = localParts(after, timeZone);
  let dayDelta = (weekday - local.weekday + 7) % 7;
  if (dayDelta === 0 && (local.hour > hour || (local.hour === hour && local.minute >= minute))) {
    dayDelta = 7;
  }
  const localDate = new Date(Date.UTC(local.year, local.month - 1, local.day + dayDelta, hour, minute));
  return zonedLocalDateToUTC(
    localDate.getUTCFullYear(),
    localDate.getUTCMonth() + 1,
    localDate.getUTCDate(),
    hour,
    minute,
    timeZone
  );
}

function zonedLocalDateToUTC(
  year: number,
  month: number,
  day: number,
  hour: number,
  minute: number,
  timeZone: string
): Date {
  const desired = Date.UTC(year, month - 1, day, hour, minute);
  let candidate = new Date(desired);
  for (let index = 0; index < 4; index += 1) {
    const observed = localParts(candidate, timeZone);
    const observedValue = Date.UTC(
      observed.year,
      observed.month - 1,
      observed.day,
      observed.hour,
      observed.minute
    );
    const difference = desired - observedValue;
    if (difference === 0) break;
    candidate = new Date(candidate.getTime() + difference);
  }
  return candidate;
}

function localParts(date: Date, timeZone: string) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    weekday: "short",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23"
  }).formatToParts(date);
  const value = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((part) => part.type === type)?.value ?? "";
  const weekdayMap: Record<string, number> = {
    Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7
  };
  return {
    weekday: weekdayMap[value("weekday")] ?? 1,
    year: Number(value("year")),
    month: Number(value("month")),
    day: Number(value("day")),
    hour: Number(value("hour")),
    minute: Number(value("minute"))
  };
}

function normalizedTimeZone(value: string): string {
  const candidate = value.trim() || "UTC";
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: candidate }).format();
    return candidate;
  } catch {
    return "UTC";
  }
}

function normalizedLocale(value: string): string {
  return value.trim().slice(0, 35) || "en";
}

function geminiURL(): string {
  return `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(GEMINI_MODEL)}:generateContent?key=${encodeURIComponent(GEMINI_API_KEY)}`;
}

function guardDate(value: Date | null): asserts value is Date {
  if (!value) throw new Error("Weekly topic settings missing nextRunAt");
}

function safeError(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
