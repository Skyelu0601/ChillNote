import fetch from "node-fetch";
import { randomUUID } from "node:crypto";
import { prisma } from "./db.js";
import { acquireUserSyncTransactionLock, logSyncChange, upsertUser } from "./store.js";
import { isUUIDSyncIdentity, normalizeNewSyncEntityId } from "./syncIdentity.js";
import { shouldReuseCompletedLinkImportJob } from "./linkImportPolicy.js";
import { hasForeignSyncIdentityOwner, SyncOwnershipError } from "./syncPolicy.js";
import {
  isHandledTikTokTranscriptError,
  isSupportedMediaLinkURL,
  transcribeMediaLinkURL,
  type MediaLinkTranscriptMetadata
} from "./tiktokTranscript.js";
import { scheduleImportCompletionNotifications } from "./pushNotifications.js";
import {
  normalizeMediaLinkSections,
  type MediaLinkSections
} from "./mediaLinkSections.js";
import {
  linkImportContentStrings,
  normalizeLinkImportContentLocale,
  type LinkImportContentLocale
} from "./linkImportLocalization.js";

type LinkImportJobStatus = "queued" | "processing" | "completed" | "failed";

type LinkImportJobRow = {
  id: string;
  userId: string;
  noteId: string;
  url: string;
  status: LinkImportJobStatus;
  attempts: number;
  showDescription: boolean;
  showAuthor: boolean;
  showHook: boolean;
  showTranscript: boolean;
  contentLocale: LinkImportContentLocale;
};

type LinkImportSource = {
  url: string;
  title: string;
  platformID: string;
  platformName: string;
  host: string;
  authorName?: string | null;
  authorHandle?: string | null;
};

type LinkImportFailureDetails = {
  errorCode: string;
  content?: string;
  source?: LinkImportSource;
};

type LinkImportCreditAuthorization = {
  tier: "free" | "pro";
  cost: number;
  initialCredits: number;
};

export class LinkImportInsufficientCreditsError extends Error {
  constructor(
    readonly balance: number,
    readonly cost: number
  ) {
    super("Insufficient credits");
    this.name = "LinkImportInsufficientCreditsError";
  }
}

const GEMINI_MODEL = process.env.GEMINI_MODEL?.trim() || "gemini-3.1-flash-lite";
const GEMINI_API_KEY = process.env.GEMINI_API_KEY?.trim() || "";
const MAX_WEB_TEXT_CHARS = Number(process.env.LINK_IMPORT_MAX_WEB_TEXT_CHARS ?? 18_000);
const JOB_MAX_ATTEMPTS = Number(process.env.LINK_IMPORT_MAX_ATTEMPTS ?? 2);
const configuredProcessingLeaseMs = Number(
  process.env.LINK_IMPORT_PROCESSING_LEASE_MS ?? 15 * 60 * 1_000
);
const JOB_PROCESSING_LEASE_MS = Number.isFinite(configuredProcessingLeaseMs)
  && configuredProcessingLeaseMs > 0
  ? configuredProcessingLeaseMs
  : 15 * 60 * 1_000;
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
  mediaLinkSections?: MediaLinkSections;
  contentLocale?: string | null;
  creditAuthorization: LinkImportCreditAuthorization;
}): Promise<{
  jobId: string;
  status: LinkImportJobStatus;
  balance: number | null;
  tier: "free" | "pro";
}> {
  const now = new Date();
  const mediaLinkSections = normalizeMediaLinkSections(params.mediaLinkSections);
  const contentLocale = normalizeLinkImportContentLocale(params.contentLocale);

  const transactionResult = await prisma.$transaction(async (tx) => {
    await acquireUserSyncTransactionLock(params.userId, tx);
    await upsertUser(params.userId, tx);
    const identityRows = await tx.note.findMany({
      where: {
        id: isUUIDSyncIdentity(params.noteId)
          ? { equals: params.noteId, mode: "insensitive" }
          : params.noteId
      },
      orderBy: [{ serverUpdatedAt: "desc" }, { updatedAt: "desc" }],
      select: { id: true, userId: true, importJobId: true }
    });
    if (hasForeignSyncIdentityOwner(params.userId, identityRows.map((note) => note.userId))) {
      throw new SyncOwnershipError();
    }
    const tombstones = await tx.hardDeleteTombstone.findMany({
      where: {
        entityType: "note",
        entityId: isUUIDSyncIdentity(params.noteId)
          ? { equals: params.noteId, mode: "insensitive" }
          : params.noteId
      },
      select: { userId: true }
    });
    if (
      tombstones.length > 0
      || hasForeignSyncIdentityOwner(params.userId, tombstones.map((item) => item.userId))
    ) {
      throw new SyncOwnershipError();
    }
    const existing = identityRows[0];
    const resolvedNoteId = existing?.id ?? normalizeNewSyncEntityId(params.noteId);
    const existingJob = existing
      ? await tx.linkImportJob.findUnique({
        where: {
          userId_noteId: {
            userId: params.userId,
            noteId: resolvedNoteId
          }
        },
        select: { id: true, status: true }
      })
      : null;
    if (shouldReuseCompletedLinkImportJob(existingJob?.status)) {
      let balance: number | null = null;
      if (params.creditAuthorization.tier === "free") {
        const rows = await tx.$queryRaw<Array<{ balance: number }>>`
          SELECT "balance"
          FROM "UserCredits"
          WHERE "userId" = ${params.userId}
          LIMIT 1
        `;
        balance = Number(rows[0]?.balance ?? params.creditAuthorization.initialCredits);
      }
      return {
        balance,
        jobId: existingJob!.id,
        status: "completed" as const,
        shouldScheduleWorker: false
      };
    }
    const jobId = existing?.importJobId || randomUUID();
    const noteMutationId = randomUUID();

    const noteRows = await tx.$queryRaw<Array<{ version: number; serverUpdatedAt: Date }>>`
      INSERT INTO "Note" (
        "id", "userId", "content", "createdAt", "updatedAt", "serverUpdatedAt",
        "lastMutationId",
        "sourceURL", "sourceTitle", "sourcePlatformID", "sourcePlatformName", "sourceHost",
        "sourceAuthorName", "sourceAuthorHandle", "sourceCapturedAt",
        "section", "importStatus", "importJobId", "importErrorCode", "importStartedAt", "importCompletedAt"
      )
      VALUES (
        ${resolvedNoteId}, ${params.userId}, ${params.placeholderContent}, ${now}, ${now}, ${now},
        ${noteMutationId},
        ${params.source.url}, ${params.source.title}, ${params.source.platformID}, ${params.source.platformName}, ${params.source.host},
        ${params.source.authorName ?? null}, ${params.source.authorHandle ?? null}, ${now},
        ${params.section ?? "inbox"}, 'queued', ${jobId}, NULL, NULL, NULL
      )
      ON CONFLICT ("id") DO UPDATE SET
        "content" = EXCLUDED."content",
        "updatedAt" = EXCLUDED."updatedAt",
        "serverUpdatedAt" = EXCLUDED."serverUpdatedAt",
        "version" = "Note"."version" + 1,
        "lastMutationId" = EXCLUDED."lastMutationId",
        "sourceURL" = EXCLUDED."sourceURL",
        "sourceTitle" = EXCLUDED."sourceTitle",
        "sourcePlatformID" = EXCLUDED."sourcePlatformID",
        "sourcePlatformName" = EXCLUDED."sourcePlatformName",
        "sourceHost" = EXCLUDED."sourceHost",
        "sourceAuthorName" = EXCLUDED."sourceAuthorName",
        "sourceAuthorHandle" = EXCLUDED."sourceAuthorHandle",
        "sourceCapturedAt" = EXCLUDED."sourceCapturedAt",
        "section" = EXCLUDED."section",
        "importStatus" = 'queued',
        "importJobId" = ${jobId},
        "importErrorCode" = NULL,
        "importStartedAt" = NULL,
        "importCompletedAt" = NULL
      WHERE "Note"."userId" = EXCLUDED."userId"
      RETURNING "version", "serverUpdatedAt"
    `;
    if (!noteRows.length) throw new SyncOwnershipError();

    const jobRows = await tx.$queryRaw<Array<{ id: string; status: LinkImportJobStatus }>>`
      INSERT INTO "LinkImportJob" (
        "id", "userId", "noteId", "url", "status",
        "showDescription", "showAuthor", "showHook", "showTranscript",
        "contentLocale",
        "createdAt", "updatedAt"
      )
      VALUES (
        ${jobId}, ${params.userId}, ${resolvedNoteId}, ${params.url}, 'queued',
        ${mediaLinkSections.showDescription}, ${mediaLinkSections.showAuthor},
        ${mediaLinkSections.showHook}, ${mediaLinkSections.showTranscript},
        ${contentLocale},
        ${now}, ${now}
      )
      ON CONFLICT ("userId", "noteId") DO UPDATE SET
        "url" = EXCLUDED."url",
        "status" = CASE
          WHEN "LinkImportJob"."status" = 'completed' THEN "LinkImportJob"."status"
          ELSE 'queued'
        END,
        "showDescription" = EXCLUDED."showDescription",
        "showAuthor" = EXCLUDED."showAuthor",
        "showHook" = EXCLUDED."showHook",
        "showTranscript" = EXCLUDED."showTranscript",
        "contentLocale" = EXCLUDED."contentLocale",
        "errorCode" = NULL,
        "updatedAt" = EXCLUDED."updatedAt"
      RETURNING "id", "status"
    `;
    const persistedJobId = jobRows[0]?.id ?? jobId;
    const persistedJobStatus = jobRows[0]?.status ?? "queued";

    // A concurrent request may have won the unique (userId, noteId) insert
    // with a different generated ID. Keep the note and API response aligned
    // with the single persisted job.
    if (persistedJobId !== jobId) {
      await tx.$executeRaw`
        UPDATE "Note"
        SET "importJobId" = ${persistedJobId}
        WHERE "id" = ${resolvedNoteId} AND "userId" = ${params.userId}
      `;
    }

    const authorizationRows = await tx.$queryRaw<Array<{ creditAuthorizedAt: Date | null }>>`
      SELECT "creditAuthorizedAt"
      FROM "LinkImportJob"
      WHERE "userId" = ${params.userId} AND "noteId" = ${resolvedNoteId}
      FOR UPDATE
    `;
    const isAlreadyAuthorized = authorizationRows[0]?.creditAuthorizedAt != null;
    let balance: number | null = null;

    if (params.creditAuthorization.tier === "free") {
      await tx.$executeRaw`
        INSERT INTO "UserCredits" ("userId", "balance", "createdAt", "updatedAt")
        VALUES (${params.userId}, ${params.creditAuthorization.initialCredits}, NOW(), NOW())
        ON CONFLICT ("userId") DO NOTHING
      `;

      if (isAlreadyAuthorized) {
        const rows = await tx.$queryRaw<Array<{ balance: number }>>`
          SELECT "balance" FROM "UserCredits" WHERE "userId" = ${params.userId} LIMIT 1
        `;
        balance = Number(rows[0]?.balance ?? 0);
      } else {
        const updated = await tx.$queryRaw<Array<{ balance: number }>>`
          UPDATE "UserCredits"
          SET "balance" = "balance" - ${params.creditAuthorization.cost}, "updatedAt" = NOW()
          WHERE "userId" = ${params.userId}
            AND "balance" >= ${params.creditAuthorization.cost}
          RETURNING "balance"
        `;
        if (!updated.length) {
          const rows = await tx.$queryRaw<Array<{ balance: number }>>`
            SELECT "balance" FROM "UserCredits" WHERE "userId" = ${params.userId} LIMIT 1
          `;
          throw new LinkImportInsufficientCreditsError(
            Number(rows[0]?.balance ?? 0),
            params.creditAuthorization.cost
          );
        }
        balance = Number(updated[0].balance);
      }
    }

    if (!isAlreadyAuthorized) {
      await tx.$executeRaw`
        UPDATE "LinkImportJob"
        SET "creditAuthorizedAt" = ${now}, "updatedAt" = ${now}
        WHERE "userId" = ${params.userId} AND "noteId" = ${resolvedNoteId}
      `;
    }

    await logSyncChange({
      userId: params.userId,
      entityType: "note",
      entityId: resolvedNoteId,
      version: noteRows[0].version,
      serverUpdatedAt: noteRows[0].serverUpdatedAt,
      operation: "upsert"
    }, tx);

    return {
      balance,
      jobId: persistedJobId,
      status: persistedJobStatus,
      shouldScheduleWorker: true
    };
  }, {
    maxWait: 10_000,
    timeout: 30_000
  });

  if (transactionResult.shouldScheduleWorker) scheduleLinkImportWorker();
  return {
    jobId: transactionResult.jobId,
    status: transactionResult.status,
    balance: transactionResult.balance,
    tier: params.creditAuthorization.tier
  };
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
  while (true) {
    const staleBefore = new Date(Date.now() - JOB_PROCESSING_LEASE_MS);
    const result = await prisma.$transaction(async (tx) => {
      // Do not hold a job row lock while waiting for the per-user advisory
      // lock: sync-driven hard deletes take the advisory lock first and may
      // cascade into this table. The guarded UPDATE below is the actual claim.
      const candidates = await tx.$queryRaw<Array<{ id: string; userId: string }>>`
        SELECT "id", "userId"
        FROM "LinkImportJob"
        WHERE "attempts" < ${JOB_MAX_ATTEMPTS}
          AND (
            "status" = 'queued'
            OR (
              "status" = 'processing'
              AND ("startedAt" IS NULL OR "startedAt" <= ${staleBefore})
            )
          )
        ORDER BY "createdAt" ASC
        LIMIT 1
      `;
      const candidate = candidates[0];
      if (!candidate) return { hadCandidate: false, job: null };

      await acquireUserSyncTransactionLock(candidate.userId, tx);
      const jobs = await tx.$queryRaw<LinkImportJobRow[]>`
        UPDATE "LinkImportJob"
        SET "status" = 'processing',
            "attempts" = "attempts" + 1,
            "startedAt" = NOW(),
            "updatedAt" = NOW()
        WHERE "id" = ${candidate.id}
          AND "userId" = ${candidate.userId}
          AND "attempts" < ${JOB_MAX_ATTEMPTS}
          AND (
            "status" = 'queued'
            OR (
              "status" = 'processing'
              AND ("startedAt" IS NULL OR "startedAt" <= ${staleBefore})
            )
          )
        RETURNING
          "id",
          "userId",
          "noteId",
          "url",
          "status",
          "attempts",
          "showDescription",
          "showAuthor",
          "showHook",
          "showTranscript",
          "contentLocale"
      `;
      return { hadCandidate: true, job: jobs[0] ?? null };
    }, {
      maxWait: 10_000,
      timeout: 30_000
    });

    if (result.job || !result.hadCandidate) return result.job;
    // Another worker claimed the same unlocked candidate first. Re-read the
    // queue so this worker can move on to a different account's job.
  }
}

async function processJob(job: LinkImportJobRow): Promise<void> {
  try {
    const result = await buildImportedNote(job.url, {
      showDescription: job.showDescription,
      showAuthor: job.showAuthor,
      showHook: job.showHook,
      showTranscript: job.showTranscript
    }, job.contentLocale);
    await completeJob(job, result.content, result.source);
  } catch (error) {
    const failure = await failureDetailsForError(job, error);
    console.error("❌ Link import job failed:", {
      jobId: job.id,
      noteId: job.noteId,
      userId: job.userId,
      errorCode: failure.errorCode,
      error
    });
    await failJob(job, failure.errorCode, {
      content: failure.content,
      source: failure.source
    });
  }
}

async function completeJob(job: LinkImportJobRow, content: string, source: LinkImportSource): Promise<void> {
  const now = new Date();
  const noteMutationId = randomUUID();
  const updated = await prisma.$transaction(async (tx) => {
    await acquireUserSyncTransactionLock(job.userId, tx);
    const completedJobs = await tx.$executeRaw`
      UPDATE "LinkImportJob"
      SET "status" = 'completed',
          "errorCode" = NULL,
          "completedAt" = ${now},
          "updatedAt" = ${now}
      WHERE "id" = ${job.id}
        AND "userId" = ${job.userId}
        AND "status" = 'processing'
        AND "attempts" = ${job.attempts}
    `;
    if (completedJobs === 0) return null;

    const rows = await tx.$queryRaw<Array<{ version: number; serverUpdatedAt: Date }>>`
      UPDATE "Note"
      SET "content" = ${content},
          "updatedAt" = ${now},
          "serverUpdatedAt" = ${now},
          "version" = "version" + 1,
          "lastMutationId" = ${noteMutationId},
          "sourceURL" = ${source.url},
          "sourceTitle" = ${source.title},
          "sourcePlatformID" = ${source.platformID},
          "sourcePlatformName" = ${source.platformName},
          "sourceHost" = ${source.host},
          "sourceAuthorName" = COALESCE(${source.authorName ?? null}, "sourceAuthorName"),
          "sourceAuthorHandle" = COALESCE(${source.authorHandle ?? null}, "sourceAuthorHandle"),
          "sourceCapturedAt" = COALESCE("sourceCapturedAt", ${now}),
          "importStatus" = 'completed',
          "importJobId" = ${job.id},
          "importErrorCode" = NULL,
          "importCompletedAt" = ${now}
      WHERE "id" = ${job.noteId}
        AND "userId" = ${job.userId}
      RETURNING "version", "serverUpdatedAt"
    `;

    const note = rows[0];
    if (note) {
      await logSyncChange({
        userId: job.userId,
        entityType: "note",
        entityId: job.noteId,
        version: note.version,
        serverUpdatedAt: note.serverUpdatedAt,
        operation: "upsert"
      }, tx);
    }
    return note;
  }, {
    maxWait: 10_000,
    timeout: 30_000
  });

  if (updated) {
    try {
      await scheduleImportCompletionNotifications({
        jobId: job.id,
        userId: job.userId,
        noteId: job.noteId
      });
    } catch (error) {
      // A notification problem must never turn a successfully imported note
      // into a failed import.
      console.error("Failed to schedule import completion notification:", {
        jobId: job.id,
        error
      });
    }
  }
}

async function failJob(
  job: LinkImportJobRow,
  errorCode: string,
  fallback?: { content?: string; source?: LinkImportSource }
): Promise<void> {
  const now = new Date();
  const noteMutationId = randomUUID();
  await prisma.$transaction(async (tx) => {
    await acquireUserSyncTransactionLock(job.userId, tx);
    const failedJobs = await tx.$executeRaw`
      UPDATE "LinkImportJob"
      SET "status" = 'failed',
          "errorCode" = ${errorCode},
          "completedAt" = ${now},
          "updatedAt" = ${now}
      WHERE "id" = ${job.id}
        AND "userId" = ${job.userId}
        AND "status" = 'processing'
        AND "attempts" = ${job.attempts}
    `;
    if (failedJobs === 0) return;

    const rows = await tx.$queryRaw<Array<{ version: number; serverUpdatedAt: Date }>>`
      UPDATE "Note"
      SET "content" = COALESCE(${fallback?.content ?? null}, "content"),
          "updatedAt" = ${now},
          "serverUpdatedAt" = ${now},
          "version" = "version" + 1,
          "lastMutationId" = ${noteMutationId},
          "sourceURL" = COALESCE(${fallback?.source?.url ?? null}, "sourceURL"),
          "sourceTitle" = COALESCE(${fallback?.source?.title ?? null}, "sourceTitle"),
          "sourcePlatformID" = COALESCE(${fallback?.source?.platformID ?? null}, "sourcePlatformID"),
          "sourcePlatformName" = COALESCE(${fallback?.source?.platformName ?? null}, "sourcePlatformName"),
          "sourceHost" = COALESCE(${fallback?.source?.host ?? null}, "sourceHost"),
          "sourceAuthorName" = COALESCE(${fallback?.source?.authorName ?? null}, "sourceAuthorName"),
          "sourceAuthorHandle" = COALESCE(${fallback?.source?.authorHandle ?? null}, "sourceAuthorHandle"),
          "sourceCapturedAt" = COALESCE("sourceCapturedAt", ${now}),
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
      }, tx);
    }
  }, {
    maxWait: 10_000,
    timeout: 30_000
  });
}

async function failureDetailsForError(
  job: LinkImportJobRow,
  error: unknown
): Promise<LinkImportFailureDetails> {
  if (!isHandledTikTokTranscriptError(error)) {
    return { errorCode: "import_failed" };
  }

  const source = sourceFromTranscriptMetadata(job.url, error.metadata);
  const content = makeCreatorMediaUnavailableNote({
    description: source.title,
    author: creatorMediaAuthorLabel(source, job.contentLocale),
    mediaLinkSections: sectionsFromJob(job),
    contentLocale: job.contentLocale
  });

  return {
    errorCode: error.reason,
    content,
    source
  };
}

async function buildImportedNote(
  rawURL: string,
  mediaLinkSections: MediaLinkSections,
  contentLocale: LinkImportContentLocale
): Promise<{ content: string; source: LinkImportSource }> {
  const source = makeInitialLinkSource(rawURL);

  if (isSupportedMediaLinkURL(rawURL)) {
    const transcript = await transcribeMediaLinkURL(rawURL);
    if (transcript.available && transcript.text?.trim()) {
      const updatedSource = sourceFromTranscriptMetadata(rawURL, transcript.metadata);
      const content = await makeCreatorMediaTranscriptNote({
        description: updatedSource.title,
        author: creatorMediaAuthorLabel(updatedSource, contentLocale),
        transcript: transcript.text,
        mediaLinkSections,
        contentLocale
      });
      return { content, source: updatedSource };
    }

    const updatedSource = sourceFromTranscriptMetadata(rawURL, transcript.metadata);
    return {
      content: makeCreatorMediaUnavailableNote({
        description: updatedSource.title,
        author: creatorMediaAuthorLabel(updatedSource, contentLocale),
        mediaLinkSections,
        contentLocale
      }),
      source: updatedSource
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

function makeCreatorMediaUnavailableNote(params: {
  description: string;
  author: string;
  mediaLinkSections: MediaLinkSections;
  contentLocale: LinkImportContentLocale;
}): string {
  const sections = normalizeMediaLinkSections(params.mediaLinkSections);
  const strings = linkImportContentStrings(params.contentLocale);
  const content: string[] = [];

  if (sections.showDescription) {
    content.push(markdownSection(strings.descriptionHeading, params.description.trim() || strings.unavailable));
  }
  if (sections.showAuthor) {
    content.push(markdownSection(strings.authorHeading, params.author.trim() || strings.unknownAuthor));
  }
  if (sections.showHook) {
    content.push(markdownSection(strings.hookHeading, strings.unavailable));
  }
  if (sections.showTranscript) {
    content.push(markdownSection(strings.transcriptHeading, strings.unavailable));
  }

  return content.join("\n\n");
}

function sourceFromTranscriptMetadata(
  rawURL: string,
  metadata?: MediaLinkTranscriptMetadata
): LinkImportSource {
  const source = makeInitialLinkSource(rawURL);
  const title = metadata?.title?.trim();

  return {
    ...source,
    title: title || source.title,
    authorName: metadata?.authorName?.trim() || null,
    authorHandle: metadata?.authorHandle?.trim() || null
  };
}

async function makeCreatorMediaTranscriptNote(params: {
  description: string;
  author: string;
  transcript: string;
  mediaLinkSections: MediaLinkSections;
  contentLocale: LinkImportContentLocale;
}): Promise<string> {
  const cleanedTranscript = params.transcript.trim();
  const sections = normalizeMediaLinkSections(params.mediaLinkSections);
  const strings = linkImportContentStrings(params.contentLocale);

  if (!cleanedTranscript) {
    return makeCreatorMediaUnavailableNote({
      description: params.description,
      author: params.author,
      mediaLinkSections: sections,
      contentLocale: params.contentLocale
    });
  }

  const polishedTranscript = sections.showTranscript
    ? await polishCreatorMediaTranscript(cleanedTranscript)
    : cleanedTranscript;
  const content: string[] = [];

  if (sections.showDescription) {
    content.push(markdownSection(strings.descriptionHeading, params.description.trim() || strings.unavailable));
  }
  if (sections.showAuthor) {
    content.push(markdownSection(strings.authorHeading, params.author.trim() || strings.unknownAuthor));
  }
  if (sections.showHook) {
    content.push(markdownSection(strings.hookHeading, fallbackCreatorMediaHook(cleanedTranscript, strings.unavailable)));
  }
  if (sections.showTranscript) {
    content.push(markdownSection(strings.transcriptHeading, polishedTranscript));
  }

  return content.join("\n\n");
}

function sectionsFromJob(job: LinkImportJobRow): MediaLinkSections {
  return {
    showDescription: job.showDescription,
    showAuthor: job.showAuthor,
    showHook: job.showHook,
    showTranscript: job.showTranscript
  };
}

function creatorMediaAuthorLabel(
  source: LinkImportSource,
  contentLocale: LinkImportContentLocale
): string {
  const authorName = source.authorName?.trim();
  if (authorName) return authorName;

  const authorHandle = source.authorHandle?.trim().replace(/^@+/, "");
  return authorHandle ? `@${authorHandle}` : linkImportContentStrings(contentLocale).unknownAuthor;
}

function fallbackCreatorMediaHook(transcript: string, unavailable: string): string {
  const source = transcript.trim();
  const firstLine = source
    .split(/\r?\n/)
    .map((line) => line.trim())
    .find(Boolean) ?? source;

  const firstSentenceMatch = firstLine.match(/^.*?[.!?。！？]/u);
  const firstSentence = firstSentenceMatch?.[0] ?? firstLine;
  const collapsed = collapseWhitespace(firstSentence).trim();

  if (!collapsed) {
    return unavailable;
  }

  return collapsed.length <= 160 ? collapsed : `${collapsed.slice(0, 160).trim()}...`;
}

async function polishCreatorMediaTranscript(transcript: string): Promise<string> {
  const trimmed = transcript.trim();
  if (!GEMINI_API_KEY || !trimmed) {
    return trimmed;
  }

  const prompt = `
Polish this media transcript for a personal quick-capture note.

Raw transcript:
${trimmed.slice(0, 30_000)}
`.trim();

  const systemInstruction = `
You clean up audio/video transcripts for a personal notes app.

Return only the cleaned transcript text.
Keep the speaker's original language, meaning, order, and wording.
Add helpful punctuation and paragraph breaks.
Separate paragraphs with single line breaks. Never insert blank lines.
Clean obvious transcription noise when needed.
`.trim();

  try {
    const result = await generateGeminiText(prompt, systemInstruction, 90_000);
    return result.trim() || trimmed;
  } catch {
    return trimmed;
  }
}

async function generateGeminiText(
  prompt: string,
  systemInstruction: string,
  timeout: number
): Promise<string> {
  const body = {
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    systemInstruction: {
      parts: [{ text: systemInstruction }]
    }
  };

  const response = await fetch(buildGeminiGenerateContentURL(GEMINI_MODEL), {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
    timeout
  });

  if (!response.ok) {
    throw new Error(`Gemini generate failed: ${response.status}`);
  }

  const data = await response.json() as any;
  return String(data.candidates?.[0]?.content?.parts?.[0]?.text ?? "");
}

export function normalizeTranscriptParagraphs(body: string): string {
  return body
    .trim()
    .replace(/\r\n?/g, "\n")
    .replace(/[\u2028\u2029]/g, "\n")
    .replace(/\n[\t ]*\n+/g, "\n");
}

function markdownSection(heading: string, body: string): string {
  const compactBody = normalizeTranscriptParagraphs(body);
  return `## ${heading}\n${compactBody}`;
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
Turn this ${params.kind} into a useful ChillScript note.

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

function collapseWhitespace(text: string): string {
  return text.replace(/\s+/g, " ");
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
