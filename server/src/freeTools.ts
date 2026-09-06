import { Router } from "express";
import { randomUUID, timingSafeEqual } from "node:crypto";
import { z } from "zod";
import { transcribeMediaLinkURL } from "./tiktokTranscript.js";

export function validVideoURL(value: string): boolean {
  try {
    const u = new URL(value);
    if (u.protocol !== "https:" || u.username || u.password || u.port) return false;
    const host = u.hostname.replace(/^www\./, "");
    return (host === "tiktok.com" && /^\/@[^/]+\/video\/\d+\/?$/.test(u.pathname))
      || (["vm.tiktok.com", "vt.tiktok.com"].includes(host) && /^\/[\w-]+\/?$/.test(u.pathname))
      || (host === "tiktok.com" && /^\/t\/[\w-]+\/?$/.test(u.pathname))
      || (["youtube.com", "m.youtube.com"].includes(host) && ((u.pathname === "/watch" && /^[\w-]{11}$/.test(u.searchParams.get("v") ?? "")) || /^\/(shorts|live)\/[\w-]{11}\/?$/.test(u.pathname)))
      || (host === "youtu.be" && /^\/[\w-]{11}\/?$/.test(u.pathname))
      || (host === "instagram.com" && /^\/(reel|reels|p)\/[\w-]+\/?$/.test(u.pathname));
  } catch { return false; }
}

type Job = { owner: string; expires: number; status: "processing" | "ready" | "failed"; transcript?: string; error?: string };
type Dependencies = { transcribe: typeof transcribeMediaLinkURL; now: () => number };

// Single-process, bounded anonymous sessions. No user account or note is created.
export function createFreeToolsRouter(overrides: Partial<Dependencies> = {}) {
  const deps: Dependencies = { transcribe: transcribeMediaLinkURL, now: Date.now, ...overrides };
  const router = Router();
  const jobs = new Map<string, Job>();
  const usage = new Map<string, number>();
  const cleanup = setInterval(() => {
    for (const [id, job] of jobs) if (job.expires < deps.now() && job.status !== "processing") jobs.delete(id);
  }, 60_000);
  cleanup.unref();
  let day = ""; let total = 0; let active = 0;
  router.use((req, res, next) => {
    res.set("Cache-Control", "no-store");
    const secret = process.env.FREE_TOOLS_SECRET;
    const provided = req.get("x-free-tools-secret") || "";
    if (!secret || secret.length < 32) { res.status(503).json({ error: "unavailable" }); return; }
    if (Buffer.byteLength(secret) !== Buffer.byteLength(provided) || !timingSafeEqual(Buffer.from(secret), Buffer.from(provided))) { res.status(401).json({ error: "unauthorized" }); return; }
    if (!/^[a-f0-9]{64}$/.test(req.get("x-free-tools-client") || "")) { res.status(400).json({ error: "invalid_request" }); return; }
    const today = new Date(deps.now()).toISOString().slice(0, 10);
    if (today !== day) { day = today; usage.clear(); total = 0; }
    for (const [id, job] of jobs) if (job.expires < deps.now() && job.status !== "processing") jobs.delete(id);
    next();
  });
  router.post("/jobs", (req, res) => {
    const parsed = z.object({ url: z.string().max(2048).refine(validVideoURL) }).safeParse(req.body);
    if (!parsed.success) { res.status(400).json({ error: "invalid_url" }); return; }
    const owner = req.get("x-free-tools-client")!;
    const configuredLimit = Number(process.env.FREE_TOOLS_DAILY_LIMIT || 100);
    const limit = Number.isFinite(configuredLimit) && configuredLimit > 0 ? configuredLimit : 100;
    if ((usage.get(owner) || 0) >= 3 || total >= limit || jobs.size >= 300) { res.status(429).json({ error: "limit" }); return; }
    if (active >= 2) { res.status(429).json({ error: "busy" }); return; }
    usage.set(owner, (usage.get(owner) || 0) + 1); total++; active++;
    const id = randomUUID();
    const job: Job = { owner, expires: deps.now() + 30 * 60_000, status: "processing" };
    jobs.set(id, job);
    res.status(202).json({ id });
    void deps.transcribe(parsed.data.url).then(result => {
      if (!result.available || !result.text?.trim()) throw new Error("no_transcript");
      job.transcript = result.text; job.status = "ready";
    }).catch(() => { job.status = "failed"; job.error = "transcript_failed"; })
      .finally(() => { active--; job.expires = deps.now() + 30 * 60_000; });
  });
  router.get("/jobs/:id", (req, res) => {
    const job = jobs.get(req.params.id);
    if (!job || job.owner !== req.get("x-free-tools-client")) { res.status(404).json({ error: "expired" }); return; }
    res.json({ status: job.status, transcript: job.transcript, error: job.error });
  });
  return router;
}
