// Opt-in integration test: real PostgreSQL and Gemini, synthetic fixtures only.
// Refuses production/remote databases. Run migrations in the isolated DB first.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { setTimeout as delay } from 'node:timers/promises';
import { once } from 'node:events';
import { config } from 'dotenv';
import express from 'express';

const testURL = process.env.CHILLO_TEST_DATABASE_URL;
assert.ok(testURL, 'CHILLO_TEST_DATABASE_URL must name an isolated local database');
const target = new URL(testURL);
assert.equal(target.protocol, 'postgresql:');
assert.equal(target.hostname, '127.0.0.1', 'Remote databases are never allowed');
assert.match(target.pathname, /^\/chillo_test(?:_[a-z0-9]+)?$/);
assert.equal(process.env.CHILLO_LIVE_MODEL_TEST, '1', 'Explicit live-model opt-in is required');
config({ path: new URL('../.env', import.meta.url) });
process.env.DATABASE_URL = testURL;
assert.ok(process.env.GEMINI_API_KEY, 'Gemini must be configured');

// Import the database singleton only after overriding DATABASE_URL.
const { prisma } = await import('../dist/db.js');
const { registerChillo } = await import('../dist/chillo.js');
const { indexChilloLibrary, searchLibrary } = await import('../dist/chilloSearch.js');
const { contentHash, searchPlanSchema } = await import('../dist/chilloCore.js');
const { getChangesSinceCursor, deleteUser } = await import('../dist/store.js');
const { CHILLO_EMBED_MODEL } = await import('../dist/chilloModel.js');
const owner = `chillo-test-${randomUUID()}`, outsider = `chillo-test-${randomUUID()}`;
const oldNoteID = `zz-${randomUUID()}`, conversationID = randomUUID();
const fixtures = [owner, outsider];
const app = express();
app.use(express.json());
const closeWorkers = registerChillo(app, (req, res, next) => {
  const user = req.header('x-test-user');
  if (!fixtures.includes(user)) return res.status(401).json({ error: 'UNAUTHORIZED' });
  req.userId = user;
  next();
}, { credits: async () => ({ allowed: true, tier: 'free', cost: 1, balance: 50 }) });
const server = app.listen(0, '127.0.0.1');
await once(server, 'listening');
const base = `http://127.0.0.1:${server.address().port}/chillo`;
async function request(path, method = 'GET', body, user = owner, expected = 200) {
  const result = await fetch(base + path, { method, headers: { 'x-test-user': user, 'content-type': 'application/json' },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }) });
  const value = await result.json();
  assert.equal(result.status, expected, `${method} ${path}: ${JSON.stringify(value)}`);
  return value;
}
const conversationPath = `/conversations/${conversationID}`;
async function waitForTurn(id) {
  const deadline = Date.now() + 180000;
  while (Date.now() < deadline) {
    const detail = await request(conversationPath);
    const turn = detail.turns.find(item => item.id === id);
    if (turn && !['queued', 'running'].includes(turn.status)) {
      assert.equal(turn.status, 'completed', `Generation failed: ${turn.errorCode}`);
      return turn;
    }
    await delay(1000);
  }
  throw Error('Generation timed out');
}

try {
  const tables = await prisma.$queryRaw`SELECT relname, relrowsecurity FROM pg_class
    WHERE relname IN ('ChilloConversation', 'ChilloTurn', 'ChilloChunk', 'ChilloDraft')`;
  assert.equal(tables.length, 4);
  for (const table of tables) {
    assert.equal(table.relrowsecurity, true);
    for (const role of ['anon', 'authenticated']) {
      const [access] = await prisma.$queryRaw`SELECT has_table_privilege(${role}, ${'"' + table.relname + '"'}, 'SELECT,INSERT,UPDATE,DELETE') AS allowed`;
      assert.equal(access.allowed, false, `${role} must not access ${table.relname}`);
    }
  }
  console.log('PASS: migrated tables enable RLS and deny direct client access');

  await prisma.user.createMany({ data: fixtures.map(id => ({ id, welcomeNotificationEligible: false })) });
  await prisma.userCredits.create({ data: { userId: owner, balance: 50, initialGrantAmount: 50 } });
  const now = new Date();
  const source = '访谈剪辑方法：把一次访谈拆成三条短视频，每条只讲一个问题。保留受访者原话，不能编造亲身经历。';
  const sourceText = '虚构测试归档，无实际访谈内容。\n'.repeat(1000) + source;
  await prisma.note.createMany({ data: [
    ...Array.from({ length: 121 }, (_, index) => ({ id: `a-${owner}-${index.toString().padStart(3, '0')}`,
      userId: owner, content: `虚构菜谱${index}：番茄和鸡蛋，冰箱储藏。`, createdAt: now, updatedAt: now })),
    { id: oldNoteID, userId: owner, content: sourceText, sourceTitle: '访谈剪辑方法收藏', sourcePlatformName: 'Test source',
      createdAt: new Date('2020-01-01T00:00:00Z'), updatedAt: now },
    { id: randomUUID(), userId: owner, content: '访谈剪辑方法：回收站不应被读取', deletedAt: now, createdAt: now, updatedAt: now },
    { id: randomUUID(), userId: owner, content: '访谈剪辑方法：未完成导入不应被读取', importStatus: 'processing', createdAt: now, updatedAt: now },
    { id: randomUUID(), userId: outsider, content: '访谈剪辑方法：另一个账号的私密笔记不应被读取', createdAt: now, updatedAt: now }
  ] });
  await request('/conversations', 'POST', { id: conversationID });
  await request(conversationPath, 'GET', undefined, outsider, 404);
  const turnID = randomUUID();
  const input = { id: turnID, message: '请找到我收藏的访谈剪辑方法，只根据原笔记总结三个要点，每点标注来源。不要编造任何访谈内容。', locale: 'zh-CN' };
  await request(`${conversationPath}/turns`, 'POST', input, owner, 403);
  await request('/consent', 'PUT', { version: 1 });
  const library = await request('/library');
  assert.equal(library.available, 122);
  await indexChilloLibrary(owner);
  assert.ok(await prisma.chilloChunk.count({ where: { note: { userId: owner } } }) > 0);
  const passages = await searchLibrary(owner, searchPlanSchema.parse({ queries: ['访谈剪辑方法'] }), [], []);
  assert.ok(passages.some(p => p.noteId === oldNoteID && p.end > 16000), 'Find old long note beyond first page');
  assert.ok(passages.every(p => !p.text.includes('不应被读取')));
  console.log('PASS: consent, account isolation, real embeddings and paginated old-note retrieval');

  await request(`${conversationPath}/turns`, 'POST', input, owner, 202);
  await request(`${conversationPath}/turns`, 'POST', input, owner, 202);
  const answer = await waitForTurn(turnID);
  assert.ok(answer.sources.some(s => s.noteId === oldNoteID));
  assert.match(answer.answer, /\[\d+\]/);
  assert.equal((await prisma.userCredits.findUniqueOrThrow({ where: { userId: owner } })).balance, 49);
  console.log('PASS: real Gemini multi-step answer, valid citation, exactly one credit', answer.answer);

  const draft = await request(`${conversationPath}/turns/${turnID}/draft`, 'POST');
  await prisma.note.update({ where: { id: draft.noteId }, data: { content: '手工修改的虚构测试草稿' } });
  assert.deepEqual(await request(`${conversationPath}/turns/${turnID}/draft`, 'POST'), draft);
  assert.equal((await prisma.note.findUniqueOrThrow({ where: { id: draft.noteId } })).content, '手工修改的虚构测试草稿');
  const sync = await getChangesSinceCursor(owner, null);
  assert.ok(sync.changes.notes.some(n => n.id === draft.noteId && n.section === 'drafts'));
  console.log('PASS: draft saves once, keeps manual edits and appears in existing mobile sync');

  const creativeID = randomUUID();
  await request(`${conversationPath}/turns`, 'POST', { id: creativeID, locale: 'zh-CN',
    message: '把这些剪辑方法改写成60字以内的短视频开场，主题是如何剪辑访谈。原笔记没有实际受访者的发言，不能编造台词或亲身经历。' }, owner, 202);
  const creative = await waitForTurn(creativeID);
  assert.doesNotMatch(creative.answer, /受访者曾|受访者说|受访者提到|我采访过/);
  assert.equal((await prisma.userCredits.findUniqueOrThrow({ where: { userId: owner } })).balance, 48);
  console.log('PASS: follow-up creation without invented attributed speech', creative.answer);

  await prisma.chilloChunk.create({ data: { id: randomUUID(), noteId: oldNoteID, hash: contentHash(sourceText),
    start: 0, end: 100, embedding: [1], model: CHILLO_EMBED_MODEL } });
  await prisma.note.update({ where: { id: oldNoteID }, data: { content: '原文已改变' } });
  assert.equal(await prisma.chilloChunk.count({ where: { noteId: oldNoteID } }), 0);
  const changed = (await request(conversationPath)).turns.find(t => t.id === turnID);
  assert.equal(changed.sourcesChanged, true);
  assert.equal(changed.answer, '');
  // A fresh source-dependent response cannot be saved after its source changes.
  const staleID = randomUUID();
  await prisma.chilloTurn.create({ data: { id: staleID, conversationId: conversationID, request: 'Fixture',
    status: 'completed', answer: 'Stale [1]', sources: [{ number: 1, noteId: oldNoteID, hash: contentHash(sourceText), start: 0, end: 100 }] } });
  await request(`${conversationPath}/turns/${staleID}/draft`, 'POST', undefined, owner, 409);
  console.log('PASS: source edits invalidate vectors, hide stale responses and block stale drafts');

  const queuedID = randomUUID();
  await prisma.chilloTurn.create({ data: { id: queuedID, conversationId: conversationID, request: 'Do not generate' } });
  await request('/consent', 'PUT', { version: 0 });
  assert.equal((await prisma.chilloTurn.findUniqueOrThrow({ where: { id: queuedID } })).status, 'cancelled');
  assert.equal(await prisma.chilloChunk.count({ where: { note: { userId: owner } } }), 0);
  await request(`${conversationPath}/turns/${queuedID}/retry`, 'POST', undefined, owner, 403);
  await request(conversationPath, 'DELETE');
  assert.ok(await prisma.note.findUnique({ where: { id: draft.noteId } }));
  await deleteUser(owner);
  assert.equal(await prisma.note.count({ where: { userId: owner } }), 0);
  assert.equal(await prisma.syncLog.count({ where: { userId: owner } }), 0);
  assert.equal(await prisma.chilloConversation.count({ where: { userId: owner } }), 0);
  console.log('PASS: revoke cancels work, conversation deletion keeps drafts, account deletion cascades');
  console.log('PASS: isolated PostgreSQL + live Gemini Chillo integration');
} finally {
  closeWorkers();
  await new Promise(resolve => server.close(resolve));
  // Only this run\'s synthetic account IDs are removed, never arbitrary users.
  await prisma.user.deleteMany({ where: { id: { in: fixtures } } });
  await prisma.accountDeletionMarker.deleteMany({ where: { userId: { in: fixtures } } });
  await prisma.$disconnect();
}
