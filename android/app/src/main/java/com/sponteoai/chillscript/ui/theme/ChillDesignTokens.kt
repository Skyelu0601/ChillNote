package com.sponteoai.chillscript.ui.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material3.Typography

/**
 * Android mirror of iOS `Color+Chill.swift` and `BrandTokens.swift`.
 *
 * Keep these values one-to-one with iOS. New visual values belong in the iOS
 * design system first and should then be mirrored here, rather than invented
 * independently on Android.
 */
object ChillColors {
    val BrandBlue = Color(0xFF2F86FF)
    val BrandBlueText = Color(0xFF176BCB)
    val BrandBlueSoft = Color(0xFFEEF5FF)

    val BrandTeal = Color(0xFF258C86)
    val BrandTealText = Color(0xFF176F6A)
    val BrandTealSoft = Color(0xFFEAF4F2)

    val BrandHoney = Color(0xFFD89A3D)
    val BrandHoneyText = Color(0xFF8C5A10)
    val BrandHoneySoft = Color(0xFFFBF3E4)

    val BackgroundPrimary = Color(0xFFF6F5F2)
    val BackgroundSecondary = Color.White
    val CardBackground = Color.White
    val Separator = Color(0xFFE7E5E0)
    val BorderSubtle = Color(0xFFEBE9E4)
    val TextMain = Color(0xFF17181B)
    val TextSub = Color(0xFF6B6B73)
    val TextTertiary = Color(0xFF9A9AA3)
    val Shadow = Color(0x0F0B0B10)
}

object ChillSpacing {
    val S1 = 8.dp
    val S2 = 12.dp
    val S3 = 16.dp
    val S4 = 24.dp
    val S5 = 32.dp
    val S6 = 48.dp
}

object ChillRadius {
    val Button = 14.dp
    val Card = 20.dp
    val Pill = 999.dp
}

object ChillSizes {
    val PrimaryButtonHeight = 56.dp
    val SecondaryButtonHeight = 44.dp
}

val ChillTypography = Typography(
    displayLarge = TextStyle(
        fontSize = 34.sp,
        lineHeight = 41.sp,
        fontWeight = FontWeight.Bold,
    ),
    headlineLarge = TextStyle(
        fontSize = 28.sp,
        lineHeight = 34.sp,
        fontWeight = FontWeight.Bold,
    ),
    headlineMedium = TextStyle(
        fontSize = 22.sp,
        lineHeight = 27.sp,
        fontWeight = FontWeight.SemiBold,
    ),
    titleMedium = TextStyle(
        fontSize = 17.sp,
        lineHeight = 22.sp,
        fontWeight = FontWeight.SemiBold,
    ),
    bodyLarge = TextStyle(
        fontSize = 17.sp,
        lineHeight = 22.sp,
        fontWeight = FontWeight.Normal,
    ),
    bodyMedium = TextStyle(
        fontSize = 15.sp,
        lineHeight = 20.sp,
        fontWeight = FontWeight.Medium,
    ),
    labelLarge = TextStyle(
        fontSize = 17.sp,
        lineHeight = 22.sp,
        fontWeight = FontWeight.SemiBold,
    ),
    labelMedium = TextStyle(
        fontSize = 13.sp,
        lineHeight = 18.sp,
        fontWeight = FontWeight.SemiBold,
    ),
)

/** Shared onboarding/login/paywall background, matching iOS BrandBackground. */
@Composable
fun BrandBackground(
    modifier: Modifier = Modifier,
    content: @Composable BoxScope.() -> Unit = {},
) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(
                Brush.linearGradient(
                    colors = listOf(
                        ChillColors.BackgroundPrimary,
                        Color.White.copy(alpha = 0.96f),
                        ChillColors.BrandBlueSoft.copy(alpha = 0.45f),
                    ),
                ),
            ),
    ) {
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .offset(x = 92.dp, y = (-150).dp)
                .size(240.dp)
                .blur(14.dp)
                .background(ChillColors.BrandBlue.copy(alpha = 0.08f), CircleShape),
        )
        Box(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .offset(x = (-92).dp, y = 120.dp)
                .size(210.dp)
                .blur(18.dp)
                .background(ChillColors.BrandTeal.copy(alpha = 0.07f), CircleShape),
        )
        content()
    }
}
