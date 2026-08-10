package com.sponteoai.chillscript.ui.markdown

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.sp
import com.sponteoai.chillscript.domain.MarkdownBlockType
import com.sponteoai.chillscript.domain.MarkdownParser
import com.sponteoai.chillscript.domain.MarkdownImages
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.net.URI
import androidx.compose.ui.unit.dp

@Composable
fun MarkdownText(
    markdown: String,
    modifier: Modifier = Modifier,
    maxLines: Int = Int.MAX_VALUE,
    style: TextStyle = MaterialTheme.typography.bodyLarge,
) {
    val primary = MaterialTheme.colorScheme.primary
    val secondary = MaterialTheme.colorScheme.onSurfaceVariant
    val localImages = MarkdownImages.urls(markdown)
    if (localImages.isEmpty()) {
        Text(markdownAnnotatedString(markdown, primary, secondary), modifier = modifier, maxLines = maxLines, style = style)
    } else {
        Column(modifier) {
            localImages.take(if (maxLines == Int.MAX_VALUE) localImages.size else 1).forEach { LocalMarkdownImage(it) }
            Text(
                markdownAnnotatedString(MarkdownImages.removingImages(markdown), primary, secondary),
                maxLines = maxLines,
                style = style,
            )
        }
    }
}

@Composable
private fun LocalMarkdownImage(rawUrl: String) {
    val bitmap by produceState<Bitmap?>(initialValue = null, rawUrl) {
        value = withContext(Dispatchers.IO) {
            val file = runCatching { File(URI(rawUrl)) }.getOrNull()?.takeIf(File::isFile) ?: return@withContext null
            BitmapFactory.decodeFile(file.path)
        }
    }
    bitmap?.let {
        Image(
            bitmap = it.asImageBitmap(),
            contentDescription = null,
            modifier = Modifier.fillMaxWidth().height(180.dp).clip(RoundedCornerShape(10.dp)),
            contentScale = ContentScale.Crop,
        )
    }
}

fun markdownAnnotatedString(markdown: String, primary: Color, secondary: Color): AnnotatedString = buildAnnotatedString {
    val blocks = MarkdownParser.parse(markdown)
    blocks.forEachIndexed { index, block ->
        val blockStyle = when (block.type) {
            MarkdownBlockType.Heading1 -> SpanStyle(fontSize = 24.sp, fontWeight = FontWeight.Bold)
            MarkdownBlockType.Heading2 -> SpanStyle(fontSize = 20.sp, fontWeight = FontWeight.Bold)
            MarkdownBlockType.Heading3 -> SpanStyle(fontWeight = FontWeight.SemiBold)
            MarkdownBlockType.ChecklistDone -> SpanStyle(color = secondary, textDecoration = TextDecoration.LineThrough)
            MarkdownBlockType.Quote -> SpanStyle(color = secondary, fontStyle = FontStyle.Italic)
            MarkdownBlockType.Separator -> SpanStyle(color = secondary)
            MarkdownBlockType.Image -> SpanStyle(color = secondary, fontStyle = FontStyle.Italic)
            else -> SpanStyle()
        }
        if (block.prefix.isNotEmpty()) {
            withStyle(SpanStyle(color = if (block.type == MarkdownBlockType.ChecklistDone) Color(0xFF2E9B63) else primary)) {
                append(block.prefix)
            }
        }
        withStyle(blockStyle) {
            if (block.type == MarkdownBlockType.Image) append(block.imageUrl.orEmpty())
            else appendInlineMarkdown(block.text, primary)
        }
        if (index < blocks.lastIndex) append('\n')
    }
}

private fun AnnotatedString.Builder.appendInlineMarkdown(text: String, primary: Color) {
    var index = 0
    while (index < text.length) {
        val marker = when {
            text.startsWith("**", index) -> "**"
            text.startsWith("`", index) -> "`"
            text.startsWith("*", index) -> "*"
            else -> null
        }
        if (marker == null) {
            append(text[index])
            index++
            continue
        }
        val contentStart = index + marker.length
        val end = text.indexOf(marker, contentStart)
        if (end < 0) { append(marker); index = contentStart; continue }
        val span = when (marker) {
            "**" -> SpanStyle(fontWeight = FontWeight.Bold)
            "*" -> SpanStyle(fontStyle = FontStyle.Italic)
            else -> SpanStyle(fontFamily = FontFamily.Monospace, color = primary, background = Color(0x14000000))
        }
        withStyle(span) { append(text.substring(contentStart, end)) }
        index = end + marker.length
    }
}
