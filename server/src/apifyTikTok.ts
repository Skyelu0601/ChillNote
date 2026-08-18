import { randomUUID } from "node:crypto";
import fetch, { type RequestInit, type Response } from "node-fetch";
import { z } from "zod";

const APIFY_API_BASE_URL = "https://api.apify.com/v2";
const TERMINAL_RUN_STATUSES = new Set(["SUCCEEDED", "FAILED", "ABORTED", "TIMED-OUT"]);

const apifyRunSchema = z.object({
  id: z.string().min(1),
  status: z.string().min(1),
  defaultDatasetId: z.string().min(1).optional().nullable(),
  defaultKeyValueStoreId: z.string().min(1).optional().nullable(),
  defaultRequestQueueId: z.string().min(1).optional().nullable()
}).passthrough();

const apifyRunResponseSchema = z.object({
  data: apifyRunSchema
});

const apifyVideoItemSchema = z.object({
  id: z.union([z.string(), z.number()]).optional().nullable(),
  error: z.string().optional().nullable(),
  errorCode: z.string().optional().nullable(),
  mediaUrls: z.array(z.string().url()).optional().nullable(),
  videoMeta: z.object({
    duration: z.number().nonnegative().optional().nullable(),
    downloadAddr: z.string().url().optional().nullable()
  }).passthrough().optional().nullable()
}).passthrough();

const apifyStoreListSchema = z.object({
  data: z.object({
    items: z.array(z.object({
      id: z.string().min(1),
      name: z.string().optional().nullable()
    }).passthrough())
  }).passthrough()
});

type ApifyRun = z.infer<typeof apifyRunSchema>;

export type ApifyTikTokMedia = {
  bytes: Buffer;
  mimeType: string;
  fileName?: string;
  durationSec?: number;
};

export type ApifyTikTokOptions = {
  token: string;
  actorID: string;
  timeoutMs: number;
  maxBytes: number;
  maxTotalChargeUSD: number;
};

export type ApifyTikTokDatasetResult = {
  mediaURL: string;
  videoID?: string;
  durationSec?: number;
};

export function parseApifyTikTokDataset(payload: unknown): ApifyTikTokDatasetResult {
  const items = z.array(apifyVideoItemSchema).parse(payload);
  const item = items[0];
  if (!item) {
    throw new Error("Apify returned no TikTok result");
  }
  if (item.error || item.errorCode) {
    throw new Error(`Apify TikTok result failed: ${item.errorCode || item.error || "unknown"}`);
  }

  const mediaURL = item.mediaUrls?.[0] || item.videoMeta?.downloadAddr;
  if (!mediaURL) {
    throw new Error("Apify TikTok result did not include downloadable media");
  }

  return {
    mediaURL,
    videoID: item.id == null ? undefined : String(item.id),
    durationSec: item.videoMeta?.duration ?? undefined
  };
}

export function extractApifyStoreID(mediaURL: string): string | undefined {
  try {
    const parsed = new URL(mediaURL);
    if (parsed.protocol !== "https:" || parsed.hostname !== "api.apify.com") {
      return undefined;
    }
    const match = parsed.pathname.match(/^\/v2\/key-value-stores\/([^/]+)\/records\//);
    return match?.[1] ? decodeURIComponent(match[1]) : undefined;
  } catch {
    return undefined;
  }
}

export function shouldSendApifyAuthorization(mediaURL: string): boolean {
  try {
    const parsed = new URL(mediaURL);
    return parsed.protocol === "https:" && parsed.hostname === "api.apify.com";
  } catch {
    return false;
  }
}

export function isTrustedApifyMediaURL(mediaURL: string): boolean {
  try {
    const parsed = new URL(mediaURL);
    if (parsed.protocol !== "https:") {
      return false;
    }
    const hostname = parsed.hostname.toLowerCase();
    return hostname === "api.apify.com" || [
      "tiktok.com",
      "tiktokcdn.com",
      "tiktokcdn-us.com",
      "tiktokv.com",
      "byteoversea.com"
    ].some((domain) => hostname === domain || hostname.endsWith(`.${domain}`));
  } catch {
    return false;
  }
}

export function makeApifyMediaRequestHeaders(
  mediaURL: string,
  token: string
): Record<string, string> {
  return {
    "User-Agent": "ChillNote-Media-Worker/1.0",
    Accept: "*/*",
    ...(shouldSendApifyAuthorization(mediaURL)
      ? { Authorization: `Bearer ${token}` }
      : {})
  };
}

export async function downloadTikTokVideoWithApify(
  sourceURL: string,
  options: ApifyTikTokOptions
): Promise<ApifyTikTokMedia> {
  const token = options.token.trim();
  if (!token) {
    throw new Error("Apify token is missing");
  }

  const storeName = `chillnote-tiktok-${randomUUID()}`;
  const deadline = Date.now() + Math.max(1_000, options.timeoutMs);
  let run: ApifyRun | undefined;
  let mediaURL: string | undefined;

  try {
    run = await startApifyRun(sourceURL, storeName, options, deadline);
    run = await waitForApifyRun(run, options, deadline);
    if (run.status !== "SUCCEEDED") {
      throw new Error(`Apify TikTok run ended with status ${run.status}`);
    }
    if (!run.defaultDatasetId) {
      throw new Error("Apify TikTok run did not provide a dataset");
    }

    const dataset = await apifyJSON(
      `/datasets/${encodeURIComponent(run.defaultDatasetId)}/items?clean=true&limit=1`,
      options,
      deadline
    );
    const resolved = parseApifyTikTokDataset(dataset);
    mediaURL = resolved.mediaURL;
    const downloaded = await downloadApifyMedia(mediaURL, options, deadline);

    return {
      ...downloaded,
      fileName: fileNameFromMediaURL(mediaURL, resolved.videoID),
      durationSec: resolved.durationSec
    };
  } finally {
    await cleanupApifyRun(run, storeName, mediaURL, options);
  }
}

async function startApifyRun(
  sourceURL: string,
  storeName: string,
  options: ApifyTikTokOptions,
  deadline: number
): Promise<ApifyRun> {
  const actorID = normalizeActorID(options.actorID);
  const query = new URLSearchParams({
    maxItems: "1",
    maxTotalChargeUsd: String(options.maxTotalChargeUSD),
    restartOnError: "false"
  });
  const payload = await apifyJSON(
    `/acts/${actorID}/runs?${query.toString()}`,
    options,
    deadline,
    {
      method: "POST",
      body: JSON.stringify({
        postURLs: [sourceURL],
        scrapeRelatedVideos: false,
        shouldDownloadVideos: true,
        shouldDownloadCovers: false,
        shouldDownloadSlideshowImages: false,
        downloadSubtitlesOptions: "NEVER_DOWNLOAD_SUBTITLES",
        videoKvStoreIdOrName: storeName
      })
    }
  );
  return apifyRunResponseSchema.parse(payload).data;
}

async function waitForApifyRun(
  initialRun: ApifyRun,
  options: ApifyTikTokOptions,
  deadline: number
): Promise<ApifyRun> {
  let run = initialRun;
  while (!TERMINAL_RUN_STATUSES.has(run.status)) {
    const remainingMs = deadline - Date.now();
    if (remainingMs <= 0) {
      throw new Error("Apify TikTok run timed out");
    }

    const waitSeconds = Math.max(1, Math.min(30, Math.floor(remainingMs / 1_000)));
    const payload = await apifyJSON(
      `/actor-runs/${encodeURIComponent(run.id)}?waitForFinish=${waitSeconds}`,
      options,
      deadline
    );
    run = apifyRunResponseSchema.parse(payload).data;
  }
  return run;
}

async function downloadApifyMedia(
  mediaURL: string,
  options: ApifyTikTokOptions,
  deadline: number
): Promise<{ bytes: Buffer; mimeType: string }> {
  if (!isTrustedApifyMediaURL(mediaURL)) {
    throw new Error("Apify returned an untrusted media URL");
  }
  const headers = makeApifyMediaRequestHeaders(mediaURL, options.token);
  const response = await fetchWithDeadline(
    mediaURL,
    options,
    deadline,
    { headers },
    false
  );
  if (!response.ok) {
    throw new Error(`Apify media HTTP ${response.status}`);
  }

  const declaredLength = Number(response.headers.get("content-length") || "0");
  if (declaredLength > options.maxBytes) {
    throw new Error(`Apify media exceeded ${options.maxBytes} bytes`);
  }

  const chunks: Buffer[] = [];
  let byteLength = 0;
  const responseBody = response.body as any;
  for await (const chunk of responseBody) {
    const bytes = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    byteLength += bytes.byteLength;
    if (byteLength > options.maxBytes) {
      responseBody.destroy?.();
      throw new Error(`Apify media exceeded ${options.maxBytes} bytes`);
    }
    chunks.push(bytes);
  }

  return {
    bytes: Buffer.concat(chunks, byteLength),
    mimeType: response.headers.get("content-type")?.split(";")[0]?.trim() || "video/mp4"
  };
}

async function cleanupApifyRun(
  run: ApifyRun | undefined,
  storeName: string,
  mediaURL: string | undefined,
  options: ApifyTikTokOptions
): Promise<void> {
  if (run && !TERMINAL_RUN_STATUSES.has(run.status)) {
    await bestEffortApifyRequest(
      `/actor-runs/${encodeURIComponent(run.id)}/abort`,
      options,
      { method: "POST" }
    );
  }

  const mediaStoreID = mediaURL
    ? extractApifyStoreID(mediaURL)
    : await findApifyStoreID(storeName, options);
  const keyValueStoreIDs = new Set([
    mediaStoreID,
    run?.defaultKeyValueStoreId ?? undefined
  ].filter((value): value is string => Boolean(value)));

  const cleanupRequests: Promise<void>[] = [];
  for (const storeID of keyValueStoreIDs) {
    cleanupRequests.push(bestEffortApifyRequest(
      `/key-value-stores/${encodeURIComponent(storeID)}`,
      options,
      { method: "DELETE" }
    ));
  }
  if (run?.defaultDatasetId) {
    cleanupRequests.push(bestEffortApifyRequest(
      `/datasets/${encodeURIComponent(run.defaultDatasetId)}`,
      options,
      { method: "DELETE" }
    ));
  }
  if (run?.defaultRequestQueueId) {
    cleanupRequests.push(bestEffortApifyRequest(
      `/request-queues/${encodeURIComponent(run.defaultRequestQueueId)}`,
      options,
      { method: "DELETE" }
    ));
  }
  await Promise.all(cleanupRequests);
  if (run?.id) {
    await bestEffortApifyRequest(
      `/actor-runs/${encodeURIComponent(run.id)}`,
      options,
      { method: "DELETE" }
    );
  }
}

async function findApifyStoreID(
  storeName: string,
  options: ApifyTikTokOptions
): Promise<string | undefined> {
  try {
    const payload = await apifyJSON(
      "/key-value-stores?limit=100&desc=1&ownership=ownedByMe",
      options,
      Date.now() + Math.min(15_000, options.timeoutMs)
    );
    const stores = apifyStoreListSchema.parse(payload).data.items;
    return stores.find((store) => store.name === storeName)?.id;
  } catch {
    return undefined;
  }
}

async function bestEffortApifyRequest(
  path: string,
  options: ApifyTikTokOptions,
  init?: RequestInit
): Promise<void> {
  try {
    await fetchWithDeadline(
      `${APIFY_API_BASE_URL}${path}`,
      options,
      Date.now() + Math.min(15_000, options.timeoutMs),
      init
    );
  } catch {
    // Cleanup is deliberately best-effort and must not hide the transcription result.
  }
}

async function apifyJSON(
  path: string,
  options: ApifyTikTokOptions,
  deadline: number,
  init?: RequestInit
): Promise<unknown> {
  const response = await fetchWithDeadline(`${APIFY_API_BASE_URL}${path}`, options, deadline, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(init?.headers || {})
    }
  });
  if (!response.ok) {
    throw new Error(`Apify HTTP ${response.status}`);
  }
  return await response.json();
}

async function fetchWithDeadline(
  url: string,
  options: ApifyTikTokOptions,
  deadline: number,
  init?: RequestInit,
  includeAuthorization = true
): Promise<Response> {
  const remainingMs = deadline - Date.now();
  if (remainingMs <= 0) {
    throw new Error("Apify TikTok request timed out");
  }

  return await fetch(url, {
    ...init,
    headers: {
      ...(includeAuthorization ? { Authorization: `Bearer ${options.token}` } : {}),
      ...(init?.headers || {})
    },
    timeout: remainingMs
  });
}

function normalizeActorID(actorID: string): string {
  const normalized = actorID.trim();
  if (!/^[A-Za-z0-9_-]+~[A-Za-z0-9_-]+$/.test(normalized)) {
    throw new Error("Apify actor ID is invalid");
  }
  return normalized;
}

function fileNameFromMediaURL(mediaURL: string, videoID?: string): string {
  try {
    const name = decodeURIComponent(new URL(mediaURL).pathname.split("/").pop() || "").trim();
    if (name && /\.[A-Za-z0-9]{2,5}$/.test(name)) {
      return name;
    }
  } catch {
    // Fall through to a stable local filename.
  }
  return `tiktok-${videoID || "video"}.mp4`;
}
