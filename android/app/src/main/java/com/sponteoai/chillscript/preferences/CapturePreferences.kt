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

    fun updateMediaSections(next: MediaLinkSectionsDto) {
        val normalized = if (listOf(next.showDescription, next.showAuthor, next.showHook, next.showTranscript).none { it }) {
            MediaLinkSectionsDto()
        } else next
        preferences.edit()
            .putBoolean(KEY_DESCRIPTION, normalized.showDescription)
            .putBoolean(KEY_AUTHOR, normalized.showAuthor)
            .putBoolean(KEY_HOOK, normalized.showHook)
            .putBoolean(KEY_TRANSCRIPT, normalized.showTranscript)
            .apply()
        mutableMediaSections.value = normalized
    }

    private fun loadVoice() = VoiceLanguageSettings(
        mode = preferences.getString(KEY_VOICE_MODE, "auto") ?: "auto",
        languageHint = preferences.getString(KEY_VOICE_HINT, "") ?: "",
    )

    private fun loadMediaSections(): MediaLinkSectionsDto {
        val loaded = MediaLinkSectionsDto(
            showDescription = preferences.getBoolean(KEY_DESCRIPTION, true),
            showAuthor = preferences.getBoolean(KEY_AUTHOR, true),
            showHook = preferences.getBoolean(KEY_HOOK, true),
            showTranscript = preferences.getBoolean(KEY_TRANSCRIPT, true),
        )
        return if (listOf(loaded.showDescription, loaded.showAuthor, loaded.showHook, loaded.showTranscript).none { it }) {
            MediaLinkSectionsDto()
        } else loaded
    }

    private companion object {
        const val KEY_VOICE_MODE = "voice_language_mode"
        const val KEY_VOICE_HINT = "voice_language_hint"
        const val KEY_DESCRIPTION = "media_link_show_description"
        const val KEY_AUTHOR = "media_link_show_author"
        const val KEY_HOOK = "media_link_show_hook"
        const val KEY_TRANSCRIPT = "media_link_show_transcript"
    }
}
