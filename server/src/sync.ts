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

function buildConflict(params: {
  entityType: "note" | "tag";
  id: string;
  serverVersion: number;
  serverContent?: string | null;
  clientContent?: string | null;
  message: string;
}): ConflictDTO {
  return {
    entityType: params.entityType,
    id: params.id,
    serverVersion: params.serverVersion,
    serverContent: params.serverContent ?? null,
    clientContent: params.clientContent ?? null,
    message: params.message
  };
}

export async function applySync(payload: SyncPayload, userId: string): Promise<{ conflicts: ConflictDTO[] }> {
  const conflicts: ConflictDTO[] = [];
  const now = new Date();
  const deviceId = payload.deviceId ?? null;

  // 1) Tags: upsert first so note->tag relations can connect safely.
  const dedupedTags = pickLatestByClientTime<TagDTO>(payload.tags ?? []);
  const tagsToApply: TagDTO[] = [];

  for (const tag of dedupedTags.values()) {
    const existing = await prisma.tag.findFirst({
      where: { id: tag.id, userId }
    });
    const baseVersion = tag.baseVersion ?? 0;
    if (existing && baseVersion < (existing.version ?? 0)) {
      conflicts.push(
        buildConflict({
          entityType: "tag",
          id: tag.id,
          serverVersion: existing.version ?? 0,
          serverContent: existing.name,
          clientContent: tag.name,
          message: "Tag 在其他设备已更新，发生冲突。"
        })
      );
      continue;
    }
    const nextVersion = (existing?.version ?? 0) + 1;
    const isDelete = !!tag.deletedAt;
    const serverDeletedAt = isDelete ? now.toISOString() : null;
    tagsToApply.push({
      ...tag,
      updatedAt: now.toISOString(),
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
    const baseVersion = note.baseVersion ?? 0;
    if (existing && baseVersion < (existing.version ?? 0)) {
      conflicts.push(
        buildConflict({
          entityType: "note",
          id: note.id,
          serverVersion: existing.version ?? 0,
          serverContent: existing.content,
          clientContent: note.content,
          message: "笔记在其他设备已更新，发生冲突。"
        })
      );
      continue;
    }

    const nextVersion = (existing?.version ?? 0) + 1;
    const isDelete = !!note.deletedAt;
    const serverDeletedAt = isDelete ? now.toISOString() : null;
    const upsertPayload: NoteDTO = {
      ...note,
      updatedAt: now.toISOString(),
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

  return { conflicts };
}
