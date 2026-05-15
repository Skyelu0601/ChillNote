import type { NoteDTO, TagDTO } from "./chillnote-api";

export const WEB_DEVICE_ID_KEY = "chillnote.web.device_id";
export const WEB_DEVICE_PREFIX = "chillnote-web";
export const TRASH_RETENTION_DAYS = 30;
export const FREE_RECORDING_TIME_LIMIT_SECONDS = 60;
export const PRO_RECORDING_TIME_LIMIT_SECONDS = 600;

export const tagPaletteHexes = [
  "#2F86FF",
  "#5B8CFF",
  "#7A5CFF",
  "#B14DFF",
  "#00A3FF",
  "#00B8A9",
  "#2ECC71",
  "#A3A3AE",
  "#6B7280",
  "#111114",
];

export type ChecklistItem = {
  isDone: boolean;
  text: string;
};

export type ParsedChecklist = {
  notes: string;
  items: ChecklistItem[];
};

export type NoteSourceMetadata = {
  url: string;
  title: string;
  platformID: string;
  platformName: string;
  host: string;
};

const checkboxRegex = /^\s*[-*]\s*\[( |x|X)\]\s*(.*?)\s*$/;

export function newClientId() {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }

  const randomPart = Math.random().toString(16).slice(2);
  const timePart = Date.now().toString(16);
  return `${timePart}-${randomPart}`;
}

export function getOrCreateDeviceId() {
  if (typeof window === "undefined") return `${WEB_DEVICE_PREFIX}-server`;
  try {
    const existing = window.localStorage.getItem(WEB_DEVICE_ID_KEY);
    if (existing) return existing;
    const next = `${WEB_DEVICE_PREFIX}-${newClientId()}`;
    window.localStorage.setItem(WEB_DEVICE_ID_KEY, next);
    return next;
  } catch {
    return `${WEB_DEVICE_PREFIX}-${newClientId()}`;
  }
}

export function parseChecklist(content: string): ParsedChecklist | null {
  const lines = content.split("\n");
  const items: ChecklistItem[] = [];
  const notesLines: string[] = [];
  let currentItemIndex: number | null = null;

  for (const line of lines) {
    const match = checkboxRegex.exec(line);
    if (match) {
      items.push({
        isDone: match[1].toLowerCase() === "x",
        text: match[2].trim(),
      });
      currentItemIndex = items.length - 1;
      continue;
    }

    const trimmed = line.trim();
    if (!trimmed) continue;

    if (currentItemIndex !== null) {
      const existing = items[currentItemIndex].text;
      items[currentItemIndex].text = existing ? `${existing}\n${trimmed}` : trimmed;
    } else {
      notesLines.push(line);
    }
  }

  if (items.length === 0) return null;
  return {
    notes: notesLines.join("\n").trim(),
    items,
  };
}

export function serializeChecklist(notes: string, items: ChecklistItem[]) {
  const parts: string[] = [];
  const trimmedNotes = notes.trim();
  if (trimmedNotes) {
    parts.push(trimmedNotes, "");
  }

  for (const item of items) {
    const mark = item.isDone ? "x" : " ";
    const lines = item.text
      .split("\n")
      .map((line) => line.trim())
      .filter(Boolean);

    if (lines.length === 0) {
      parts.push(`- [${mark}]`);
      continue;
    }

    parts.push(`- [${mark}] ${lines[0]}`);
    for (const continuation of lines.slice(1)) {
      parts.push(`    ${continuation}`);
    }
  }

  return parts.join("\n").trim();
}

export function toggleChecklistItem(content: string, index: number) {
  const parsed = parseChecklist(content);
  if (!parsed || !parsed.items[index]) return content;
  const items = parsed.items.map((item, itemIndex) => (
    itemIndex === index ? { ...item, isDone: !item.isDone } : item
  ));
  return serializeChecklist(parsed.notes, items);
}

export function previewPlainText(content: string) {
  let result = content;
  result = result.replace(/^#{1,6}\s+/gm, "");
  result = result.replace(/\*\*/g, "");
  result = result.replace(/\*/g, "");
  result = result.replace(/`/g, "");
  result = result.replace(/!\[[^\]]*\]\([^)]+\)/g, "");
  result = result.replace(/- \[ \] /g, "☐ ");
  result = result.replace(/- \[[xX]\] /g, "☑ ");
  result = result.replace(/^[-•]\s+/gm, "");
  return result.length <= 360 ? result : `${result.slice(0, 360)}...`;
}

export function dateTimeOrNull(value?: string | null) {
  if (!value) return null;
  const time = Date.parse(value);
  return Number.isNaN(time) ? null : time;
}

export function sortNotesForFeed(notes: NoteDTO[]) {
  return [...notes].sort((a, b) => {
    const leftPinned = dateTimeOrNull(a.pinnedAt) ?? -Infinity;
    const rightPinned = dateTimeOrNull(b.pinnedAt) ?? -Infinity;
    if (leftPinned !== rightPinned) return rightPinned - leftPinned;

    const leftCreated = dateTimeOrNull(a.createdAt) ?? -Infinity;
    const rightCreated = dateTimeOrNull(b.createdAt) ?? -Infinity;
    if (leftCreated !== rightCreated) return rightCreated - leftCreated;

    return b.id.localeCompare(a.id);
  });
}

export function daysRemainingInTrash(deletedAt: string) {
  const deletedTime = Date.parse(deletedAt);
  if (Number.isNaN(deletedTime)) return 0;
  const expirationTime = deletedTime + TRASH_RETENTION_DAYS * 24 * 60 * 60 * 1000;
  const remaining = Math.ceil((expirationTime - Date.now()) / (24 * 60 * 60 * 1000));
  return Math.max(0, remaining);
}

export function normalizeTagColorHex(raw?: string | null) {
  const trimmed = (raw ?? "").trim().replaceAll("#", "").toUpperCase();
  return /^[0-9A-F]{6}$/.test(trimmed) ? `#${trimmed}` : tagPaletteHexes[0];
}

export function autoColorHex(tagName: string, existingTags: TagDTO[]) {
  const matched = existingTags.find((tag) => (
    !tag.deletedAt && tag.name.localeCompare(tagName, undefined, { sensitivity: "accent" }) === 0
  ));
  if (matched) return normalizeTagColorHex(matched.colorHex);

  const activeCount = existingTags.filter((tag) => !tag.deletedAt).length;
  return tagPaletteHexes[activeCount % tagPaletteHexes.length];
}

export function activeTagsForNote(note: NoteDTO | null, tags: TagDTO[]) {
  if (!note?.tagIds?.length) return [];
  const byId = new Map(tags.filter((tag) => !tag.deletedAt).map((tag) => [tag.id, tag]));
  return note.tagIds.map((id) => byId.get(id)).filter((tag): tag is TagDTO => Boolean(tag));
}

function normalizedHost(url: URL) {
  const host = url.hostname.toLowerCase();
  return host.startsWith("www.") ? host.slice(4) : host;
}

function matchesAnyDomain(host: string, domains: string[]) {
  return domains.some((domain) => host === domain || host.endsWith(`.${domain}`));
}

export function resolveSourcePlatform(url: URL) {
  const host = normalizedHost(url);
  if (matchesAnyDomain(host, ["xiaohongshu.com", "xhslink.com"])) return { id: "xiaohongshu", displayName: "小红书" };
  if (matchesAnyDomain(host, ["youtube.com", "youtu.be", "youtube-nocookie.com"])) return { id: "youtube", displayName: "YouTube" };
  if (matchesAnyDomain(host, ["tiktok.com", "vm.tiktok.com", "vt.tiktok.com"])) return { id: "tiktok", displayName: "TikTok" };
  if (matchesAnyDomain(host, ["instagram.com"])) return { id: "instagram", displayName: "Instagram" };
  if (matchesAnyDomain(host, ["threads.net"])) return { id: "threads", displayName: "Threads" };
  if (matchesAnyDomain(host, ["x.com", "twitter.com", "t.co"])) return { id: "x", displayName: "X" };
  if (matchesAnyDomain(host, ["medium.com"])) return { id: "medium", displayName: "Medium" };
  if (matchesAnyDomain(host, ["substack.com"])) return { id: "substack", displayName: "Substack" };
  if (matchesAnyDomain(host, ["reddit.com", "redd.it"])) return { id: "reddit", displayName: "Reddit" };
  if (matchesAnyDomain(host, ["pinterest.com", "pin.it"])) return { id: "pinterest", displayName: "Pinterest" };
  if (matchesAnyDomain(host, ["linkedin.com", "lnkd.in"])) return { id: "linkedin", displayName: "LinkedIn" };
  if (matchesAnyDomain(host, ["facebook.com", "fb.com", "fb.watch"])) return { id: "facebook", displayName: "Facebook" };
  if (matchesAnyDomain(host, ["vimeo.com"])) return { id: "vimeo", displayName: "Vimeo" };
  if (matchesAnyDomain(host, ["twitch.tv"])) return { id: "twitch", displayName: "Twitch" };
  if (matchesAnyDomain(host, ["producthunt.com"])) return { id: "product_hunt", displayName: "Product Hunt" };
  if (matchesAnyDomain(host, ["news.ycombinator.com"])) return { id: "hacker_news", displayName: "Hacker News" };
  if (matchesAnyDomain(host, ["bilibili.com", "b23.tv"])) return { id: "bilibili", displayName: "Bilibili" };
  if (matchesAnyDomain(host, ["spotify.com", "open.spotify.com"])) return { id: "spotify", displayName: "Spotify" };
  if (matchesAnyDomain(host, ["podcasts.apple.com"])) return { id: "apple_podcasts", displayName: "Apple Podcasts" };
  return { id: "web", displayName: host };
}

export function sourceMetadataForNote(note: NoteDTO | null): NoteSourceMetadata | null {
  if (!note?.sourceURL) return null;
  try {
    const url = new URL(note.sourceURL);
    if (!["http:", "https:"].includes(url.protocol)) return null;
    const host = note.sourceHost?.trim() || normalizedHost(url);
    const platform = resolveSourcePlatform(url);
    const platformID = note.sourcePlatformID?.trim() || platform.id;
    const platformName = note.sourcePlatformName?.trim() || platform.displayName;
    const title = note.sourceTitle?.trim() || host;
    return {
      url: note.sourceURL,
      title: title || note.sourceURL,
      platformID,
      platformName,
      host,
    };
  } catch {
    return null;
  }
}

export function metadataFromURL(rawURL: string): NoteSourceMetadata | null {
  const trimmed = rawURL.trim();
  if (!trimmed) return null;
  try {
    const url = new URL(trimmed);
    if (!["http:", "https:"].includes(url.protocol)) return null;
    const host = normalizedHost(url);
    const platform = resolveSourcePlatform(url);
    return {
      url: url.toString(),
      title: host,
      platformID: platform.id,
      platformName: platform.displayName,
      host,
    };
  } catch {
    return null;
  }
}
