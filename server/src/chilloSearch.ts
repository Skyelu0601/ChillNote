import { randomUUID } from "node:crypto";
import { Prisma } from "@prisma/client";
import { prisma } from "./db.js";
import { acquireUserSyncTransactionLock } from "./store.js";
import { contentHash, lexicalScore, similarity, sourceTitle, splitNote, type SearchPlan, type SourceNote } from "./chilloCore.js";
import { CHILLO_EMBED_MODEL, embedChillo } from "./chilloModel.js";

export const activeChilloNotes: Prisma.NoteWhereInput = {
  deletedAt: null, content: { not: "" }, OR: [{ importStatus: null }, { importStatus: "completed" }]
};

// Cloud processing is opt-in, separately from opening the chat or syncing notes.
export async function requireChilloConsent(userId: string): Promise<void> {
  const user = await prisma.user.findUnique({ where: { id: userId }, select: { chilloConsentVersion: true } });
  if (user?.chilloConsentVersion !== 1) throw new Error("CONSENT_REQUIRED");
}

export async function libraryStatus(userId: string) {
  const [total, available, indexed, user] = await Promise.all([
    prisma.note.count({ where: { userId, deletedAt: null } }),
    prisma.note.count({ where: { userId, ...activeChilloNotes } }),
    prisma.note.count({ where: { userId, ...activeChilloNotes, chilloChunks: { some: { model: CHILLO_EMBED_MODEL } } } }),
    prisma.user.findUnique({ where: { id: userId }, select: { chilloConsentVersion: true } })
  ]);
  return { total, available, indexed, pending: total - available, consentVersion: user?.chilloConsentVersion ?? 0 };
}

export type Passage = { noteId: string; hash: string; start: number; end: number; text: string; title: string; platform: string | null; generated: boolean; score: number };

export function validDate(raw?: string | null): Date | undefined {
  if (!raw || !/^\d{4}-\d{2}-\d{2}(?:T.*)?$/.test(raw)) return undefined;
  const date = new Date(raw);
  return Number.isFinite(date.getTime()) ? date : undefined;
}

export async function searchLibrary(userId: string, plan: SearchPlan, pinnedIds: string[], excludedIds: string[]): Promise<Passage[]> {
  await requireChilloConsent(userId);
  const queries = plan.queries.length ? plan.queries : [""];
  let vectors: number[][] = [];
  try { vectors = await embedChillo(queries.filter(Boolean), true); } catch { /* Lexical retrieval still covers the full library. */ }
  const after = validDate(plan.after), before = validDate(plan.before);
  const where: Prisma.NoteWhereInput = {
    userId, ...activeChilloNotes, id: { notIn: excludedIds },
    ...(plan.section !== "all" ? { section: plan.section } : {}),
    ...(after || before ? { createdAt: { gte: after, lt: before } } : {}),
    ...(plan.tag ? { tags: { some: { userId, deletedAt: null, name: { equals: plan.tag, mode: "insensitive" } } } } : {})
  };
  let cursor: string | undefined;
  let best: Passage[] = [];
  // Keyset paging scans every active note, including old and long notes, with bounded memory.
  for (;;) {
    const notes = await prisma.note.findMany({ where, take: 100, orderBy: { id: "asc" },
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: { tags: { where: { deletedAt: null } }, chilloChunks: { where: { model: CHILLO_EMBED_MODEL } } }
    });
    for (const note of notes) {
      const hash = contentHash(note.content);
      const metadata = [sourceTitle(note), note.sourceAuthorName, ...note.tags.map(tag => tag.name)].join(" ");
      const chunks = new Map(note.chilloChunks.filter(chunk => chunk.hash === hash).map(chunk => [chunk.start, chunk]));
      const ranked = splitNote(note.content).map(part => {
        const embedding = chunks.get(part.start)?.embedding ?? [];
        const score = Math.max(...queries.map(query => lexicalScore(query, part.text, metadata)))
          + Math.max(0, ...vectors.map(vector => similarity(vector, embedding) - 0.35)) * 1.8
          + (pinnedIds.includes(note.id) ? 3 : 0) + (queries.every(query => !query) ? 0.2 : 0);
        return { ...part, noteId: note.id, hash, title: sourceTitle(note), platform: note.sourcePlatformName, generated: note.isChilloDraft, score };
      }).filter(part => part.score > 0).sort((a, b) => b.score - a.score).slice(0, 2);
      best.push(...ranked);
    }
    best = best.sort((a, b) => b.score - a.score).slice(0, 32);
    if (notes.length < 100) break;
    cursor = notes.at(-1)!.id;
  }
  return best.slice(0, 16);
}

export async function indexChilloLibrary(userId: string): Promise<void> {
  await requireChilloConsent(userId);
  const notes = await prisma.note.findMany({ where: { userId, ...activeChilloNotes,
    AND: [{ OR: [{ chilloIndexRetryAt: null }, { chilloIndexRetryAt: { lte: new Date() } }] }],
    chilloChunks: { none: { model: CHILLO_EMBED_MODEL } } }, orderBy: { id: "asc" }, take: 4 });
  for (const note of notes) {
    try {
    const chunks = splitNote(note.content);
    const vectors: number[][] = [];
    for (let start = 0; start < chunks.length; start += 32) {
      await requireChilloConsent(userId);
      vectors.push(...await embedChillo(chunks.slice(start, start + 32).map(chunk => chunk.text)));
    }
    await prisma.$transaction(async tx => {
      // Serialize publication with consent revocation/account deletion. Without
      // this lock, a late index commit could recreate vectors after revocation.
      await acquireUserSyncTransactionLock(userId, tx);
      await tx.$queryRaw`SELECT "id" FROM "Note" WHERE "id" = ${note.id} AND "userId" = ${userId} FOR UPDATE`;
      const current = await tx.note.findUnique({ where: { id: note.id } });
      const user = await tx.user.findUnique({ where: { id: userId } });
      if (!current || current.deletedAt || current.content !== note.content || user?.chilloConsentVersion !== 1) return;
      await tx.chilloChunk.deleteMany({ where: { noteId: note.id } });
      await tx.chilloChunk.createMany({ data: chunks.map((chunk, i) => ({ id: randomUUID(), noteId: note.id, hash: contentHash(note.content), start: chunk.start, end: chunk.end, embedding: vectors[i], model: CHILLO_EMBED_MODEL })) });
      await tx.note.update({ where: { id: note.id }, data: { chilloIndexRetryAt: null } });
    });
    } catch {
      // A single malformed/oversized note must not starve the rest of the library.
      await prisma.note.updateMany({ where: { id: note.id, userId }, data: { chilloIndexRetryAt: new Date(Date.now() + 15 * 60 * 1000) } });
    }
  }
}
