export type NoteDTO = {
  id: string;
  content: string;
  createdAt: string;
  updatedAt: string;
  deletedAt?: string | null;
};

export type SyncPayload = {
  notes: NoteDTO[];
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
