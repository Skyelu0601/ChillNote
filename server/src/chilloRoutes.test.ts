import assert from "node:assert/strict";
import test from "node:test";
import type { RequestHandler } from "express";
import { registerChillo } from "./chillo.js";
import { contentHash } from "./chilloCore.js";

const conversationId = "11111111-1111-4111-8111-111111111111";
const turnId = "22222222-2222-4222-8222-222222222222";

// Every database method is replaced. No configured database, provider or network is contacted.
function fixture() {
  const conversation = { id: conversationId, userId: "owner", title: "", pinnedIds: [], excludedIds: [], updatedAt: new Date() };
  let consent = 1;
  let turn: any;
  let draft: any;
  let savedNote: any;
  const source = { id: "source", content: "Original material", sourceTitle: "Saved source", sourcePlatformName: null, importStatus: null, deletedAt: null, section: "inbox", updatedAt: new Date() };
  const logs: any[] = [];
  const tx: any = {
    $queryRaw: async () => [], $executeRaw: async () => 1,
    accountDeletionMarker: { findUnique: async () => null },
    user: { findUnique: async () => ({ chilloConsentVersion: consent }), update: async ({ data }: any) => { consent = data.chilloConsentVersion; } },
    chilloConversation: {
      findFirst: async ({ where }: any) => where.id === conversation.id && where.userId === conversation.userId ? conversation : null,
      findUnique: async () => conversation,
      update: async ({ data }: any) => Object.assign(conversation, data),
      delete: async () => { turn = undefined; draft = undefined; }
    },
    chilloTurn: {
      findUnique: async ({ where }: any) => turn?.id === where.id ? turn : null,
      findFirst: async () => turn,
      count: async () => turn && ["queued", "running"].includes(turn.status) ? 1 : 0,
      create: async ({ data }: any) => turn = { ...data, status: "queued", sources: [], answer: "", errorCode: null, createdAt: new Date() },
      updateMany: async ({ data }: any) => { if (turn) Object.assign(turn, data); return { count: 1 }; },
      update: async ({ data }: any) => Object.assign(turn, data)
    },
    chilloDraft: {
      findUnique: async () => draft ? { ...draft, note: savedNote } : null,
      create: async ({ data }: any) => draft = data
    },
    chilloChunk: { deleteMany: async () => ({ count: 0 }) },
    note: { findMany: async ({ where }: any) => where.userId === "owner" ? [source] : [], create: async ({ data }: any) => savedNote = { ...data, deletedAt: null } },
    syncLog: { create: async ({ data }: any) => { logs.push(data); } }
  };
  tx.$transaction = async (action: any) => action(tx);
  const handlers = new Map<string, RequestHandler>();
  const auth: RequestHandler = (_req, _res, next) => next();
  const app: any = {};
  for (const verb of ["get", "post", "put", "patch", "delete"]) app[verb] = (path: string, middleware: RequestHandler, handler: RequestHandler) => {
    assert.equal(middleware, auth, `${verb} ${path} must authenticate`);
    handlers.set(verb + " " + path, handler);
  };
  registerChillo(app, auth, { database: tx, startWorkers: false, credits: async () => { throw Error("Tests must not generate"); } });
  function request(route: string, body: unknown = {}, userId = "owner", action?: string): Promise<{ status: number; body: any }> {
    return new Promise(resolve => {
      let status = 200;
      const res: any = { status(code: number) { status = code; return res; }, json(value: unknown) { resolve({ status, body: value }); return res; } };
      handlers.get(route)!({ userId, body, params: { id: conversationId, turnId, action }, query: {} } as any, res, () => {});
    });
  }
  return { request, conversation, source, logs, get turn() { return turn; }, get note() { return savedNote; }, setConsent: (value: number) => { consent = value; },
    complete: () => { turn.status = "completed"; turn.answer = "A draft [1]"; turn.sources = [{ number: 1, noteId: source.id, hash: contentHash(source.content), start: 0, end: source.content.length }]; } };
}

const enqueue = "post /chillo/conversations/:id/turns";
const act = "post /chillo/conversations/:id/turns/:turnId/:action";
const input = { id: turnId, message: "Write a script" };

test("all routes require auth and cross-account writes cannot access a conversation", async () => {
  const f = fixture();
  assert.equal((await f.request(enqueue, input, "another-user")).status, 404);
  assert.equal(f.turn, undefined);
});
test("opening conversations does not implicitly grant cloud processing consent", async () => {
  const f = fixture(); f.setConsent(0);
  const result = await f.request(enqueue, input);
  assert.equal(result.status, 403); assert.equal(result.body.error, "CONSENT_REQUIRED");
  assert.equal(f.turn, undefined);
});
test("an ambiguous network retry returns the same persisted turn, while changed input conflicts", async () => {
  const f = fixture();
  assert.equal((await f.request(enqueue, input)).status, 202);
  assert.equal((await f.request(enqueue, input)).body.id, turnId);
  assert.equal((await f.request(enqueue, { ...input, message: "Different intent" })).status, 409);
});
test("one conversation cannot launch overlapping turns", async () => {
  const f = fixture(); await f.request(enqueue, input);
  const result = await f.request(enqueue, { ...input, id: "33333333-3333-4333-8333-333333333333" });
  assert.equal(result.body.error, "BUSY");
});
test("saving is idempotent, sync-visible, and never overwrites manually edited drafts", async () => {
  const f = fixture(); await f.request(enqueue, input); f.complete();
  const first = await f.request(act, {}, "owner", "draft");
  assert.equal(first.status, 200); assert.equal(f.note.section, "drafts"); assert.equal(f.note.isChilloDraft, true);
  assert.equal(f.note.content, "A draft"); assert.equal(f.logs.length, 1);
  f.note.content = "My manually edited version";
  assert.equal((await f.request(act, {}, "owner", "draft")).body.noteId, first.body.noteId);
  assert.equal(f.note.content, "My manually edited version"); assert.equal(f.logs.length, 1);
  f.note.deletedAt = new Date();
  assert.equal((await f.request(act, {}, "owner", "draft")).body.error, "DRAFT_DELETED");
});
test("changed sources block draft creation rather than copying a stale answer", async () => {
  const f = fixture(); await f.request(enqueue, input); f.complete(); f.source.content = "Edited source";
  assert.equal((await f.request(act, {}, "owner", "draft")).body.error, "SOURCES_CHANGED");
  assert.equal(f.note, undefined);
});
test("revoking access cancels outstanding jobs; deleting a conversation preserves saved notes", async () => {
  const f = fixture(); await f.request(enqueue, input);
  await f.request("put /chillo/consent", { version: 0 });
  assert.equal(f.turn.status, "cancelled");
  assert.equal((await f.request(act, {}, "owner", "retry")).status, 403);
  f.complete(); await f.request(act, {}, "owner", "draft");
  await f.request("delete /chillo/conversations/:id");
  assert.equal(f.turn, undefined); assert.equal(f.note.content, "A draft");
});
