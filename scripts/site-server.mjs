import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { handle } from '../bridge/server.mjs';

const root = new URL('../site/', import.meta.url).pathname;
const port = Number(process.env.PORT ?? 4173);
const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.txt': 'text/plain; charset=utf-8', '.png': 'image/png', '.svg': 'image/svg+xml' };

createServer(async (request, response) => {
  const path = decodeURIComponent(new URL(request.url, 'http://site').pathname);
  if (path.startsWith('/bridge/')) return handle(request, response);
  const candidates = path.endsWith('/') ? [`${path}index.html`] : [path, `${path}.html`];
  for (const candidate of candidates) {
    try {
      const file = join(root, normalize(candidate));
      if (!file.startsWith(root)) break;
      const body = await readFile(file);
      response.writeHead(200, { 'Content-Type': types[extname(file)] ?? 'application/json', 'Cache-Control': 'no-store' });
      return response.end(body);
    } catch {}
  }
  response.writeHead(404);
  response.end('not found');
}).listen(port, '127.0.0.1', () => console.log(`site on http://127.0.0.1:${port}`));
