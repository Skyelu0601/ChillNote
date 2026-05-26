import fetch from "node-fetch";
import { randomUUID } from "node:crypto";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { promises as fs } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { z } from "zod";

const execFileAsync = promisify(execFile);

const GEMINI_MODEL = process.env.GEMINI_MODEL?.trim() || "gemini-3.1-flash-lite";
const GEMINI_API_KEY = process.env.GEMINI_API_KEY?.trim() || "";
const MEDIA_LINK_RESOLVER_URL =
  process.env.MEDIA_LINK_TRANSCRIPT_RESOLVER_URL?.trim()
  || process.env.TIKTOK_TRANSCRIPT_RESOLVER_URL?.trim()
  || "";
const MEDIA_LINK_RESOLVER_TOKEN =
  process.env.MEDIA_LINK_TRANSCRIPT_RESOLVER_TOKEN?.trim()
  || process.env.TIKTOK_TRANSCRIPT_RESOLVER_TOKEN?.trim()
  || "";
const MEDIA_LINK_YTDLP_BIN =
  process.env.MEDIA_LINK_YTDLP_BIN?.trim()
  || process.env.TIKTOK_YTDLP_BIN?.trim()
  || "yt-dlp";
const MEDIA_LINK_FFMPEG_BIN =
  process.env.MEDIA_LINK_FFMPEG_BIN?.trim()
  || process.env.TIKTOK_FFMPEG_BIN?.trim()
  || "ffmpeg";
const MEDIA_LINK_USE_YTDLP =
  process.env.MEDIA_LINK_TRANSCRIPT_USE_YTDLP
  ?? process.env.TIKTOK_TRANSCRIPT_USE_YTDLP
  ?? "true";
const MEDIA_LINK_EXTRACT_AUDIO =
  process.env.MEDIA_LINK_TRANSCRIPT_EXTRACT_AUDIO
  ?? process.env.TIKTOK_TRANSCRIPT_EXTRACT_AUDIO
  ?? "true";
const MEDIA_LINK_DOWNLOAD_TIMEOUT_MS = Number(
  process.env.MEDIA_LINK_TRANSCRIPT_DOWNLOAD_TIMEOUT_MS
  ?? process.env.TIKTOK_TRANSCRIPT_DOWNLOAD_TIMEOUT_MS
  ?? 90_000
);
const MEDIA_LINK_RESOLVER_TIMEOUT_MS = Number(
  process.env.MEDIA_LINK_TRANSCRIPT_RESOLVER_TIMEOUT_MS
  ?? process.env.TIKTOK_TRANSCRIPT_RESOLVER_TIMEOUT_MS
  ?? 45_000
);
const MEDIA_LINK_TRANSCRIBE_TIMEOUT_MS = Number(
  process.env.MEDIA_LINK_TRANSCRIPT_TIMEOUT_MS
  ?? process.env.TIKTOK_TRANSCRIPT_TIMEOUT_MS
  ?? 180_000
);
const MEDIA_LINK_MAX_MEDIA_MB = Number(
  process.env.MEDIA_LINK_TRANSCRIPT_MAX_MEDIA_MB
  ?? process.env.TIKTOK_TRANSCRIPT_MAX_MEDIA_MB
  ?? 100
);

const mediaOEmbedSchema = z.object({
  title: z.string().optional().nullable(),
  author_name: z.string().optional().nullable(),
  author_url: z.string().optional().nullable(),
  author_unique_id: z.string().optional().nullable(),
  html: z.string().optional().nullable()
});

const resolverResponseSchema = z.object({
  mediaURL: z.string().url().optional(),
  mediaBase64: z.string().min(1).optional(),
  mimeType: z.string().min(1).optional(),
  fileName: z.string().min(1).optional(),
  title: z.string().optional(),
  authorName: z.string().optional(),
  durationSec: z.number().nonnegative().optional()
});

type MediaLinkTranscriptReason =
  | "invalid_tiktok_url"
  | "resolver_not_configured"
  | "short_link_resolve_failed"
  | "metadata_fetch_failed"
  | "media_fetch_failed"
  | "media_too_large"
  | "transcription_timeout"
  | "transcription_failed"
  | "private_or_unavailable_video"
  | "rate_limited"
  | "server_configuration_error";

type MediaLinkMetadata = {
  platform: MediaLinkPlatform;
  title?: string;
  authorName?: string;
  authorURL?: string;
  authorUniqueID?: string;
  videoID?: string;
};

type MediaLinkPlatform = "tiktok" | "youtube" | "instagram";

type PreparedMedia = {
  bytes: Buffer;
  mimeType: string;
  fileName?: string;
  cleanupPaths?: string[];
  durationSec?: number;
};

type YtDlpCaptionFormat = {
  ext?: string;
  url?: string;
  name?: string;
};

type YtDlpInfo = {
  subtitles?: Record<string, YtDlpCaptionFormat[]>;
  automatic_captions?: Record<string, YtDlpCaptionFormat[]>;
};

export type MediaLinkTranscriptResponse = {
  available: boolean;
  text: string | null;
  reason: MediaLinkTranscriptReason | null;
  metadata?: {
    resolvedURL: string;
    videoID?: string;
    title?: string;
    authorName?: string;
    durationSec?: number;
    mimeType?: string;
  };
};

class MediaLinkTranscriptError extends Error {
  reason: MediaLinkTranscriptReason;

  constructor(reason: MediaLinkTranscriptReason, message?: string) {
    super(message ?? reason);
    this.reason = reason;
  }
}

export async function transcribeMediaLinkURL(rawURL: string): Promise<MediaLinkTranscriptResponse> {
  if (!GEMINI_API_KEY) {
    throw new MediaLinkTranscriptError("server_configuration_error", "GEMINI_API_KEY is not configured");
  }

  const platform = detectMediaLinkPlatform(rawURL);
  if (!platform) {
    throw new MediaLinkTranscriptError("invalid_tiktok_url");
  }

  const resolvedURL = await resolveMediaLinkURL(rawURL, platform);
  const metadata = await fetchMediaLinkMetadata(resolvedURL, platform);

  const caption = await fetchMediaCaptionTranscript(resolvedURL);
  if (caption) {
    return {
      available: true,
      text: caption.text,
      reason: null,
      metadata: {
        resolvedURL,
        videoID: metadata.videoID,
        title: metadata.title,
        authorName: metadata.authorName,
        mimeType: caption.mimeType
      }
    };
  }

  const media = await prepareMediaLinkMedia(resolvedURL, metadata);

  try {
    const text = await transcribeMedia(media.bytes, media.mimeType, metadata);
    const trimmed = text.trim();
    if (!trimmed) {
      throw new MediaLinkTranscriptError("transcription_failed", "Transcript is empty");
    }

    return {
      available: true,
      text: trimmed,
      reason: null,
      metadata: {
        resolvedURL,
        videoID: metadata.videoID,
        title: metadata.title,
        authorName: metadata.authorName,
        durationSec: media.durationSec,
        mimeType: media.mimeType
      }
    };
  } finally {
    await cleanupTemporaryFiles(media.cleanupPaths);
  }
}

export function isTikTokURL(rawURL: string): boolean {
  return detectMediaLinkPlatform(rawURL) === "tiktok";
}

export function isSupportedMediaLinkURL(rawURL: string): boolean {
  return detectMediaLinkPlatform(rawURL) != null;
}

export async function transcribeTikTokURL(rawURL: string): Promise<MediaLinkTranscriptResponse> {
  if (!isTikTokURL(rawURL)) {
    throw new MediaLinkTranscriptError("invalid_tiktok_url");
  }

  return await transcribeMediaLinkURL(rawURL);
}

function detectMediaLinkPlatform(rawURL: string): MediaLinkPlatform | null {
  try {
    const url = new URL(rawURL);
    if (!["http:", "https:"].includes(url.protocol)) return null;

    const host = url.hostname.toLowerCase().replace(/^www\./, "");
    if (host === "tiktok.com" || host.endsWith(".tiktok.com")) {
      return "tiktok";
    }
    if (
      host === "youtube.com"
      || host.endsWith(".youtube.com")
      || host === "youtu.be"
      || host === "youtube-nocookie.com"
      || host.endsWith(".youtube-nocookie.com")
    ) {
      return "youtube";
    }
    if (host === "instagram.com" || host.endsWith(".instagram.com")) {
      return "instagram";
    }
    return null;
  } catch {
    return null;
  }
}

export function isHandledTikTokTranscriptError(error: unknown): error is MediaLinkTranscriptError {
  return error instanceof MediaLinkTranscriptError;
}

function buildGeminiGenerateContentURL(model: string): string {
  const encodedModel = encodeURIComponent(model);
  const encodedApiKey = encodeURIComponent(GEMINI_API_KEY);
  return `https://generativelanguage.googleapis.com/v1beta/models/${encodedModel}:generateContent?key=${encodedApiKey}`;
}

async function resolveMediaLinkURL(rawURL: string, platform: MediaLinkPlatform): Promise<string> {
  const url = new URL(rawURL);
  const normalizedHost = url.hostname.toLowerCase().replace(/^www\./, "");
  const needsRedirectResolution = (
    platform === "tiktok" && (normalizedHost === "vm.tiktok.com" || normalizedHost === "vt.tiktok.com")
  ) || normalizedHost === "youtu.be";

  if (!needsRedirectResolution) {
    return url.toString();
  }

  try {
    const response = await fetch(url.toString(), {
      redirect: "follow",
      headers: makeBrowserHeaders(),
      timeout: 15_000
    });
    return response.url || url.toString();
  } catch (error) {
    throw new MediaLinkTranscriptError("short_link_resolve_failed", String(error));
  }
}

async function fetchMediaLinkMetadata(url: string, platform: MediaLinkPlatform): Promise<MediaLinkMetadata> {
  if (platform === "tiktok") {
    return await fetchTikTokMetadata(url);
  }
  if (platform === "youtube") {
    return await fetchYouTubeMetadata(url);
  }

  return {
    platform,
    videoID: extractVideoIDFromURL(url, platform)
  };
}

async function fetchTikTokMetadata(url: string): Promise<MediaLinkMetadata> {
  try {
    const oembedURL = new URL("https://www.tiktok.com/oembed");
    oembedURL.searchParams.set("url", url);

    const response = await fetch(oembedURL.toString(), {
      headers: {
        ...makeBrowserHeaders(),
        Accept: "application/json"
      },
      timeout: 15_000
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const json = mediaOEmbedSchema.parse(await response.json());
    const videoID = extractVideoIDFromURL(url, "tiktok") ?? extractVideoIDFromEmbedHTML(json.html ?? undefined);

    return {
      platform: "tiktok",
      title: normalizeOptionalString(json.title),
      authorName: normalizeOptionalString(json.author_name),
      authorURL: normalizeOptionalString(json.author_url),
      authorUniqueID: normalizeOptionalString(json.author_unique_id),
      videoID
    };
  } catch (error) {
    throw new MediaLinkTranscriptError("metadata_fetch_failed", String(error));
  }
}

async function fetchYouTubeMetadata(url: string): Promise<MediaLinkMetadata> {
  try {
    const oembedURL = new URL("https://www.youtube.com/oembed");
    oembedURL.searchParams.set("url", url);
    oembedURL.searchParams.set("format", "json");

    const response = await fetch(oembedURL.toString(), {
      headers: {
        ...makeBrowserHeaders(),
        Accept: "application/json"
      },
      timeout: 15_000
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const json = mediaOEmbedSchema.parse(await response.json());
    return {
      platform: "youtube",
      title: normalizeOptionalString(json.title),
      authorName: normalizeOptionalString(json.author_name),
      authorURL: normalizeOptionalString(json.author_url),
      videoID: extractVideoIDFromURL(url, "youtube")
    };
  } catch (error) {
    throw new MediaLinkTranscriptError("metadata_fetch_failed", String(error));
  }
}

async function prepareMediaLinkMedia(url: string, metadata: MediaLinkMetadata): Promise<PreparedMedia> {
  if (MEDIA_LINK_RESOLVER_URL) {
    return await prepareMediaWithResolver(url, metadata.videoID, metadata.platform);
  }

  if (MEDIA_LINK_USE_YTDLP !== "false") {
    return await prepareMediaWithYtDlp(url, metadata.platform);
  }

  throw new MediaLinkTranscriptError("resolver_not_configured");
}

async function prepareMediaWithResolver(
  url: string,
  videoID: string | undefined,
  platform: MediaLinkPlatform
): Promise<PreparedMedia> {
  try {
    const headers: Record<string, string> = {
      "Content-Type": "application/json"
    };
    if (MEDIA_LINK_RESOLVER_TOKEN) {
      headers.Authorization = `Bearer ${MEDIA_LINK_RESOLVER_TOKEN}`;
    }

    const response = await fetch(MEDIA_LINK_RESOLVER_URL, {
      method: "POST",
      headers,
      body: JSON.stringify({ url, videoID, platform }),
      timeout: MEDIA_LINK_RESOLVER_TIMEOUT_MS
    });

    if (!response.ok) {
      throw new Error(`Resolver HTTP ${response.status}`);
    }

    const payload = resolverResponseSchema.parse(await response.json());
    if (payload.mediaBase64) {
      const bytes = Buffer.from(payload.mediaBase64, "base64");
      assertMediaSize(bytes.byteLength);
      const prepared: PreparedMedia = {
        bytes,
        mimeType: payload.mimeType || "video/mp4",
        fileName: payload.fileName,
        durationSec: payload.durationSec
      };
      if (MEDIA_LINK_EXTRACT_AUDIO !== "false" && prepared.mimeType.startsWith("video/")) {
        const extracted = await maybeExtractAudio(prepared, undefined, platform);
        extracted.durationSec = payload.durationSec;
        return extracted;
      }
      return prepared;
    }

    if (payload.mediaURL) {
      const download = await downloadMediaFromURL(payload.mediaURL, payload.mimeType, payload.fileName);
      download.durationSec = payload.durationSec;
      if (MEDIA_LINK_EXTRACT_AUDIO !== "false" && download.mimeType.startsWith("video/")) {
        return await maybeExtractAudio(download, undefined, platform);
      }
      return download;
    }

    throw new Error("Resolver response did not include media");
  } catch (error) {
    throw new MediaLinkTranscriptError("media_fetch_failed", String(error));
  }
}

async function prepareMediaWithYtDlp(url: string, platform: MediaLinkPlatform): Promise<PreparedMedia> {
  const tempBase = join(tmpdir(), `chillnote-${platform}-${randomUUID()}`);
  const audioTemplate = `${tempBase}.%(ext)s`;
  try {
    const downloadedAudio = await downloadWithYtDlp(url, [
      "--no-playlist",
      "--no-warnings",
      "--restrict-filenames",
      "-f",
      "ba[ext=m4a]/ba/bestaudio/best",
      "-o",
      audioTemplate,
      "--print",
      "after_move:filepath",
      url
    ]);

    const audioBuffer = await readFileWithLimit(downloadedAudio.filePath);
    return {
      bytes: audioBuffer,
      mimeType: mimeTypeForFile(downloadedAudio.filePath),
      fileName: downloadedAudio.fileName,
      cleanupPaths: [downloadedAudio.filePath]
    };
  } catch (audioError) {
    try {
      const videoTemplate = `${tempBase}-video.%(ext)s`;
      const downloadedVideo = await downloadWithYtDlp(url, [
        "--no-playlist",
        "--no-warnings",
        "--restrict-filenames",
        "-f",
        "mp4/best",
        "-o",
        videoTemplate,
        "--print",
        "after_move:filepath",
        url
      ]);

      const videoPrepared: PreparedMedia = {
        bytes: await readFileWithLimit(downloadedVideo.filePath),
        mimeType: mimeTypeForFile(downloadedVideo.filePath),
        fileName: downloadedVideo.fileName,
        cleanupPaths: [downloadedVideo.filePath]
      };

      if (MEDIA_LINK_EXTRACT_AUDIO === "false" || !videoPrepared.mimeType.startsWith("video/")) {
        return videoPrepared;
      }

      return await maybeExtractAudio(videoPrepared, downloadedVideo.filePath, platform);
    } catch (videoError) {
      const message = [String(audioError), String(videoError)].join(" | ");
      throw new MediaLinkTranscriptError("media_fetch_failed", message);
    }
  }
}

async function fetchMediaCaptionTranscript(url: string): Promise<{ text: string; mimeType: string } | null> {
  if (MEDIA_LINK_USE_YTDLP === "false") {
    return null;
  }

  try {
    const info = await dumpYtDlpInfo(url);
    const caption = selectBestCaption(info);
    if (!caption?.url) {
      return null;
    }

    const rawCaption = await downloadCaptionText(caption.url);
    const ext = caption.ext?.toLowerCase();
    const transcript = parseCaptionText(rawCaption, ext);
    const normalized = normalizeCaptionTranscript(transcript);

    return normalized
      ? { text: normalized, mimeType: mimeTypeForCaptionExtension(ext) }
      : null;
  } catch {
    return null;
  }
}

async function dumpYtDlpInfo(url: string): Promise<YtDlpInfo> {
  const { stdout } = await execFileAsync(MEDIA_LINK_YTDLP_BIN, [
    "--dump-json",
    "--skip-download",
    "--no-playlist",
    "--no-warnings",
    url
  ], {
    timeout: MEDIA_LINK_DOWNLOAD_TIMEOUT_MS,
    maxBuffer: 16 * 1024 * 1024
  });

  return JSON.parse(stdout) as YtDlpInfo;
}

function selectBestCaption(info: YtDlpInfo): YtDlpCaptionFormat | null {
  const captionGroups = [
    info.subtitles ?? {},
    info.automatic_captions ?? {}
  ];
  const preferredLanguages = ["en", "en-US", "en-GB", "zh-Hans", "zh-Hant", "zh", "ja", "ko", "es", "fr", "de"];

  for (const captions of captionGroups) {
    const exactLanguage = preferredLanguages
      .map((language) => captions[language])
      .find((formats) => formats?.length);
    const fallbackLanguage = Object.entries(captions)
      .find(([language, formats]) => formats?.length && preferredLanguages.some((preferred) => language.startsWith(preferred)))?.[1];
    const anyLanguage = Object.values(captions).find((formats) => formats?.length);

    const selectedFormats = exactLanguage ?? fallbackLanguage ?? anyLanguage;
    const selected = selectBestCaptionFormat(selectedFormats ?? []);
    if (selected) {
      return selected;
    }
  }

  return null;
}

function selectBestCaptionFormat(formats: YtDlpCaptionFormat[]): YtDlpCaptionFormat | null {
  const preferredFormats = ["json3", "vtt", "ttml", "srv3", "srv2", "srv1"];
  for (const ext of preferredFormats) {
    const match = formats.find((format) => format.ext?.toLowerCase() === ext && format.url);
    if (match) return match;
  }
  return formats.find((format) => format.url) ?? null;
}

function parseCaptionText(raw: string, ext?: string): string {
  switch (ext) {
    case "json3":
      return parseYouTubeJSON3Caption(raw);
    case "ttml":
    case "srv3":
    case "srv2":
    case "srv1":
      return parseXMLCaption(raw);
    case "vtt":
    default:
      return parseWebVTTCaption(raw);
  }
}

function mimeTypeForCaptionExtension(ext?: string): string {
  switch (ext) {
    case "json3":
      return "application/json";
    case "ttml":
    case "srv3":
    case "srv2":
    case "srv1":
      return "application/xml";
    case "vtt":
    default:
      return "text/vtt";
  }
}

async function downloadCaptionText(captionURL: string): Promise<string> {
  const abortController = new AbortController();
  const timeoutId = setTimeout(() => abortController.abort(), MEDIA_LINK_DOWNLOAD_TIMEOUT_MS);

  try {
    const response = await fetch(captionURL, {
      headers: makeBrowserHeaders(),
      signal: abortController.signal as any
    });
    if (!response.ok) {
      throw new Error(`Caption HTTP ${response.status}`);
    }
    return await response.text();
  } finally {
    clearTimeout(timeoutId);
  }
}

function parseYouTubeJSON3Caption(raw: string): string {
  try {
    const parsed = JSON.parse(raw);
    const events = Array.isArray(parsed?.events) ? parsed.events : [];
    const cueTexts = events
      .map((event: any) => {
        const segments = Array.isArray(event?.segs) ? event.segs : [];
        return segments
          .map((segment: any) => typeof segment?.utf8 === "string" ? segment.utf8 : "")
          .join("");
      });

    return dedupeAdjacentCaptionCues(cueTexts).join(" ");
  } catch {
    return "";
  }
}

function parseWebVTTCaption(raw: string): string {
  const cueTexts = raw
    .split(/\r?\n\r?\n/)
    .map((block) => {
      const lines = block
        .split(/\r?\n/)
        .map((line) => line.trim())
        .filter(Boolean);
      if (!lines.some((line) => line.includes("-->"))) {
        return "";
      }

      return lines
        .filter((line) => !line.includes("-->"))
        .filter((line) => !/^\d+$/.test(line))
        .join(" ");
    });

  return dedupeAdjacentCaptionCues(cueTexts).join(" ");
}

function parseXMLCaption(raw: string): string {
  const cueTexts = Array.from(raw.matchAll(/<text\b[^>]*>([\s\S]*?)<\/text>/gi))
    .map((match) => decodeCaptionEntities(match[1] ?? "").replace(/<[^>]+>/g, " "));

  if (cueTexts.length) {
    return dedupeAdjacentCaptionCues(cueTexts).join(" ");
  }

  return decodeCaptionEntities(raw.replace(/<[^>]+>/g, " "));
}

function decodeCaptionEntities(text: string): string {
  return text
    .replace(/&#x([0-9a-f]+);/gi, (_, hex: string) => String.fromCodePoint(parseInt(hex, 16)))
    .replace(/&#(\d+);/g, (_, decimal: string) => String.fromCodePoint(parseInt(decimal, 10)))
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&#39;/g, "'")
    .replace(/&quot;/g, "\"");
}

function dedupeAdjacentCaptionCues(cueTexts: string[]): string[] {
  const result: string[] = [];
  let previousKey = "";

  for (const cueText of cueTexts) {
    const cleaned = cleanCaptionCueText(cueText);
    const key = normalizeCaptionCueKey(cleaned);
    if (!key || key === previousKey) {
      continue;
    }

    result.push(cleaned);
    previousKey = key;
  }

  return result;
}

function cleanCaptionCueText(text: string): string {
  return text
    .replace(/<\d{2}:\d{2}:\d{2}\.\d{3}>/g, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/\[Music\]/gi, "[music]")
    .replace(/\s+/g, " ")
    .trim();
}

function normalizeCaptionCueKey(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function normalizeCaptionTranscript(text: string): string | null {
  const normalized = text
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&#39;/g, "'")
    .replace(/&quot;/g, "\"")
    .replace(/\s+/g, " ")
    .trim();

  return normalized.length >= 2 ? normalized : null;
}

async function downloadWithYtDlp(url: string, args: string[]): Promise<{ filePath: string; fileName: string }> {
  try {
    const { stdout } = await execFileAsync(MEDIA_LINK_YTDLP_BIN, args, {
      timeout: MEDIA_LINK_DOWNLOAD_TIMEOUT_MS,
      maxBuffer: 8 * 1024 * 1024
    });
    const lines = stdout
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter(Boolean);
    const filePath = lines[lines.length - 1];
    if (!filePath) {
      throw new Error("yt-dlp did not return a file path");
    }
    return {
      filePath,
      fileName: filePath.split("/").pop() || "media-link"
    };
  } catch (error) {
    throw new MediaLinkTranscriptError("media_fetch_failed", String(error));
  }
}

async function downloadMediaFromURL(mediaURL: string, mimeType?: string, fileName?: string): Promise<PreparedMedia> {
  const abortController = new AbortController();
  const timeoutId = setTimeout(() => abortController.abort(), MEDIA_LINK_DOWNLOAD_TIMEOUT_MS);

  try {
    const response = await fetch(mediaURL, {
      headers: makeBrowserHeaders(),
      signal: abortController.signal as any
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const headerLength = Number(response.headers.get("content-length") ?? "0");
    if (headerLength > 0) {
      assertMediaSize(headerLength);
    }

    const bytes = Buffer.from(await response.arrayBuffer());
    assertMediaSize(bytes.byteLength);

    return {
      bytes,
      mimeType: normalizeOptionalString(mimeType)
        || normalizeOptionalString(response.headers.get("content-type"))
        || "video/mp4",
      fileName
    };
  } finally {
    clearTimeout(timeoutId);
  }
}

async function maybeExtractAudio(
  media: PreparedMedia,
  existingVideoPath?: string,
  platform: MediaLinkPlatform = "tiktok"
): Promise<PreparedMedia> {
  const cleanupPaths = [...(media.cleanupPaths ?? [])];
  let tempVideoPath = existingVideoPath;

  if (!tempVideoPath) {
    tempVideoPath = join(tmpdir(), `chillnote-${platform}-video-${randomUUID()}.mp4`);
    await fs.writeFile(tempVideoPath, media.bytes);
    cleanupPaths.push(tempVideoPath);
  }

  const audioPath = join(tmpdir(), `chillnote-${platform}-audio-${randomUUID()}.m4a`);
  cleanupPaths.push(audioPath);

  try {
    await execFileAsync(MEDIA_LINK_FFMPEG_BIN, [
      "-y",
      "-i",
      tempVideoPath,
      "-vn",
      "-acodec",
      "aac",
      "-b:a",
      "96k",
      audioPath
    ], {
      timeout: MEDIA_LINK_DOWNLOAD_TIMEOUT_MS,
      maxBuffer: 8 * 1024 * 1024
    });

    const audioBuffer = await readFileWithLimit(audioPath);
    return {
      bytes: audioBuffer,
      mimeType: "audio/mp4",
      fileName: media.fileName?.replace(/\.[^.]+$/, ".m4a") || `${platform}-audio.m4a`,
      cleanupPaths
    };
  } catch {
    return {
      ...media,
      cleanupPaths
    };
  }
}

async function readFileWithLimit(filePath: string): Promise<Buffer> {
  const stats = await fs.stat(filePath);
  assertMediaSize(stats.size);
  return await fs.readFile(filePath);
}

function assertMediaSize(byteLength: number): void {
  const limitBytes = Math.max(1, MEDIA_LINK_MAX_MEDIA_MB) * 1024 * 1024;
  if (byteLength > limitBytes) {
    throw new MediaLinkTranscriptError(
      "media_too_large",
      `Media exceeded ${MEDIA_LINK_MAX_MEDIA_MB}MB`
    );
  }
}

async function transcribeMedia(bytes: Buffer, mimeType: string, metadata: MediaLinkMetadata): Promise<string> {
  const url = buildGeminiGenerateContentURL(GEMINI_MODEL);
  const body = {
    systemInstruction: {
      parts: [{
        text: [
          "You are a professional transcription assistant.",
          "Your only job is to transcribe spoken content from imported web media faithfully.",
          "Return STRICT JSON only using schema {\"text\": string}.",
          "Do not summarize, translate, add timestamps, speaker labels, or commentary.",
          "Keep the original spoken language exactly as heard.",
          "If there is no meaningful speech, return an empty string."
        ].join("\n")
      }]
    },
    contents: [
      {
        parts: [
          {
            inlineData: {
              mimeType,
              data: bytes.toString("base64")
            }
          },
          {
            text: [
              "Transcribe the spoken audio exactly as heard.",
              metadata.title ? `Video title context: ${metadata.title}` : undefined,
              metadata.authorName ? `Creator context: ${metadata.authorName}` : undefined
            ].filter(Boolean).join("\n")
          }
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
  const timeoutId = setTimeout(() => abortController.abort(), MEDIA_LINK_TRANSCRIBE_TIMEOUT_MS);

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
      signal: abortController.signal as any
    });

    if (!response.ok) {
      throw new MediaLinkTranscriptError("transcription_failed", `Gemini HTTP ${response.status}`);
    }

    const data = await response.json() as any;
    const content = data.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    const parsed = parseTranscriptModelOutput(content);
    return parsed.text;
  } catch (error: any) {
    if (error?.name === "AbortError") {
      throw new MediaLinkTranscriptError("transcription_timeout");
    }
    if (error instanceof MediaLinkTranscriptError) {
      throw error;
    }
    throw new MediaLinkTranscriptError("transcription_failed", String(error));
  } finally {
    clearTimeout(timeoutId);
  }
}

async function cleanupTemporaryFiles(paths?: string[]): Promise<void> {
  if (!paths?.length) return;

  await Promise.all(paths.map(async (filePath) => {
    try {
      await fs.unlink(filePath);
    } catch {
      // Best-effort cleanup only.
    }
  }));
}

function normalizeOptionalString(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed ? trimmed : undefined;
}

function extractVideoIDFromURL(url: string, platform: MediaLinkPlatform): string | undefined {
  if (platform === "tiktok" || platform === "instagram") {
    const match = url.match(/\/(?:reel|video|tv)\/([A-Za-z0-9_-]+)/);
    return match?.[1];
  }

  try {
    const parsed = new URL(url);
    const directID = parsed.searchParams.get("v")?.trim();
    if (directID) return directID;

    const pathComponents = parsed.pathname.split("/").filter(Boolean);
    const shortID = pathComponents[pathComponents.length - 1]?.trim();
    return shortID || undefined;
  } catch {
    return undefined;
  }
}

function extractVideoIDFromEmbedHTML(html?: string): string | undefined {
  if (!html) return undefined;
  const match = html.match(/data-video-id="(\d+)"/);
  return match?.[1];
}

function mimeTypeForFile(filePath: string): string {
  const lower = filePath.toLowerCase();
  if (lower.endsWith(".m4a")) return "audio/mp4";
  if (lower.endsWith(".mp3")) return "audio/mpeg";
  if (lower.endsWith(".wav")) return "audio/wav";
  if (lower.endsWith(".aac")) return "audio/aac";
  if (lower.endsWith(".mov")) return "video/quicktime";
  if (lower.endsWith(".m4v")) return "video/x-m4v";
  return "video/mp4";
}

function makeBrowserHeaders(): Record<string, string> {
  return {
    "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
    Accept: "*/*"
  };
}

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
  } catch {
    // Fall through to the looser parser below.
  }
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

function parseTranscriptModelOutput(raw: string): { text: string; parsed: boolean } {
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
