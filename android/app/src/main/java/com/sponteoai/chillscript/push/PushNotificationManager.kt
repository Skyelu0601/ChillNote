package com.sponteoai.chillscript.push

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.google.android.gms.tasks.Task
import com.google.firebase.installations.FirebaseInstallations
import com.google.firebase.messaging.FirebaseMessaging
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.auth.AuthRepository
import kotlinx.coroutines.suspendCancellableCoroutine
import java.util.Locale
import java.util.TimeZone
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

sealed interface PushRegistrationResult {
    data object Disabled : PushRegistrationResult
    data object PermissionRequired : PushRegistrationResult
    data object Registered : PushRegistrationResult
    data object UpToDate : PushRegistrationResult
    data object RetryPending : PushRegistrationResult
    data object Failed : PushRegistrationResult
}

class PushNotificationManager private constructor(
    private val context: Context,
    private val api: PushDeviceDataSource,
) {
    private val preferences = PushRegistrationPreferences(context)

    fun initialize() {
        createNotificationChannel(context)
        FirebasePushConfiguration.messagingOrNull(context)
    }

    suspend fun refreshRegistration(
        userId: String,
        accessToken: String,
        enqueueRetry: Boolean = true,
    ): PushRegistrationResult {
        val messaging = FirebasePushConfiguration.messagingOrNull(context)
        val initial = decidePushRegistration(snapshot(userId, messaging != null))
        when (initial) {
            PushRegistrationDecision.Disabled -> return PushRegistrationResult.Disabled
            PushRegistrationDecision.AwaitPermission -> return PushRegistrationResult.PermissionRequired
            PushRegistrationDecision.UpToDate -> return PushRegistrationResult.UpToDate
            is PushRegistrationDecision.Register -> return registerToken(
                userId,
                accessToken,
                initial.token,
                enqueueRetry,
            )
            PushRegistrationDecision.FetchToken -> Unit
        }

        checkNotNull(messaging)
        messaging.isAutoInitEnabled = true
        val installationId = try {
            messaging.register().awaitCompletion()
            FirebaseInstallations.getInstance().id.awaitValue()
        } catch (_: Exception) {
            if (enqueueRetry) enqueueRegistration(context)
            return PushRegistrationResult.RetryPending
        }
        preferences.setCurrentToken(installationId)
        return registerToken(userId, accessToken, installationId, enqueueRetry)
    }

    suspend fun deactivate(accessToken: String) {
        val token = preferences.currentToken ?: return
        api.deactivate(accessToken, token)
        preferences.clear()
        FirebasePushConfiguration.messagingOrNull(context)?.let { messaging ->
            messaging.isAutoInitEnabled = false
            runCatching { messaging.unregister().awaitCompletion() }
        }
    }

    suspend fun clearLocalRegistration() {
        preferences.clear()
        FirebasePushConfiguration.messagingOrNull(context)?.let { messaging ->
            messaging.isAutoInitEnabled = false
            runCatching { messaging.unregister().awaitCompletion() }
        }
    }

    fun recordRegistration(installationId: String) {
        runCatching { validateDeviceToken(installationId) }.getOrElse { return }
        preferences.setCurrentToken(installationId)
        enqueueRegistration(context)
    }

    private suspend fun registerToken(
        userId: String,
        accessToken: String,
        token: String,
        enqueueRetry: Boolean,
    ): PushRegistrationResult = try {
        api.register(
            accessToken = accessToken,
            payload = PushDeviceRegistrationPayload(
                token = token,
                locale = Locale.getDefault().toLanguageTag().ifBlank { "en" },
                timeZone = TimeZone.getDefault().id.ifBlank { "UTC" },
                authorizationStatus = "authorized",
            ),
        )
        preferences.markRegistered(token, userId)
        PushRegistrationResult.Registered
    } catch (error: PushDeviceApiException) {
        if (error.reason.retryable) {
            if (enqueueRetry) enqueueRegistration(context)
            PushRegistrationResult.RetryPending
        } else {
            PushRegistrationResult.Failed
        }
    } catch (_: Exception) {
        if (enqueueRetry) enqueueRegistration(context)
        PushRegistrationResult.RetryPending
    }

    private fun snapshot(userId: String, configured: Boolean) = PushRegistrationSnapshot(
        firebaseConfigured = configured,
        permissionGranted = hasNotificationPermission(context),
        currentToken = preferences.currentToken,
        registeredToken = preferences.registeredToken,
        registeredUserId = preferences.registeredUserId,
        currentUserId = userId,
    )

    companion object {
        @Volatile private var instance: PushNotificationManager? = null

        fun get(context: Context): PushNotificationManager = instance ?: synchronized(this) {
            instance ?: PushNotificationManager(
                context = context.applicationContext,
                api = PushDeviceApi(),
            ).also { instance = it }
        }

        fun createNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val channel = NotificationChannel(
                PushContract.CHANNEL_ID,
                context.getString(R.string.notification_channel_updates_name),
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = context.getString(R.string.notification_channel_updates_description)
            }
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }

        fun hasNotificationPermission(context: Context): Boolean =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.POST_NOTIFICATIONS,
                ) == PackageManager.PERMISSION_GRANTED

        fun isFirebaseConfigured(): Boolean = FirebasePushConfiguration.isConfigured()

        internal fun enqueueRegistration(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()
            val request = OneTimeWorkRequestBuilder<PushTokenRegistrationWorker>()
                .setConstraints(constraints)
                .build()
            WorkManager.getInstance(context.applicationContext).enqueueUniqueWork(
                REGISTRATION_WORK,
                ExistingWorkPolicy.REPLACE,
                request,
            )
        }

        private const val REGISTRATION_WORK = "push-token-registration"
    }
}

class PushTokenRegistrationWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        val session = AuthRepository(applicationContext).restoreSession() ?: return Result.success()
        return when (
            PushNotificationManager.get(applicationContext).refreshRegistration(
                userId = session.user.id,
                accessToken = session.accessToken,
                enqueueRetry = false,
            )
        ) {
            PushRegistrationResult.RetryPending -> Result.retry()
            else -> Result.success()
        }
    }
}

private class PushRegistrationPreferences(context: Context) {
    private val preferences = context.getSharedPreferences(FILE_NAME, Context.MODE_PRIVATE)

    val currentToken: String? get() = preferences.getString(KEY_CURRENT_TOKEN, null)
    val registeredToken: String? get() = preferences.getString(KEY_REGISTERED_TOKEN, null)
    val registeredUserId: String? get() = preferences.getString(KEY_REGISTERED_USER, null)

    fun setCurrentToken(token: String) {
        preferences.edit()
            .putString(KEY_CURRENT_TOKEN, token)
            .remove(KEY_REGISTERED_TOKEN)
            .remove(KEY_REGISTERED_USER)
            .apply()
    }

    fun markRegistered(token: String, userId: String) {
        preferences.edit()
            .putString(KEY_CURRENT_TOKEN, token)
            .putString(KEY_REGISTERED_TOKEN, token)
            .putString(KEY_REGISTERED_USER, userId)
            .apply()
    }

    fun clear() {
        preferences.edit().clear().apply()
    }

    private companion object {
        const val FILE_NAME = "push_registration"
        const val KEY_CURRENT_TOKEN = "current_token"
        const val KEY_REGISTERED_TOKEN = "registered_token"
        const val KEY_REGISTERED_USER = "registered_user"
    }
}

private suspend fun <T> Task<T>.awaitValue(): T = suspendCancellableCoroutine { continuation ->
    addOnCompleteListener { task ->
        if (!continuation.isActive) return@addOnCompleteListener
        val error = task.exception
        if (task.isSuccessful && error == null) continuation.resume(task.result)
        else continuation.resumeWithException(error ?: IllegalStateException("Firebase task failed"))
    }
}

private suspend fun Task<*>.awaitCompletion(): Unit = suspendCancellableCoroutine { continuation ->
    addOnCompleteListener { task ->
        if (!continuation.isActive) return@addOnCompleteListener
        val error = task.exception
        if (task.isSuccessful && error == null) continuation.resume(Unit)
        else continuation.resumeWithException(error ?: IllegalStateException("Firebase task failed"))
    }
}
