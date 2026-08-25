package com.sponteoai.chillscript.weekly

import kotlinx.serialization.KSerializer
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.nullable
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import java.time.Instant

@Serializable
enum class WeeklyTopicSourceAvailability {
    @SerialName("active")
    ACTIVE,

    @SerialName("trashed")
    TRASHED,

    @SerialName("deleted")
    DELETED,
}

@Serializable
data class WeeklyTopicSettings(
    val enabled: Boolean,
    val weekday: Int,
    val hour: Int,
    val minute: Int,
    val timeZone: String,
    val locale: String,
    @Serializable(with = NullableIsoInstantSerializer::class)
    val lastPeriodEnd: Instant? = null,
    @Serializable(with = NullableIsoInstantSerializer::class)
    val nextRunAt: Instant? = null,
)

@Serializable
data class WeeklyTopicSource(
    val noteId: String,
    val noteTitle: String,
    val platformName: String? = null,
    val excerpt: String,
    val availability: WeeklyTopicSourceAvailability? = null,
) {
    val resolvedAvailability: WeeklyTopicSourceAvailability
        get() = availability ?: WeeklyTopicSourceAvailability.ACTIVE
}

@Serializable
data class WeeklyTopicItem(
    val id: String,
    val title: String,
    val sources: List<WeeklyTopicSource>,
)

@Serializable
data class WeeklyTopicReport(
    val id: String,
    @Serializable(with = IsoInstantSerializer::class)
    val periodStart: Instant,
    @Serializable(with = IsoInstantSerializer::class)
    val periodEnd: Instant,
    val sourceNoteCount: Int,
    val language: String,
    val topics: List<WeeklyTopicItem>,
    @Serializable(with = NullableIsoInstantSerializer::class)
    val readAt: Instant? = null,
    val regenerationCount: Int,
    @Serializable(with = IsoInstantSerializer::class)
    val createdAt: Instant,
) {
    val isUnread: Boolean
        get() = readAt == null

    val canRegenerate: Boolean
        get() = regenerationCount < 1
}

@Serializable
data class WeeklyTopicDashboard(
    val settings: WeeklyTopicSettings,
    val latestReport: WeeklyTopicReport? = null,
    val hasUnreadReport: Boolean,
    val currentSourceCount: Int,
    val minimumSourceCount: Int,
)

@Serializable
data class WeeklyTopicReportsResponse(
    val reports: List<WeeklyTopicReport>,
)

@Serializable
data class WeeklyTopicSettingsPayload(
    val enabled: Boolean,
    val weekday: Int,
    val hour: Int,
    val minute: Int,
    val timeZone: String,
    val locale: String,
)

object IsoInstantSerializer : KSerializer<Instant> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("IsoInstant", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: Instant) {
        encoder.encodeString(value.toString())
    }

    override fun deserialize(decoder: Decoder): Instant {
        val value = decoder.decodeString()
        return try {
            Instant.parse(value)
        } catch (error: Exception) {
            throw SerializationException("Invalid ISO-8601 instant", error)
        }
    }
}

@OptIn(ExperimentalSerializationApi::class)
object NullableIsoInstantSerializer : KSerializer<Instant?> {
    override val descriptor: SerialDescriptor = IsoInstantSerializer.descriptor.nullable

    override fun serialize(encoder: Encoder, value: Instant?) {
        if (value == null) {
            encoder.encodeNull()
        } else {
            encoder.encodeString(value.toString())
        }
    }

    override fun deserialize(decoder: Decoder): Instant? {
        if (!decoder.decodeNotNullMark()) {
            decoder.decodeNull()
            return null
        }
        val value = decoder.decodeString()
        return try {
            Instant.parse(value)
        } catch (error: Exception) {
            throw SerializationException("Invalid ISO-8601 instant", error)
        }
    }
}
