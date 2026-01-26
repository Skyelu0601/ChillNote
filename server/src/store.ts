import type { NoteDTO, SyncPayload } from "./types.js";
import { prisma } from "./db.js";

export async function upsertUser(userId: string): Promise<void> {
  await prisma.user.upsert({
    where: { id: userId },
    update: {},
    create: { id: userId }
  });
}

export async function toPayload(userId: string, since?: string): Promise<SyncPayload> {
  const sinceDate = since ? new Date(since) : null;
  const noteWhere = sinceDate
    ? {
      userId,
      OR: [{ updatedAt: { gte: sinceDate } }, { deletedAt: { gte: sinceDate } }]
    }
    : { userId };

  const notes = await prisma.note.findMany({ where: noteWhere });

  return {
    notes: notes.map((note: any): NoteDTO => ({
      id: note.id,
      content: note.content,
      createdAt: note.createdAt.toISOString(),
      updatedAt: note.updatedAt.toISOString(),
      deletedAt: note.deletedAt?.toISOString() ?? null
    }))
  };
}

export async function upsertNote(userId: string, incoming: NoteDTO): Promise<void> {
  await prisma.note.upsert({
    where: { id: incoming.id },
    update: {
      content: incoming.content,
      createdAt: new Date(incoming.createdAt),
      updatedAt: new Date(incoming.updatedAt),
      deletedAt: incoming.deletedAt ? new Date(incoming.deletedAt) : null,
      userId
    },
    create: {
      id: incoming.id,
      userId,
      content: incoming.content,
      createdAt: new Date(incoming.createdAt),
      updatedAt: new Date(incoming.updatedAt),
      deletedAt: incoming.deletedAt ? new Date(incoming.deletedAt) : null
    }
  });
}

export async function deleteUser(userId: string): Promise<void> {
  await prisma.user.delete({
    where: { id: userId }
  });
}
