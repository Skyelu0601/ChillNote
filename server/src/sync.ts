import type { SyncPayload, TagDTO } from "./types.js";
import { upsertNote, upsertTag } from "./store.js";

function parseDate(value?: string | null): number | null {
  if (!value) return null;
  const time = Date.parse(value);
  return Number.isNaN(time) ? null : time;
}

function shouldApply(remoteUpdatedAt?: string | null, remoteDeletedAt?: string | null, localUpdatedAt?: string | null, localDeletedAt?: string | null): boolean {
  const remoteDeletedTime = parseDate(remoteDeletedAt);
  const remoteUpdatedTime = parseDate(remoteUpdatedAt);
  const localDeletedTime = parseDate(localDeletedAt);
  const localUpdatedTime = parseDate(localUpdatedAt);

  if (remoteDeletedTime !== null) {
    if (localDeletedTime !== null && localDeletedTime >= remoteDeletedTime) {
      return false;
    }
    if (localUpdatedTime !== null && localUpdatedTime > remoteDeletedTime) {
      return false;
    }
    return true;
  }

  if (remoteUpdatedTime === null) return false;
  if (localDeletedTime !== null && localDeletedTime >= remoteUpdatedTime) return false;
  if (localUpdatedTime === null) return true;
  return remoteUpdatedTime > localUpdatedTime;
}

export async function applySync(payload: SyncPayload, existing: SyncPayload, userId: string): Promise<void> {
  // 1) Tags: upsert first so note->tag relations can connect safely.
  const dedupedTags = new Map<string, TagDTO>();
  for (const tag of payload.tags ?? []) {
    const current = dedupedTags.get(tag.id);
    const tagTimestamp = Math.max(parseDate(tag.deletedAt) ?? -Infinity, parseDate(tag.updatedAt) ?? -Infinity, parseDate(tag.createdAt) ?? -Infinity);
    if (!current) {
      dedupedTags.set(tag.id, tag);
      continue;
    }
    const existingTimestamp = Math.max(parseDate(current.deletedAt) ?? -Infinity, parseDate(current.updatedAt) ?? -Infinity, parseDate(current.createdAt) ?? -Infinity);
    if (tagTimestamp > existingTimestamp) {
      dedupedTags.set(tag.id, tag);
    }
  }

  // Stage 1: create/update tag core fields without parent links to avoid FK issues.
  for (const tag of dedupedTags.values()) {
    const local = existing.tags?.find((item) => item.id === tag.id);
    if (!local || shouldApply(tag.updatedAt, tag.deletedAt ?? null, local.updatedAt, local.deletedAt ?? null)) {
      await upsertTag(userId, { ...tag, parentId: tag.parentId ?? null }, { setParent: false });
    }
  }
  // Stage 2: apply parent relationships once all tags exist.
  for (const tag of dedupedTags.values()) {
    const local = existing.tags?.find((item) => item.id === tag.id);
    if (!local || shouldApply(tag.updatedAt, tag.deletedAt ?? null, local.updatedAt, local.deletedAt ?? null)) {
      await upsertTag(userId, tag, { setParent: true });
    }
  }

  // 2) Notes: dedupe and apply changes with tag relations.
  const deduped = new Map<string, typeof payload.notes[number]>();
  for (const note of payload.notes) {
    const existing = deduped.get(note.id);
    const currentTimestamp = Math.max(parseDate(note.deletedAt) ?? -Infinity, parseDate(note.updatedAt) ?? -Infinity);
    if (!existing) {
      deduped.set(note.id, note);
      continue;
    }
    const existingTimestamp = Math.max(parseDate(existing.deletedAt) ?? -Infinity, parseDate(existing.updatedAt) ?? -Infinity);
    if (currentTimestamp > existingTimestamp) {
      deduped.set(note.id, note);
    }
  }

  for (const note of deduped.values()) {
    const local = existing.notes.find((item) => item.id === note.id);
    if (!local || shouldApply(note.updatedAt, note.deletedAt, local.updatedAt, local.deletedAt)) {
      await upsertNote(userId, note);
    }
  }
}
