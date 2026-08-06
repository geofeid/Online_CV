// Zero-dependency static file server: node scripts/serve.mjs <dir> <port>
import http from "node:http";
import fs from "node:fs";
import path from "node:path";

const dir = path.resolve(process.argv[2] ?? "dist");
const port = Number(process.argv[3] ?? 5500);

const types = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".json": "application/json",
  ".pdf": "application/pdf",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".png": "image/png",
  ".gif": "image/gif",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".webp": "image/webp",
  ".map": "application/json",
  ".txt": "text/plain; charset=utf-8",
};

http
  .createServer((req, res) => {
    const urlPath = decodeURIComponent(new URL(req.url, "http://x").pathname);
    let filePath = path.join(dir, urlPath);
    if (!filePath.startsWith(dir)) {
      res.writeHead(403).end();
      return;
    }
    if (fs.existsSync(filePath) && fs.statSync(filePath).isDirectory()) {
      filePath = path.join(filePath, "index.html");
    }
    fs.readFile(filePath, (err, data) => {
      if (err) {
        res.writeHead(404).end("Not found");
        return;
      }
      res.writeHead(200, {
        "content-type": types[path.extname(filePath).toLowerCase()] ?? "application/octet-stream",
        "cache-control": "no-store",
      });
      res.end(data);
    });
  })
  .listen(port, () => console.log(`Serving ${dir} at http://localhost:${port}`));
