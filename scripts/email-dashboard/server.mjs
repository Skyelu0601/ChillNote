import http from "node:http";
import { spawn } from "node:child_process";
import { createReadStream } from "node:fs";
import { readFile } from "node:fs/promises";
import { randomBytes } from "node:crypto";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const baseDir = dirname(fileURLToPath(import.meta.url));
const token = randomBytes(24).toString("base64url");
const host = "127.0.0.1";
const assets = {
  "/": ["index.html", "text/html; charset=utf-8"],
  "/app.js": ["app.js", "text/javascript; charset=utf-8"],
  "/styles.css": ["styles.css", "text/css; charset=utf-8"]
};

function validateOptions(url) {
  const days = Number(url.searchParams.get("days") || "1");
  const page = Number(url.searchParams.get("page") || "1");
  const kind = url.searchParams.get("kind") || "";
  const state = url.searchParams.get("state") || "";
  const search = url.searchParams.get("search") || "";
  if (![1, 7, 30, 0].includes(days) || !Number.isInteger(page) || page < 1 || page > 10000
    || !/^[a-z0-9_]{0,50}$/.test(kind) || search.length > 120
    || !["", "delivered", "accepted", "bounced", "complained", "rejected", "scheduled", "failed", "skipped", "cancelled", "suppressed"].includes(state)) {
    throw new Error("筛选条件无效");
  }
  return { days, page, kind, state, search };
}

function fetchProduction(options) {
  return new Promise(async (resolve, reject) => {
    const encoded = Buffer.from(JSON.stringify(options)).toString("base64url");
    const command = `cd /root/chillnote-api/current && DOTENV_CONFIG_PATH=/root/chillnote-api/shared/.env node -r dotenv/config - ${encoded}`;
    const child = spawn("ssh", ["-o", "BatchMode=yes", "-o", "ConnectTimeout=10", "root@45.43.57.244", command], {
      stdio: ["pipe", "pipe", "pipe"]
    });
    let stdout = "";
    let stderr = "";
    const timeout = setTimeout(() => child.kill("SIGTERM"), 30000);
    child.stdout.on("data", (chunk) => { stdout += chunk; });
    child.stderr.on("data", (chunk) => { stderr += chunk; });
    child.on("error", (error) => { clearTimeout(timeout); reject(error); });
    child.on("close", (code) => {
      clearTimeout(timeout);
      if (code !== 0) return reject(new Error(stderr.trim() || "无法连接生产数据"));
      try { resolve(JSON.parse(stdout)); } catch { reject(new Error("生产数据格式不正确")); }
    });
    try { child.stdin.end(await readFile(join(baseDir, "remote-data.cjs"))); }
    catch (error) { child.kill("SIGTERM"); reject(error); }
  });
}

const server = http.createServer(async (request, response) => {
  const origin = `http://${host}:${server.address().port}`;
  if (request.headers.host !== `${host}:${server.address().port}`
    || (request.headers.origin && request.headers.origin !== origin)) {
    response.writeHead(403).end();
    return;
  }
  const url = new URL(request.url || "/", origin);
  const prefix = `/${token}`;
  if (request.method !== "GET" || !(url.pathname === prefix || url.pathname.startsWith(`${prefix}/`))) {
    response.writeHead(404).end();
    return;
  }
  const pathname = url.pathname.slice(prefix.length) || "/";
  response.setHeader("Cache-Control", "no-store");
  response.setHeader("Referrer-Policy", "no-referrer");
  response.setHeader("X-Content-Type-Options", "nosniff");
  response.setHeader("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self'; base-uri 'none'; frame-ancestors 'none'");
  if (pathname === "/api/data") {
    try {
      const data = await fetchProduction(validateOptions(url));
      response.writeHead(200, { "Content-Type": "application/json; charset=utf-8" }).end(JSON.stringify(data));
    } catch (error) {
      response.writeHead(502, { "Content-Type": "application/json; charset=utf-8" }).end(JSON.stringify({ error: error instanceof Error ? error.message : "读取失败" }));
    }
    return;
  }
  const asset = assets[pathname];
  if (!asset) { response.writeHead(404).end(); return; }
  response.writeHead(200, { "Content-Type": asset[1] });
  createReadStream(join(baseDir, asset[0])).pipe(response);
});

server.listen(0, host, () => {
  const url = `http://${host}:${server.address().port}/${token}/`;
  console.log(`ChillScript 邮件看板已启动：${url}`);
  console.log("关闭这个终端窗口即可停止看板。");
  if (process.platform === "darwin" && !process.argv.includes("--no-open")) {
    spawn("open", [url], { stdio: "ignore", detached: true }).unref();
  }
});
