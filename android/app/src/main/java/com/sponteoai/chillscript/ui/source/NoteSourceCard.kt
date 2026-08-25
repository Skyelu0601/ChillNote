package com.sponteoai.chillscript.ui.source

import androidx.annotation.DrawableRes
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.OpenInNew
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.GraphicEq
import androidx.compose.material.icons.outlined.Link
import androidx.compose.material.icons.outlined.NorthEast
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.domain.NoteSourceMetadata
import com.sponteoai.chillscript.domain.authorDisplayName
import com.sponteoai.chillscript.ui.theme.ChillColors

/** Android rendering of the current iOS NoteSourceCard. */
@Composable
fun NoteSourceCard(
    source: NoteSourceMetadata,
    compact: Boolean = false,
    onOpen: () -> Unit,
) {
    val author = source.authorDisplayName?.takeIf { it.isNotBlank() }
    val showsDescription = source.title.trim().let { title ->
        title.isNotEmpty() &&
            !title.equals(source.platformName, ignoreCase = true) &&
            !title.equals(source.host, ignoreCase = true)
    }
    val accessibilityLabel = stringResource(
        R.string.note_source_accessibility_open,
        source.platformName,
        source.title,
    )
    val compactShape = RoundedCornerShape(14.dp)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .then(if (compact) Modifier.clip(compactShape).background(ChillColors.BackgroundSecondary) else Modifier)
            .clickable(onClick = onOpen)
            .clearAndSetSemantics {
                role = Role.Button
                contentDescription = listOfNotNull(accessibilityLabel, author).joinToString(". ")
                onClick {
                    onOpen()
                    true
                }
            }
            .padding(
                horizontal = if (compact) 10.dp else 0.dp,
                vertical = if (compact) 9.dp else 10.dp,
            ),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(if (compact) 10.dp else 14.dp),
    ) {
        SourceBadge(source.platformId, compact)

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(if (compact) 1.dp else 4.dp),
        ) {
            if (compact) {
                if (author != null) {
                    Text(
                        text = author,
                        color = ChillColors.TextSub,
                        fontSize = 12.sp,
                        lineHeight = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                if (showsDescription) {
                    Text(
                        text = source.title,
                        color = ChillColors.TextMain,
                        fontSize = 13.sp,
                        lineHeight = 17.sp,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            } else {
                if (showsDescription) {
                    Text(
                        text = source.title,
                        color = ChillColors.TextMain,
                        fontSize = 17.sp,
                        lineHeight = 22.sp,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                Text(
                    text = if (author == null) source.platformName else "$author · ${source.platformName}",
                    color = ChillColors.TextSub,
                    fontSize = 15.sp,
                    lineHeight = 20.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }

        Spacer(Modifier.size(8.dp))
        Icon(
            imageVector = if (compact) Icons.Outlined.NorthEast else Icons.AutoMirrored.Outlined.OpenInNew,
            contentDescription = null,
            tint = ChillColors.TextSub,
            modifier = Modifier.size(if (compact) 12.dp else 18.dp),
        )
    }
}

@Composable
private fun SourceBadge(platformId: String, compact: Boolean) {
    val badgeSize = if (compact) 30.dp else 38.dp
    val markSize = if (compact) 17.dp else 21.dp
    Box(
        modifier = Modifier.size(badgeSize).background(platformColor(platformId), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        val brand = platformBrandDrawable(platformId)
        val initials = platformInitials(platformId)
        when {
            brand != null -> Icon(
                painter = painterResource(brand),
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(markSize),
            )
            initials != null -> Text(
                text = initials,
                color = Color.White,
                fontSize = if (compact) 9.sp else 10.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
            )
            else -> Icon(
                imageVector = platformFallbackIcon(platformId),
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(if (compact) 14.dp else 17.dp),
            )
        }
    }
}

@DrawableRes
private fun platformBrandDrawable(id: String): Int? = when (id) {
    "youtube" -> R.drawable.source_brand_youtube
    "tiktok" -> R.drawable.source_brand_tiktok
    "instagram" -> R.drawable.source_brand_instagram
    else -> null
}

private fun platformInitials(id: String): String? = when (id) {
    "xiaohongshu" -> "小红书"
    "threads" -> "TH"
    "reddit" -> "RD"
    "pinterest" -> "PI"
    "linkedin" -> "IN"
    "facebook" -> "FB"
    "vimeo" -> "VI"
    "twitch" -> "TW"
    "product_hunt" -> "PH"
    "hacker_news" -> "HN"
    "bilibili" -> "B"
    else -> null
}

private fun platformFallbackIcon(id: String): ImageVector = when (id) {
    "x" -> Icons.Outlined.Close
    "spotify", "apple_podcasts" -> Icons.Outlined.GraphicEq
    else -> Icons.Outlined.Link
}

private fun platformColor(id: String): Color = when (id) {
    "xiaohongshu" -> Color(0xFFF52E40)
    "youtube" -> Color(0xFFFF0000)
    "tiktok" -> Color(0xFF0D0F14)
    "instagram" -> Color(0xFFD13F8C)
    "threads", "x" -> Color(0xFF141417)
    "reddit" -> Color(0xFFFF4500)
    "pinterest" -> Color(0xFFE6001F)
    "linkedin" -> Color(0xFF0078B5)
    "facebook" -> Color(0xFF1778F2)
    "vimeo" -> Color(0xFF1AB0ED)
    "twitch" -> Color(0xFF6441A5)
    "product_hunt" -> Color(0xFFD94526)
    "hacker_news" -> Color(0xFFFF6600)
    "bilibili" -> Color(0xFF00A1DB)
    "spotify" -> Color(0xFF1FBA54)
    else -> ChillColors.BrandTeal
}
