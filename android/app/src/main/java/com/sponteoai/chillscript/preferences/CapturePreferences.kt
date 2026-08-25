package com.sponteoai.chillscript.preferences

import android.content.Context
import com.sponteoai.chillscript.data.remote.MediaLinkSectionsDto
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class VoiceLanguageSettings(val mode: String = "auto", val languageHint: String = "")

class CapturePreferences(context: Context) {
    private val preferences = context.getSharedPreferences("capture_preferences", Context.MODE_PRIVATE)
    private val mutableVoice = MutableStateFlow(loadVoice())
    val voice: StateFlow<VoiceLanguageSettings> = mutableVoice.asStateFlow()
    private val mutableMediaSections = MutableStateFlow(loadMediaSections())
    val mediaSections: StateFlow<MediaLinkSectionsDto> = mutableMediaSections.asStateFlow()

    fun updateVoice(mode: String, languageHint: String) {
        val normalizedMode = if (mode == "prefer") "prefer" else "auto"
        val settings = VoiceLanguageSettings(normalizedMode, languageHint.trim())
        preferences.edit().putString(KEY_VOICE_MODE, settings.mode).putString(KEY_VOICE_HINT, settings.languageHint).apply()
        mutableVoice.value = settings
    }

    private fun loadVoice() = VoiceLanguageSettings(
        mode = preferences.getString(KEY_VOICE_MODE, "auto") ?: "auto",
        languageHint = preferences.getString(KEY_VOICE_HINT, "") ?: "",
    )

    private fun loadMediaSections(): MediaLinkSectionsDto = MediaLinkSectionsDto.TranscriptOnly

    private companion object {
        const val KEY_VOICE_MODE = "voice_language_mode"
        const val KEY_VOICE_HINT = "voice_language_hint"
    }
}
