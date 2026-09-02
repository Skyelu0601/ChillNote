package com.sponteoai.chillscript.billing

import android.content.Context
import android.util.Log
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.sponteoai.chillscript.BuildConfig

object RevenueCatService {
    private const val TAG = "RevenueCatService"

    fun configure(context: Context) {
        if (Purchases.isConfigured) return
        val apiKey = BuildConfig.REVENUECAT_ANDROID_API_KEY.trim()
        if (!apiKey.startsWith("goog_") || apiKey.contains("REPLACE", ignoreCase = true)) {
            Log.i(TAG, "RevenueCat is disabled because its Google public SDK key is missing")
            return
        }

        if (BuildConfig.DEBUG) Purchases.logLevel = LogLevel.DEBUG
        Purchases.configure(
            PurchasesConfiguration.Builder(context.applicationContext, apiKey).build(),
        )
    }

    val isConfigured: Boolean
        get() = Purchases.isConfigured
}
