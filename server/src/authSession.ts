import type { PrismaClient } from "@prisma/client";
import type { ActiveAuthUser } from "./auth.js";

/** Uses the existing server-only database connection; no Data API grants or RPC are needed. */
export async function findActiveAuthUser(
  database: Pick<PrismaClient, "$queryRaw">,
  userId: string,
  sessionId: string
): Promise<ActiveAuthUser | null> {
  const users = await database.$queryRaw<ActiveAuthUser[]>`
    SELECT u.id::text AS id, u.email, u.created_at AS "createdAt"
    FROM auth.sessions s
    JOIN auth.users u ON u.id = s.user_id
    WHERE s.id = ${sessionId}::uuid
      AND s.user_id = ${userId}::uuid
      AND u.deleted_at IS NULL
      AND (u.banned_until IS NULL OR u.banned_until <= now())
      AND (s.not_after IS NULL OR s.not_after > now())
    LIMIT 1
  `;
  return users[0] ?? null;
}
