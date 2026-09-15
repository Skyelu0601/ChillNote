package com.sponteoai.chillscript.share

/** Fixed categories only: exception messages may contain the user's shared text or link. */
internal fun Throwable.analyticsCode(): String = when (this) {
    is ShareLinkInsufficientCreditsException -> "insufficient_credits"
    is ShareLinkImportException, is IllegalArgumentException -> "invalid_share_content"
    is SecurityException -> "not_authorized"
    is java.io.IOException -> "io_error"
    else -> "unknown"
}
