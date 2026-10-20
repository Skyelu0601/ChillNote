package com.sponteoai.chillscript.ui.skills

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material.icons.automirrored.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import com.sponteoai.chillscript.R
import com.sponteoai.chillscript.ui.theme.ChillColors

// Keep stable symbol identifiers; Android renders their native Material equivalents.
internal val customSkillIcons: List<Pair<String, ImageVector>> = listOf(
    "envelope.fill" to Icons.Outlined.Email,
    "envelope.badge.fill" to Icons.Outlined.MarkEmailUnread,
    "mail.fill" to Icons.Outlined.Mail,
    "bubble.left.and.bubble.right.fill" to Icons.Outlined.Forum,
    "text.bubble.fill" to Icons.AutoMirrored.Outlined.Chat,
    "doc.text.fill" to Icons.Outlined.Description,
    "doc.plaintext.fill" to Icons.AutoMirrored.Outlined.Article,
    "note.text" to Icons.AutoMirrored.Outlined.Note,
    "list.bullet.rectangle" to Icons.AutoMirrored.Outlined.ListAlt,
    "list.bullet.clipboard.fill" to Icons.AutoMirrored.Outlined.Assignment,
    "checklist" to Icons.Outlined.Checklist,
    "checkmark.circle.fill" to Icons.Outlined.CheckCircle,
    "checkmark.square.fill" to Icons.Outlined.CheckBox,
    "calendar" to Icons.Outlined.CalendarMonth,
    "clock.fill" to Icons.Outlined.Schedule,
    "timer" to Icons.Outlined.Timer,
    "pencil" to Icons.Outlined.Edit,
    "pencil.circle.fill" to Icons.Outlined.EditNote,
    "square.and.pencil" to Icons.Outlined.DriveFileRenameOutline,
    "text.badge.checkmark" to Icons.Outlined.Spellcheck,
    "text.badge.star" to Icons.Outlined.TextFields,
    "lightbulb.fill" to Icons.Outlined.Lightbulb,
    "brain.head.profile" to Icons.Outlined.Psychology,
    "sparkles" to Icons.Outlined.AutoAwesome,
    "star.fill" to Icons.Outlined.Star,
    "wand.and.stars" to Icons.Outlined.AutoFixHigh,
    "folder.fill" to Icons.Outlined.Folder,
    "archivebox.fill" to Icons.Outlined.Archive,
    "tray.fill" to Icons.Outlined.Inbox,
    "tag.fill" to Icons.AutoMirrored.Outlined.Label,
    "bookmark.fill" to Icons.Outlined.Bookmark,
    "person.2.fill" to Icons.Outlined.Group,
    "megaphone.fill" to Icons.Outlined.Campaign,
    "speaker.wave.2.fill" to Icons.AutoMirrored.Outlined.VolumeUp,
    "square.and.arrow.up.fill" to Icons.Outlined.Share,
    "link" to Icons.Outlined.Link,
    "chart.bar.fill" to Icons.Outlined.BarChart,
    "chart.pie.fill" to Icons.Outlined.PieChart,
    "magnifyingglass" to Icons.Outlined.Search,
    "eye.fill" to Icons.Outlined.Visibility,
    "scope" to Icons.Outlined.MyLocation,
    "gearshape.fill" to Icons.Outlined.Settings,
    "bolt.fill" to Icons.Outlined.Bolt,
    "flame.fill" to Icons.Outlined.LocalFireDepartment,
    "heart.fill" to Icons.Outlined.Favorite,
    "flag.fill" to Icons.Outlined.Flag,
    "bell.fill" to Icons.Outlined.Notifications,
)

internal fun customSkillImage(selectedIcon: String): ImageVector =
    customSkillIcons.firstOrNull { it.first == selectedIcon }?.second ?: Icons.Outlined.AutoAwesome

@Composable
internal fun CustomSkillIconPicker(selectedIcon: String, onSelect: (String) -> Unit, onDismiss: () -> Unit) {
    AlertDialog(onDismissRequest = onDismiss,
        containerColor = ChillColors.BackgroundPrimary,
        title = { Text(stringResource(R.string.creator_skills_icon_picker_title)) },
        text = {
            LazyVerticalGrid(columns = GridCells.Adaptive(60.dp), modifier = Modifier.fillMaxWidth().heightIn(max = 440.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                itemsIndexed(customSkillIcons, key = { _, option -> option.first }) { index, option ->
                    val isSelected = option.first == selectedIcon
                    Surface(onClick = { onSelect(option.first) }, shape = RoundedCornerShape(12.dp),
                        color = if (isSelected) ChillColors.BrandBlueSoft else ChillColors.BackgroundSecondary,
                        border = BorderStroke(1.dp, if (isSelected) ChillColors.BrandBlue else ChillColors.BorderSubtle),
                        modifier = Modifier.size(60.dp).semantics { selected = isSelected }) {
                        Icon(option.second, stringResource(R.string.creator_skills_icon_option, index + 1),
                            modifier = Modifier.padding(18.dp), tint = if (isSelected) ChillColors.BrandBlueText else ChillColors.TextMain)
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.common_done)) } },
    )
}
