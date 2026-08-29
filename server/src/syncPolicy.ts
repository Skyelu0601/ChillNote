export const STRICT_SYNC_PROTOCOL_VERSION = 3;
export const DURABLE_MUTATION_PROTOCOL_VERSION = 4;

export type SyncMutationDecision = "hard_delete" | "tombstoned" | "conflict" | "idempotent" | "apply";

export function usesStrictSyncVersioning(protocolVersion?: number | null): boolean {
  return (protocolVersion ?? 0) >= STRICT_SYNC_PROTOCOL_VERSION;
}

export function usesDurableSyncMutations(protocolVersion?: number | null): boolean {
  return (protocolVersion ?? 0) >= DURABLE_MUTATION_PROTOCOL_VERSION;
}

function sameMutationId(left?: string | null, right?: string | null): boolean {
  return !!left && !!right && left.toLowerCase() === right.toLowerCase();
}

export function hasForeignSyncIdentityOwner(
  userId: string,
  ownerIds: Iterable<string>
): boolean {
  return Array.from(ownerIds).some((ownerId) => ownerId !== userId);
}

export function decideSyncMutation(params: {
  protocolVersion?: number | null;
  hardDeleteRequested?: boolean;
  hasTombstone?: boolean;
  hasExisting?: boolean;
  baseVersion?: number | null;
  serverVersion?: number | null;
  mutationId?: string | null;
  previousMutationId?: string | null;
  serverMutationId?: string | null;
}): SyncMutationDecision {
  if (params.hardDeleteRequested) return "hard_delete";
  if (params.hasTombstone) return "tombstoned";
  if (usesDurableSyncMutations(params.protocolVersion)) {
    if (!params.mutationId) return "conflict";
    if (!params.hasExisting) return "apply";
    if (sameMutationId(params.mutationId, params.serverMutationId)) return "idempotent";
    // v4 defines an entity that is known not to exist as server version zero.
    // Treat a missing wire value as zero too for upgrade resilience.
    const durableBaseVersion = params.baseVersion ?? 0;
    if (durableBaseVersion === (params.serverVersion ?? 0)) return "apply";

    // The previous request committed but its HTTP acknowledgement was lost.
    // A later local edit names that submitted mutation as its predecessor. The
    // +1 version check ensures no third-party/server mutation happened after it.
    if (
      sameMutationId(params.previousMutationId, params.serverMutationId)
      && params.serverVersion === durableBaseVersion + 1
    ) {
      return "apply";
    }
    return "conflict";
  }
  if (
    params.hasExisting
    && usesStrictSyncVersioning(params.protocolVersion)
    && params.baseVersion !== (params.serverVersion ?? 0)
  ) {
    return "conflict";
  }
  return "apply";
}

/**
 * A cursor is a SyncLog primary key, so it is always a non-negative safe
 * integer at or below this user's high-water mark. Apply this validation to
 * every protocol: accepting an old device's future/global cursor can make it
 * permanently skip this account's history before that device upgrades.
 */
export function resolveSyncCursor(
  cursor: string | null | undefined,
  _protocolVersion: number | null | undefined,
  maximumAcceptedCursor: number
): number | null {
  if (!cursor) return null;
  const parsed = Number(cursor);
  if (!Number.isSafeInteger(parsed) || parsed < 0 || parsed > maximumAcceptedCursor) {
    return null;
  }
  return parsed;
}

/**
 * SyncLog IDs are global. A non-zero cursor must point to one of this user's
 * own rows, not merely be numerically below this user's maximum ID.
 */
export function requireOwnedSyncCursor(
  cursorId: number | null,
  checkpointBelongsToUser: boolean
): number | null {
  if (cursorId == null || cursorId === 0 || checkpointBelongsToUser) return cursorId;
  return null;
}

export function isPrismaUniqueConstraintError(error: unknown): boolean {
  return typeof error === "object"
    && error !== null
    && "code" in error
    && (error as { code?: unknown }).code === "P2002";
}

export function isAccountDeletedDatabaseError(error: unknown): boolean {
  if (typeof error !== "object" || error === null) return false;
  const candidate = error as {
    message?: unknown;
    meta?: { message?: unknown; database_error?: unknown };
  };
  return [candidate.message, candidate.meta?.message, candidate.meta?.database_error]
    .some((value) => typeof value === "string" && value.includes("sync.account_deleted"));
}

export class SyncOwnershipError extends Error {
  constructor() {
    super("sync.identity_unavailable");
    this.name = "SyncOwnershipError";
  }
}

export class SyncReferenceError extends Error {
  constructor() {
    super("sync.invalid_reference");
    this.name = "SyncReferenceError";
  }
}

export class AccountDeletedError extends Error {
  constructor() {
    super("sync.account_deleted");
    this.name = "AccountDeletedError";
  }
}
