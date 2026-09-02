package com.sponteoai.chillscript

import android.app.Application
import com.sponteoai.chillscript.billing.RevenueCatService
import com.sponteoai.chillscript.push.PushNotificationManager

class ChillScriptApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        RevenueCatService.configure(this)
        PushNotificationManager.get(this).initialize()
    }
}
