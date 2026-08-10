package com.sponteoai.chillscript.onboarding

import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Notes
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.Bolt
import androidx.compose.material.icons.outlined.Link
import androidx.compose.material.icons.outlined.Mic
import androidx.compose.material.icons.outlined.Movie
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.sponteoai.chillscript.R

private data class IntroPage(
    @StringRes val title: Int,
    @StringRes val body: Int,
    val icon: ImageVector,
)

@Composable
fun OnboardingScreen(onFinish: () -> Unit) {
    val pages = listOf(
        IntroPage(R.string.onboarding_page_hero_title, R.string.onboarding_page_hero_body, Icons.Outlined.Bolt),
        IntroPage(R.string.onboarding_page_save_video_title, R.string.onboarding_page_save_video_body, Icons.Outlined.Movie),
        IntroPage(R.string.onboarding_page_extract_title, R.string.onboarding_page_extract_body, Icons.Outlined.Link),
        IntroPage(R.string.onboarding_page_capture_title, R.string.onboarding_page_capture_body, Icons.Outlined.Mic),
        IntroPage(R.string.onboarding_page_hooks_title, R.string.onboarding_page_hooks_body, Icons.AutoMirrored.Outlined.Notes),
        IntroPage(R.string.onboarding_page_skills_title, R.string.onboarding_page_skills_body, Icons.Outlined.AutoAwesome),
    )
    var pageIndex by remember { mutableIntStateOf(0) }
    val page = pages[pageIndex]
    val isLastPage = pageIndex == pages.lastIndex

    Column(
        Modifier.fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(horizontal = 24.dp, vertical = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            if (pageIndex in 1 until pages.lastIndex) {
                TextButton(onClick = onFinish) { Text(stringResource(R.string.common_skip)) }
            } else Spacer(Modifier.height(48.dp))
        }
        Column(
            Modifier.weight(1f),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                Modifier.background(MaterialTheme.colorScheme.primaryContainer, CircleShape).padding(28.dp),
                contentAlignment = Alignment.Center,
            ) {
                Icon(page.icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            }
            Text(
                stringResource(page.title),
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 30.dp),
            )
            Text(
                stringResource(page.body),
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 14.dp),
            )
            Card(
                Modifier.fillMaxWidth().padding(top = 32.dp),
                shape = RoundedCornerShape(24.dp),
            ) {
                Text(
                    stringResource(pageDemoText(pageIndex)),
                    modifier = Modifier.padding(24.dp),
                    style = MaterialTheme.typography.bodyLarge,
                )
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(bottom = 18.dp)) {
            pages.indices.forEach { index ->
                Box(
                    Modifier.background(
                        if (index == pageIndex) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant,
                        CircleShape,
                    ).padding(horizontal = if (index == pageIndex) 10.dp else 4.dp, vertical = 4.dp),
                )
            }
        }
        Button(
            onClick = { if (isLastPage) onFinish() else pageIndex += 1 },
            modifier = Modifier.fillMaxWidth().height(54.dp),
        ) {
            Text(stringResource(if (isLastPage) R.string.onboarding_action_start_creating else if (pageIndex == 0) R.string.onboarding_action_get_started else R.string.common_next))
        }
        if (pageIndex == 0) {
            TextButton(onClick = onFinish) {
                Text(stringResource(R.string.onboarding_login_prompt))
            }
        }
    }
}

@StringRes
private fun pageDemoText(index: Int): Int = when (index) {
    1 -> R.string.onboarding_demo_save_video
    2 -> R.string.onboarding_demo_extract
    3 -> R.string.onboarding_demo_capture
    4 -> R.string.onboarding_demo_hooks
    5 -> R.string.onboarding_demo_skills
    else -> R.string.onboarding_demo_hero
}
