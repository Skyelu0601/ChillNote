// Explicit deployment smoke test: creates one disposable Auth account and only
// synthetic notes. It never reads or modifies an existing user's account.
import 'dotenv/config';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { setTimeout as delay } from 'node:timers/promises';
import { createClient } from '@supabase/supabase-js';
import fetch from 'node-fetch';
import { prisma } from '../dist/db.js';
import { deleteUser } from '../dist/store.js';

assert.equal(process.env.CHILLO_DEPLOYMENT_SMOKE, '1', 'Explicit deployment-test opt-in required');
assert.equal(process.env.SUPABASE_URL?.replace(/\/$/, ''), 'https://qsyhkpaeyzhjojdvbntq.supabase.co');
const base = 'https://api.chillnoteai.com';
const auth = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } });
const email = `chillo-deployment-${randomUUID()}@example.invalid`;
const password = randomUUID() + 'Aa1!';
let fixtureID, token;
async function request(path, method = 'GET', body, status = 200) {
  const response = await fetch(base + path, { method, timeout: 30000,
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }) });
  const result = await response.json();
  assert.equal(response.status, status, `${method} ${path} failed with ${response.status}: ${result.error ?? ''}`);
  return result;
}
try {
  const created = await auth.auth.admin.createUser({ email, password, email_confirm: true });
  if (created.error) throw Error(`Test account creation failed: ${created.error.code ?? 'AUTH_ERROR'}`);
  fixtureID = created.data.user.id;
  const signed = await auth.auth.signInWithPassword({ email, password });
  if (signed.error) throw Error(`Test account sign-in failed: ${signed.error.code ?? 'AUTH_ERROR'}`);
  assert.equal(signed.data.user.id, fixtureID);
  token = signed.data.session.access_token;
  const noteID = randomUUID(), conversationID = randomUUID(), turnID = randomUUID();
  const note = { id: noteID, content: '虚构部署测试素材：短视频每条只讲一个问题。前3秒明确告诉观众能学到什么。',
    createdAt: new Date().toISOString(), section: 'inbox', baseVersion: 0, mutationId: randomUUID(), tagIds: [] };
  await request('/sync', 'POST', { protocolVersion: 4, deviceId: 'chillo-deployment-test', notes: [note], tags: [] });
  assert.equal((await request('/chillo/library')).consentVersion, 0);
  await request('/chillo/consent', 'PUT', { version: 1 });
  await request('/chillo/conversations', 'POST', { id: conversationID });
  const before = await request('/credits/balance');
  const path = `/chillo/conversations/${conversationID}`;
  const input = { id: turnID, message: '根据我保存的短视频笔记，总结两个要点，每点标注来源。不要补充资料里没有的事实。', locale: 'zh-CN' };
  await request(path + '/turns', 'POST', input, 202);
  await request(path + '/turns', 'POST', input, 202);
  let turn;
  const deadline = Date.now() + 180000;
  while (Date.now() < deadline) {
    turn = (await request(path)).turns.find(item => item.id === turnID);
    if (turn && !['queued', 'running'].includes(turn.status)) break;
    await delay(1500);
  }
  assert.equal(turn?.status, 'completed', `Chillo generation: ${turn?.errorCode ?? 'TIMEOUT'}`);
  assert.ok(turn.answer && turn.sources.some(source => source.noteId === noteID));
  const after = await request('/credits/balance');
  const configuredCost = Number(process.env.CREDIT_COST_CHAT);
  const cost = Number.isInteger(configuredCost) && configuredCost > 0 ? configuredCost : 2;
  assert.equal(before.balance - after.balance, cost);
  const draft = await request(path + `/turns/${turnID}/draft`, 'POST');
  assert.deepEqual(await request(path + `/turns/${turnID}/draft`, 'POST'), draft);
  for (const protocolVersion of [2, 3, 4]) {
    const sync = await request('/sync', 'POST', { protocolVersion, notes: [], tags: [] });
    assert.ok(sync.changes.notes.some(item => item.id === draft.noteId && item.section === 'drafts'));
  }
  await request('/weekly-topics/dashboard');
  await request('/chillo/consent', 'PUT', { version: 0 });
  assert.equal((await request('/chillo/library')).consentVersion, 0);
  await request('/auth/account', 'DELETE');
  assert.equal(await prisma.user.count({ where: { id: fixtureID } }), 0);
  console.log(JSON.stringify({ ok: true, authenticated: true, liveAnswerWithCitation: true,
    exactlyOneTurnCharge: cost, savedDraft: true, syncProtocols: [2, 3, 4], legacyWeeklyEndpoint: true,
    consentRevoked: true, temporaryAccountDeleted: true }));
} finally {
  if (fixtureID) {
    // Exact ID returned by this run's createUser; never supplied externally.
    await deleteUser(fixtureID);
    await auth.auth.admin.deleteUser(fixtureID);
    // Keep the normal account-deletion marker, as production deletion does.
  }
  await prisma.$disconnect();
}
