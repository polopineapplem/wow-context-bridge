// Mock Cloudflare environment for tests: runs the real Worker and ContextStore code with an
// in-memory Durable Object storage. Not Cloudflare's runtime; deploy-time behavior is unverified.
import http from 'node:http';
import worker, { ContextStore } from '../src/worker.js';

export const UPLOAD_TOKEN = 'test-upload-token-0123456789abcdefghijklmnop';
export const READ_TOKEN = 'test-read-token-0123456789abcdefghijklmnopqrs';

export function makeEnv(overrides = {}) {
  const data = new Map();
  const storage = {
    async get(k) { return data.has(k) ? structuredClone(data.get(k)) : undefined; },
    async put(k, v) { data.set(k, structuredClone(v)); storage.writes++; },
    writes: 0,
  };
  const instance = new ContextStore({ storage }, {});
  const env = {
    UPLOAD_TOKEN, READ_TOKEN,
    CONTEXT: {
      idFromName: (n) => `id:${n}`,
      get: () => ({ fetch: (input, init) => instance.fetch(new Request(input, init)) }),
    },
    storage,
    ...overrides,
  };
  return env;
}

export function call(env, path, { method = 'POST', token, body, headers = {} } = {}) {
  const h = { ...headers };
  if (token) h.authorization = `Bearer ${token}`;
  if (body !== undefined) h['content-type'] = 'application/json';
  return worker.fetch(new Request(`https://example.invalid${path}`, { method, headers: h, body: body === undefined ? undefined : (typeof body === 'string' ? body : JSON.stringify(body)) }), env);
}

// Serves the Worker on 127.0.0.1 so the PowerShell uploader can be tested end to end.
export function serve(env, port = 0) {
  const server = http.createServer(async (req, res) => {
    const chunks = [];
    for await (const c of req) chunks.push(c);
    const body = chunks.length ? Buffer.concat(chunks) : undefined;
    const r = await worker.fetch(new Request(`http://127.0.0.1${req.url}`, { method: req.method, headers: req.headers, body: req.method === 'GET' || req.method === 'HEAD' ? undefined : body }), env);
    res.writeHead(r.status, Object.fromEntries(r.headers));
    res.end(Buffer.from(await r.arrayBuffer()));
  });
  return new Promise((resolve) => server.listen(port, '127.0.0.1', () => resolve(server)));
}
