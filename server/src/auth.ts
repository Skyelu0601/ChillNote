import type { RequestHandler } from "express";

export interface ActiveAuthUser {
  id: string;
  email: string | null;
  createdAt: Date;
}

interface AuthDependencies {
  issuer: string;
  getClaims(token: string): Promise<{
    data: { claims: Record<string, unknown> } | null;
    error: unknown;
  }>;
  findActiveUser(userId: string, sessionId: string): Promise<ActiveAuthUser | null>;
  onError?(error: unknown): void;
}

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Verify the signature locally, then check live session/user state without an Auth HTTP call. */
export function createRequireAuth(deps: AuthDependencies): RequestHandler {
  return async (req, res, next) => {
    const header = req.headers.authorization;
    if (!header?.startsWith("Bearer ")) {
      res.status(401).json({ error: "Missing token" });
      return;
    }

    try {
      const token = header.slice(7);
      if (!token) {
        res.status(401).json({ error: "Invalid token" });
        return;
      }
      const { data, error } = await deps.getClaims(token);
      const claims = data?.claims;
      const now = Date.now() / 1000;
      // The SDK checks signature and expiry. Also bind this identity to our
      // project, user audience and session; never authorize from user_metadata.
      if (error || !claims || claims.iss !== deps.issuer
          || !(claims.aud === "authenticated"
            || (Array.isArray(claims.aud) && claims.aud.includes("authenticated")))
          || claims.role !== "authenticated"
          || typeof claims.sub !== "string" || !uuid.test(claims.sub)
          || typeof claims.session_id !== "string" || !uuid.test(claims.session_id)
          || typeof claims.exp !== "number" || !Number.isFinite(claims.exp) || claims.exp <= now
          || (claims.nbf !== undefined
            && (typeof claims.nbf !== "number" || !Number.isFinite(claims.nbf) || claims.nbf > now))) {
        res.status(401).json({ error: "Invalid token" });
        return;
      }

      // Do not cache this lookup: sign-out, deletion and bans must still take
      // effect on the next request, including on other backend instances.
      const user = await deps.findActiveUser(claims.sub, claims.session_id);
      if (!user || user.id !== claims.sub) {
        res.status(401).json({ error: "Invalid token" });
        return;
      }
      req.userId = user.id;
      req.userEmail = user.email ?? undefined;
      req.userCreatedAt = user.createdAt.toISOString();
    } catch (error) {
      deps.onError?.(error);
      res.status(401).json({ error: "Invalid token" });
      return;
    }
    next();
  };
}

declare global {
  namespace Express {
    interface Request {
      userId?: string;
      userEmail?: string;
      userCreatedAt?: string;
    }
  }
}
