import test from "node:test";
import assert from "node:assert/strict";
import express from "express";
import fetch from "node-fetch";
import { createFreeToolsRouter, validVideoURL } from "./freeTools.js";

test("public tools accept video paths and reject arbitrary URLs and credentials", () => {
  for (const url of ["https://www.tiktok.com/@creator/video/123456", "https://vm.tiktok.com/abcd/", "https://www.youtube.com/watch?v=dQw4w9WgXcQ", "https://youtu.be/dQw4w9WgXcQ", "https://youtube.com/shorts/dQw4w9WgXcQ", "https://www.instagram.com/reel/abc_123/"]) assert.equal(validVideoURL(url), true, url);
  for (const url of ["http://tiktok.com/@c/video/123", "https://tiktok.com.evil.test/@c/video/123", "https://localhost/video/1", "https://user:pass@youtube.com/watch?v=dQw4w9WgXcQ", "https://tiktok.com:444/@c/video/123", "https://www.instagram.com/username/", "https://youtube.com/redirect?q=http://localhost", "https://youtu.be/nope"]) assert.equal(validVideoURL(url), false, url);
});

test("anonymous job flow isolates owners, limits usage, and expires", async () => {
  const original = process.env.FREE_TOOLS_SECRET;
  process.env.FREE_TOOLS_SECRET = "test-only-secret-with-at-least-32-characters";
  let now = Date.now(); let fail = false;
  const app = express(); app.use(express.json());
  app.use(createFreeToolsRouter({ now: () => now, transcribe: async () => {
    if (fail) throw new Error("internal sensitive provider details");
    return { available: true, text: "A sample source transcript.", reason: null };
  } }));
  const server = app.listen(0, "127.0.0.1");
  await new Promise<void>(resolve => server.once("listening", resolve));
  const address = server.address(); assert.ok(address && typeof address !== "string");
  const base = `http://127.0.0.1:${address.port}`;
  const call = async (path: string, body?: unknown, owner = "a".repeat(64), secret = process.env.FREE_TOOLS_SECRET!) => {
    const response = await fetch(base + path, { method: body ? "POST" : "GET", headers: { "Content-Type": "application/json", "x-free-tools-client": owner, "x-free-tools-secret": secret }, body: body ? JSON.stringify(body) : undefined });
    return { status: response.status, data: await response.json().catch(() => null) as any };
  };
  try {
    assert.equal((await call("/jobs/nope", undefined, undefined, "wrong")).status, 401);
    assert.equal((await call("/jobs", { url: "https://localhost" })).status, 400);
    const created = await call("/jobs", { url: "https://youtu.be/dQw4w9WgXcQ" });
    assert.equal(created.status, 202);
    const path = `/jobs/${created.data.id}`;
    const ready = await call(path); assert.equal(ready.data.transcript, "A sample source transcript.");
    assert.equal((await call(path, undefined, "b".repeat(64))).status, 404);
    assert.equal((await call(path, { action: "script" }, "b".repeat(64))).status, 404);
    assert.equal((await call(path, { action: "script" })).status, 404);
    fail = true;
    const failed = await call("/jobs", { url: "https://youtu.be/dQw4w9WgXcQ" });
    assert.equal((await call(`/jobs/${failed.data.id}`)).data.error, "transcript_failed");
    await call("/jobs", { url: "https://youtu.be/dQw4w9WgXcQ" });
    assert.equal((await call("/jobs", { url: "https://youtu.be/dQw4w9WgXcQ" })).status, 429);
    now += 31 * 60_000;
    assert.equal((await call(path)).status, 404);
    delete process.env.FREE_TOOLS_SECRET;
    assert.equal((await call(path, undefined, undefined, "unused")).status, 503);
  } finally {
    server.close();
    if (original === undefined) delete process.env.FREE_TOOLS_SECRET; else process.env.FREE_TOOLS_SECRET = original;
  }
});

test("concurrent video requests cannot bypass the worker limit", async () => {
  const original = process.env.FREE_TOOLS_SECRET;
  process.env.FREE_TOOLS_SECRET = "test-only-secret-with-at-least-32-characters";
  const pending: (() => void)[] = [];
  const app = express(); app.use(express.json());
  app.use(createFreeToolsRouter({ transcribe: () => new Promise(resolve => pending.push(() => resolve({ available: true, text: "Source", reason: null }))) }));
  const server = app.listen(0, "127.0.0.1");
  await new Promise<void>(resolve => server.once("listening", resolve));
  const addr = server.address(); assert.ok(addr && typeof addr !== "string");
  try {
    const call = () => fetch(`http://127.0.0.1:${addr.port}/jobs`, { method: "POST", headers: { "Content-Type": "application/json", "x-free-tools-client": "a".repeat(64), "x-free-tools-secret": process.env.FREE_TOOLS_SECRET! }, body: JSON.stringify({ url: "https://youtu.be/dQw4w9WgXcQ" }) });
    assert.equal((await call()).status, 202); assert.equal((await call()).status, 202); assert.equal((await call()).status, 429);
  } finally { pending.forEach(resolve => resolve()); server.close(); if (original === undefined) delete process.env.FREE_TOOLS_SECRET; else process.env.FREE_TOOLS_SECRET = original; }
});
