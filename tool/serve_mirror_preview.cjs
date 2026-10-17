// Serves only the compiled preview, on loopback. No dependencies required.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '../build/web');
const port = Number(process.env.PORT || 8787);
const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.ttf': 'font/ttf',
};

const server = http.createServer((request, response) => {
  let file;
  try {
    const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    file = path.resolve(root, `.${pathname === '/' ? '/index.html' : pathname}`);
  } catch {
    response.writeHead(400).end();
    return;
  }
  if (!file.startsWith(`${root}${path.sep}`)) {
    response.writeHead(403).end();
    return;
  }
  const stream = fs.createReadStream(file);
  stream.on('error', () => {
    if (!response.headersSent) response.writeHead(404);
    response.end();
  });
  response.setHeader('Content-Type', types[path.extname(file)] || 'application/octet-stream');
  response.setHeader('Cache-Control', 'no-store');
  stream.pipe(response);
});
server.requestTimeout = 10000;
server.on('error', (error) => {
  console.error(`Preview server: ${error.message}`);
  process.exitCode = 1;
});
server.listen(port, '127.0.0.1', () => {
  console.log(`Mirror preview: http://127.0.0.1:${port}`);
});
