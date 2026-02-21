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
};

export type SyncPayload = {
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
