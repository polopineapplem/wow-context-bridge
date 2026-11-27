// Mock tests for the remote Worker (fixture data, in-memory Durable Object). Not a live game test,
// not Cloudflare's runtime. Run: node --test remote/test/*.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { makeEnv, call, UPLOAD_TOKEN, READ_TOKEN } from './harness.mjs';
import { advisorSource } from '../scripts/sync-advisor.mjs';

const fixture = JSON.parse(readFileSync(new URL('../../tests/fixtures/player-sample.json', import.meta.url), 'utf8').replace(/^﻿/, ''));
const now = () => Math.floor(Date.now() / 1000);
const live = () => ({ ...structuredClone(fixture), capturedAt: now() });
const history = [{ capturedAt: now() - 60, location: { zone: '贫瘠之地' }, changes: ['level 21 -> 22'] }];

const rpc = (id, method, params) => ({ jsonrpc: '2.0', id, method, ...(params ? { params } : {}) });
async function mcp(env, msg, path = '/mcp', token = READ_TOKEN) {
  const r = await call(env, path, { token, body: msg });
  return { status: r.status, body: r.status === 202 ? null : await r.json() };
}
async function tool(env, name, args) {
  const { body } = await mcp(env, rpc(9, 'tools/call', { name, arguments: args || {} }));
  assert.equal(body.result.isError, false, JSON.stringify(body));
  return JSON.parse(body.result.content[0].text);
}

test('upload requires the upload token', async () => {
  const env = makeEnv();
  assert.equal((await call(env, '/upload', { body: { snapshot: live() } })).status, 401);
  assert.equal((await call(env, '/upload', { token: 'wrong', body: { snapshot: live() } })).status, 401);
  assert.equal((await call(env, '/upload', { token: READ_TOKEN, body: { snapshot: live() } })).status, 401, 'read token cannot upload');
  assert.equal(env.storage.writes, 0);
  const ok = await call(env, '/upload', { token: UPLOAD_TOKEN, body: { snapshot: live(), history } });
  assert.equal(ok.status, 200);
  assert.equal(env.storage.writes, 1, 'one storage write per upload');
  assert.equal((await call(env, '/upload', { method: 'GET', token: UPLOAD_TOKEN })).status, 200, 'GET /upload checks the token only');
});

test('mcp requires the read token (header or path)', async () => {
  const env = makeEnv();
  const ping = rpc(1, 'ping');
  assert.equal((await mcp(env, ping, '/mcp', null)).status, 401);
  const r401 = await call(env, '/mcp', { body: ping });
  assert.match(r401.headers.get('www-authenticate'), /^Bearer/);
  assert.equal((await mcp(env, ping, '/mcp', UPLOAD_TOKEN)).status, 401, 'upload token cannot read');
  assert.equal((await mcp(env, ping, '/mcp/wrong-token', null)).status, 401);
  assert.deepEqual((await mcp(env, ping)).body.result, {});
  assert.deepEqual((await mcp(env, ping, `/mcp/${READ_TOKEN}`, null)).body.result, {}, 'token in path works without header');
});

test('server refuses to run without strong, distinct secrets', async () => {
  for (const env of [makeEnv({ READ_TOKEN: undefined }), makeEnv({ UPLOAD_TOKEN: 'short' }), makeEnv({ READ_TOKEN: UPLOAD_TOKEN })]) {
    assert.equal((await call(env, '/mcp', { token: env.READ_TOKEN, body: rpc(1, 'ping') })).status, 503);
    assert.equal((await call(env, '/upload', { token: env.UPLOAD_TOKEN, body: { snapshot: live() } })).status, 503);
  }
});

test('secrets with a trailing newline (piped into wrangler) still match', async () => {
  const env = makeEnv({ UPLOAD_TOKEN: UPLOAD_TOKEN + '\n', READ_TOKEN: READ_TOKEN + '\r\n' });
  assert.equal((await call(env, '/upload', { token: UPLOAD_TOKEN, body: { snapshot: live() } })).status, 200);
  assert.deepEqual((await mcp(env, rpc(1, 'ping'))).body.result, {});
});

test('upload validation', async () => {
  const env = makeEnv();
  const bad = async (body) => (await call(env, '/upload', { token: UPLOAD_TOKEN, body })).status;
  assert.equal(await bad('not json{'), 400);
  assert.equal(await bad({}), 400);
  assert.equal(await bad({ snapshot: { ...live(), schemaVersion: 2 } }), 400);
  assert.equal(await bad({ snapshot: { schemaVersion: 1, capturedAt: now() } }), 400);
  assert.equal(await bad({ snapshot: live(), history: 'x' }), 400);
  assert.equal(await bad({ snapshot: live(), pad: 'x'.repeat(1024 * 1024) }), 413);
  assert.equal(env.storage.writes, 0);
});

test('MCP protocol over HTTP', async () => {
  const env = makeEnv();
  const init = await mcp(env, rpc(1, 'initialize', { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 't', version: '0' } }));
  assert.equal(init.body.result.protocolVersion, '2025-06-18');
  assert.ok(init.body.result.capabilities.tools && init.body.result.capabilities.prompts);
  assert.equal((await mcp(env, rpc(1, 'initialize', { protocolVersion: '1999-01-01' }))).body.result.protocolVersion, '2025-06-18');
  assert.equal((await mcp(env, { jsonrpc: '2.0', method: 'notifications/initialized' })).status, 202);
  const tools = (await mcp(env, rpc(2, 'tools/list'))).body.result.tools;
  assert.deepEqual(tools.map((t) => t.name).sort(), ['get_equipment', 'get_player_context', 'get_quests', 'get_recent_changes']);
  assert.ok(tools.every((t) => t.annotations.readOnlyHint === true));
  assert.equal((await mcp(env, rpc(3, 'tools/call', { name: 'nope' }))).body.error.code, -32602);
  assert.equal((await mcp(env, rpc(4, 'nope'))).body.error.code, -32601);
  const parse = await call(env, '/mcp', { token: READ_TOKEN, body: '{bad' });
  assert.equal(parse.status, 400);
  assert.equal((await parse.json()).error.code, -32700);
  assert.equal((await call(env, '/mcp', { method: 'GET', token: READ_TOKEN })).status, 405, 'no SSE stream');
  const batch = await mcp(env, [rpc(5, 'ping'), { jsonrpc: '2.0', method: 'notifications/x' }]);
  assert.equal(batch.body.length, 1);
  assert.equal((await call(env, '/other', { token: READ_TOKEN, body: {} })).status, 404);
});

test('what_next prompt is the ADVISOR.md body and in sync', async () => {
  assert.equal(readFileSync(new URL('../src/advisor.js', import.meta.url), 'utf8'), advisorSource(), 'run node remote/scripts/sync-advisor.mjs');
  const env = makeEnv();
  assert.deepEqual((await mcp(env, rpc(1, 'prompts/list'))).body.result.prompts.map((p) => p.name), ['what_next']);
  const text = (await mcp(env, rpc(2, 'prompts/get', { name: 'what_next', arguments: { focus: '升级' } }))).body.result.messages[0].content.text;
  assert.ok(text.includes('get_player_context') && text.includes('游戏顾问') && !text.includes('prompt:start') && text.endsWith('Focus on: 升级'));
  assert.equal((await mcp(env, rpc(3, 'prompts/get', { name: 'x' }))).body.error.code, -32602);
});

test('no upload yet: no fabricated character', async () => {
  const env = makeEnv();
  const ctx = await tool(env, 'get_player_context');
  assert.equal(ctx.status, 'no_data');
  assert.equal(ctx.freshness.stale, true);
  assert.equal(ctx.freshness.summary, 'no snapshot uploaded yet');
  assert.deepEqual((await tool(env, 'get_recent_changes')).changes, []);
});

test('tools return the uploaded snapshot (same fields as mcp-server.ps1)', async () => {
  const env = makeEnv();
  const snap = live();
  snap.quests[0] = { ...snap.quests[0], header: '贫瘠之地', level: 21, objectivesText: '把皮革交给某人。', poi: { mapID: 1413, x: 40, y: 60 } };
  snap.api = { GetQuestLogQuestText: true };
  await call(env, '/upload', { token: UPLOAD_TOKEN, body: { snapshot: snap, history } });
  const ctx = await tool(env, 'get_player_context');
  assert.equal(ctx.character.name, fixture.character.name);
  assert.equal(ctx.character.level, fixture.character.level);
  assert.equal(ctx.freshness.stale, false);
  assert.equal(ctx.freshness.summary, 'live');
  assert.equal(ctx.freshness.readerLikelyRunning, true);
  assert.equal(ctx.freshness.staleAfterSeconds, 240);
  assert.equal(ctx.questCount, fixture.quests.length);
  assert.equal(ctx.questLogMayBeIncomplete, fixture.questLogMayBeIncomplete);
  assert.equal(ctx.quests[0].header, '贫瘠之地');
  assert.equal(ctx.quests[0].poi.x, 40);
  assert.ok(!('header' in ctx.quests[1]));
  assert.equal(ctx.questApi.GetQuestLogQuestText, true);
  assert.equal(ctx.equipment.length, fixture.equipment.filter((e) => e && e.id).length);
  assert.deepEqual(ctx.recentChanges[0].changes, ['level 21 -> 22']);
  assert.match(ctx.notice, /game data/);
  const q = await tool(env, 'get_quests', { includeCompletedIds: true });
  assert.equal(q.completedQuestIDs.length, fixture.completedQuestIDs.length);
  assert.ok(!('completedQuestIDs' in await tool(env, 'get_quests')));
  const eq = (await tool(env, 'get_equipment')).equipment;
  assert.equal(eq.length, 19);
  assert.ok(eq.some((e) => e.slotName === 'mainHand' && e.id));
  assert.equal((await tool(env, 'get_recent_changes', { limit: 5 })).changes.length, 1);
});

test('freshness: stale after 4 minutes, silent uploader reported', async () => {
  const env = makeEnv();
  await call(env, '/upload', { token: UPLOAD_TOKEN, body: { snapshot: { ...live(), capturedAt: now() - 230 } } });
  assert.equal((await tool(env, 'get_player_context')).freshness.stale, false, '230 s is still fresh');
  await call(env, '/upload', { token: UPLOAD_TOKEN, body: { snapshot: { ...live(), capturedAt: now() - 300 } } });
  let f = (await tool(env, 'get_player_context')).freshness;
  assert.equal(f.stale, true);
  assert.equal(f.readerLikelyRunning, true);
  assert.equal(f.summary, 'game not sending (offline, loading or in combat)');
  // Uploader stopped: last upload 10 minutes ago.
  const state = await env.storage.get('state');
  state.receivedAt -= 600;
  await env.storage.put('state', state);
  f = (await tool(env, 'get_player_context')).freshness;
  assert.equal(f.readerLikelyRunning, false);
  assert.match(f.summary, /not sending; data is from the last upload/);
  // Historical fixture (capturedAt long ago) is never reported live.
  await call(env, '/upload', { token: UPLOAD_TOKEN, body: { snapshot: fixture } });
  assert.equal((await tool(env, 'get_player_context')).freshness.stale, true);
});
