import type { NoteDTO, SyncPayload, TagDTO } from "./types.js";
import { prisma } from "./db.js";
import type { Prisma } from "@prisma/client";

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

export async function toPayload(userId: string, since?: string): Promise<SyncPayload> {
  const sinceDate = since ? new Date(since) : null;
  const noteWhere: Prisma.NoteWhereInput = sinceDate
    ? {
      userId,
      OR: [{ updatedAt: { gte: sinceDate } }, { deletedAt: { gte: sinceDate } }]
    }
    : { userId };
  // Cast to any to allow compilation before prisma client is regenerated with new fields.
  const tagWhere: any = sinceDate
    ? {
      userId,
      OR: [{ updatedAt: { gte: sinceDate } }, { deletedAt: { gte: sinceDate } }]
    }
    : { userId };

  const notes = await prisma.note.findMany({
    where: noteWhere,
    include: { tags: true }
  });
  const tags = await prisma.tag.findMany({
    where: tagWhere
  });

  return {
    notes: notes.map((note: any): NoteDTO => ({
      id: note.id,
      content: note.content,
      createdAt: note.createdAt.toISOString(),
      updatedAt: note.updatedAt.toISOString(),
      deletedAt: note.deletedAt?.toISOString() ?? null,
      tagIds: Array.isArray(note.tags) ? note.tags.filter((tag: any) => tag.deletedAt == null).map((tag: any) => tag.id) : []
    })),
    tags: tags.map(
      (tag: any): TagDTO => ({
        id: tag.id,
        name: tag.name,
        colorHex: tag.colorHex,
        createdAt: tag.createdAt.toISOString(),
        updatedAt: tag.updatedAt.toISOString(),
        lastUsedAt: tag.lastUsedAt?.toISOString() ?? null,
        sortOrder: tag.sortOrder,
        parentId: tag.parentId ?? null,
        deletedAt: tag.deletedAt?.toISOString() ?? null
      })
    )
  };
}

export async function upsertTag(userId: string, incoming: TagDTO, options: { setParent?: boolean } = {}): Promise<void> {
  const setParent = options.setParent ?? true;
  const baseData = {
    name: incoming.name,
    colorHex: incoming.colorHex,
    createdAt: new Date(incoming.createdAt),
    updatedAt: new Date(incoming.updatedAt),
    lastUsedAt: incoming.lastUsedAt ? new Date(incoming.lastUsedAt) : null,
    sortOrder: incoming.sortOrder,
    userId,
    deletedAt: incoming.deletedAt ? new Date(incoming.deletedAt) : null
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
  const tagIds = incoming.tagIds ?? undefined;
  await prisma.note.upsert({
    where: { id: incoming.id },
    update: {
      content: incoming.content,
      createdAt: new Date(incoming.createdAt),
      updatedAt: new Date(incoming.updatedAt),
      deletedAt: incoming.deletedAt ? new Date(incoming.deletedAt) : null,
      userId,
      tags: tagIds ? { set: tagIds.map((tagId) => ({ id: tagId })) } : undefined
    },
    create: {
      id: incoming.id,
      userId,
      content: incoming.content,
      createdAt: new Date(incoming.createdAt),
      updatedAt: new Date(incoming.updatedAt),
      deletedAt: incoming.deletedAt ? new Date(incoming.deletedAt) : null,
      tags: tagIds ? { connect: tagIds.map((tagId) => ({ id: tagId })) } : undefined
    }
  });
}

export async function deleteUser(userId: string): Promise<void> {
  await prisma.user.delete({
    where: { id: userId }
  });
}
