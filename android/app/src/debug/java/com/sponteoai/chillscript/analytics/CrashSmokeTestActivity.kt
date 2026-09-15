package com.sponteoai.chillscript.analytics

import android.app.Activity
import android.os.Bundle
import android.os.Handler
import android.os.Looper

/** Launch explicitly on an emulator, wait for a fatal crash, then reopen the normal main activity. */
class CrashSmokeTestActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Handler(Looper.getMainLooper()).postDelayed({
            throw IllegalStateException("PostHog crash smoke test")
        }, 10_000)
    }
}
