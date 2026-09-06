import { createHmac } from "node:crypto";
import { NextRequest, NextResponse } from "next/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
type Context = { params: Promise<{ path?: string[] }> };
async function proxy(request: NextRequest, context: Context) {
  const path = (await context.params).path || [];
  if (path[0] !== "jobs" || path.length > 2 || (path[1] && !/^[a-f0-9-]{36}$/.test(path[1])) || (request.method === "GET" && path.length !== 2) || (request.method === "POST" && path.length !== 1)) {
    return NextResponse.json({ error: "invalid_request" }, { status: 400 });
  }
  const origin = request.headers.get("origin");
  if (request.method === "POST" && origin !== request.nextUrl.origin) return NextResponse.json({ error: "invalid_request" }, { status: 403 });
  const secret = process.env.FREE_TOOLS_SECRET;
  const backend = process.env.FREE_TOOLS_BACKEND_URL;
  if (!secret || secret.length < 32 || !backend) return NextResponse.json({ error: "unavailable" }, { status: 503 });
  // Vercel overwrites this header. Other hosts must configure a trusted ingress;
  // never accept arbitrary x-forwarded-for for anonymous quota identities.
  const ip = process.env.VERCEL ? request.headers.get("x-vercel-forwarded-for")?.split(",")[0]?.trim() : "local-preview";
  if (!ip || (!process.env.VERCEL && process.env.NODE_ENV === "production" && process.env.FREE_TOOLS_ALLOW_LOCAL !== "true")) return NextResponse.json({ error: "unavailable" }, { status: 503 });
  const owner = createHmac("sha256", secret).update(ip).digest("hex");
  let body: string | undefined;
  if (request.method === "POST") {
    if (Number(request.headers.get("content-length")) > 8192) return NextResponse.json({ error: "invalid_request" }, { status: 413 });
    const reader = request.body?.getReader();
    const chunks: Uint8Array[] = []; let bytes = 0;
    if (reader) {
      try {
        while (true) {
          const part = await reader.read(); if (part.done) break;
          bytes += part.value.byteLength;
          if (bytes > 8192) { await reader.cancel(); return NextResponse.json({ error: "invalid_request" }, { status: 413 }); }
          chunks.push(part.value);
        }
      } catch { return NextResponse.json({ error: "invalid_request" }, { status: 400 }); }
    }
    body = Buffer.concat(chunks).toString("utf8");
    try { JSON.parse(body); } catch { return NextResponse.json({ error: "invalid_request" }, { status: 400 }); }
  }
  try {
    const response = await fetch(`${backend.replace(/\/$/, "")}/free-tools/${path.join("/")}`, {
      method: request.method, body, cache: "no-store", signal: AbortSignal.timeout(12000),
      headers: { "Content-Type": "application/json", "x-free-tools-secret": secret, "x-free-tools-client": owner }
    });
    const data = await response.json();
    return NextResponse.json(data, { status: response.status, headers: { "Cache-Control": "no-store" } });
  } catch { return NextResponse.json({ error: "unavailable" }, { status: 503 }); }
}
export const GET = proxy;
export const POST = proxy;
