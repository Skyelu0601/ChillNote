export type NoteDTO = {
  id: string;
  content: string;
  createdAt: string;
  updatedAt: string;
  deletedAt?: string | null;
  tagIds?: string[] | null;
};

export type TagDTO = {
  id: string;
  name: string;
  colorHex: string;
  createdAt: string;
  updatedAt: string;
  lastUsedAt?: string | null;
  sortOrder: number;
  parentId?: string | null;
  deletedAt?: string | null;
};

export type SyncPayload = {
  notes: NoteDTO[];
  tags?: TagDTO[] | null;
  preferences?: Record<string, string> | null;
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
