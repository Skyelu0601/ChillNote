package com.sponteoai.chillscript.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color

private val LightColors = lightColorScheme(
    primary = Color(0xFF368F85),
    onPrimary = Color.White,
    background = Color(0xFFF7F8F4),
    onBackground = Color(0xFF17211F),
    surface = Color(0xFFFFFFFF),
    onSurface = Color(0xFF17211F),
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFF78C8BE),
    background = Color(0xFF101615),
    surface = Color(0xFF17211F),
)

@Composable
fun ChillScriptTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = if (isSystemInDarkTheme()) DarkColors else LightColors) {
        Surface(
            modifier = Modifier.fillMaxSize(),
            color = MaterialTheme.colorScheme.background,
            contentColor = MaterialTheme.colorScheme.onBackground,
            content = content,
        )
    }
}
