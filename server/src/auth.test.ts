import assert from "node:assert/strict";
import test from "node:test";
import { randomUUID } from "node:crypto";
import type { Request, RequestHandler, Response } from "express";
import { createClient } from "@supabase/supabase-js";
import { exportJWK, generateKeyPair, SignJWT } from "jose";
import { createRequireAuth, type ActiveAuthUser } from "./auth.js";

const userId = "ae07a1c7-f40a-43ac-877f-95fd04140d7b";
const sessionId = "2f6be3d1-7fa9-4ac9-851e-9f7cf25a065f";
const createdAt = new Date("2026-01-01T00:00:00Z");

async function call(middleware: RequestHandler, authorization?: string) {
  const req = { headers: { authorization } } as Request;
  let status = 200;
  let body: unknown;
  let passed = false;
  const res = {
    status(code: number) { status = code; return this; },
    json(value: unknown) { body = value; return this; }
  } as Response;
  await middleware(req, res, () => { passed = true; });
  return { req, status, body, passed };
}

async function fixture() {
  const baseUrl = `https://auth-${randomUUID()}.example.test`;
  const issuer = `${baseUrl}/auth/v1`;
  const key = await generateKeyPair("ES256");
  const jwk = { ...await exportJWK(key.publicKey), kid: "test-key", alg: "ES256" };
  const requests: string[] = [];
  const checks: Array<[string, string]> = [];
  const errors: unknown[] = [];
  const state: { user: ActiveAuthUser | null; databaseError?: Error } = {
    user: { id: userId, email: "current@example.test", createdAt }
  };
  const client = createClient(baseUrl, "public-test-key", {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
    global: {
      fetch: async (input) => {
        const path = new URL(String(input)).pathname;
        requests.push(path);
        if (path.endsWith("/.well-known/jwks.json")) {
          return new Response(JSON.stringify({ keys: [jwk] }), { headers: { "Content-Type": "application/json" } });
        }
        if (path === "/auth/v1/user") {
          return new Response(JSON.stringify({ id: userId, email: "current@example.test", created_at: createdAt.toISOString() }),
            { headers: { "Content-Type": "application/json" } });
        }
        throw new Error(`Unexpected Auth request: ${path}`);
      }
    }
  });
  const middleware = createRequireAuth({
    issuer,
    getClaims: token => client.auth.getClaims(token),
    findActiveUser: async (user, session) => {
      checks.push([user, session]);
      if (state.databaseError) throw state.databaseError;
      return state.user;
    },
    onError: error => errors.push(error)
  });
  async function token(overrides: Record<string, unknown> = {}, signingKey = key.privateKey) {
    return new SignJWT({
      iss: issuer, aud: "authenticated", sub: userId, role: "authenticated", session_id: sessionId,
      exp: Math.floor(Date.now() / 1000) + 300, email: "stale@example.test", ...overrides
    }).setProtectedHeader({ alg: "ES256", kid: "test-key" }).sign(signingKey);
  }
  return { middleware, token, requests, checks, errors, state, issuer };
}

test("repeated mobile Bearer requests verify locally with one cached JWKS fetch and live user fields", async () => {
  const f = await fixture();
  const token = await f.token();
  for (let i = 0; i < 20; i++) {
    const response = await call(f.middleware, `Bearer ${token}`);
    assert.equal(response.passed, true);
    assert.equal(response.req.userId, userId);
    assert.equal(response.req.userEmail, "current@example.test");
    assert.equal(response.req.userCreatedAt, createdAt.toISOString());
  }
  assert.deepEqual(f.requests, ["/auth/v1/.well-known/jwks.json"]);
  assert.equal(f.checks.length, 20);
  assert.ok(f.checks.every(([u, s]) => u === userId && s === sessionId));
});

test("missing, empty and malformed tokens preserve the existing 401 response contract", async () => {
  const f = await fixture();
  for (const header of [undefined, "Basic abc", "Bearer ", "Bearer malformed"]) {
    const result = await call(f.middleware, header);
    assert.equal(result.status, 401);
    assert.equal(result.passed, false);
    assert.deepEqual(result.body, { error: header?.startsWith("Bearer ") ? "Invalid token" : "Missing token" });
  }
  assert.equal(f.checks.length, 0);
});

test("expired and forged signatures cannot reach the database or protected handler", async () => {
  const f = await fixture();
  const forgedKey = await generateKeyPair("ES256");
  for (const token of [await f.token({ exp: 1 }), await f.token({}, forgedKey.privateKey)]) {
    const result = await call(f.middleware, `Bearer ${token}`);
    assert.equal(result.status, 401);
    assert.equal(result.passed, false);
  }
  assert.equal(f.checks.length, 0);
});

test("verified tokens must belong to this project, audience, user role and a valid session", async () => {
  const f = await fixture();
  const cases = [
    { iss: "https://another.example.test/auth/v1" }, { aud: "another-api" },
    { role: "service_role" }, { role: "anon" }, { sub: "not-a-uuid" },
    { session_id: "" }, { session_id: undefined }, { exp: undefined },
    { nbf: Math.floor(Date.now() / 1000) + 600 },
    { role: "anon", user_metadata: { role: "authenticated", sub: userId, session_id: sessionId } }
  ];
  for (const claims of cases) {
    const result = await call(f.middleware, `Bearer ${await f.token(claims)}`);
    assert.equal(result.status, 401, JSON.stringify(claims));
    assert.equal(result.passed, false);
  }
  assert.equal(f.checks.length, 0);
});

test("session revocation or user deletion takes effect on the next request even with the same valid token", async () => {
  const f = await fixture();
  const token = await f.token();
  assert.equal((await call(f.middleware, `Bearer ${token}`)).passed, true);
  f.state.user = null;
  const result = await call(f.middleware, `Bearer ${token}`);
  assert.equal(result.status, 401);
  assert.equal(result.passed, false);
  assert.equal(result.req.userId, undefined);
  assert.equal(f.checks.length, 2);
});

test("a mismatched user result or unavailable session database fails closed", async () => {
  const f = await fixture();
  const token = await f.token();
  f.state.user = { id: randomUUID(), email: null, createdAt };
  assert.equal((await call(f.middleware, `Bearer ${token}`)).status, 401);
  f.state.databaseError = new Error("Database unavailable");
  const result = await call(f.middleware, `Bearer ${token}`);
  assert.equal(result.status, 401);
  assert.equal(result.passed, false);
  assert.equal(f.errors.length, 1);
});

test("legacy HS256 user sessions retain the SDK's remote verification fallback", async () => {
  const f = await fixture();
  const token = await new SignJWT({
    iss: f.issuer, aud: "authenticated", sub: userId, role: "authenticated", session_id: sessionId
  }).setProtectedHeader({ alg: "HS256" }).setExpirationTime("5m")
    .sign(new TextEncoder().encode("test-secret-with-at-least-32-characters"));
  assert.equal((await call(f.middleware, `Bearer ${token}`)).passed, true);
  assert.deepEqual(f.requests, ["/auth/v1/user"]);
  assert.equal(f.checks.length, 1);
});
