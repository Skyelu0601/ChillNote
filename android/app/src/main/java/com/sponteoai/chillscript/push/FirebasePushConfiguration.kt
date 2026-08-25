package com.sponteoai.chillscript.push

import android.content.Context
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import com.sponteoai.chillscript.BuildConfig
import java.util.concurrent.atomic.AtomicBoolean

internal object FirebasePushConfiguration {
    private val loggedMissingConfiguration = AtomicBoolean(false)

    fun isConfigured(): Boolean = requiredValues().all(String::isNotBlank)

    @Synchronized
    fun messagingOrNull(context: Context): FirebaseMessaging? {
        if (!isConfigured()) {
            if (loggedMissingConfiguration.compareAndSet(false, true)) {
                Log.i(TAG, "Firebase push configuration is absent; notifications are disabled")
            }
            return null
        }
        return runCatching {
            val appContext = context.applicationContext
            val existing = FirebaseApp.getApps(appContext)
                .firstOrNull { it.name == FirebaseApp.DEFAULT_APP_NAME }
            if (existing == null) {
                val options = FirebaseOptions.Builder()
                    .setApiKey(BuildConfig.FIREBASE_API_KEY)
                    .setApplicationId(BuildConfig.FIREBASE_APP_ID)
                    .setProjectId(BuildConfig.FIREBASE_PROJECT_ID)
                    .setGcmSenderId(BuildConfig.FIREBASE_SENDER_ID)
                    .build()
                FirebaseApp.initializeApp(appContext, options)
            }
            FirebaseMessaging.getInstance()
        }.onFailure { error ->
            Log.w(TAG, "Firebase push initialization failed; notifications remain disabled", error)
        }.getOrNull()
    }

    private fun requiredValues(): List<String> = listOf(
        BuildConfig.FIREBASE_API_KEY,
        BuildConfig.FIREBASE_APP_ID,
        BuildConfig.FIREBASE_PROJECT_ID,
        BuildConfig.FIREBASE_SENDER_ID,
    )

    private const val TAG = "FirebasePushConfig"
}
