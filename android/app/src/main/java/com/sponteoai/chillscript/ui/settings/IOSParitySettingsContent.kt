package com.sponteoai.chillscript.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.automirrored.outlined.ArrowForwardIos
import androidx.compose.material.icons.automirrored.outlined.Logout
import androidx.compose.material.icons.outlined.AccountCircle
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.Email
import androidx.compose.material.icons.outlined.FileUpload
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Language
import androidx.compose.material.icons.outlined.PrivacyTip
import androidx.compose.material.icons.outlined.Security
import androidx.compose.material.icons.outlined.StarOutline
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.ui.theme.ChillColors

/** Exact Compose shell for the current iOS SettingsView. */
@Composable
fun IOSParitySettingsContent(
    accountEmail: String,
    isPro: Boolean,
    voiceLanguageSummary: String,
    busy: Boolean,
    exporting: Boolean,
    onBack: () -> Unit,
    onSubscription: () -> Unit,
    onExport: () -> Unit,
    onVoiceLanguage: () -> Unit,
    onPermissions: () -> Unit,
    onFeedback: () -> Unit,
    onRate: () -> Unit,
    onPrivacy: () -> Unit,
    onAgreement: () -> Unit,
    onAbout: () -> Unit,
    onDeleteAccount: () -> Unit,
    onSignOut: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier.fillMaxSize().background(ChillColors.BackgroundPrimary).statusBarsPadding()) {
        Box(
            Modifier.fillMaxWidth().height(58.dp).padding(horizontal = 24.dp, vertical = 7.dp),
            contentAlignment = Alignment.Center,
        ) {
            IconButton(onClick = onBack, modifier = Modifier.align(Alignment.CenterStart).size(44.dp)) {
                Icon(
                    Icons.AutoMirrored.Outlined.ArrowBack,
                    contentDescription = stringResource(R.string.common_back),
                    tint = ChillColors.TextMain,
                    modifier = Modifier.size(25.dp),
                )
            }
            Text(
                stringResource(R.string.settings_title),
                color = Color.Black,
                fontSize = 17.sp,
                fontWeight = FontWeight.Bold,
            )
        }

        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(start = 24.dp, top = 17.dp, end = 24.dp, bottom = 40.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            item {
                IOSSettingsCard {
                    Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                                    Text(
                                        stringResource(R.string.settings_ui_account_title),
                                        color = ChillColors.TextMain,
                                        fontSize = 17.sp,
                                        fontWeight = FontWeight.SemiBold,
                                    )
                                    if (isPro) {
                                        Text(
                                            stringResource(R.string.subscription_pro),
                                            color = Color.White,
                                            fontSize = 10.sp,
                                            fontWeight = FontWeight.Bold,
                                            modifier = Modifier.background(ChillColors.BrandBlue, CircleShape).padding(horizontal = 6.dp, vertical = 2.dp),
                                        )
                                    }
                                }
                                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                    Icon(Icons.Outlined.AccountCircle, contentDescription = null, tint = ChillColors.TextSub, modifier = Modifier.size(14.dp))
                                    Text(accountEmail, color = ChillColors.TextSub, fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                }
                            }
                        }
                        Box(Modifier.fillMaxWidth().height(1.dp).background(ChillColors.BorderSubtle))
                        Row(
                            Modifier.fillMaxWidth().clickable(enabled = !busy, onClick = onSubscription).padding(top = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Text(stringResource(R.string.settings_ui_subscription_plan), color = ChillColors.TextMain, fontSize = 15.sp)
                                Text(
                                    stringResource(if (isPro) R.string.settings_ui_pro_active else R.string.settings_ui_free_plan),
                                    color = ChillColors.TextSub,
                                    fontSize = 13.sp,
                                )
                            }
                            Text(
                                stringResource(if (isPro) R.string.settings_ui_manage else R.string.settings_ui_upgrade),
                                color = if (isPro) ChillColors.TextMain else ChillColors.BrandBlue,
                                fontSize = 14.sp,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier
                                    .background(
                                        if (isPro) Color.Gray.copy(alpha = 0.10f) else ChillColors.BrandBlue.copy(alpha = 0.10f),
                                        RoundedCornerShape(12.dp),
                                    )
                                    .padding(horizontal = 12.dp, vertical = 6.dp),
                            )
                        }
                    }
                }
            }

            item {
                IOSSettingsCard {
                    IOSSettingsRow(
                        icon = Icons.Outlined.FileUpload,
                        title = stringResource(R.string.settings_export_all_notes),
                        value = if (exporting) stringResource(R.string.settings_exporting) else null,
                        busy = exporting,
                        onClick = onExport,
                    )
                    IOSSettingsDivider()
                    IOSSettingsRow(Icons.Outlined.Language, stringResource(R.string.settings_voice_title), voiceLanguageSummary, onClick = onVoiceLanguage)
                    IOSSettingsDivider()
                    IOSSettingsRow(Icons.Outlined.Security, stringResource(R.string.settings_ui_permissions), onClick = onPermissions)
                }
            }

            item {
                IOSSettingsCard {
                    IOSSettingsRow(Icons.Outlined.Email, stringResource(R.string.settings_send_feedback), onClick = onFeedback)
                    IOSSettingsDivider()
                    IOSSettingsRow(Icons.Outlined.StarOutline, stringResource(R.string.settings_ui_rate_google_play), onClick = onRate)
                    IOSSettingsDivider()
                    IOSSettingsRow(Icons.Outlined.PrivacyTip, stringResource(R.string.settings_privacy_policy), onClick = onPrivacy)
                    IOSSettingsDivider()
                    IOSSettingsRow(Icons.Outlined.Description, stringResource(R.string.settings_ui_user_agreement), onClick = onAgreement)
                    IOSSettingsDivider()
                    IOSSettingsRow(Icons.Outlined.Info, stringResource(R.string.settings_about), onClick = onAbout)
                    IOSSettingsDivider()
                    IOSSettingsRow(Icons.Outlined.Delete, stringResource(R.string.settings_ui_delete_account), onClick = onDeleteAccount)
                }
            }

            item {
                IOSSettingsCard {
                    IOSSettingsRow(
                        icon = Icons.AutoMirrored.Outlined.Logout,
                        title = stringResource(R.string.settings_ui_sign_out),
                        titleColor = Color(0xFFD14343),
                        iconColor = Color(0xFFD14343),
                        showChevron = false,
                        enabled = !busy,
                        onClick = onSignOut,
                    )
                }
            }
        }
    }
}

@Composable
private fun IOSSettingsCard(content: @Composable () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .shadow(8.dp, RoundedCornerShape(16.dp), ambientColor = Color.Black.copy(alpha = 0.04f), spotColor = Color.Black.copy(alpha = 0.04f))
            .background(Color.White, RoundedCornerShape(16.dp)),
    ) { content() }
}

@Composable
private fun IOSSettingsDivider() {
    Box(Modifier.fillMaxWidth().padding(start = 56.dp).height(1.dp).background(ChillColors.BorderSubtle))
}

@Composable
private fun IOSSettingsRow(
    icon: ImageVector,
    title: String,
    value: String? = null,
    busy: Boolean = false,
    titleColor: Color = ChillColors.TextMain,
    iconColor: Color = ChillColors.TextMain.copy(alpha = 0.6f),
    showChevron: Boolean = true,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    Row(
        Modifier.fillMaxWidth().clickable(enabled = enabled, onClick = onClick).padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Icon(icon, contentDescription = null, tint = iconColor.copy(alpha = if (enabled) 1f else 0.4f), modifier = Modifier.size(24.dp))
        Text(title, color = titleColor.copy(alpha = if (enabled) 1f else 0.4f), fontSize = 15.sp, fontWeight = FontWeight.Medium, modifier = Modifier.weight(1f))
        if (busy) {
            CircularProgressIndicator(modifier = Modifier.size(18.dp), color = ChillColors.BrandBlue, strokeWidth = 2.dp)
        } else if (value != null) {
            Text(value, color = ChillColors.TextSub, fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        if (showChevron) {
            Icon(Icons.AutoMirrored.Outlined.ArrowForwardIos, contentDescription = null, tint = ChillColors.TextSub.copy(alpha = 0.7f), modifier = Modifier.size(13.dp))
        }
    }
}
