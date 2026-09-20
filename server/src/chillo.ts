import { randomUUID } from "node:crypto";
import type { Express, RequestHandler } from "express";
import type { ChilloTurn, Prisma } from "@prisma/client";
import { z } from "zod";
import { prisma } from "./db.js";
import { acquireUserSyncTransactionLock, logSyncChange, upsertUser } from "./store.js";
import { chilloId, chilloRequest, chilloScope, chilloSystemPrompt, finalizeCitations, parseSources, searchPlanSchema, sourceAvailability, sourceTitle, stripCitations, type SourceRef } from "./chilloCore.js";
import { generateChillo } from "./chilloModel.js";
import { indexChilloLibrary, libraryStatus, requireChilloConsent, searchLibrary, type Passage } from "./chilloSearch.js";

type Billing = { allowed: boolean; tier: string; cost: number; balance: number | null };
type Dependencies = { credits: (userId: string) => Promise<Billing>; startWorkers?: boolean; database?: typeof prisma };
const active = ["queued", "running"];
const publicErrors = new Set(["CONSENT_REQUIRED", "INSUFFICIENT_CREDITS", "MODEL_NOT_CONFIGURED", "MODEL_BUSY", "SOURCES_CHANGED", "NOT_FOUND", "BUSY", "CONFLICT", "DRAFT_DELETED", "INVALID_REQUEST"]);

async function transactUser<T>(userId: string, action: (tx: Prisma.TransactionClient) => Promise<T>, database = prisma) {
  return database.$transaction(async tx => {
    await acquireUserSyncTransactionLock(userId, tx);
    await upsertUser(userId, tx);
    return action(tx);
  });
}
async function ownedConversation(userId: string, id: string, tx: Prisma.TransactionClient = prisma) {
  const conversation = await tx.chilloConversation.findFirst({ where: { id: chilloId.parse(id), userId } });
  if (!conversation) throw new Error("NOT_FOUND");
  return conversation;
}
async function resolveSources(userId: string, raw: unknown, tx: Prisma.TransactionClient = prisma) {
  const refs = parseSources(raw);
  const notes = await tx.note.findMany({ where: { userId, id: { in: refs.map(ref => ref.noteId) } } });
  return refs.map(ref => {
    const note = notes.find(note => note.id === ref.noteId);
    const availability = sourceAvailability(ref, note);
    return { number: ref.number, noteId: ref.noteId, availability,
      title: note && !note.deletedAt ? sourceTitle(note) : "",
      excerpt: availability === "active" ? note!.content.slice(ref.start, ref.end) : "", platform: note?.sourcePlatformName ?? null };
  });
}
async function lockSources(userId: string, raw: unknown, tx: Prisma.TransactionClient) {
  const ids = [...new Set(parseSources(raw).map(source => source.noteId))].sort();
  if (ids.length) await tx.$queryRaw`SELECT "id" FROM "Note" WHERE "userId" = ${userId} AND "id" = ANY(${ids}::text[]) ORDER BY "id" FOR SHARE`;
}
async function presentTurn(userId: string, turn: ChilloTurn, tx: Prisma.TransactionClient = prisma) {
  const [sources, draft] = await Promise.all([
    resolveSources(userId, turn.sources, tx), tx.chilloDraft.findUnique({ where: { turnId: turn.id } })
  ]);
  const sourcesChanged = sources.some(source => source.availability !== "active");
  return { id: turn.id, request: turn.request, answer: sourcesChanged ? "" : turn.answer, status: turn.status,
    errorCode: turn.errorCode, sources, sourcesChanged, createdAt: turn.createdAt, draftNoteId: draft?.noteId ?? null };
}

export function registerChillo(app: Express, auth: RequestHandler, deps: Dependencies) {
  const database = deps.database ?? prisma;
  const userTransaction = <T>(userId: string, action: (tx: Prisma.TransactionClient) => Promise<T>) => transactUser(userId, action, database);
  const consent = async (userId: string) => {
    const user = await database.user.findUnique({ where: { id: userId }, select: { chilloConsentVersion: true } });
    if (user?.chilloConsentVersion !== 1) throw new Error("CONSENT_REQUIRED");
  };
  const route = (handler: RequestHandler): RequestHandler => (req, res, next) => {
    Promise.resolve(handler(req, res, next)).catch(error => {
      const code = error instanceof z.ZodError ? "INVALID_REQUEST" : publicErrors.has(error?.message) ? error.message : "REQUEST_FAILED";
      const status = code === "NOT_FOUND" ? 404 : code === "CONSENT_REQUIRED" ? 403 : code === "INVALID_REQUEST" ? 400 : ["BUSY", "CONFLICT", "DRAFT_DELETED", "SOURCES_CHANGED"].includes(code) ? 409 : 503;
      res.status(status).json({ error: code });
    });
  };
  app.get("/chillo/library", auth, route(async (req, res) => { res.json(await libraryStatus(req.userId!)); }));
  app.put("/chillo/consent", auth, route(async (req, res) => {
    const { version } = z.object({ version: z.union([z.literal(0), z.literal(1)]) }).parse(req.body);
    await userTransaction(req.userId!, async tx => {
      await tx.user.update({ where: { id: req.userId! }, data: { chilloConsentVersion: version, chilloConsentAt: version ? new Date() : null } });
      if (!version) {
        await tx.chilloTurn.updateMany({ where: { conversation: { userId: req.userId! }, status: { in: active } }, data: { status: "cancelled", leaseId: null, leaseExpiresAt: null } });
        await tx.chilloChunk.deleteMany({ where: { note: { userId: req.userId! } } });
      }
    });
    res.json({ consentVersion: version });
  }));
  app.get("/chillo/conversations", auth, route(async (req, res) => {
    const cursor = req.query.cursor ? chilloId.parse(req.query.cursor) : undefined;
    if (cursor) await ownedConversation(req.userId!, cursor, database);
    const conversations = await database.chilloConversation.findMany({ where: { userId: req.userId! }, orderBy: [{ updatedAt: "desc" }, { id: "desc" }], take: 30,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}), select: { id: true, title: true, updatedAt: true } });
    res.json({ conversations, nextCursor: conversations.length === 30 ? conversations.at(-1)!.id : null });
  }));
  app.post("/chillo/conversations", auth, route(async (req, res) => {
    const id = chilloId.parse(req.body.id);
    const conversation = await userTransaction(req.userId!, async tx => {
      const existing = await tx.chilloConversation.findUnique({ where: { id } });
      if (existing && existing.userId !== req.userId) throw new Error("CONFLICT");
      return existing ?? tx.chilloConversation.create({ data: { id, userId: req.userId!, title: "" } });
    });
    res.json(conversation);
  }));
  app.get("/chillo/conversations/:id", auth, route(async (req, res) => {
    const conversation = await ownedConversation(req.userId!, req.params.id, database);
    const cursor = req.query.cursor ? chilloId.parse(req.query.cursor) : undefined;
    if (cursor && !await database.chilloTurn.findFirst({ where: { id: cursor, conversationId: conversation.id } })) throw new Error("NOT_FOUND");
    const turns = await database.chilloTurn.findMany({ where: { conversationId: conversation.id }, orderBy: [{ createdAt: "desc" }, { id: "desc" }], take: 40,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}) });
    res.json({ ...conversation, turns: await Promise.all([...turns].reverse().map(turn => presentTurn(req.userId!, turn, database))), olderCursor: turns.length === 40 ? turns.at(-1)!.id : null });
  }));
  app.patch("/chillo/conversations/:id", auth, route(async (req, res) => {
    const scope = chilloScope.parse(req.body);
    await userTransaction(req.userId!, async tx => {
      const conversation = await ownedConversation(req.userId!, req.params.id, tx);
      if (await tx.chilloTurn.count({ where: { conversationId: conversation.id, status: { in: active } } })) throw new Error("BUSY");
      const ids = [...scope.pinnedIds, ...scope.excludedIds];
      const notes = ids.length ? await tx.note.findMany({ where: { userId: req.userId!, deletedAt: null, OR: ids.map(id => ({ id: { equals: id, mode: "insensitive" as const } })) }, select: { id: true } }) : [];
      const canonical = (list: string[]) => [...new Set(list.map(id => notes.find(note => note.id.toLowerCase() === id.toLowerCase())?.id).filter((id): id is string => Boolean(id)))];
      await tx.chilloConversation.update({ where: { id: conversation.id }, data: { pinnedIds: canonical(scope.pinnedIds), excludedIds: canonical(scope.excludedIds) } });
    });
    res.json({ ok: true });
  }));
  app.delete("/chillo/conversations/:id", auth, route(async (req, res) => {
    await userTransaction(req.userId!, async tx => {
      await ownedConversation(req.userId!, req.params.id, tx);
      await tx.chilloConversation.delete({ where: { id: chilloId.parse(req.params.id) } });
    });
    res.json({ ok: true });
  }));
  app.post("/chillo/conversations/:id/turns", auth, route(async (req, res) => {
    await consent(req.userId!);
    const input = chilloRequest.parse(req.body);
    const turn = await userTransaction(req.userId!, async tx => {
      const conversation = await ownedConversation(req.userId!, req.params.id, tx);
      const existing = await tx.chilloTurn.findUnique({ where: { id: input.id } });
      if (existing) {
        if (existing.conversationId !== conversation.id || existing.request !== input.message) throw new Error("CONFLICT");
        return existing;
      }
      if (await tx.chilloTurn.count({ where: { conversationId: conversation.id, status: { in: active } } }) ||
        await tx.chilloTurn.count({ where: { conversation: { userId: req.userId! }, status: { in: active } } }) >= 2) throw new Error("BUSY");
      await tx.chilloConversation.update({ where: { id: conversation.id }, data: { title: conversation.title || input.message.slice(0, 80), updatedAt: new Date() } });
      return tx.chilloTurn.create({ data: { id: input.id, conversationId: conversation.id, request: input.message, locale: input.locale } });
    });
    res.status(202).json(await presentTurn(req.userId!, turn, database));
    void tick();
  }));
  app.post("/chillo/conversations/:id/turns/:turnId/:action", auth, route(async (req, res) => {
    const action = z.enum(["cancel", "retry", "draft"]).parse(req.params.action);
    if (action === "retry") await consent(req.userId!);
    const result = await userTransaction(req.userId!, async tx => {
      const conversation = await ownedConversation(req.userId!, req.params.id, tx);
      const turn = await tx.chilloTurn.findFirst({ where: { id: chilloId.parse(req.params.turnId), conversationId: conversation.id } });
      if (!turn) throw new Error("NOT_FOUND");
      if (action === "cancel") {
        await tx.chilloTurn.updateMany({ where: { id: turn.id, status: { in: active } }, data: { status: "cancelled", leaseId: null, leaseExpiresAt: null } });
        return { ok: true };
      }
      if (action === "retry") {
        const latest = await tx.chilloTurn.findFirst({ where: { conversationId: conversation.id }, orderBy: [{ createdAt: "desc" }, { id: "desc" }] });
        if (!["failed", "cancelled"].includes(turn.status) || latest?.id !== turn.id) throw new Error("CONFLICT");
        if (await tx.chilloTurn.count({ where: { conversation: { userId: req.userId! }, status: { in: active } } }) >= 2) throw new Error("BUSY");
        await tx.chilloTurn.update({ where: { id: turn.id }, data: { status: "queued", errorCode: null, leaseId: null, leaseExpiresAt: null } });
        return { ok: true };
      }
      const existing = await tx.chilloDraft.findUnique({ where: { turnId: turn.id }, include: { note: true } });
      if (existing) {
        if (!existing.note || existing.note.deletedAt) throw new Error("DRAFT_DELETED");
        return { noteId: existing.noteId };
      }
      if (turn.status !== "completed" || !turn.answer) throw new Error("CONFLICT");
      await lockSources(req.userId!, turn.sources, tx);
      const sources = await resolveSources(req.userId!, turn.sources, tx);
      if (sources.some(source => source.availability !== "active")) throw new Error("SOURCES_CHANGED");
      const noteId = randomUUID(), now = new Date();
      await tx.note.create({ data: { id: noteId, userId: req.userId!, content: stripCitations(turn.answer), section: "drafts", isChilloDraft: true, createdAt: now, updatedAt: now, serverUpdatedAt: now, version: 1, lastMutationId: randomUUID() } });
      await tx.chilloDraft.create({ data: { id: randomUUID(), turnId: turn.id, noteId } });
      await logSyncChange({ userId: req.userId!, entityType: "note", entityId: noteId, version: 1, serverUpdatedAt: now, operation: "upsert" }, tx);
      return { noteId };
    });
    res.json(result);
    if (action === "retry") void tick();
  }));

  let running = false, indexing = false;
  async function tick() {
    if (running || deps.startWorkers === false) return;
    running = true;
    try {
      const turns = await prisma.chilloTurn.findMany({ where: { OR: [{ status: "queued" }, { status: "running", leaseExpiresAt: { lt: new Date() } }] }, orderBy: { createdAt: "asc" }, take: 2 });
      await Promise.allSettled(turns.map(turn => runTurn(turn.id, deps)));
    } catch { /* Retry on next worker tick; never log note contents or prompts. */ }
    finally { running = false; }
  }
  async function indexTick() {
    if (indexing) return;
    indexing = true;
    try {
      // Fair round-robin across explicitly opted-in accounts, not just recent conversations.
      const user = await prisma.user.findFirst({ where: { chilloConsentVersion: 1 }, orderBy: { chilloIndexCheckedAt: { sort: "asc", nulls: "first" } }, select: { id: true } });
      if (user) {
        await prisma.user.update({ where: { id: user.id }, data: { chilloIndexCheckedAt: new Date() } });
        await indexChilloLibrary(user.id);
      }
    } catch { /* Retrieval continues using text while the index is unavailable. */ }
    finally { indexing = false; }
  }
  if (deps.startWorkers === false) return () => {};
  const turnTimer = setInterval(() => void tick(), 4000);
  const indexTimer = setInterval(() => void indexTick(), 15000);
  turnTimer.unref(); indexTimer.unref();
  return () => { clearInterval(turnTimer); clearInterval(indexTimer); };
}

async function runTurn(id: string, deps: Dependencies) {
  const leaseId = randomUUID();
  const claimed = await prisma.chilloTurn.updateMany({ where: { id, OR: [{ status: "queued" }, { status: "running", leaseExpiresAt: { lt: new Date() } }] }, data: { status: "running", leaseId, leaseExpiresAt: new Date(Date.now() + 90000) } });
  if (!claimed.count) return;
  const heartbeat = setInterval(() => {
    void prisma.chilloTurn.updateMany({ where: { id, leaseId, status: "running" }, data: { leaseExpiresAt: new Date(Date.now() + 90000) } }).catch(() => {});
  }, 20000);
  heartbeat.unref();
  try {
    const turn = await prisma.chilloTurn.findUniqueOrThrow({ where: { id }, include: { conversation: true } });
    const conversation = turn.conversation, userId = conversation.userId;
    await requireChilloConsent(userId);
    const billing = await deps.credits(userId);
    if (!billing.allowed) throw new Error("INSUFFICIENT_CREDITS");
    const history = await prisma.chilloTurn.findMany({ where: { conversationId: conversation.id, status: "completed", createdAt: { lt: turn.createdAt } }, orderBy: { createdAt: "desc" }, take: 80 });
    const previous = await Promise.all(history.reverse().map(async (item, index) => {
      const sources = await resolveSources(userId, item.sources);
      const safe = sources.every(source => source.availability === "active" && !conversation.excludedIds.includes(source.noteId));
      return { request: item.request.slice(0, index < history.length - 8 ? 1200 : 16000), answer: safe && index >= history.length - 8 ? stripCitations(item.answer) : undefined };
    }));
    const status = await libraryStatus(userId);
    let passages: Passage[] = [];
    let answer = "";
    let scope = searchPlanSchema.parse({});
    for (let round = 0; round < 5; round++) {
      await requireChilloConsent(userId);
      if (!await prisma.chilloTurn.count({ where: { id, leaseId, status: "running" } })) return;
      const plan = await generateChillo(chilloSystemPrompt,
        JSON.stringify({ request: turn.request, locale: turn.locale, history: previous, library: status, searchesRemaining: 4 - round,
          instruction: round === 4 ? "Return your answer now, with empty queries. State any gaps." : round === 0 ? "Interpret any explicit date/tag/section constraints before searching. Search the library for requests about saved material. Prior answers are not independent evidence." : "Search further if needed, or answer.",
          sources: passages.map((passage, index) => ({ number: index + 1, title: passage.title, platform: passage.platform, generatedDraft: passage.generated, text: passage.text })) }));
      if (plan.answer && !plan.queries.length) { answer = plan.answer; break; }
      if (round === 4) throw new Error("INCOMPLETE_RESPONSE");
      // One turn has one user request: a later synonym query cannot silently drop its filters.
      scope = { ...plan, section: plan.section === "all" ? scope.section : plan.section,
        after: plan.after ?? scope.after, before: plan.before ?? scope.before, tag: plan.tag ?? scope.tag };
      const found = await searchLibrary(userId, scope, conversation.pinnedIds, conversation.excludedIds);
      // Explicit filters replace context so excluded time ranges/sections cannot leak back in.
      const filtered = scope.section !== "all" || scope.after || scope.before || scope.tag;
      const unique = new Map((filtered ? found : [...passages, ...found]).map(p => [`${p.noteId}:${p.start}`, p]));
      passages = [...unique.values()].sort((a, b) => b.score - a.score).slice(0, 28);
    }
    if (!answer.trim()) throw new Error("INCOMPLETE_RESPONSE");
    const offered: SourceRef[] = passages.map((p, index) => ({ number: index + 1, noteId: p.noteId, hash: p.hash, start: p.start, end: p.end }));
    const finalized = finalizeCitations(answer, offered);
    await transactUser(userId, async tx => {
      const user = await tx.user.findUniqueOrThrow({ where: { id: userId } });
      if (user.chilloConsentVersion !== 1) throw new Error("CONSENT_REQUIRED");
      const current = await tx.chilloTurn.findFirst({ where: { id, leaseId, status: "running" } });
      if (!current) return;
      await lockSources(userId, finalized.sources, tx);
      const sources = await resolveSources(userId, finalized.sources, tx);
      if (sources.some(source => source.availability !== "active")) throw new Error("SOURCES_CHANGED");
      if (billing.tier !== "pro") {
        const charged = await tx.userCredits.updateMany({ where: { userId, balance: { gte: billing.cost } }, data: { balance: { decrement: billing.cost } } });
        if (!charged.count) throw new Error("INSUFFICIENT_CREDITS");
      }
      // Answer publication and the single turn charge commit atomically; retries cannot double-charge.
      await tx.chilloTurn.update({ where: { id }, data: { status: "completed", answer: finalized.answer, sources: finalized.sources, completedAt: new Date(), errorCode: null, leaseId: null, leaseExpiresAt: null } });
      await tx.chilloConversation.update({ where: { id: conversation.id }, data: { updatedAt: new Date() } });
    });
  } catch (error: any) {
    const errorCode = publicErrors.has(error?.message) ? error.message : "GENERATION_FAILED";
    await prisma.chilloTurn.updateMany({ where: { id, leaseId, status: "running" }, data: { status: "failed", errorCode, leaseId: null, leaseExpiresAt: null } }).catch(() => {});
  } finally { clearInterval(heartbeat); }
}
