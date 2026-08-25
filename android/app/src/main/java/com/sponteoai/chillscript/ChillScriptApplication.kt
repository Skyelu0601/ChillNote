package com.sponteoai.chillscript

import android.app.Application
import com.sponteoai.chillscript.push.PushNotificationManager

class ChillScriptApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        PushNotificationManager.get(this).initialize()
    }
}
