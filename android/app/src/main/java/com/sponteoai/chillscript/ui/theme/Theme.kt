package com.sponteoai.chillscript.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color

private val LightColors = lightColorScheme(
    primary = ChillColors.BrandBlue,
    onPrimary = Color.White,
    primaryContainer = ChillColors.BrandBlueSoft,
    onPrimaryContainer = ChillColors.BrandBlueText,
    secondary = ChillColors.BrandTeal,
    onSecondary = Color.White,
    secondaryContainer = ChillColors.BrandTealSoft,
    onSecondaryContainer = ChillColors.BrandTealText,
    tertiary = ChillColors.BrandHoney,
    onTertiary = Color.White,
    tertiaryContainer = ChillColors.BrandHoneySoft,
    onTertiaryContainer = ChillColors.BrandHoneyText,
    background = ChillColors.BackgroundPrimary,
    onBackground = ChillColors.TextMain,
    surface = ChillColors.BackgroundSecondary,
    onSurface = ChillColors.TextMain,
    surfaceVariant = ChillColors.BrandBlueSoft,
    onSurfaceVariant = ChillColors.TextSub,
    outline = ChillColors.BorderSubtle,
    outlineVariant = ChillColors.Separator,
)

@Composable
fun ChillScriptTheme(content: @Composable () -> Unit) {
    // The current iOS source uses a fixed warm-light palette. Android stays on
    // that same palette until iOS defines a complete dark appearance.
    MaterialTheme(
        colorScheme = LightColors,
        typography = ChillTypography,
    ) {
        Surface(
            modifier = Modifier.fillMaxSize(),
            color = MaterialTheme.colorScheme.background,
            contentColor = MaterialTheme.colorScheme.onBackground,
            content = content,
        )
    }
}
