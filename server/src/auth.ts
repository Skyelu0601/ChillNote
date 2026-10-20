import type { RequestHandler } from "express";

export interface ActiveAuthUser {
  id: string;
  email: string | null;
  createdAt: Date;
}

type AuthRejectionReason = "missing_token" | "empty_token" | "claims_rejected"
  | "inactive_session" | "claims_verification_failed" | "session_lookup_failed";

interface AuthDependencies {
  issuer: string;
  getClaims(token: string): Promise<{
    data: { claims: Record<string, unknown> } | null;
    error: unknown;
  }>;
  findActiveUser(userId: string, sessionId: string): Promise<ActiveAuthUser | null>;
  onError?(error: unknown): void;
  onRejected?(reason: AuthRejectionReason, path: string, error?: unknown): void;
}

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Verify the signature locally, then check live session/user state without an Auth HTTP call. */
export function createRequireAuth(deps: AuthDependencies): RequestHandler {
  return async (req, res, next) => {
    const reject = (reason: AuthRejectionReason, message: string, error?: unknown) => {
      try { deps.onRejected?.(reason, req.path, error); } catch { /* Diagnostics cannot affect authentication. */ }
      res.status(401).json({ error: message });
    };
    const header = req.headers.authorization;
    if (!header?.startsWith("Bearer ")) {
      reject("missing_token", "Missing token");
      return;
    }

    let stage: "claims" | "session" = "claims";
    try {
      const token = header.slice(7);
      if (!token) {
        reject("empty_token", "Invalid token");
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
        reject("claims_rejected", "Invalid token", error);
        return;
      }

      // Do not cache this lookup: sign-out, deletion and bans must still take
      // effect on the next request, including on other backend instances.
      stage = "session";
      const user = await deps.findActiveUser(claims.sub, claims.session_id);
      if (!user || user.id !== claims.sub) {
        reject("inactive_session", "Invalid token");
        return;
      }
      req.userId = user.id;
      req.userEmail = user.email ?? undefined;
      req.userCreatedAt = user.createdAt.toISOString();
    } catch (error) {
      deps.onError?.(error);
      reject(stage === "claims" ? "claims_verification_failed" : "session_lookup_failed", "Invalid token", error);
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
