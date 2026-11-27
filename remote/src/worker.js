// Cloudflare Worker: snapshot upload + read-only remote MCP (streamable HTTP, JSON responses).
// Storage: one SQLite-backed Durable Object holding the latest snapshot (one row write per upload).
// Secrets (set with `wrangler secret put`, never in the repo): UPLOAD_TOKEN, READ_TOKEN.
import { handleRpc, parseUpload, MAX_UPLOAD_BYTES } from './core.js';

const MIN_TOKEN_LENGTH = 32;
const JSON_HEADERS = { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' };

const json = (obj, status = 200, extra = {}) => new Response(JSON.stringify(obj), { status, headers: { ...JSON_HEADERS, ...extra } });
const nowSeconds = () => Math.floor(Date.now() / 1000);

function safeEqual(a, b) {
  const enc = new TextEncoder();
  const x = enc.encode(a), y = enc.encode(b);
  let d = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) d |= (x[i] | 0) ^ (y[i] | 0);
  return d === 0;
}

// Returns null when the two secrets are usable, else a short reason.
// Secrets piped into `wrangler secret put` may carry a trailing newline.
const secret = (v) => (typeof v === 'string' ? v.trim() : v);

function configProblem(env) {
  const u = secret(env.UPLOAD_TOKEN), r = secret(env.READ_TOKEN);
  if (typeof u !== 'string' || u.length < MIN_TOKEN_LENGTH) return 'UPLOAD_TOKEN secret missing or shorter than 32 characters';
  if (typeof r !== 'string' || r.length < MIN_TOKEN_LENGTH) return 'READ_TOKEN secret missing or shorter than 32 characters';
  if (u === r) return 'UPLOAD_TOKEN and READ_TOKEN must differ';
  return null;
}

function bearer(request) {
  const h = request.headers.get('authorization') || '';
  const m = /^Bearer\s+(\S+)\s*$/i.exec(h);
  return m ? m[1] : null;
}

const unauthorized = () => json({ error: 'unauthorized' }, 401, { 'www-authenticate': 'Bearer realm="wow-context-bridge"' });

function store(env) {
  return env.CONTEXT.get(env.CONTEXT.idFromName('default'));
}

async function loadStored(env) {
  const res = await store(env).fetch('https://store/get');
  if (!res.ok) throw new Error(`storage read failed (${res.status})`);
  return res.json();
}

async function handleUpload(request, env) {
  const token = bearer(request);
  if (!token || !safeEqual(token, secret(env.UPLOAD_TOKEN))) return unauthorized();
  if (request.method === 'GET') return json({ ok: true, message: 'upload token accepted' }); // used by configure-remote -Check
  if (request.method !== 'POST') return json({ error: 'method not allowed' }, 405, { allow: 'GET, POST' });
  const declared = Number(request.headers.get('content-length') || 0);
  if (declared > MAX_UPLOAD_BYTES) return json({ error: 'payload too large' }, 413);
  const text = await request.text();
  if (new TextEncoder().encode(text).length > MAX_UPLOAD_BYTES) return json({ error: 'payload too large' }, 413);
  let body;
  try { body = JSON.parse(text); } catch { return json({ error: 'invalid JSON' }, 400); }
  const now = nowSeconds();
  const parsed = parseUpload(body, now);
  if (parsed.error) return json({ error: parsed.error }, 400);
  const res = await store(env).fetch('https://store/put', { method: 'POST', body: JSON.stringify(parsed.stored) });
  if (!res.ok) return json({ error: 'storage write failed' }, 502);
  return json({ ok: true, receivedAt: now });
}

async function handleMcp(request, env, pathToken) {
  const token = pathToken ?? bearer(request);
  if (!token || !safeEqual(token, secret(env.READ_TOKEN))) return unauthorized();
  if (request.method !== 'POST') return json({ error: 'method not allowed; this server has no SSE stream' }, 405, { allow: 'POST' });
  let msg;
  try { msg = JSON.parse(await request.text()); } catch { return json({ jsonrpc: '2.0', id: null, error: { code: -32700, message: 'Parse error' } }, 400); }
  let cached;
  const load = async () => (cached ??= await loadStored(env));
  const now = nowSeconds();
  if (Array.isArray(msg)) {
    const out = [];
    for (const m of msg) { const r = await handleRpc(m, load, now); if (r) out.push(r); }
    return out.length ? json(out) : new Response(null, { status: 202 });
  }
  const r = await handleRpc(msg, load, now);
  return r ? json(r) : new Response(null, { status: 202 });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, '') || '/';
    if (path === '/') {
      return new Response('wow-context-bridge remote MCP (read-only). See the project README.\n', { headers: { 'content-type': 'text/plain; charset=utf-8' } });
    }
    const isUpload = path === '/upload';
    const mcpMatch = /^\/mcp(?:\/([^/]+))?$/.exec(path);
    if (!isUpload && !mcpMatch) return json({ error: 'not found' }, 404);
    const problem = configProblem(env);
    if (problem) return json({ error: 'server not configured', detail: problem }, 503);
    try {
      if (isUpload) return await handleUpload(request, env);
      return await handleMcp(request, env, mcpMatch[1] !== undefined ? decodeURIComponent(mcpMatch[1]) : null);
    } catch (e) {
      return json({ error: 'internal error' }, 500);
    }
  },
};

// SQLite-backed Durable Object (the only kind on the Workers Free plan). Key-value API:
// each put is billed as one row written.
export class ContextStore {
  constructor(ctx, env) {
    this.storage = ctx.storage;
  }

  async fetch(request) {
    const path = new URL(request.url).pathname;
    if (path === '/get') return json((await this.storage.get('state')) ?? null);
    if (path === '/put' && request.method === 'POST') {
      await this.storage.put('state', await request.json());
      return json({ ok: true });
    }
    return json({ error: 'not found' }, 404);
  }
}
