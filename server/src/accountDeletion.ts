export interface AccountDeletionRequest {
  userId?: string;
}

export interface AccountDeletionResponse {
  status(code: number): AccountDeletionResponse;
  json(body: unknown): unknown;
}

export interface AccountDeletionLogger {
  error(...values: unknown[]): void;
  log(...values: unknown[]): void;
}

export interface AccountDeletionDependencies {
  deleteBusinessData(userId: string): Promise<void>;
  deleteAuthUser(userId: string): Promise<{ error: unknown | null }>;
  onBusinessDataDeleted?(userId: string): void;
  logger?: AccountDeletionLogger;
}

const failureBody = (code: "ACCOUNT_DATA_DELETE_FAILED" | "ACCOUNT_AUTH_DELETE_FAILED") => ({
  error: "Failed to delete account",
  code,
  retryable: true
});

export async function handleAccountDeletion(
  request: AccountDeletionRequest,
  response: AccountDeletionResponse,
  dependencies: AccountDeletionDependencies
): Promise<void> {
  const userId = request.userId;
  const logger = dependencies.logger ?? console;

  if (!userId) {
    response.status(401).json({ error: "Unauthorized" });
    return;
  }

  try {
    // Delete database data first. If the external Auth deletion then fails,
    // the still-valid session can call this endpoint again; database deletion
    // is transactional and idempotent, so that retry is safe.
    await dependencies.deleteBusinessData(userId);
  } catch (error) {
    logger.error(`❌ [Backend] Failed to delete business data for user ${userId}:`, error);
    response.status(500).json(failureBody("ACCOUNT_DATA_DELETE_FAILED"));
    return;
  }

  try {
    dependencies.onBusinessDataDeleted?.(userId);
  } catch (error) {
    // Cache cleanup must never turn an otherwise retryable deletion into an
    // unrecoverable state. The persistent business data is already gone.
    logger.error(`⚠️ [Backend] Failed to clear deleted-user cache ${userId}:`, error);
  }

  let authError: unknown | null = null;
  try {
    const result = await dependencies.deleteAuthUser(userId);
    authError = result.error;
  } catch (error) {
    authError = error;
  }

  if (authError) {
    logger.error(`❌ [Backend] Failed to delete Supabase Auth user ${userId}:`, authError);
    response.status(502).json(failureBody("ACCOUNT_AUTH_DELETE_FAILED"));
    return;
  }

  logger.log(`🗑️ [Backend] Deleted user account: ${userId}`);
  response.json({ success: true });
}
