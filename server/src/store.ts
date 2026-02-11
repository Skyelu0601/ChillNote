import type { NoteDTO, SyncChanges, TagDTO } from "./types.js";
import { prisma } from "./db.js";

export async function upsertUser(userId: string): Promise<void> {
  await prisma.user.upsert({
    where: { id: userId },
    update: {},
    create: { id: userId }
  });
}

export async function updateSubscriptionStatus(
  userId: string,
  tier: string,
  expiresAt: Date | null,
  originalTransactionId: string | null
): Promise<void> {
  await prisma.user.update({
    where: { id: userId },
    data: {
      subscriptionTier: tier,
      subscriptionExpiresAt: expiresAt,
      originalTransactionId: originalTransactionId
    }
  });
}

function mapNoteToDTO(note: any): NoteDTO {
  return {
    id: note.id,
    content: note.content,
    createdAt: note.createdAt.toISOString(),
    updatedAt: note.serverUpdatedAt?.toISOString() ?? note.updatedAt?.toISOString() ?? null,
    deletedAt: note.serverDeletedAt?.toISOString() ?? note.deletedAt?.toISOString() ?? null,
    pinnedAt: note.pinnedAt?.toISOString() ?? null,
    tagIds: Array.isArray(note.tags)
      ? note.tags.filter((tag: any) => tag.serverDeletedAt == null && tag.deletedAt == null).map((tag: any) => tag.id)
      : [],
    version: note.version ?? 1,
    lastModifiedByDeviceId: note.lastModifiedByDeviceId ?? null
  };
}

function mapTagToDTO(tag: any): TagDTO {
  return {
    id: tag.id,
    name: tag.name,
    colorHex: tag.colorHex,
    createdAt: tag.createdAt.toISOString(),
    updatedAt: tag.serverUpdatedAt?.toISOString() ?? tag.updatedAt?.toISOString() ?? null,
    lastUsedAt: tag.lastUsedAt?.toISOString() ?? null,
    sortOrder: tag.sortOrder,
    parentId: tag.parentId ?? null,
    deletedAt: tag.serverDeletedAt?.toISOString() ?? tag.deletedAt?.toISOString() ?? null,
    version: tag.version ?? 1,
    lastModifiedByDeviceId: tag.lastModifiedByDeviceId ?? null
  };
}

export async function getChangesSinceCursor(userId: string, cursor?: string | null): Promise<{ changes: SyncChanges; cursor: string }> {
  const parsedCursor = cursor ? Number(cursor) : null;
  const cursorId = Number.isFinite(parsedCursor) ? parsedCursor : null;
  const logs = await prisma.syncLog.findMany({
    where: cursorId ? { userId, id: { gt: cursorId } } : { userId },
    orderBy: { id: "asc" }
  });

  let newCursor = cursorId ?? 0;
  if (logs.length > 0) {
    newCursor = logs[logs.length - 1].id;
  }

  if (cursorId == null) {
    const notes = await prisma.note.findMany({
      where: { userId },
      include: { tags: true }
    });
    const tags = await prisma.tag.findMany({
      where: { userId }
    });
    return {
      cursor: String(newCursor),
      changes: {
        notes: notes.map(mapNoteToDTO),
        tags: tags.map(mapTagToDTO)
      }
    };
  }

  const latestByEntity = new Map<string, { entityType: string; entityId: string }>();
  for (const log of logs) {
    const key = `${log.entityType}:${log.entityId}`;
    latestByEntity.set(key, { entityType: log.entityType, entityId: log.entityId });
  }

  const noteIds: string[] = [];
  const tagIds: string[] = [];
  for (const entry of latestByEntity.values()) {
    if (entry.entityType === "note") {
      noteIds.push(entry.entityId);
    } else if (entry.entityType === "tag") {
      tagIds.push(entry.entityId);
    }
  }

  const notes = noteIds.length
    ? await prisma.note.findMany({
      where: { userId, id: { in: noteIds } },
      include: { tags: true }
    })
    : [];
  const tags = tagIds.length
    ? await prisma.tag.findMany({
      where: { userId, id: { in: tagIds } }
    })
    : [];

  return {
    cursor: String(newCursor),
    changes: {
      notes: notes.map(mapNoteToDTO),
      tags: tags.map(mapTagToDTO)
    }
  };
}

export async function upsertTag(
  userId: string,
  incoming: TagDTO,
  options: { setParent?: boolean } = {}
): Promise<void> {
  const setParent = options.setParent ?? true;
  const serverUpdatedAt = incoming.updatedAt ? new Date(incoming.updatedAt) : new Date();
  const baseData = {
    name: incoming.name,
    colorHex: incoming.colorHex,
    createdAt: new Date(incoming.createdAt),
    updatedAt: new Date(),
    lastUsedAt: incoming.lastUsedAt ? new Date(incoming.lastUsedAt) : null,
    sortOrder: incoming.sortOrder,
    userId,
    deletedAt: incoming.deletedAt ? new Date(incoming.deletedAt) : null,
    serverUpdatedAt,
    serverDeletedAt: incoming.deletedAt ? new Date(incoming.deletedAt) : null,
    version: incoming.version ?? 1,
    lastModifiedByDeviceId: incoming.lastModifiedByDeviceId ?? null
  };

  await prisma.tag.upsert({
    where: { id: incoming.id },
    update: {
      ...baseData,
      ...(setParent ? { parentId: incoming.parentId ?? null } : {})
    },
    create: {
      id: incoming.id,
      ...baseData,
      parentId: setParent ? incoming.parentId ?? null : null
    }
  });
}

export async function upsertNote(userId: string, incoming: NoteDTO): Promise<void> {
  const serverUpdatedAt = incoming.updatedAt ? new Date(incoming.updatedAt) : new Date();
  const tagIds = incoming.tagIds ?? undefined;
  await prisma.note.upsert({
    where: { id: incoming.id },
    update: {
      content: incoming.content,
      createdAt: new Date(incoming.createdAt),
      updatedAt: new Date(),
      deletedAt: incoming.deletedAt ? new Date(incoming.deletedAt) : null,
      pinnedAt: incoming.pinnedAt ? new Date(incoming.pinnedAt) : null,
      userId,
      serverUpdatedAt,
      serverDeletedAt: incoming.deletedAt ? new Date(incoming.deletedAt) : null,
      version: incoming.version ?? 1,
      lastModifiedByDeviceId: incoming.lastModifiedByDeviceId ?? null,
      tags: tagIds ? { set: tagIds.map((tagId) => ({ id: tagId })) } : undefined
    },
    create: {
      id: incoming.id,
      userId,
      content: incoming.content,
      createdAt: new Date(incoming.createdAt),
      updatedAt: new Date(),
      deletedAt: incoming.deletedAt ? new Date(incoming.deletedAt) : null,
      pinnedAt: incoming.pinnedAt ? new Date(incoming.pinnedAt) : null,
      serverUpdatedAt,
      serverDeletedAt: incoming.deletedAt ? new Date(incoming.deletedAt) : null,
      version: incoming.version ?? 1,
      lastModifiedByDeviceId: incoming.lastModifiedByDeviceId ?? null,
      tags: tagIds ? { connect: tagIds.map((tagId) => ({ id: tagId })) } : undefined
    }
  });
}

export async function deleteUser(userId: string): Promise<void> {
  await prisma.user.delete({
    where: { id: userId }
  });
}

export async function logSyncChange(params: {
  userId: string;
  entityType: "note" | "tag";
  entityId: string;
  version: number;
  serverUpdatedAt: Date;
  operation: "upsert" | "delete";
}): Promise<void> {
  await prisma.syncLog.create({
    data: {
      userId: params.userId,
      entityType: params.entityType,
      entityId: params.entityId,
      version: params.version,
      serverUpdatedAt: params.serverUpdatedAt,
      operation: params.operation
    }
  });
}
