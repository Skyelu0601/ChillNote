package com.sponteoai.chillscript.analytics

import android.content.Context
import com.posthog.PostHog
import com.posthog.android.PostHogAndroid
import com.posthog.android.PostHogAndroidConfig
import com.sponteoai.chillscript.BuildConfig

/** Product metadata only: never capture note content, URLs, email, audio, or error messages. */
object ProductAnalytics {
    data class PurchaseAttribution(
        val placement: String,
        val paywallViewId: String,
        val purchaseAttemptId: String,
        val planId: String,
    ) {
        fun analyticsProperties(): Map<String, Any> = mapOf(
            "paywall_placement" to placement,
            "paywall_view_id" to paywallViewId,
            "purchase_attempt_id" to purchaseAttemptId,
            "plan_id" to planId,
        )

        fun revenueCatAttributes(): Map<String, String> = mapOf(
            "paywall_placement" to placement,
            "paywall_view_id" to paywallViewId,
            "purchase_attempt_id" to purchaseAttemptId,
        )
    }

    private var configured = false
    private var preferences: android.content.SharedPreferences? = null
    private const val FirstOpenKey = "first_open_captured"
    private const val CompletedOperationsKey = "completed_operations"
    private var pendingPurchase: PurchaseAttribution? = null

    @Synchronized
    fun configure(context: Context) {
        if (configured) return
        preferences = context.getSharedPreferences("product_analytics", Context.MODE_PRIVATE)
        // Reuse the analytics identity until background session restoration completes.
        // Reading AndroidKeyStore here would block Application.onCreate before the first frame.
        val userId = preferences?.getString("user_id", null)
        // Public ingestion token, not a personal/admin API key.
        val config = PostHogAndroidConfig(
            apiKey = "phc_pYcofJNTakcLUaB2pC6jAEDyiz53CVkoULFu6SpAeWkM",
            host = "https://us.i.posthog.com",
        ).apply {
            captureApplicationLifecycleEvents = true
            captureScreenViews = false
            captureDeepLinks = false
            capturePushNotificationSubscriptions = false
            capturePushNotificationOpened = false
            sessionReplay = false
            preloadFeatureFlags = false
            surveys = false
            errorTrackingConfig.autoCapture = true
            errorTrackingConfig.captureNativeCrashes = true
            // Breadcrumbs can contain business-event properties; keep crash reports to stack metadata.
            errorTrackingConfig.exceptionSteps.enabled = false
            addBeforeSend(com.posthog.PostHogBeforeSend { event ->
                event.properties?.put("platform", "android")
                event.properties?.put("schema_version", 1)
                event.properties?.put("environment", if (BuildConfig.DEBUG) "development" else "production")
                event.properties?.put("\$geoip_disable", true)
                if (event.event == "\$exception") {
                    val sanitized = CrashEventSanitizer.sanitize(event.properties.orEmpty())
                    event.properties?.clear()
                    event.properties?.putAll(sanitized)
                }
                event
            })
        }
        PostHogAndroid.setup(context.applicationContext, config)
        configured = true
        synchronizeUser(userId)
        capture("app_session_started", mapOf("surface" to "main_app"))
        if (preferences?.getBoolean(FirstOpenKey, false) != true) {
            val existingInstall = context.getSharedPreferences("onboarding_state", Context.MODE_PRIVATE)
                .getBoolean("intro_viewed_on_device", false) || userId != null
            if (!existingInstall) {
                capture("app_first_opened", mapOf("surface" to "main_app"))
            }
            preferences?.edit()?.putBoolean(FirstOpenKey, true)?.apply()
        }
    }

    @Synchronized
    fun synchronizeUser(userId: String?) {
        if (!configured) return
        val normalizedId = userId?.lowercase(java.util.Locale.ROOT)
        val previousId = preferences?.getString("user_id", null)
        if (previousId != null && previousId != normalizedId) PostHog.reset()
        if (normalizedId != null) PostHog.identify(normalizedId)
        preferences?.edit()?.putString("user_id", normalizedId)?.apply()
    }

    fun capture(event: String, properties: Map<String, Any> = emptyMap()) {
        if (!configured) return
        PostHog.capture(event, properties = properties)
    }

    @Synchronized
    fun captureCreationCompleted(
        operationId: String,
        type: String,
        entryPoint: String,
        properties: Map<String, Any> = emptyMap(),
    ) {
        if (!configured) return
        val completed = preferences?.getStringSet(CompletedOperationsKey, emptySet()).orEmpty().toMutableSet()
        if (!completed.add(operationId)) return
        preferences?.edit()
            ?.putStringSet(CompletedOperationsKey, completed.toList().takeLast(250).toSet())
            ?.apply()
        capture(
            "creation_completed",
            properties + mapOf(
                "operation_id" to operationId,
                "creation_type" to type,
                "entry_point" to entryPoint,
                "surface" to "main_app",
            ),
        )
    }

    @Synchronized
    fun beginPurchase(placement: String, paywallViewId: String, planId: String) {
        pendingPurchase = PurchaseAttribution(
            placement = placement,
            paywallViewId = paywallViewId,
            purchaseAttemptId = java.util.UUID.randomUUID().toString(),
            planId = planId,
        )
        capture("purchase_started", pendingPurchase?.analyticsProperties().orEmpty())
    }

    @Synchronized
    fun currentRevenueCatPurchaseAttributes(): Map<String, String> {
        return pendingPurchase?.revenueCatAttributes().orEmpty()
    }

    @Synchronized
    fun completePurchase(
        event: String,
        errorCode: String? = null,
        billingProvider: String? = null,
        billingErrorCode: String? = null,
        billingStage: String? = null,
    ) {
        val attempt = pendingPurchase ?: return
        val properties = attempt.analyticsProperties() +
            if (errorCode == null) emptyMap() else mapOf("error_code" to errorCode)
        // Only SDK enum names/numeric codes, never debug messages, receipts or purchase tokens.
        val diagnostics = mapOf(
            "billing_provider" to billingProvider,
            "billing_error_code" to billingErrorCode,
            "billing_stage" to billingStage,
        ).mapNotNull { (key, value) -> value?.let { key to it } }.toMap()
        capture(event, properties + diagnostics)
        pendingPurchase = null
    }
}
