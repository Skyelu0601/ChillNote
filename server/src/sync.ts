import type { ConflictDTO, NoteDTO, SyncPayload, TagDTO } from "./types.js";
import { randomUUID } from "node:crypto";
import { prisma } from "./db.js";
import { logSyncChange, upsertNote, upsertTag, type SyncDatabase } from "./store.js";
import { hardDeleteNoteWithWeeklyTopicCleanup } from "./weeklyTopics.js";
import {
  isUUIDSyncIdentity,
  normalizeNewSyncEntityId,
  pickLatestBySyncIdentity,
  syncIdentityKey
} from "./syncIdentity.js";
import {
  decideSyncMutation,
  hasForeignSyncIdentityOwner,
  SyncOwnershipError,
  SyncReferenceError
} from "./syncPolicy.js";
import { sanitizeTagParentChanges } from "./tagHierarchyPolicy.js";

function syncIdWhere(id: string): string | { equals: string; mode: "insensitive" } {
  return isUUIDSyncIdentity(id) ? { equals: id, mode: "insensitive" } : id;
}

function parseDate(value?: string | null): number | null {
  if (!value) return null;
  const time = Date.parse(value);
  return Number.isNaN(time) ? null : time;
}

function pickLatestByClientTime<T extends { id: string; clientUpdatedAt?: string | null; updatedAt?: string | null; deletedAt?: string | null }>(
  items: T[]
): Map<string, T> {
  return pickLatestBySyncIdentity(items, (item) =>
    Math.max(
      parseDate(item.clientUpdatedAt) ?? -Infinity,
      parseDate(item.updatedAt) ?? -Infinity,
      parseDate(item.deletedAt) ?? -Infinity
    )
  );
}

function buildConflict(params: {
  entityType: "note" | "tag";
  id: string;
  serverVersion: number;
  serverContent?: string | null;
  clientContent?: string | null;
  message: "sync.conflict.version" | "sync.conflict.hard_deleted";
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

async function ownedTagAliases(database: SyncDatabase, userId: string, requestedId: string) {
  const aliases = await database.tag.findMany({
    where: { id: syncIdWhere(requestedId) },
    orderBy: [{ serverUpdatedAt: "desc" }, { updatedAt: "desc" }]
  });
  if (hasForeignSyncIdentityOwner(userId, aliases.map((tag) => tag.userId))) {
    throw new SyncOwnershipError();
  }
  return aliases;
}

async function ownedNoteAliases(database: SyncDatabase, userId: string, requestedId: string) {
  const aliases = await database.note.findMany({
    where: { id: syncIdWhere(requestedId) },
    orderBy: [{ serverUpdatedAt: "desc" }, { updatedAt: "desc" }]
  });
  if (hasForeignSyncIdentityOwner(userId, aliases.map((note) => note.userId))) {
    throw new SyncOwnershipError();
  }
  return aliases;
}

async function resolveTagId(database: SyncDatabase, userId: string, requestedId: string): Promise<string> {
  const existing = (await ownedTagAliases(database, userId, requestedId))[0];
  return existing?.id ?? normalizeNewSyncEntityId(requestedId);
}

async function resolveNoteId(database: SyncDatabase, userId: string, requestedId: string): Promise<string> {
  const existing = (await ownedNoteAliases(database, userId, requestedId))[0];
  return existing?.id ?? normalizeNewSyncEntityId(requestedId);
}

async function findTombstone(
  database: SyncDatabase,
  userId: string,
  entityType: "note" | "tag",
  requestedId: string
) {
  const tombstones = await database.hardDeleteTombstone.findMany({
    where: {
      entityType,
      entityId: syncIdWhere(requestedId)
    },
    orderBy: { deletedAt: "desc" }
  });
  if (hasForeignSyncIdentityOwner(userId, tombstones.map((item) => item.userId))) {
    throw new SyncOwnershipError();
  }
  return tombstones.find((item) => item.userId === userId) ?? null;
}

async function ensureTombstone(
  database: SyncDatabase,
  userId: string,
  entityType: "note" | "tag",
  requestedId: string,
  deletedAt: Date
): Promise<{ entityId: string; alreadyExisted: boolean }> {
  const existing = await findTombstone(database, userId, entityType, requestedId);
  if (existing) {
    return { entityId: normalizeNewSyncEntityId(existing.entityId), alreadyExisted: true };
  }
  const entityId = normalizeNewSyncEntityId(requestedId);
  await database.hardDeleteTombstone.create({
    data: { userId, entityType, entityId, deletedAt }
  });
  return { entityId, alreadyExisted: false };
}

async function resolveOwnedTagReference(
  database: SyncDatabase,
  userId: string,
  requestedId: string,
  resolvedTagIds: Map<string, string>,
  hardDeletedTagKeys: Set<string>
): Promise<string | null> {
  const key = syncIdentityKey(requestedId);
  if (hardDeletedTagKeys.has(key) || await findTombstone(database, userId, "tag", requestedId)) {
    return null;
  }
  const resolvedId = resolvedTagIds.get(key) ?? await resolveTagId(database, userId, requestedId);
  const existing = await database.tag.findFirst({
    where: { id: resolvedId, userId },
    select: { id: true, deletedAt: true, serverDeletedAt: true }
  });
  if (!existing) throw new SyncReferenceError();
  if (existing.deletedAt || existing.serverDeletedAt) return null;
  return resolvedId;
}

function shouldPreserveFinishedImport(existing: {
  importStatus: string | null;
  importJobId: string | null;
} | null, incoming: NoteDTO): boolean {
  if (!existing || (incoming.importStatus !== "queued" && incoming.importStatus !== "processing")) {
    return false;
  }
  const serverFinished = existing.importStatus === "completed" || existing.importStatus === "failed";
  const sameImport = !incoming.importJobId || !existing.importJobId || incoming.importJobId === existing.importJobId;
  return serverFinished && sameImport;
}

export type ApplySyncResult = {
  conflicts: ConflictDTO[];
  forcedNoteIds: string[];
  forcedTagIds: string[];
  forcedHardDeletedNoteIds: string[];
  forcedHardDeletedTagIds: string[];
};

export async function applySync(
  payload: SyncPayload,
  userId: string,
  database: SyncDatabase = prisma
): Promise<ApplySyncResult> {
  const conflicts: ConflictDTO[] = [];
  const forcedNoteIds = new Set<string>();
  const forcedTagIds = new Set<string>();
  const forcedHardDeletedNoteIds = new Set<string>();
  const forcedHardDeletedTagIds = new Set<string>();
  const now = new Date();
  const deviceId = payload.deviceId ?? null;
  const nowIso = now.toISOString();

  const hardDeletedNoteIds = Array.from(new Map(
    (payload.hardDeletedNoteIds ?? [])
      .filter((id): id is string => !!id)
      .map((id) => [syncIdentityKey(id), id])
  ).values());
  const hardDeletedTagIds = Array.from(new Map(
    (payload.hardDeletedTagIds ?? [])
      .filter((id): id is string => !!id)
      .map((id) => [syncIdentityKey(id), id])
  ).values());
  const hardDeletedNoteKeys = new Set(hardDeletedNoteIds.map(syncIdentityKey));
  const hardDeletedTagKeys = new Set(hardDeletedTagIds.map(syncIdentityKey));

  // Hard delete is terminal and wins over an upsert for the same identity in
  // this request. One canonical tombstone protects every UUID case variant.
  for (const noteId of hardDeletedNoteIds) {
    const aliases = await ownedNoteAliases(database, userId, noteId);
    const tombstone = await ensureTombstone(database, userId, "note", noteId, now);
    const deletedVersion = aliases.reduce((latest, note) => Math.max(latest, note.version), 0) + 1;
    for (const alias of aliases) {
      await hardDeleteNoteWithWeeklyTopicCleanup(userId, alias.id, database);
    }
    if (aliases.length > 0 || !tombstone.alreadyExisted) {
      await logSyncChange({
        userId,
        entityType: "note",
        entityId: tombstone.entityId,
        version: deletedVersion,
        serverUpdatedAt: now,
        operation: "hard_delete"
      }, database);
    }
    forcedHardDeletedNoteIds.add(tombstone.entityId);
  }

  for (const tagId of hardDeletedTagIds) {
    const aliases = await ownedTagAliases(database, userId, tagId);
    const tombstone = await ensureTombstone(database, userId, "tag", tagId, now);
    const deletedVersion = aliases.reduce((latest, tag) => Math.max(latest, tag.version), 0) + 1;

    // PostgreSQL clears Tag.parentId through ON DELETE SET NULL. Make that
    // relationship change an explicit versioned sync mutation too: Android's
    // local tag table intentionally has no self-FK, so merely delivering the
    // deleted parent would otherwise leave a dangling parentId indefinitely.
    const aliasIds = aliases.map((alias) => alias.id);
    const affectedChildren = aliasIds.length > 0
      ? await database.tag.findMany({
        where: { userId, parentId: { in: aliasIds } }
      })
      : [];
    for (const child of affectedChildren) {
      const childVersion = child.version + 1;
      await database.tag.update({
        where: { id: child.id },
        data: {
          parentId: null,
          version: childVersion,
          updatedAt: now,
          serverUpdatedAt: now,
          lastModifiedByDeviceId: deviceId,
          lastMutationId: randomUUID()
        }
      });
      await logSyncChange({
        userId,
        entityType: "tag",
        entityId: child.id,
        version: childVersion,
        serverUpdatedAt: now,
        operation: child.deletedAt ? "delete" : "upsert"
      }, database);
    }
    for (const alias of aliases) {
      await database.tag.delete({ where: { id: alias.id } });
    }
    if (aliases.length > 0 || !tombstone.alreadyExisted) {
      await logSyncChange({
        userId,
        entityType: "tag",
        entityId: tombstone.entityId,
        version: deletedVersion,
        serverUpdatedAt: now,
        operation: "hard_delete"
      }, database);
    }
    forcedHardDeletedTagIds.add(tombstone.entityId);
  }

  // Tags are written first so note relationships can only reference owned rows.
  const dedupedTags = pickLatestByClientTime<TagDTO>(payload.tags ?? []);
  const tagsToApply: TagDTO[] = [];
  const resolvedTagIds = new Map<string, string>();

  for (const tag of dedupedTags.values()) {
    const resolvedId = await resolveTagId(database, userId, tag.id);
    const tombstone = await findTombstone(database, userId, "tag", tag.id);
    const existing = await database.tag.findFirst({ where: { id: resolvedId, userId } });
    const decision = decideSyncMutation({
      protocolVersion: payload.protocolVersion,
      hardDeleteRequested: hardDeletedTagKeys.has(syncIdentityKey(tag.id)),
      hasTombstone: !!tombstone,
      hasExisting: !!existing,
      baseVersion: tag.baseVersion,
      serverVersion: existing?.version,
      mutationId: tag.mutationId,
      previousMutationId: tag.previousMutationId,
      serverMutationId: existing?.lastMutationId
    });

    if (decision === "hard_delete" || decision === "tombstoned") {
      const hardDeletedId = normalizeNewSyncEntityId(tombstone?.entityId ?? tag.id);
      forcedHardDeletedTagIds.add(hardDeletedId);
      conflicts.push(buildConflict({
        entityType: "tag",
        id: resolvedId,
        serverVersion: 0,
        clientContent: tag.name,
        message: "sync.conflict.hard_deleted"
      }));
      continue;
    }

    resolvedTagIds.set(syncIdentityKey(tag.id), resolvedId);
    if (decision === "idempotent" && existing) {
      forcedTagIds.add(existing.id);
      continue;
    }
    if (decision === "conflict" && existing) {
      forcedTagIds.add(existing.id);
      conflicts.push(buildConflict({
        entityType: "tag",
        id: existing.id,
        serverVersion: existing.version,
        serverContent: existing.name,
        clientContent: tag.name,
        message: "sync.conflict.version"
      }));
      continue;
    }

    const nextVersion = (existing?.version ?? 0) + 1;
    const isDelete = !!tag.deletedAt;
    tagsToApply.push({
      ...tag,
      id: resolvedId,
      updatedAt: nowIso,
      deletedAt: isDelete ? nowIso : null,
      version: nextVersion,
      lastModifiedByDeviceId: deviceId,
      // Legacy clients have no durable mutation ID. The server still assigns a
      // fresh identity so a v4 peer never mistakes a legacy/third-party write
      // for its own lost acknowledgement.
      mutationId: tag.mutationId ?? randomUUID()
    });
  }

  for (const tag of tagsToApply) {
    await upsertTag(userId, { ...tag, parentId: tag.parentId ?? null }, { setParent: false }, database);
  }

  // Soft-deleting a parent has the same hierarchy semantics as Android's local
  // delete: active children become roots immediately. Children uploaded in this
  // batch are handled by the normal parent-resolution pass below and retain the
  // client's mutation/version; untouched children receive their own explicit
  // server mutation so every device observes parentId = null incrementally.
  const softDeletedTagIds = tagsToApply.filter((tag) => !!tag.deletedAt).map((tag) => tag.id);
  if (softDeletedTagIds.length > 0) {
    const appliedTagKeys = new Set(tagsToApply.map((tag) => syncIdentityKey(tag.id)));
    const affectedChildren = await database.tag.findMany({
      where: { userId, parentId: { in: softDeletedTagIds } }
    });
    for (const child of affectedChildren) {
      if (appliedTagKeys.has(syncIdentityKey(child.id))) continue;
      const childVersion = child.version + 1;
      await database.tag.update({
        where: { id: child.id },
        data: {
          parentId: null,
          version: childVersion,
          updatedAt: now,
          serverUpdatedAt: now,
          lastModifiedByDeviceId: deviceId,
          lastMutationId: randomUUID()
        }
      });
      await logSyncChange({
        userId,
        entityType: "tag",
        entityId: child.id,
        version: childVersion,
        serverUpdatedAt: now,
        operation: child.deletedAt ? "delete" : "upsert"
      }, database);
      forcedTagIds.add(child.id);
    }
  }
  const proposedParents: Array<{ id: string; parentId: string | null }> = [];
  for (const tag of tagsToApply) {
    const parentId = !tag.deletedAt && tag.parentId
      ? await resolveOwnedTagReference(database, userId, tag.parentId, resolvedTagIds, hardDeletedTagKeys)
      : null;
    if (tag.parentId && !parentId) forcedTagIds.add(tag.id);
    proposedParents.push({ id: tag.id, parentId });
  }
  const activeTagGraph = await database.tag.findMany({
    where: { userId, deletedAt: null, serverDeletedAt: null },
    select: { id: true, parentId: true }
  });
  const sanitizedParents = sanitizeTagParentChanges(activeTagGraph, proposedParents);

  for (const tag of tagsToApply) {
    const key = syncIdentityKey(tag.id);
    const parentId = sanitizedParents.parentByTagId.get(key) ?? null;
    if (sanitizedParents.adjustedTagIds.has(key)) forcedTagIds.add(tag.id);
    await upsertTag(userId, { ...tag, parentId }, { setParent: true }, database);
    await logSyncChange({
      userId,
      entityType: "tag",
      entityId: tag.id,
      version: tag.version ?? 1,
      serverUpdatedAt: now,
      operation: tag.deletedAt ? "delete" : "upsert"
    }, database);
  }

  const dedupedNotes = pickLatestByClientTime<NoteDTO>(payload.notes);
  for (const note of dedupedNotes.values()) {
    const resolvedId = await resolveNoteId(database, userId, note.id);
    const tombstone = await findTombstone(database, userId, "note", note.id);
    const existing = await database.note.findFirst({ where: { id: resolvedId, userId } });
    const decision = decideSyncMutation({
      protocolVersion: payload.protocolVersion,
      hardDeleteRequested: hardDeletedNoteKeys.has(syncIdentityKey(note.id)),
      hasTombstone: !!tombstone,
      hasExisting: !!existing,
      baseVersion: note.baseVersion,
      serverVersion: existing?.version,
      mutationId: note.mutationId,
      previousMutationId: note.previousMutationId,
      serverMutationId: existing?.lastMutationId
    });

    if (decision === "hard_delete" || decision === "tombstoned") {
      const hardDeletedId = normalizeNewSyncEntityId(tombstone?.entityId ?? note.id);
      forcedHardDeletedNoteIds.add(hardDeletedId);
      conflicts.push(buildConflict({
        entityType: "note",
        id: resolvedId,
        serverVersion: 0,
        clientContent: note.content,
        message: "sync.conflict.hard_deleted"
      }));
      continue;
    }

    if (shouldPreserveFinishedImport(existing, note)) {
      forcedNoteIds.add(existing!.id);
      continue;
    }

    if (decision === "idempotent" && existing) {
      forcedNoteIds.add(existing.id);
      continue;
    }

    if (decision === "conflict" && existing) {
      forcedNoteIds.add(existing.id);
      conflicts.push(buildConflict({
        entityType: "note",
        id: existing.id,
        serverVersion: existing.version,
        serverContent: existing.content,
        clientContent: note.content,
        message: "sync.conflict.version"
      }));
      continue;
    }

    const resolvedNoteTagIds: string[] | null | undefined = note.tagIds
      ? (await Promise.all(note.tagIds.map((tagId) =>
        resolveOwnedTagReference(database, userId, tagId, resolvedTagIds, hardDeletedTagKeys)
      ))).filter((tagId): tagId is string => !!tagId)
      : note.tagIds;
    const nextVersion = (existing?.version ?? 0) + 1;
    const isDelete = !!note.deletedAt;
    const upsertPayload: NoteDTO = {
      ...note,
      id: resolvedId,
      tagIds: resolvedNoteTagIds ? Array.from(new Set(resolvedNoteTagIds)) : resolvedNoteTagIds,
      updatedAt: nowIso,
      deletedAt: isDelete ? nowIso : null,
      version: nextVersion,
      lastModifiedByDeviceId: deviceId,
      mutationId: note.mutationId ?? randomUUID()
    };
    await upsertNote(userId, upsertPayload, database);
    await logSyncChange({
      userId,
      entityType: "note",
      entityId: resolvedId,
      version: nextVersion,
      serverUpdatedAt: now,
      operation: isDelete ? "delete" : "upsert"
    }, database);
  }

  return {
    conflicts,
    forcedNoteIds: Array.from(forcedNoteIds),
    forcedTagIds: Array.from(forcedTagIds),
    forcedHardDeletedNoteIds: Array.from(forcedHardDeletedNoteIds),
    forcedHardDeletedTagIds: Array.from(forcedHardDeletedTagIds)
  };
}
