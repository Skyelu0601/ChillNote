import fetch from "node-fetch";
import { randomUUID } from "node:crypto";
import { prisma } from "./db.js";
import { logSyncChange } from "./store.js";
import { isSupportedMediaLinkURL, transcribeMediaLinkURL } from "./tiktokTranscript.js";

type LinkImportJobStatus = "queued" | "processing" | "completed" | "failed";

type LinkImportJobRow = {
  id: string;
  userId: string;
  noteId: string;
  url: string;
  status: LinkImportJobStatus;
  attempts: number;
};

type LinkImportSource = {
  url: string;
  title: string;
  platformID: string;
  platformName: string;
  host: string;
};

const GEMINI_MODEL = process.env.GEMINI_MODEL?.trim() || "gemini-3.1-flash-lite-preview";
const GEMINI_API_KEY = process.env.GEMINI_API_KEY?.trim() || "";
const MAX_WEB_TEXT_CHARS = Number(process.env.LINK_IMPORT_MAX_WEB_TEXT_CHARS ?? 18_000);
const JOB_MAX_ATTEMPTS = Number(process.env.LINK_IMPORT_MAX_ATTEMPTS ?? 2);

let isWorkerRunning = false;
let workerScheduled = false;

export function makeInitialLinkSource(rawURL: string): LinkImportSource {
  const url = new URL(rawURL);
  const host = normalizedHost(url);
  const platform = platformForHost(host);
  return {
    url: url.toString(),
    title: platform.displayName,
    platformID: platform.id,
    platformName: platform.displayName,
    host
  };
}

export async function enqueueLinkImportJob(params: {
  userId: string;
  noteId: string;
  url: string;
  placeholderContent: string;
  source: LinkImportSource;
  section?: string | null;
}): Promise<{ jobId: string; status: LinkImportJobStatus }> {
  const now = new Date();
  const existingRows = await prisma.$queryRaw<Array<{ importJobId: string | null }>>`
    SELECT "importJobId"
    FROM "Note"
    WHERE "id" = ${params.noteId}
      AND "userId" = ${params.userId}
    LIMIT 1
  `;
  const existing = existingRows[0];
  const jobId = existing?.importJobId || randomUUID();

  const noteRows = await prisma.$queryRaw<Array<{ version: number; serverUpdatedAt: Date }>>`
    INSERT INTO "Note" (
      "id", "userId", "content", "createdAt", "updatedAt", "serverUpdatedAt",
      "sourceURL", "sourceTitle", "sourcePlatformID", "sourcePlatformName", "sourceHost", "sourceCapturedAt",
      "section", "importStatus", "importJobId", "importErrorCode", "importStartedAt", "importCompletedAt"
    )
    VALUES (
      ${params.noteId}, ${params.userId}, ${params.placeholderContent}, ${now}, ${now}, ${now},
      ${params.source.url}, ${params.source.title}, ${params.source.platformID}, ${params.source.platformName}, ${params.source.host}, ${now},
      ${params.section ?? "inbox"}, 'queued', ${jobId}, NULL, NULL, NULL
    )
    ON CONFLICT ("id") DO UPDATE SET
      "content" = EXCLUDED."content",
      "updatedAt" = EXCLUDED."updatedAt",
      "serverUpdatedAt" = EXCLUDED."serverUpdatedAt",
      "version" = "Note"."version" + 1,
      "sourceURL" = EXCLUDED."sourceURL",
      "sourceTitle" = EXCLUDED."sourceTitle",
      "sourcePlatformID" = EXCLUDED."sourcePlatformID",
      "sourcePlatformName" = EXCLUDED."sourcePlatformName",
      "sourceHost" = EXCLUDED."sourceHost",
      "sourceCapturedAt" = EXCLUDED."sourceCapturedAt",
      "section" = EXCLUDED."section",
      "importStatus" = 'queued',
      "importJobId" = ${jobId},
      "importErrorCode" = NULL,
      "importStartedAt" = NULL,
      "importCompletedAt" = NULL
    RETURNING "version", "serverUpdatedAt"
  `;

  await prisma.$executeRaw`
    INSERT INTO "LinkImportJob" ("id", "userId", "noteId", "url", "status", "createdAt", "updatedAt")
    VALUES (${jobId}, ${params.userId}, ${params.noteId}, ${params.url}, 'queued', ${now}, ${now})
    ON CONFLICT ("userId", "noteId") DO UPDATE SET
      "url" = EXCLUDED."url",
      "status" = CASE
        WHEN "LinkImportJob"."status" = 'completed' THEN "LinkImportJob"."status"
        ELSE 'queued'
      END,
      "errorCode" = NULL,
      "updatedAt" = EXCLUDED."updatedAt"
  `;

  await logSyncChange({
    userId: params.userId,
    entityType: "note",
    entityId: params.noteId,
    version: noteRows[0]?.version ?? 1,
    serverUpdatedAt: noteRows[0]?.serverUpdatedAt ?? now,
    operation: "upsert"
  });

  scheduleLinkImportWorker();
  return { jobId, status: "queued" };
}

export function scheduleLinkImportWorker() {
  if (workerScheduled) return;
  workerScheduled = true;
  setTimeout(() => {
    workerScheduled = false;
    void runLinkImportWorker();
  }, 0);
}

export async function runLinkImportWorker(): Promise<void> {
  if (isWorkerRunning) return;
  isWorkerRunning = true;
  try {
    while (true) {
      const job = await claimNextJob();
      if (!job) return;
      await processJob(job);
    }
  } finally {
    isWorkerRunning = false;
  }
}

async function claimNextJob(): Promise<LinkImportJobRow | null> {
  const jobs = await prisma.$queryRaw<LinkImportJobRow[]>`
    UPDATE "LinkImportJob"
    SET "status" = 'processing',
        "attempts" = "attempts" + 1,
        "startedAt" = NOW(),
        "updatedAt" = NOW()
    WHERE "id" = (
      SELECT "id"
      FROM "LinkImportJob"
      WHERE "status" IN ('queued', 'processing')
        AND "attempts" < ${JOB_MAX_ATTEMPTS}
      ORDER BY "createdAt" ASC
      LIMIT 1
    )
    RETURNING "id", "userId", "noteId", "url", "status", "attempts"
  `;
  return jobs[0] ?? null;
}

async function processJob(job: LinkImportJobRow): Promise<void> {
  try {
    const result = await buildImportedNote(job.url);
    await completeJob(job, result.content, result.source);
  } catch (error) {
    console.error("❌ Link import job failed:", {
      jobId: job.id,
      noteId: job.noteId,
      userId: job.userId,
      error
    });
    await failJob(job, "import_failed");
  }
}

async function completeJob(job: LinkImportJobRow, content: string, source: LinkImportSource): Promise<void> {
  const now = new Date();
  const rows = await prisma.$queryRaw<Array<{ version: number; serverUpdatedAt: Date }>>`
    UPDATE "Note"
    SET "content" = ${content},
        "updatedAt" = ${now},
        "serverUpdatedAt" = ${now},
        "version" = "version" + 1,
        "sourceURL" = ${source.url},
        "sourceTitle" = ${source.title},
        "sourcePlatformID" = ${source.platformID},
        "sourcePlatformName" = ${source.platformName},
        "sourceHost" = ${source.host},
        "sourceCapturedAt" = COALESCE("sourceCapturedAt", ${now}),
        "importStatus" = 'completed',
        "importJobId" = ${job.id},
        "importErrorCode" = NULL,
        "importCompletedAt" = ${now}
    WHERE "id" = ${job.noteId}
      AND "userId" = ${job.userId}
    RETURNING "version", "serverUpdatedAt"
  `;

  await prisma.$executeRaw`
    UPDATE "LinkImportJob"
    SET "status" = 'completed',
        "errorCode" = NULL,
        "completedAt" = ${now},
        "updatedAt" = ${now}
    WHERE "id" = ${job.id}
  `;

  const updated = rows[0];
  if (updated) {
    await logSyncChange({
      userId: job.userId,
      entityType: "note",
      entityId: job.noteId,
      version: updated.version,
      serverUpdatedAt: updated.serverUpdatedAt,
      operation: "upsert"
    });
  }
}

async function failJob(job: LinkImportJobRow, errorCode: string): Promise<void> {
  const now = new Date();
  await prisma.$executeRaw`
    UPDATE "LinkImportJob"
    SET "status" = 'failed',
        "errorCode" = ${errorCode},
        "completedAt" = ${now},
        "updatedAt" = ${now}
    WHERE "id" = ${job.id}
  `;

  const rows = await prisma.$queryRaw<Array<{ version: number; serverUpdatedAt: Date }>>`
    UPDATE "Note"
    SET "updatedAt" = ${now},
        "serverUpdatedAt" = ${now},
        "version" = "version" + 1,
        "importStatus" = 'failed',
        "importJobId" = ${job.id},
        "importErrorCode" = ${errorCode},
        "importCompletedAt" = ${now}
    WHERE "id" = ${job.noteId}
      AND "userId" = ${job.userId}
    RETURNING "version", "serverUpdatedAt"
  `;

  const updated = rows[0];
  if (updated) {
    await logSyncChange({
      userId: job.userId,
      entityType: "note",
      entityId: job.noteId,
      version: updated.version,
      serverUpdatedAt: updated.serverUpdatedAt,
      operation: "upsert"
    });
  }
}

async function buildImportedNote(rawURL: string): Promise<{ content: string; source: LinkImportSource }> {
  const source = makeInitialLinkSource(rawURL);

  if (isSupportedMediaLinkURL(rawURL)) {
    const transcript = await transcribeMediaLinkURL(rawURL);
    if (transcript.available && transcript.text?.trim()) {
      const title = transcript.metadata?.title?.trim() || source.title;
      const updatedSource = { ...source, title };
      const content = await organizeContent({
        url: rawURL,
        title,
        sourceText: transcript.text,
        kind: "media transcript"
      });
      return { content, source: updatedSource };
    }

    return {
      content: `# ${source.title}\n\n## Summary\n\nTranscript is not available for this link yet.`,
      source
    };
  }

  const web = await fetchWebPage(rawURL);
  const updatedSource = {
    ...source,
    title: web.title || source.title
  };
  const content = await organizeContent({
    url: rawURL,
    title: updatedSource.title,
    sourceText: [web.description, web.text].filter(Boolean).join("\n\n"),
    kind: "web page"
  });
  return { content, source: updatedSource };
}

async function fetchWebPage(rawURL: string): Promise<{ title: string; description: string; text: string }> {
  const response = await fetch(rawURL, {
    headers: {
      "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
    },
    timeout: 20_000
  });

  if (!response.ok) {
    throw new Error(`Web fetch failed: ${response.status}`);
  }

  const html = await response.text();
  const title = decodeEntities(firstMatch(html, /<title[^>]*>([\s\S]*?)<\/title>/i));
  const description = decodeEntities(
    firstMatch(html, /<meta[^>]+name=["']description["'][^>]+content=["']([^"']*)["'][^>]*>/i)
      || firstMatch(html, /<meta[^>]+content=["']([^"']*)["'][^>]+name=["']description["'][^>]*>/i)
  );
  const text = decodeEntities(
    html
      .replace(/<script[\s\S]*?<\/script>/gi, " ")
      .replace(/<style[\s\S]*?<\/style>/gi, " ")
      .replace(/<nav[\s\S]*?<\/nav>/gi, " ")
      .replace(/<footer[\s\S]*?<\/footer>/gi, " ")
      .replace(/<[^>]+>/g, " ")
      .replace(/\s+/g, " ")
      .trim()
      .slice(0, MAX_WEB_TEXT_CHARS)
  );

  if (!description && !text) {
    throw new Error("Web page did not contain readable text");
  }

  return { title, description, text };
}

async function organizeContent(params: {
  url: string;
  title: string;
  sourceText: string;
  kind: string;
}): Promise<string> {
  const trimmed = params.sourceText.trim();
  if (!GEMINI_API_KEY || !trimmed) {
    return fallbackNote(params.title, trimmed);
  }

  const prompt = `
Turn this ${params.kind} into a useful ChillNote note.

Source URL:
${params.url}

Title:
${params.title}

Source text:
${trimmed.slice(0, MAX_WEB_TEXT_CHARS)}
`.trim();

  const body = {
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    systemInstruction: {
      parts: [{
        text: `
You organize saved links for a personal notes app.
Return only Markdown.
Rules:
- Preserve the original language of the source.
- Do not invent facts.
- Start with a concise title.
- Add a short summary when useful.
- Capture key points and action items when present.
- For transcripts, include a Transcript section with a readable transcript.
`.trim()
      }]
    }
  };

  const response = await fetch(buildGeminiGenerateContentURL(GEMINI_MODEL), {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
    timeout: 90_000
  });

  if (!response.ok) {
    throw new Error(`Gemini organize failed: ${response.status}`);
  }

  const data = await response.json() as any;
  const content = String(data.candidates?.[0]?.content?.parts?.[0]?.text ?? "").trim();
  return content || fallbackNote(params.title, trimmed);
}

function buildGeminiGenerateContentURL(model: string): string {
  const encodedModel = encodeURIComponent(model);
  const encodedApiKey = encodeURIComponent(GEMINI_API_KEY);
  return `https://generativelanguage.googleapis.com/v1beta/models/${encodedModel}:generateContent?key=${encodedApiKey}`;
}

function fallbackNote(title: string, text: string): string {
  const safeTitle = title.trim() || "Imported Link";
  const excerpt = text.trim().slice(0, 4_000);
  return excerpt ? `# ${safeTitle}\n\n${excerpt}` : `# ${safeTitle}`;
}

function normalizedHost(url: URL): string {
  return url.hostname.toLowerCase().replace(/^www\./, "");
}

function platformForHost(host: string): { id: string; displayName: string } {
  if (host === "tiktok.com" || host.endsWith(".tiktok.com")) return { id: "tiktok", displayName: "TikTok" };
  if (host === "youtube.com" || host.endsWith(".youtube.com") || host === "youtu.be") return { id: "youtube", displayName: "YouTube" };
  if (host === "instagram.com" || host.endsWith(".instagram.com")) return { id: "instagram", displayName: "Instagram" };
  return { id: "web", displayName: host || "Web Link" };
}

function firstMatch(source: string, regex: RegExp): string {
  return source.match(regex)?.[1]?.trim() ?? "";
}

function decodeEntities(text: string): string {
  return text
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, "\"")
    .replace(/&#39;/g, "'")
    .replace(/\s+/g, " ")
    .trim();
}
