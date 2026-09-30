import "dotenv/config";
import assert from "node:assert/strict";
import test from "node:test";
import { Prisma, PrismaClient } from "@prisma/client";
import { findActiveAuthUser } from "./authSession.js";

// Opt-in PostgreSQL test. It only reads VALUES fixtures; no Auth rows are read
// or modified. Run with AUTH_DATABASE_TEST=1 and the backend DATABASE_URL.
test("live PostgreSQL rejects revoked, expired, deleted, banned and mismatched sessions", {
  skip: process.env.AUTH_DATABASE_TEST !== "1"
}, async () => {
  const db = new PrismaClient();
  const userId = "ae07a1c7-f40a-43ac-877f-95fd04140d7b";
  const sessionId = "2f6be3d1-7fa9-4ac9-851e-9f7cf25a065f";
  const anotherUser = "79ab8663-30f0-450a-8b65-93f4c21732e8";
  const past = "2000-01-01T00:00:00Z";
  const future = "2999-01-01T00:00:00Z";
  const cases = [
    { name: "active", allowed: true },
    { name: "future session expiry", expires: future, allowed: true },
    { name: "expired ban", banned: past, allowed: true },
    { name: "revoked session", hasSession: false, allowed: false },
    { name: "expired session", expires: past, allowed: false },
    { name: "hard-deleted user", hasUser: false, allowed: false },
    { name: "soft-deleted user", deleted: past, allowed: false },
    { name: "banned user", banned: future, allowed: false },
    { name: "session owned by another user", owner: anotherUser, allowed: false }
  ];
  try {
    for (const scenario of cases) {
      const fixtures = Prisma.sql`
        WITH fixture_users AS (
          SELECT ${userId}::uuid AS id, 'current@example.test'::text AS email,
                 '2026-01-01T00:00:00Z'::timestamptz AS created_at,
                 ${scenario.deleted ?? null}::timestamptz AS deleted_at,
                 ${scenario.banned ?? null}::timestamptz AS banned_until
          WHERE ${scenario.hasUser !== false}
        ), fixture_sessions AS (
          SELECT ${sessionId}::uuid AS id, ${scenario.owner ?? userId}::uuid AS user_id,
                 ${scenario.expires ?? null}::timestamptz AS not_after
          WHERE ${scenario.hasSession !== false}
        )
      `;
      // Run the production query and its bound parameters against the fixture
      // relations, so removing any production predicate breaks this test.
      const database = {
        $queryRaw: (parts: TemplateStringsArray, ...values: unknown[]) => {
          const query = Prisma.sql(parts.map(part => part
            .replace(/auth\.sessions/g, "fixture_sessions")
            .replace(/auth\.users/g, "fixture_users")), ...values);
          return db.$queryRaw(Prisma.sql`${fixtures} ${query}`);
        }
      } as Pick<PrismaClient, "$queryRaw">;
      const result = await findActiveAuthUser(database, userId, sessionId);
      assert.equal(result !== null, scenario.allowed, scenario.name);
      if (result) {
        assert.equal(result.id, userId);
        assert.equal(result.email, "current@example.test");
        assert.equal(result.createdAt.toISOString(), "2026-01-01T00:00:00.000Z");
      }
    }
  } finally {
    await db.$disconnect();
  }
});
