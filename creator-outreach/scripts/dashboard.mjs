import http from "node:http";
import fs from "node:fs/promises";
import path from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { readLeads } from "../src/lead-store.mjs";
import { affiliateSignupLink, outreachSubject, sendingPausePath, toolRoot } from "../src/config.mjs";
import { buildTikTokEmailInput, massTikTokEmailActor } from "../src/tiktok-email.mjs";
import { loadTemplate, renderTemplate } from "../src/template.mjs";
import {
  isPendingSendable,
  parseKeywords,
  publicLead,
  summarizeLeads,
} from "../src/dashboard.mjs";

const sourceDir = path.dirname(fileURLToPath(import.meta.url));
const dashboardDir = path.join(toolRoot, "dashboard");
const assignmentsPath = path.join(toolRoot, "data", "offer-code-assignments.json");
const host = "127.0.0.1";
const port = Number(process.env.OUTREACH_DASHBOARD_PORT || 4178);
const jobs = new Map();
let activeJobId = "";

function json(response, status, value) {
  response.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
  });
  response.end(`${JSON.stringify(value)}\n`);
}

async function readBody(request) {
  let body = "";
  for await (const chunk of request) {
    body += chunk;
    if (body.length > 1_000_000) throw new Error("Request body is too large.");
  }
  return body ? JSON.parse(body) : {};
}

async function readAssignments() {
  try {
    return JSON.parse(await fs.readFile(assignmentsPath, "utf8")).assignments || [];
  } catch (error) {
    if (error.code === "ENOENT") return [];
    throw error;
  }
}

async function readPause() {
  try {
    return (await fs.readFile(sendingPausePath, "utf8")).trim();
  } catch (error) {
    if (error.code === "ENOENT") return "";
    throw error;
  }
}

function cleanLog(value) {
  return String(value)
    .replaceAll(process.env.APIFY_TOKEN || "__NO_TOKEN__", "[hidden]")
    .replaceAll(process.env.ALI_MAIL_APP_PASSWORD || "__NO_PASSWORD__", "[hidden]");
}

function jobSummary(job) {
  return {
    id: job.id,
    label: job.label,
    status: job.status,
    startedAt: job.startedAt,
    finishedAt: job.finishedAt,
    exitCode: job.exitCode,
    logs: job.logs.slice(-160),
  };
}

function startJob({ label, script, args = [], input = "" }) {
  if (activeJobId && jobs.get(activeJobId)?.status === "running") {
    const error = new Error("另一个任务正在运行，请等待它完成。");
    error.statusCode = 409;
    throw error;
  }
  const id = `${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;
  const job = {
    id,
    label,
    status: "running",
    startedAt: new Date().toISOString(),
    finishedAt: "",
    exitCode: null,
    logs: [],
  };
  jobs.set(id, job);
  activeJobId = id;
  const child = spawn(process.execPath, [path.join(sourceDir, script), ...args], {
    cwd: toolRoot,
    env: process.env,
    stdio: ["pipe", "pipe", "pipe"],
  });
  const addLog = (chunk) => {
    job.logs.push(...cleanLog(chunk).split(/\r?\n/).filter(Boolean));
    if (job.logs.length > 500) job.logs = job.logs.slice(-500);
  };
  child.stdout.on("data", addLog);
  child.stderr.on("data", addLog);
  child.on("error", (error) => {
    addLog(error.message);
    job.status = "failed";
    job.finishedAt = new Date().toISOString();
    activeJobId = "";
  });
  child.on("close", (code) => {
    job.exitCode = code;
    job.status = code === 0 ? "completed" : "failed";
    job.finishedAt = new Date().toISOString();
    activeJobId = "";
  });
  if (input) child.stdin.write(input);
  child.stdin.end();
  return jobSummary(job);
}

function numberBetween(value, min, max, fallback) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, Math.floor(parsed)));
}

async function statusPayload() {
  const [rows, assignments, pause] = await Promise.all([
    readLeads(),
    readAssignments(),
    readPause(),
  ]);
  const assignmentsByEmail = new Map();
  for (const assignment of assignments) {
    const email = assignment.email.toLowerCase();
    if (!assignmentsByEmail.has(email)) assignmentsByEmail.set(email, []);
    assignmentsByEmail.get(email).push(assignment);
  }
  const leads = rows
    .map((row) => publicLead(row, assignmentsByEmail.get(row.email.toLowerCase()) || []))
    .sort((a, b) =>
      (b.last_reply_at || b.sent_at || "").localeCompare(a.last_reply_at || a.sent_at || ""),
    );
  return {
    summary: summarizeLeads(rows),
    paused: Boolean(pause),
    pauseReason: pause,
    affiliateLink: affiliateSignupLink,
    subject: outreachSubject,
    leads,
    replies: leads.filter((lead) => lead.reply_status === "replied"),
    assignments: assignments.map((assignment) => ({
      creator_name: assignment.creator_name,
      handle: assignment.handle,
      email: assignment.email,
      kind: assignment.kind || "legacy",
      status: assignment.status,
      sent_at: assignment.sent_at,
      redeemed: assignment.redeemed || "unknown",
    })),
    activeJob: activeJobId ? jobSummary(jobs.get(activeJobId)) : null,
  };
}

async function serveAsset(pathname, response) {
  const assets = {
    "/": ["index.html", "text/html; charset=utf-8"],
    "/app.js": ["app.js", "text/javascript; charset=utf-8"],
    "/styles.css": ["styles.css", "text/css; charset=utf-8"],
  };
  const asset = assets[pathname];
  if (!asset) return false;
  const content = await fs.readFile(path.join(dashboardDir, asset[0]));
  response.writeHead(200, { "content-type": asset[1], "cache-control": "no-store" });
  response.end(content);
  return true;
}

function profileHandleFromUrl(value) {
  return new URL(value).pathname.split("/").filter(Boolean)[0] || "";
}

function jsonStringField(html, key) {
  const match = html.match(new RegExp(`"${key}":("(?:[^"\\\\]|\\\\.)*")`));
  if (!match) return "";
  try {
    return JSON.parse(match[1]);
  } catch {
    return "";
  }
}

function numberField(html, key) {
  const match = html.match(new RegExp(`"${key}":([0-9]+)`));
  return match ? Number(match[1]) : null;
}

async function researchCreator(email) {
  const rows = await readLeads();
  const lead = rows.find((row) => row.email.toLowerCase() === email.toLowerCase());
  if (!lead) throw new Error("找不到这个联系人。");
  const handle = profileHandleFromUrl(lead.email_source);
  if (!handle.startsWith("@")) throw new Error("联系人没有直接 TikTok 主页来源。");
  const profileUrl = `https://www.tiktok.com/${handle}`;
  const result = await fetch(profileUrl, {
    headers: {
      "user-agent":
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Version/18.0 Safari/605.1.15",
    },
  });
  if (!result.ok) throw new Error(`TikTok 返回 ${result.status}，请稍后重试。`);
  const html = await result.text();
  return {
    profileUrl,
    handle,
    nickname: jsonStringField(html, "nickname"),
    signature: jsonStringField(html, "signature"),
    region: jsonStringField(html, "region"),
    verified: html.includes('"verified":true'),
    followers: numberField(html, "followerCount"),
    following: numberField(html, "followingCount"),
    likes: numberField(html, "heartCount"),
    videos: numberField(html, "videoCount"),
  };
}

const server = http.createServer(async (request, response) => {
  try {
    const url = new URL(request.url, `http://${request.headers.host || `${host}:${port}`}`);
    if (request.method === "GET" && (await serveAsset(url.pathname, response))) return;
    if (request.method === "GET" && url.pathname === "/api/status") {
      return json(response, 200, await statusPayload());
    }
    if (request.method === "GET" && url.pathname.startsWith("/api/jobs/")) {
      const job = jobs.get(url.pathname.split("/").pop());
      return job
        ? json(response, 200, jobSummary(job))
        : json(response, 404, { error: "任务不存在。" });
    }
    if (request.method === "GET" && url.pathname === "/api/template") {
      const rows = await readLeads();
      const requested = url.searchParams.get("lead");
      const lead = rows.find((row) => row.id === requested) || rows.find((row) => row.status === "pending") || {
        creator_name: "there",
        personalization:
          "I found your TikTok while researching creators who share content tips and workflows.",
      };
      return json(response, 200, {
        subject: outreachSubject,
        body: renderTemplate(await loadTemplate(), lead),
      });
    }

    if (request.method === "POST" && url.pathname === "/api/campaign/preview") {
      const body = await readBody(request);
      const keywords = parseKeywords(body.keywords);
      if (!keywords.length) return json(response, 400, { error: "请输入至少一个关键词。" });
      const maxEmails = numberBetween(body.maxEmails, 1, 105, 50);
      const actor = {
        keywords,
        domains: ["@gmail.com", "@outlook.com", "@hotmail.com", "@yahoo.com", "@icloud.com"],
        location: String(body.location || "").trim(),
        maxEmails,
      };
      return json(response, 200, {
        actor: massTikTokEmailActor,
        input: buildTikTokEmailInput(actor),
        maxEmails,
        estimatedFee: maxEmails * 0.0025,
        confirmation: `RUN ${maxEmails}`,
        rules: [
          "只接受来源路径以 /@username 开头的 TikTok 页面",
          "自动去重并排除 Discover、Tag、Search 和跳转页面",
          "新联系人先保存为未批准，不会自动发送邮件",
        ],
      });
    }

    if (request.method === "POST" && url.pathname === "/api/campaign/run") {
      const body = await readBody(request);
      const keywords = parseKeywords(body.keywords);
      const maxEmails = numberBetween(body.maxEmails, 1, 105, 50);
      if (!keywords.length) return json(response, 400, { error: "请输入至少一个关键词。" });
      if (body.confirmation !== `RUN ${maxEmails}`) {
        return json(response, 400, { error: `请输入 RUN ${maxEmails} 确认付费抓取。` });
      }
      const args = [];
      for (const keyword of keywords) args.push("--keyword", keyword);
      args.push("--max-emails", String(maxEmails), "--run");
      if (String(body.location || "").trim()) args.push("--location", String(body.location).trim());
      return json(response, 202, startJob({
        label: `抓取 ${keywords.join(" · ")}`,
        script: "campaign-tiktok.mjs",
        args,
      }));
    }

    if (request.method === "POST" && url.pathname === "/api/approve") {
      const body = await readBody(request);
      const rows = await readLeads();
      const count = rows.filter((row) =>
        row.id.startsWith("tiktok-") &&
        row.status === "pending" &&
        row.approved !== "yes" &&
        ["valid", "accepted", "mx_only"].includes(row.email_status),
      ).length;
      if (!count) return json(response, 400, { error: "没有等待批准的联系人。" });
      if (body.confirmation !== `APPROVE ${count}`) {
        return json(response, 400, { error: `请输入 APPROVE ${count}。` });
      }
      return json(response, 202, startJob({
        label: `批准 ${count} 位联系人`,
        script: "approve-tiktok-leads.mjs",
        args: ["--confirm", `APPROVE ${count}`],
      }));
    }

    if (request.method === "POST" && url.pathname === "/api/send") {
      const body = await readBody(request);
      const rows = await readLeads();
      const count = rows.filter((row) => isPendingSendable(row, true)).slice(0, 100).length;
      if (!count) return json(response, 400, { error: "没有可发送的待处理联系人。" });
      if (body.confirmation !== `SEND ${count}`) {
        return json(response, 400, { error: `请输入 SEND ${count}。` });
      }
      const pause = await readPause();
      if (pause && body.resumeConfirmation !== "RESUME") {
        return json(response, 409, {
          error: "发送当前处于暂停状态。请输入 RESUME 后再次确认。",
          pauseRequired: true,
          pauseReason: pause,
        });
      }
      if (pause) await fs.unlink(sendingPausePath);
      return json(response, 202, startJob({
        label: `监测发送 ${count} 封邮件`,
        script: "send-monitored-tiktok.mjs",
        args: [
          "--limit", String(count), "--allow-mx-only", "--send",
          "--delay-min", "60", "--delay-max", "120", "--poll-seconds", "20",
        ],
        input: `SEND ${count}\n`,
      }));
    }

    if (request.method === "POST" && url.pathname === "/api/sync") {
      return json(response, 202, startJob({
        label: "同步回复与退信",
        script: "sync-inbox.mjs",
        args: ["--days", "14"],
      }));
    }

    if (request.method === "POST" && url.pathname === "/api/research") {
      const body = await readBody(request);
      if (!body.email) return json(response, 400, { error: "缺少邮箱。" });
      return json(response, 200, await researchCreator(body.email));
    }

    if (request.method === "POST" && url.pathname === "/api/partner/joined") {
      const body = await readBody(request);
      const email = String(body.email || "").trim().toLowerCase();
      const personalAffiliateLink = String(body.affiliateLink || "").trim();
      const confirmation = `MARK PARTNER JOINED ${email}`;
      if (body.confirmation !== confirmation) {
        return json(response, 400, { error: `请输入 ${confirmation}。` });
      }
      return json(response, 202, startJob({
        label: `记录 Partner 加入 ${email}`,
        script: "mark-partner-joined.mjs",
        args: ["--email", email, "--affiliate-link", personalAffiliateLink, "--confirm", confirmation],
      }));
    }

    if (request.method === "POST" && url.pathname === "/api/partner/assign") {
      const body = await readBody(request);
      const email = String(body.email || "").trim().toLowerCase();
      const name = String(body.name || "").trim();
      const rows = await readLeads();
      const lead = rows.find((row) => row.email.toLowerCase() === email);
      if (!lead || lead.partner_status !== "joined") {
        return json(response, 400, { error: "只有已经加入 Affiliate 的创作者才能分配一年兑换码。" });
      }
      if (!name) return json(response, 400, { error: "请输入已核实的创作者姓名。" });
      if (body.confirmation !== `ASSIGN ${email}`) {
        return json(response, 400, { error: `请输入 ASSIGN ${email}。` });
      }
      return json(response, 202, startJob({
        label: `为 ${name} 分配一年 Partner 码`,
        script: "assign-offer-code.mjs",
        args: ["--email", email, "--name", name],
      }));
    }

    if (request.method === "POST" && url.pathname === "/api/partner/send") {
      const body = await readBody(request);
      const email = String(body.email || "").trim().toLowerCase();
      const confirmation = `SEND PARTNER CODE ${email}`;
      if (body.confirmation !== confirmation) {
        return json(response, 400, { error: `请输入 ${confirmation}。` });
      }
      return json(response, 202, startJob({
        label: `发送一年 Partner 码给 ${email}`,
        script: "send-partner-code.mjs",
        args: ["--email", email, "--confirm", confirmation],
      }));
    }
    return json(response, 404, { error: "页面不存在。" });
  } catch (error) {
    console.error(error);
    return json(response, error.statusCode || 500, { error: error.message || "操作失败。" });
  }
});

server.listen(port, host, () => {
  console.log(`ChillScript Creator Outreach dashboard: http://${host}:${port}`);
});
