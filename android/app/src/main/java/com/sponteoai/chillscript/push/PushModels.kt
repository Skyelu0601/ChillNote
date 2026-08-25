package com.sponteoai.chillscript.push

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

object PushContract {
    const val CHANNEL_ID = "content_updates"
    const val DATA_KIND = "kind"
    const val DATA_ROUTE = "route"
    const val DATA_NOTE_ID = "noteId"
    const val ROUTE_NOTE = "note"
    const val ROUTE_WEEKLY_TOPICS = "weekly_topics"
}

sealed interface PushDestination {
    data object Home : PushDestination
    data object WeeklyTopics : PushDestination
    data class Note(val noteId: String) : PushDestination
}

internal fun parsePushDestination(route: String?, noteId: String?): PushDestination = when (route) {
    PushContract.ROUTE_WEEKLY_TOPICS -> PushDestination.WeeklyTopics
    PushContract.ROUTE_NOTE -> noteId
        ?.takeIf(::isUuid)
        ?.let(PushDestination::Note)
        ?: PushDestination.Home
    else -> PushDestination.Home
}

private fun isUuid(value: String): Boolean = runCatching { UUID.fromString(value) }.isSuccess

@Serializable
data class PushDeviceRegistrationPayload(
    val token: String,
    val platform: String = "android",
    val environment: String = "production",
    val locale: String,
    @SerialName("timeZone") val timeZone: String,
    val authorizationStatus: String,
)

internal data class PushRegistrationSnapshot(
    val firebaseConfigured: Boolean,
    val permissionGranted: Boolean,
    val currentToken: String?,
    val registeredToken: String?,
    val registeredUserId: String?,
    val currentUserId: String,
)

internal sealed interface PushRegistrationDecision {
    data object Disabled : PushRegistrationDecision
    data object AwaitPermission : PushRegistrationDecision
    data object FetchToken : PushRegistrationDecision
    data object UpToDate : PushRegistrationDecision
    data class Register(val token: String) : PushRegistrationDecision
}

internal fun decidePushRegistration(snapshot: PushRegistrationSnapshot): PushRegistrationDecision {
    if (!snapshot.firebaseConfigured) return PushRegistrationDecision.Disabled
    if (!snapshot.permissionGranted) return PushRegistrationDecision.AwaitPermission
    val token = snapshot.currentToken?.trim().orEmpty()
    if (token.isEmpty()) return PushRegistrationDecision.FetchToken
    if (token == snapshot.registeredToken && snapshot.currentUserId == snapshot.registeredUserId) {
        return PushRegistrationDecision.UpToDate
    }
    return PushRegistrationDecision.Register(token)
}
