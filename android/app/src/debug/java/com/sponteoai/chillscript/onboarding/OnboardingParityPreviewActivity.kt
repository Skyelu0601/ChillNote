package com.sponteoai.chillscript.onboarding

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent

/** Debug-only visual QA host. It is not packaged in release builds. */
class OnboardingParityPreviewActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            IOSParityOnboardingScreen(
                onFinish = ::finish,
                onLogIn = ::finish,
                initialPage = intent.getIntExtra("initial_page", 0),
            )
        }
    }
}
