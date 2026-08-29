export type NoteDTO = {
  id: string;
  content: string;
  createdAt: string;
  updatedAt?: string | null;
  deletedAt?: string | null;
  pinnedAt?: string | null;
  tagIds?: string[] | null;
  version?: number | null;
  baseVersion?: number | null;
  clientUpdatedAt?: string | null;
  lastModifiedByDeviceId?: string | null;
  mutationId?: string | null;
  previousMutationId?: string | null;
  sourceURL?: string | null;
  sourceTitle?: string | null;
  sourcePlatformID?: string | null;
  sourcePlatformName?: string | null;
  sourceHost?: string | null;
  sourceAuthorName?: string | null;
  sourceAuthorHandle?: string | null;
  sourceCapturedAt?: string | null;
  section?: string | null;
  importStatus?: string | null;
  importJobId?: string | null;
  importErrorCode?: string | null;
  importStartedAt?: string | null;
  importCompletedAt?: string | null;
};

export type TagDTO = {
  id: string;
  name: string;
  colorHex: string;
  createdAt: string;
  updatedAt?: string | null;
  lastUsedAt?: string | null;
  sortOrder: number;
  parentId?: string | null;
  deletedAt?: string | null;
  version?: number | null;
  baseVersion?: number | null;
  clientUpdatedAt?: string | null;
  lastModifiedByDeviceId?: string | null;
  mutationId?: string | null;
  previousMutationId?: string | null;
};

export type SyncPayload = {
  protocolVersion?: number | null;
  cursor?: string | null;
  deviceId?: string | null;
  notes: NoteDTO[];
  tags?: TagDTO[] | null;
  hardDeletedNoteIds?: string[] | null;
  hardDeletedTagIds?: string[] | null;
  preferences?: Record<string, string> | null;
};

export type SyncChanges = {
  notes: NoteDTO[];
  tags?: TagDTO[] | null;
  hardDeletedNoteIds?: string[] | null;
  hardDeletedTagIds?: string[] | null;
  preferences?: Record<string, string> | null;
};

export type ConflictDTO = {
  entityType: "note" | "tag";
  id: string;
  serverVersion: number;
  serverContent?: string | null;
  clientContent?: string | null;
  message: string;
};

export type SyncResponse = {
  cursor: string;
  changes: SyncChanges;
  conflicts: ConflictDTO[];
  /**
   * The server intentionally rejected these uploaded values and returned its
   * authoritative row in `changes`. Clients must apply that row even when its
   * version/timestamp equals their local copy (for example a completed import
   * that an old queued upload attempted to restore).
   */
  forcedNoteIds?: string[];
  forcedTagIds?: string[];
  serverTime: string;
};

export type AuthAppleRequest = {
  userId: string;
  identityToken: string;
  authorizationCode: string;
};

export type AuthTokens = {
  userId: string;
  accessToken: string;
  refreshToken: string;
};
