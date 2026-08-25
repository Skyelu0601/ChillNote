package com.sponteoai.chillscript.sync

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.sponteoai.chillscript.auth.AuthException
import com.sponteoai.chillscript.auth.AuthRepository
import com.sponteoai.chillscript.auth.AuthSession
import com.sponteoai.chillscript.auth.AuthSessionUnavailableException
import com.sponteoai.chillscript.data.NotesRepository
import com.sponteoai.chillscript.data.local.ChillScriptDatabase
import com.sponteoai.chillscript.data.remote.SyncApi
import com.sponteoai.chillscript.data.remote.SyncHttpException
import kotlinx.coroutines.CancellationException
import java.io.IOException

internal enum class BackgroundSyncFailureDisposition {
    RETRY,
    AUTH_REJECTED,
    FAILURE,
}

internal fun classifyBackgroundSyncFailure(error: Throwable): BackgroundSyncFailureDisposition {
    var current: Throwable? = error
    while (current != null) {
        when (current) {
            is AuthSessionUnavailableException -> return BackgroundSyncFailureDisposition.AUTH_REJECTED
            is AuthException -> return when {
                current.statusCode in setOf(400, 401, 403) -> BackgroundSyncFailureDisposition.AUTH_REJECTED
                current.statusCode.isTransientHttpStatus() -> BackgroundSyncFailureDisposition.RETRY
                else -> BackgroundSyncFailureDisposition.FAILURE
            }
            is SyncHttpException -> return when {
                current.statusCode in setOf(401, 403) -> BackgroundSyncFailureDisposition.AUTH_REJECTED
                current.statusCode.isTransientHttpStatus() -> BackgroundSyncFailureDisposition.RETRY
                else -> BackgroundSyncFailureDisposition.FAILURE
            }
            is IOException -> return BackgroundSyncFailureDisposition.RETRY
        }
        current = current.cause?.takeUnless { it === current }
    }
    return BackgroundSyncFailureDisposition.FAILURE
}

internal fun shouldRefreshBackgroundSession(
    session: AuthSession,
    nowEpochSeconds: Long,
    refreshLeewaySeconds: Long = 5 * 60L,
): Boolean = session.expiresAt?.let { it - nowEpochSeconds <= refreshLeewaySeconds } ?: true

internal fun shouldRetryPendingLinkImport(hasPendingImport: Boolean, runAttemptCount: Int): Boolean =
    hasPendingImport && runAttemptCount < MAX_PENDING_IMPORT_RETRIES

class BackgroundSyncWorker(
    appContext: Context,
    workerParameters: WorkerParameters,
) : CoroutineWorker(appContext, workerParameters) {
    override suspend fun doWork(): Result {
        val authRepository = AuthRepository(applicationContext)
        val restoredSession = authRepository.restoreSession() ?: return Result.success()
        var session = try {
            if (shouldRefreshBackgroundSession(restoredSession, System.currentTimeMillis() / 1_000L)) {
                authRepository.refresh(restoredSession)
            } else {
                restoredSession
            }
        } catch (error: CancellationException) {
            throw error
        } catch (error: Throwable) {
            return failureResult(authRepository, error)
        }

        val dao = ChillScriptDatabase.get(applicationContext).dao()
        val notesRepository = NotesRepository(dao, SyncApi())
        var retriedAfterAuthRefresh = false
        while (true) {
            try {
                notesRepository.purgeExpiredTrash(session.user.id)
                notesRepository.sync(session.user.id, session.accessToken)
                break
            } catch (error: CancellationException) {
                throw error
            } catch (error: Throwable) {
                val isRejectedAccessToken = error is SyncHttpException && error.statusCode in setOf(401, 403)
                if (isRejectedAccessToken && !retriedAfterAuthRefresh) {
                    session = try {
                        authRepository.refresh(session)
                    } catch (refreshCancellation: CancellationException) {
                        throw refreshCancellation
                    } catch (refreshError: Throwable) {
                        return failureResult(authRepository, refreshError)
                    }
                    retriedAfterAuthRefresh = true
                    continue
                }
                return failureResult(authRepository, error)
            }
        }

        val hasPendingImport = dao.hasPendingLinkImports(session.user.id)
        return if (shouldRetryPendingLinkImport(hasPendingImport, runAttemptCount)) {
            Result.retry()
        } else {
            Result.success()
        }
    }

    private fun failureResult(authRepository: AuthRepository, error: Throwable): Result =
        when (classifyBackgroundSyncFailure(error)) {
            BackgroundSyncFailureDisposition.RETRY -> {
                Log.w(TAG, "Background sync will retry after a transient failure", error)
                Result.retry()
            }
            BackgroundSyncFailureDisposition.AUTH_REJECTED -> {
                Log.w(TAG, "Background sync stopped because the stored session was rejected")
                authRepository.signOut()
                Result.failure()
            }
            BackgroundSyncFailureDisposition.FAILURE -> {
                Log.w(TAG, "Background sync stopped after a permanent failure", error)
                Result.failure()
            }
        }

    private companion object {
        const val TAG = "BackgroundSyncWorker"
    }
}

private fun Int.isTransientHttpStatus(): Boolean = this in setOf(408, 425, 429) || this in 500..599

private const val MAX_PENDING_IMPORT_RETRIES = 4
