import type { SyncPayload } from "./types.js";
import { upsertNote } from "./store.js";

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
  for (const note of payload.notes) {
    const local = existing.notes.find((item) => item.id === note.id);
    if (!local || shouldApply(note.updatedAt, note.deletedAt, local.updatedAt, local.deletedAt)) {
      await upsertNote(userId, note);
    }
  }
}
