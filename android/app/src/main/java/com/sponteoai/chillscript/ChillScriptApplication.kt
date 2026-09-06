package com.sponteoai.chillscript

import android.app.Application
import com.sponteoai.chillscript.billing.RevenueCatService
import com.sponteoai.chillscript.push.PushNotificationManager

class ChillScriptApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        com.sponteoai.chillscript.analytics.ProductAnalytics.configure(
            this, com.sponteoai.chillscript.auth.AuthRepository(this).restoreSession()?.user?.id
        )
        RevenueCatService.configure(this)
        PushNotificationManager.get(this).initialize()
    }
}
