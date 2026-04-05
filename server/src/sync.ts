import type { ConflictDTO, NoteDTO, SyncPayload, TagDTO } from "./types.js";
import { prisma } from "./db.js";
import { logSyncChange, upsertNote, upsertTag } from "./store.js";

function parseDate(value?: string | null): number | null {
  if (!value) return null;
  const time = Date.parse(value);
  return Number.isNaN(time) ? null : time;
}

function pickLatestByClientTime<T extends { id: string; clientUpdatedAt?: string | null; updatedAt?: string | null; deletedAt?: string | null }>(
  items: T[]
): Map<string, T> {
  const deduped = new Map<string, T>();
  for (const item of items) {
    const current = deduped.get(item.id);
    const itemTime = Math.max(
      parseDate(item.clientUpdatedAt) ?? -Infinity,
      parseDate(item.updatedAt) ?? -Infinity,
      parseDate(item.deletedAt) ?? -Infinity
    );
    if (!current) {
      deduped.set(item.id, item);
      continue;
    }
    const existingTime = Math.max(
      parseDate(current.clientUpdatedAt) ?? -Infinity,
      parseDate(current.updatedAt) ?? -Infinity,
      parseDate(current.deletedAt) ?? -Infinity
    );
    if (itemTime > existingTime) {
      deduped.set(item.id, item);
    }
  }
  return deduped;
}

export async function applySync(payload: SyncPayload, userId: string): Promise<{
  conflicts: ConflictDTO[];
  forcedHardDeletedNoteIds: string[];
  forcedHardDeletedTagIds: string[];
}> {
  const conflicts: ConflictDTO[] = [];
  const forcedHardDeletedNoteIds = new Set<string>();
  const forcedHardDeletedTagIds = new Set<string>();
  const now = new Date();
  const deviceId = payload.deviceId ?? null;
  const nowIso = now.toISOString();

  const hardDeletedNoteIds = Array.from(new Set((payload.hardDeletedNoteIds ?? []).filter((id): id is string => !!id)));
  const hardDeletedTagIds = Array.from(new Set((payload.hardDeletedTagIds ?? []).filter((id): id is string => !!id)));

  // 0) Apply hard deletes first. Later uploads are allowed to recreate the entity.
  for (const noteId of hardDeletedNoteIds) {
    const existing = await prisma.note.findFirst({
      where: { id: noteId, userId }
    });

    if (existing) {
      await prisma.note.delete({
        where: { id: noteId }
      });
    }

    await logSyncChange({
      userId,
      entityType: "note",
      entityId: noteId,
      version: (existing?.version ?? 0) + 1,
      serverUpdatedAt: now,
      operation: "hard_delete"
    });
  }

  for (const tagId of hardDeletedTagIds) {
    const existing = await prisma.tag.findFirst({
      where: { id: tagId, userId }
    });

    if (existing) {
      await prisma.tag.delete({
        where: { id: tagId }
      });
    }

    await logSyncChange({
      userId,
      entityType: "tag",
      entityId: tagId,
      version: (existing?.version ?? 0) + 1,
      serverUpdatedAt: now,
      operation: "hard_delete"
    });
  }

  // 1) Tags: upsert first so note->tag relations can connect safely.
  const dedupedTags = pickLatestByClientTime<TagDTO>(payload.tags ?? []);
  const tagsToApply: TagDTO[] = [];

  for (const tag of dedupedTags.values()) {
    const existing = await prisma.tag.findFirst({
      where: { id: tag.id, userId }
    });
    const nextVersion = (existing?.version ?? 0) + 1;
    const isDelete = !!tag.deletedAt;
    const serverDeletedAt = isDelete ? nowIso : null;
    tagsToApply.push({
      ...tag,
      updatedAt: nowIso,
      deletedAt: serverDeletedAt,
      version: nextVersion,
      lastModifiedByDeviceId: deviceId ?? null
    });
  }

  // Stage 1: create/update tag core fields without parent links to avoid FK issues.
  for (const tag of tagsToApply) {
    await upsertTag(userId, { ...tag, parentId: tag.parentId ?? null }, { setParent: false });
    await logSyncChange({
      userId,
      entityType: "tag",
      entityId: tag.id,
      version: tag.version ?? 1,
      serverUpdatedAt: now,
      operation: tag.deletedAt ? "delete" : "upsert"
    });
  }
  // Stage 2: apply parent relationships once all tags exist.
  for (const tag of tagsToApply) {
    await upsertTag(userId, tag, { setParent: true });
  }

  // 2) Notes: dedupe and apply changes with tag relations.
  const dedupedNotes = pickLatestByClientTime<NoteDTO>(payload.notes);
  for (const note of dedupedNotes.values()) {
    const existing = await prisma.note.findFirst({
      where: { id: note.id, userId }
    });

    const nextVersion = (existing?.version ?? 0) + 1;
    const isDelete = !!note.deletedAt;
    const serverDeletedAt = isDelete ? nowIso : null;
    const upsertPayload: NoteDTO = {
      ...note,
      updatedAt: nowIso,
      deletedAt: serverDeletedAt,
      version: nextVersion,
      lastModifiedByDeviceId: deviceId ?? null
    };
    await upsertNote(userId, upsertPayload);
    await logSyncChange({
      userId,
      entityType: "note",
      entityId: note.id,
      version: nextVersion,
      serverUpdatedAt: now,
      operation: isDelete ? "delete" : "upsert"
    });
  }

  return {
    conflicts,
    forcedHardDeletedNoteIds: Array.from(forcedHardDeletedNoteIds),
    forcedHardDeletedTagIds: Array.from(forcedHardDeletedTagIds)
  };
}
