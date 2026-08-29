import type { NoteDTO, SyncChanges, TagDTO } from "./types.js";
import type { Prisma } from "@prisma/client";
import { prisma } from "./db.js";
import { pickLatestBySyncIdentity, syncIdentityKey } from "./syncIdentity.js";
import {
  requireOwnedSyncCursor,
  resolveSyncCursor,
  AccountDeletedError,
  SyncOwnershipError
} from "./syncPolicy.js";

export type SyncDatabase = Prisma.TransactionClient;

export async function acquireUserSyncTransactionLock(
  userId: string,
  database: SyncDatabase
): Promise<void> {
  // Selecting the void-returning lock function directly makes Prisma fail to
  // deserialize PostgreSQL's `void` type. Put it in FROM and return a regular
  // integer column after the lock has been acquired.
  await database.$queryRaw<Array<{ locked: number }>>`
    SELECT 1::int AS locked
    FROM pg_advisory_xact_lock(hashtextextended(${userId}, 0))
  `;
}

type DeleteManyDelegate<Where> = {
  deleteMany(args: { where: Where }): PromiseLike<{ count: number }>;
};

type UserDeletionTransaction = {
  $queryRaw<T = unknown>(query: TemplateStringsArray | Prisma.Sql, ...values: any[]): Promise<T>;
  accountDeletionMarker: {
    upsert(args: {
      where: { userId: string };
      create: { userId: string };
      update: Record<string, never>;
    }): PromiseLike<unknown>;
  };
  hardDeleteTombstone: DeleteManyDelegate<{ userId: string }>;
  syncLog: DeleteManyDelegate<{ userId: string }>;
  user: DeleteManyDelegate<{ id: string }>;
};

type UserDeletionDatabase = {
  $transaction<T>(operation: (transaction: UserDeletionTransaction) => Promise<T>): Promise<T>;
};

export function isProSubscriptionActive(
  tier: string | null | undefined,
  expiresAt: Date | null | undefined,
  now = new Date()
): boolean {
  return tier === "pro" && (!expiresAt || expiresAt.getTime() > now.getTime());
}

export async function hasActiveProSubscription(
  userId: string,
  now = new Date()
): Promise<boolean> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { subscriptionTier: true, subscriptionExpiresAt: true }
  });
  return isProSubscriptionActive(
    user?.subscriptionTier,
    user?.subscriptionExpiresAt,
    now
  );
}

export async function upsertUser(userId: string, database: SyncDatabase = prisma): Promise<void> {
  const deletionMarker = await database.accountDeletionMarker.findUnique({
    where: { userId },
    select: { userId: true }
  });
  if (deletionMarker) throw new AccountDeletedError();

  // Avoid Prisma upsert race conditions when multiple requests try to
  // create the same user row at the same time.
  await database.$executeRaw`
    INSERT INTO "User" ("id", "createdAt", "updatedAt")
    VALUES (${userId}, NOW(), NOW())
    ON CONFLICT ("id") DO NOTHING
  `;
}

export async function updateSubscriptionStatus(
  userId: string,
  tier: string,
  expiresAt: Date | null,
  originalTransactionId: string | null,
  provider?: string | null
): Promise<void> {
  await prisma.user.update({
    where: { id: userId },
    data: {
      subscriptionTier: tier,
      subscriptionExpiresAt: expiresAt,
      originalTransactionId: originalTransactionId,
      ...(provider !== undefined ? { subscriptionProvider: provider } : {})
    }
  });
}

export async function updateCreemSubscriptionStatus(params: {
  userId: string;
  tier: string;
  expiresAt: Date | null;
  customerId?: string | null;
  subscriptionId?: string | null;
}): Promise<void> {
  await prisma.user.update({
    where: { id: params.userId },
    data: {
      subscriptionTier: params.tier,
      subscriptionExpiresAt: params.expiresAt,
      subscriptionProvider: "creem",
      creemCustomerId: params.customerId ?? undefined,
      creemSubscriptionId: params.subscriptionId ?? undefined
    }
  });
}

function mapNoteToDTO(note: any): NoteDTO {
  return {
    id: note.id,
    content: note.content,
    createdAt: note.createdAt.toISOString(),
    updatedAt: note.serverUpdatedAt?.toISOString() ?? note.updatedAt?.toISOString() ?? null,
    deletedAt: note.serverDeletedAt?.toISOString() ?? note.deletedAt?.toISOString() ?? null,
    pinnedAt: note.pinnedAt?.toISOString() ?? null,
    tagIds: Array.isArray(note.tags)
      ? note.tags.filter((tag: any) => tag.serverDeletedAt == null && tag.deletedAt == null).map((tag: any) => tag.id)
      : [],
    version: note.version ?? 1,
    lastModifiedByDeviceId: note.lastModifiedByDeviceId ?? null,
    mutationId: note.lastMutationId ?? null,
    sourceURL: note.sourceURL ?? null,
    sourceTitle: note.sourceTitle ?? null,
    sourcePlatformID: note.sourcePlatformID ?? null,
    sourcePlatformName: note.sourcePlatformName ?? null,
    sourceHost: note.sourceHost ?? null,
    sourceAuthorName: note.sourceAuthorName ?? null,
    sourceAuthorHandle: note.sourceAuthorHandle ?? null,
    sourceCapturedAt: note.sourceCapturedAt?.toISOString() ?? null,
    section: note.section ?? "inbox",
    importStatus: note.importStatus ?? null,
    importJobId: note.importJobId ?? null,
    importErrorCode: note.importErrorCode ?? null,
    importStartedAt: note.importStartedAt?.toISOString() ?? null,
    importCompletedAt: note.importCompletedAt?.toISOString() ?? null
  };
}

function mapTagToDTO(tag: any): TagDTO {
  return {
    id: tag.id,
    name: tag.name,
    colorHex: tag.colorHex,
    createdAt: tag.createdAt.toISOString(),
    updatedAt: tag.serverUpdatedAt?.toISOString() ?? tag.updatedAt?.toISOString() ?? null,
    lastUsedAt: tag.lastUsedAt?.toISOString() ?? null,
    sortOrder: tag.sortOrder,
    parentId: tag.parentId ?? null,
    deletedAt: tag.serverDeletedAt?.toISOString() ?? tag.deletedAt?.toISOString() ?? null,
    version: tag.version ?? 1,
    lastModifiedByDeviceId: tag.lastModifiedByDeviceId ?? null,
    mutationId: tag.lastMutationId ?? null
  };
}

function latestEntityRows<T extends { id: string; serverUpdatedAt?: Date | null; updatedAt?: Date | null }>(rows: T[]): T[] {
  return Array.from(pickLatestBySyncIdentity(rows, (row) =>
    row.serverUpdatedAt?.getTime() ?? row.updatedAt?.getTime() ?? -Infinity
  ).values());
}

function uniqueSyncIDs(ids: string[]): string[] {
  return Array.from(new Map(ids.map((id) => [syncIdentityKey(id), id])).values());
}

function hasOwnField<T extends object>(value: T, key: keyof NoteDTO): boolean {
  return Object.prototype.hasOwnProperty.call(value, key);
}

function sourceUpdateData(incoming: NoteDTO) {
  const data: Record<string, string | Date | null> = {};

  if (hasOwnField(incoming, "sourceURL")) {
    data.sourceURL = incoming.sourceURL ?? null;
  }
  if (hasOwnField(incoming, "sourceTitle")) {
    data.sourceTitle = incoming.sourceTitle ?? null;
  }
  if (hasOwnField(incoming, "sourcePlatformID")) {
    data.sourcePlatformID = incoming.sourcePlatformID ?? null;
  }
  if (hasOwnField(incoming, "sourcePlatformName")) {
    data.sourcePlatformName = incoming.sourcePlatformName ?? null;
  }
  if (hasOwnField(incoming, "sourceHost")) {
    data.sourceHost = incoming.sourceHost ?? null;
  }
  if (hasOwnField(incoming, "sourceAuthorName")) {
    data.sourceAuthorName = incoming.sourceAuthorName ?? null;
  }
  if (hasOwnField(incoming, "sourceAuthorHandle")) {
    data.sourceAuthorHandle = incoming.sourceAuthorHandle ?? null;
  }
  if (hasOwnField(incoming, "sourceCapturedAt")) {
    data.sourceCapturedAt = incoming.sourceCapturedAt ? new Date(incoming.sourceCapturedAt) : null;
  }

  return data;
}

function importUpdateData(incoming: NoteDTO) {
  const data: Record<string, string | Date | null> = {};

  if (hasOwnField(incoming, "importStatus")) {
    data.importStatus = incoming.importStatus ?? null;
  }
  if (hasOwnField(incoming, "importJobId")) {
    data.importJobId = incoming.importJobId ?? null;
  }
  if (hasOwnField(incoming, "importErrorCode")) {
    data.importErrorCode = incoming.importErrorCode ?? null;
  }
  if (hasOwnField(incoming, "importStartedAt")) {
    data.importStartedAt = incoming.importStartedAt ? new Date(incoming.importStartedAt) : null;
  }
  if (hasOwnField(incoming, "importCompletedAt")) {
    data.importCompletedAt = incoming.importCompletedAt ? new Date(incoming.importCompletedAt) : null;
  }

  return data;
}

function importCreateData(incoming: NoteDTO) {
  return {
    importStatus: incoming.importStatus ?? null,
    importJobId: incoming.importJobId ?? null,
    importErrorCode: incoming.importErrorCode ?? null,
    importStartedAt: incoming.importStartedAt ? new Date(incoming.importStartedAt) : null,
    importCompletedAt: incoming.importCompletedAt ? new Date(incoming.importCompletedAt) : null
  };
}

function sourceCreateData(incoming: NoteDTO) {
  return {
    sourceURL: incoming.sourceURL ?? null,
    sourceTitle: incoming.sourceTitle ?? null,
    sourcePlatformID: incoming.sourcePlatformID ?? null,
    sourcePlatformName: incoming.sourcePlatformName ?? null,
    sourceHost: incoming.sourceHost ?? null,
    sourceAuthorName: incoming.sourceAuthorName ?? null,
    sourceAuthorHandle: incoming.sourceAuthorHandle ?? null,
    sourceCapturedAt: incoming.sourceCapturedAt ? new Date(incoming.sourceCapturedAt) : null
  };
}

export type GetChangesOptions = {
  protocolVersion?: number | null;
  maximumAcceptedCursor?: number;
  forcedNoteIds?: string[];
  forcedTagIds?: string[];
  forcedHardDeletedNoteIds?: string[];
  forcedHardDeletedTagIds?: string[];
};

export async function getLatestSyncLogId(userId: string, database: SyncDatabase = prisma): Promise<number> {
  const latestLog = await database.syncLog.aggregate({
    where: { userId },
    _max: { id: true }
  });
  return latestLog._max.id ?? 0;
}

export async function getChangesSinceCursor(
  userId: string,
  cursor?: string | null,
  database: SyncDatabase = prisma,
  options: GetChangesOptions = {}
): Promise<{ changes: SyncChanges; cursor: string }> {
  // Capture the high-water mark before reading entities. Rows that commit after
  // this point can be visible in the response, but their later log ID remains
  // above this cursor and will be delivered again instead of being skipped.
  const latestLogId = await getLatestSyncLogId(userId, database);
  let cursorId = resolveSyncCursor(
    cursor,
    options.protocolVersion,
    options.maximumAcceptedCursor ?? latestLogId
  );
  if (cursorId != null && cursorId !== 0) {
    const ownedCheckpoint = await database.syncLog.findFirst({
      where: { id: cursorId, userId },
      select: { id: true }
    });
    cursorId = requireOwnedSyncCursor(cursorId, !!ownedCheckpoint);
  }

  if (cursorId == null) {
    const notes = await database.note.findMany({
      where: { userId },
      include: { tags: true }
    });
    const tags = await database.tag.findMany({ where: { userId } });
    const tombstones = await database.hardDeleteTombstone.findMany({ where: { userId } });
    const hardDeletedNoteIds = uniqueSyncIDs([
      ...tombstones.filter((item) => item.entityType === "note").map((item) => item.entityId),
      ...(options.forcedHardDeletedNoteIds ?? [])
    ]);
    const hardDeletedTagIds = uniqueSyncIDs([
      ...tombstones.filter((item) => item.entityType === "tag").map((item) => item.entityId),
      ...(options.forcedHardDeletedTagIds ?? [])
    ]);
    const hardDeletedNoteKeys = new Set(hardDeletedNoteIds.map(syncIdentityKey));
    const hardDeletedTagKeys = new Set(hardDeletedTagIds.map(syncIdentityKey));

    return {
      cursor: String(latestLogId),
      changes: {
        notes: latestEntityRows(notes)
          .filter((note) => !hardDeletedNoteKeys.has(syncIdentityKey(note.id)))
          .map(mapNoteToDTO),
        tags: latestEntityRows(tags)
          .filter((tag) => !hardDeletedTagKeys.has(syncIdentityKey(tag.id)))
          .map(mapTagToDTO),
        hardDeletedNoteIds,
        hardDeletedTagIds
      }
    };
  }

  const logs = await database.syncLog.findMany({
    where: { userId, id: { gt: cursorId, lte: latestLogId } },
    orderBy: { id: "asc" }
  });

  let newCursor = cursorId;
  if (logs.length > 0) {
    newCursor = logs[logs.length - 1].id;
  }

  const latestByEntity = new Map<string, { entityType: string; entityId: string; operation: string }>();
  for (const log of logs) {
    const key = `${log.entityType}:${syncIdentityKey(log.entityId)}`;
    latestByEntity.set(key, {
      entityType: log.entityType,
      entityId: log.entityId,
      operation: log.operation
    });
  }

  const noteIds = [...(options.forcedNoteIds ?? [])];
  const tagIds = [...(options.forcedTagIds ?? [])];
  const hardDeletedNoteIds = [...(options.forcedHardDeletedNoteIds ?? [])];
  const hardDeletedTagIds = [...(options.forcedHardDeletedTagIds ?? [])];
  for (const entry of latestByEntity.values()) {
    if (entry.entityType === "note") {
      if (entry.operation === "hard_delete") {
        hardDeletedNoteIds.push(entry.entityId);
      } else {
        noteIds.push(entry.entityId);
      }
    } else if (entry.entityType === "tag") {
      if (entry.operation === "hard_delete") {
        hardDeletedTagIds.push(entry.entityId);
      } else {
        tagIds.push(entry.entityId);
      }
    }
  }

  const uniqueHardDeletedNoteIds = uniqueSyncIDs(hardDeletedNoteIds);
  const uniqueHardDeletedTagIds = uniqueSyncIDs(hardDeletedTagIds);
  const hardDeletedNoteKeys = new Set(uniqueHardDeletedNoteIds.map(syncIdentityKey));
  const hardDeletedTagKeys = new Set(uniqueHardDeletedTagIds.map(syncIdentityKey));
  const requestedNoteIds = uniqueSyncIDs(noteIds).filter((id) => !hardDeletedNoteKeys.has(syncIdentityKey(id)));
  const requestedTagIds = uniqueSyncIDs(tagIds).filter((id) => !hardDeletedTagKeys.has(syncIdentityKey(id)));

  const notes = requestedNoteIds.length
    ? await database.note.findMany({
      where: { userId, id: { in: requestedNoteIds } },
      include: { tags: true }
    })
    : [];
  const tags = requestedTagIds.length
    ? await database.tag.findMany({
      where: { userId, id: { in: requestedTagIds } }
    })
    : [];

  return {
    cursor: String(newCursor),
    changes: {
      notes: latestEntityRows(notes).map(mapNoteToDTO),
      tags: latestEntityRows(tags).map(mapTagToDTO),
      hardDeletedNoteIds: uniqueHardDeletedNoteIds,
      hardDeletedTagIds: uniqueHardDeletedTagIds
    }
  };
}

export async function upsertTag(
  userId: string,
  incoming: TagDTO,
  options: { setParent?: boolean } = {},
  database: SyncDatabase = prisma
): Promise<void> {
  const setParent = options.setParent ?? true;
  const serverUpdatedAt = incoming.updatedAt ? new Date(incoming.updatedAt) : new Date();
  const baseData = {
    name: incoming.name,
    colorHex: incoming.colorHex,
    createdAt: new Date(incoming.createdAt),
    updatedAt: new Date(),
    lastUsedAt: incoming.lastUsedAt ? new Date(incoming.lastUsedAt) : null,
    sortOrder: incoming.sortOrder,
    deletedAt: incoming.deletedAt ? new Date(incoming.deletedAt) : null,
    serverUpdatedAt,
    serverDeletedAt: incoming.deletedAt ? new Date(incoming.deletedAt) : null,
    version: incoming.version ?? 1,
    lastModifiedByDeviceId: incoming.lastModifiedByDeviceId ?? null,
    ...(hasOwnField(incoming, "mutationId")
      ? { lastMutationId: incoming.mutationId ?? null }
      : {})
  };

  const existing = await database.tag.findUnique({
    where: { id: incoming.id },
    select: { userId: true }
  });
  if (existing && existing.userId !== userId) throw new SyncOwnershipError();

  if (existing) {
    await database.tag.update({
      where: { id: incoming.id },
      data: {
        ...baseData,
        ...(setParent ? { parentId: incoming.parentId ?? null } : {})
      }
    });
  } else {
    await database.tag.create({
      data: {
        id: incoming.id,
        userId,
        ...baseData,
        parentId: setParent ? incoming.parentId ?? null : null
      }
    });
  }
}

export async function upsertNote(
  userId: string,
  incoming: NoteDTO,
  database: SyncDatabase = prisma
): Promise<void> {
  const serverUpdatedAt = incoming.updatedAt ? new Date(incoming.updatedAt) : new Date();
  const tagIds = incoming.tagIds ?? undefined;
  const sourceUpdate = sourceUpdateData(incoming);
  const sourceCreate = sourceCreateData(incoming);
  const importUpdate = importUpdateData(incoming);
  const importCreate = importCreateData(incoming);
  const existing = await database.note.findUnique({
    where: { id: incoming.id },
    select: { userId: true }
  });
  if (existing && existing.userId !== userId) throw new SyncOwnershipError();

  if (existing) {
    await database.note.update({
      where: { id: incoming.id },
      data: {
      content: incoming.content,
      createdAt: new Date(incoming.createdAt),
      updatedAt: new Date(),
      deletedAt: incoming.deletedAt ? new Date(incoming.deletedAt) : null,
      pinnedAt: incoming.pinnedAt ? new Date(incoming.pinnedAt) : null,
      serverUpdatedAt,
      serverDeletedAt: incoming.deletedAt ? new Date(incoming.deletedAt) : null,
      version: incoming.version ?? 1,
      lastModifiedByDeviceId: incoming.lastModifiedByDeviceId ?? null,
      ...(hasOwnField(incoming, "mutationId")
        ? { lastMutationId: incoming.mutationId ?? null }
        : {}),
      section: incoming.section ?? "inbox",
      ...sourceUpdate,
      ...importUpdate,
      tags: tagIds ? { set: tagIds.map((tagId) => ({ id: tagId })) } : undefined
      }
    });
  } else {
    await database.note.create({
      data: {
      id: incoming.id,
      userId,
      content: incoming.content,
      createdAt: new Date(incoming.createdAt),
      updatedAt: new Date(),
      deletedAt: incoming.deletedAt ? new Date(incoming.deletedAt) : null,
      pinnedAt: incoming.pinnedAt ? new Date(incoming.pinnedAt) : null,
      serverUpdatedAt,
      serverDeletedAt: incoming.deletedAt ? new Date(incoming.deletedAt) : null,
      version: incoming.version ?? 1,
      lastModifiedByDeviceId: incoming.lastModifiedByDeviceId ?? null,
      ...(hasOwnField(incoming, "mutationId")
        ? { lastMutationId: incoming.mutationId ?? null }
        : {}),
      section: incoming.section ?? "inbox",
      ...sourceCreate,
      ...importCreate,
      tags: tagIds ? { connect: tagIds.map((tagId) => ({ id: tagId })) } : undefined
      }
    });
  }
}

export async function deleteUser(
  userId: string,
  database: UserDeletionDatabase = prisma
): Promise<void> {
  await database.$transaction(async (transaction) => {
    // Account deletion and sync use the same lock ordering. Once this marker is
    // committed it survives the User cascade and every later sync fails closed,
    // including a request that authenticated before Supabase Auth was erased.
    await acquireUserSyncTransactionLock(userId, transaction as unknown as SyncDatabase);
    await transaction.accountDeletionMarker.upsert({
      where: { userId },
      create: { userId },
      update: {}
    });
    // Sync logs and hard-delete tombstones intentionally survive individual
    // note/tag deletion, but they must not survive deletion of the account.
    await transaction.syncLog.deleteMany({ where: { userId } });
    await transaction.hardDeleteTombstone.deleteMany({ where: { userId } });

    // deleteMany is deliberate: a retry after a partial external failure must
    // remain successful even when the User row was deleted by the first call.
    await transaction.user.deleteMany({ where: { id: userId } });
  });
}

export async function logSyncChange(params: {
  userId: string;
  entityType: "note" | "tag";
  entityId: string;
  version: number;
  serverUpdatedAt: Date;
  operation: "upsert" | "delete" | "hard_delete";
}, database: SyncDatabase = prisma): Promise<void> {
  await database.syncLog.create({
    data: {
      userId: params.userId,
      entityType: params.entityType,
      entityId: params.entityId,
      version: params.version,
      serverUpdatedAt: params.serverUpdatedAt,
      operation: params.operation
    }
  });
}
