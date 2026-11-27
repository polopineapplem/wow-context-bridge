// End-to-end mock test: fixture chat log -> start.ps1 (real reader + uploader) -> Worker code
// served on 127.0.0.1 with an in-memory Durable Object -> MCP tools/call. Also exercises
// configure-remote.ps1. Not a live game test and not Cloudflare's runtime.
// Run: node --test remote/test/*.test.mjs   (PWSH=/path/to/pwsh if pwsh is not on PATH)
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { makeEnv, serve, call } from './harness.mjs';

const ROOT = fileURLToPath(new URL('../../', import.meta.url));
const PWSH = process.env.PWSH || (process.platform === 'win32' ? 'powershell.exe' : 'pwsh');
const fixture = JSON.parse(readFileSync(join(ROOT, 'tests/fixtures/player-sample.json'), 'utf8').replace(/^﻿/, ''));

function run(script, args, extraEnv) {
  return new Promise((resolve, reject) => {
    const p = spawn(PWSH, ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', join(ROOT, script), ...args],
      { env: { ...process.env, ...extraEnv }, stdio: ['ignore', 'pipe', 'pipe'] });
    let out = '';
    p.stdout.on('data', (d) => { out += d; });
    p.stderr.on('data', (d) => { out += d; });
    p.on('error', reject);
    p.on('close', (code) => resolve({ code, out }));
  });
}

// Chat log lines in the addon's LCB1 format (see docs/PROTOCOL.md).
function logFor(snapshot) {
  const hex = Buffer.from(JSON.stringify(snapshot), 'utf8').toString('hex');
  const n = Math.ceil(hex.length / 700);
  const lines = ['11/27 10:00:00.000  Someone whispers: LCB1 1-1 1 1 1 deadbeef'];
  for (let i = 1; i <= n; i++) lines.push(`11/27 10:00:00.000  LCB1 ${snapshot.session} ${snapshot.sequence} ${i} ${n} ${hex.slice((i - 1) * 700, i * 700)}`);
  return lines.join('\n') + '\n';
}

test('reader uploads to the Worker only when enabled; MCP serves it', { timeout: 120000 }, async () => {
  const tmp = mkdtempSync(join(tmpdir(), 'lcb-e2e-'));
  const env = makeEnv();
  const server = await serve(env);
  const base = `http://127.0.0.1:${server.address().port}`;
  const cfg = join(tmp, 'remote.json');
  const log = join(tmp, 'WoWChatLog.txt');
  const readerArgs = ['-SkipInstall', '-Once', '-LogPath', log, '-OutputPath', join(tmp, 'player.json')];
  const withCfg = { WOW_CONTEXT_REMOTE_CONFIG: cfg };
  const snap = (level, sequence) => ({ ...structuredClone(fixture), session: '100-200', sequence, capturedAt: Math.floor(Date.now() / 1000), character: { ...fixture.character, level } });
  try {
    // 1. No config: upload is off by default.
    writeFileSync(log, logFor(snap(22, 1)));
    let r = await run('start.ps1', readerArgs, withCfg);
    assert.equal(r.code, 0, r.out);
    assert.match(r.out, /Remote upload off \(default\)/);
    assert.equal(env.storage.writes, 0, 'nothing uploaded without config');

    // 2. configure-remote creates the config (MCP URL pasted by mistake is normalised).
    r = await run('configure-remote.ps1', ['-ConfigPath', cfg, '-Url', `${base}/mcp`], {});
    assert.equal(r.code, 0, r.out);
    const c = JSON.parse(readFileSync(cfg, 'utf8').replace(/^﻿/, ''));
    assert.equal(c.url, base);
    assert.equal(c.enabled, true);
    assert.ok(c.uploadToken.length >= 40 && c.readToken.length >= 40 && c.uploadToken !== c.readToken, 'two distinct random tokens');
    assert.ok(r.out.includes(`${base}/mcp/${c.readToken}`), 'prints the Claude connector settings');
    env.UPLOAD_TOKEN = c.uploadToken; env.READ_TOKEN = c.readToken; // what -SetSecrets would store on the Worker

    // 3. -Check talks to the Worker with both tokens.
    r = await run('configure-remote.ps1', ['-ConfigPath', cfg, '-Check'], {});
    assert.equal(r.code, 0, r.out);
    assert.match(r.out, /PASS upload token accepted/);
    assert.match(r.out, /PASS read token accepted; remote data: no snapshot uploaded yet/);

    // 4. Enabled: the reader uploads; the remote MCP returns the character.
    r = await run('start.ps1', readerArgs, withCfg);
    assert.equal(r.code, 0, r.out);
    assert.match(r.out, /Remote upload ON: 127\.0\.0\.1/);
    assert.match(r.out, /first snapshot sent/);
    assert.equal(env.storage.writes, 1);
    const stored = await env.storage.get('state');
    assert.ok(!JSON.stringify(stored).includes('whispers'), 'no chat text uploaded');
    const res = await call(env, '/mcp', { token: c.readToken, body: { jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name: 'get_player_context', arguments: {} } } });
    const ctx = JSON.parse((await res.json()).result.content[0].text);
    assert.equal(ctx.character.name, fixture.character.name);
    assert.equal(ctx.freshness.stale, false);
    assert.equal(ctx.recentChanges[0].changes[0], 'baseline');

    // 5. Disabled: no upload.
    r = await run('configure-remote.ps1', ['-ConfigPath', cfg, '-Disable'], {});
    assert.equal(r.code, 0, r.out);
    writeFileSync(log, logFor(snap(23, 2)));
    r = await run('start.ps1', readerArgs, withCfg);
    assert.match(r.out, /Remote upload off/);
    assert.equal(env.storage.writes, 1, 'disabled: nothing uploaded');

    // 6. Wrong token on the Worker: reader keeps working and warns; nothing stored.
    r = await run('configure-remote.ps1', ['-ConfigPath', cfg, '-Enable'], {});
    assert.equal(r.code, 0, r.out);
    env.UPLOAD_TOKEN = 'a-different-upload-token-0123456789abcdef';
    r = await run('start.ps1', readerArgs, withCfg);
    assert.equal(r.code, 0, r.out);
    assert.match(r.out, /upload token rejected \(401\)/);
    assert.equal(env.storage.writes, 1, 'rejected upload stores nothing');
    assert.equal(JSON.parse(readFileSync(join(tmp, 'player.json'), 'utf8').replace(/^﻿/, '')).character.level, 23, 'local player.json still updated');
  } finally {
    server.close();
    rmSync(tmp, { recursive: true, force: true });
  }
});
