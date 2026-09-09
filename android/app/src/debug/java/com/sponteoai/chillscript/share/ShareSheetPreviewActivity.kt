package com.sponteoai.chillscript.share

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.core.view.WindowCompat
import com.sponteoai.chillscript.MainActivity
import com.sponteoai.chillscript.ui.theme.ChillScriptTheme

/** Renders the production share sheet without creating an import. Debug builds only. */
class ShareSheetPreviewActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        val state = when (intent.getStringExtra("state")) {
            "working" -> ShareOverlayState.Working(ShareLinkImportStage.Saving)
            "failure" -> ShareOverlayState.Failure
            "credits" -> ShareOverlayState.CreditsRequired
            else -> ShareOverlayState.Success("TikTok")
        }
        setContent {
            ChillScriptTheme {
                ShareImportSheet(
                    sourceName = "TikTok",
                    state = state,
                    onOpenApp = {
                        startActivity(Intent(this, MainActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        })
                        finish()
                    },
                    onComplete = ::finish,
                )
            }
        }
    }
}
