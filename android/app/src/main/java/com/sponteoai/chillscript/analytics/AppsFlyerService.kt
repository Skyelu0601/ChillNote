package com.sponteoai.chillscript.analytics

import android.content.Context
import android.util.Log
import com.appsflyer.AppsFlyerLib
import com.appsflyer.share.AppsFlyerConversionListener
import com.revenuecat.purchases.Purchases
import com.sponteoai.chillscript.BuildConfig

data class AppsFlyerInstallAttribution(
    val mediaSource: String?,
    val campaign: String?,
    val adGroup: String?,
    val ad: String?,
) {
    companion object {
        fun from(conversionData: Map<String, Any>): AppsFlyerInstallAttribution =
            AppsFlyerInstallAttribution(
                mediaSource = conversionData.stringValue("media_source"),
                campaign = conversionData.stringValue("campaign"),
                adGroup = conversionData.stringValue("af_adset"),
                ad = conversionData.stringValue("af_ad"),
            )

        private fun Map<String, Any>.stringValue(key: String): String? =
            get(key)?.toString()?.trim()?.takeIf(String::isNotEmpty)
    }
}

object AppsFlyerService {
    private const val TAG = "AppsFlyerService"
    private var isConfigured = false

    fun configure(context: Context) {
        if (isConfigured) return
        val devKey = BuildConfig.APPSFLYER_DEV_KEY.trim()
        if (devKey.isEmpty() || devKey.contains("REPLACE", ignoreCase = true)) {
            Log.i(TAG, "AppsFlyer is disabled because its developer key is missing")
            return
        }

        val appContext = context.applicationContext
        val listener = object : AppsFlyerConversionListener {
            override fun onConversionDataSuccess(conversionData: Map<String, Any>) {
                val data = conversionData
                val attribution = if (
                    data["af_status"]?.toString().equals("Non-organic", ignoreCase = true)
                ) {
                    AppsFlyerInstallAttribution.from(data)
                } else {
                    null
                }
                syncRevenueCat(appContext, attribution)
            }

            override fun onConversionDataFail(errorMessage: String) {
                Log.w(TAG, "AppsFlyer conversion data failed: $errorMessage")
                syncRevenueCat(appContext, null)
            }
        }

        val appsFlyer = AppsFlyerLib.getInstance()
        appsFlyer.init(devKey, listener, appContext)
        if (BuildConfig.DEBUG) appsFlyer.setDebugLog(true)
        appsFlyer.registerSessionReadyListener {
            appsFlyer.start()
            syncRevenueCat(appContext, null)
        }
        isConfigured = true
    }

    fun identify(context: Context, userID: String?) {
        if (!isConfigured || userID.isNullOrBlank()) return
        AppsFlyerLib.getInstance().setCustomerUserId(userID.lowercase())
        syncRevenueCat(context.applicationContext, null)
    }

    private fun syncRevenueCat(
        context: Context,
        attribution: AppsFlyerInstallAttribution?,
    ) {
        if (!Purchases.isConfigured) return
        val purchases = Purchases.sharedInstance
        purchases.collectDeviceIdentifiers()
        AppsFlyerLib.getInstance().getAppsFlyerUID(context)
            ?.takeIf(String::isNotBlank)
            ?.let(purchases::setAppsflyerID)
        attribution?.mediaSource?.let(purchases::setMediaSource)
        attribution?.campaign?.let(purchases::setCampaign)
        attribution?.adGroup?.let(purchases::setAdGroup)
        attribution?.ad?.let(purchases::setAd)
    }
}
