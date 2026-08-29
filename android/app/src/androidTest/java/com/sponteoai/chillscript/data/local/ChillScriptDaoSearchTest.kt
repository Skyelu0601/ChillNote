package com.sponteoai.chillscript.data.local

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.sponteoai.chillscript.domain.SearchQueryBuilder
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ChillScriptDaoSearchTest {
    private lateinit var database: ChillScriptDatabase

    @Before
    fun setUp() {
        database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            ChillScriptDatabase::class.java,
        ).allowMainThreadQueries().build()
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun searchNotes_executesLikeFallbackWithoutEscapeError() = runBlocking {
        val dao = database.dao()
        val timestamp = "2026-08-24T00:00:00Z"
        dao.upsertNote(
            NoteEntity(
                id = "note-1",
                userId = "user-1",
                content = "A creator idea",
                previewPlainText = "A creator idea",
                createdAt = timestamp,
                updatedAt = timestamp,
            ),
        )

        // "reator" is only a substring of the FTS token "creator", so this must
        // execute the LIKE fallback that previously crashed because ESCAPE had two characters.
        val query = SearchQueryBuilder.build("reator")
        val results = dao.searchNotes("user-1", query.match, query.like).first()

        assertEquals(listOf("note-1"), results.map { it.id })
    }

    @Test
    fun searchNotes_treatsLikeWildcardsAsLiteralCharacters() = runBlocking {
        val dao = database.dao()
        val timestamp = "2026-08-24T00:00:00Z"
        dao.upsertNote(
            NoteEntity(
                id = "note-special-characters",
                userId = "user-1",
                content = "Progress: 100%_ready_",
                previewPlainText = "Progress: 100%_ready_",
                createdAt = timestamp,
                updatedAt = timestamp,
            ),
        )

        val percentQuery = SearchQueryBuilder.build("%")
        val underscoreQuery = SearchQueryBuilder.build("_")

        assertEquals(
            listOf("note-special-characters"),
            dao.searchNotes("user-1", percentQuery.match, percentQuery.like).first().map { it.id },
        )
        assertEquals(
            listOf("note-special-characters"),
            dao.searchNotes("user-1", underscoreQuery.match, underscoreQuery.like).first().map { it.id },
        )
    }

    @Test
    fun observeNotes_ordersPinnedFirstThenByCreationTime() = runBlocking {
        val dao = database.dao()
        dao.upsertNotes(orderingFixtures())

        val results = dao.observeNotes("user-order").first()

        assertEquals(
            listOf("pinned-newer", "pinned-older", "created-newer", "created-older"),
            results.map { it.id },
        )
    }

    private fun orderingFixtures(): List<NoteEntity> = listOf(
        NoteEntity(
            id = "created-older",
            userId = "user-order",
            content = "Shared older note",
            previewPlainText = "Shared older note",
            createdAt = "2026-08-20T00:00:00Z",
            updatedAt = "2026-08-25T00:00:00Z",
        ),
        NoteEntity(
            id = "created-newer",
            userId = "user-order",
            content = "Shared newer note",
            previewPlainText = "Shared newer note",
            createdAt = "2026-08-24T00:00:00Z",
            updatedAt = "2026-08-21T00:00:00Z",
        ),
        NoteEntity(
            id = "pinned-older",
            userId = "user-order",
            content = "Shared pinned older note",
            previewPlainText = "Shared pinned older note",
            createdAt = "2026-08-23T00:00:00Z",
            updatedAt = "2026-08-25T00:00:00Z",
            pinnedAt = "2026-08-22T00:00:00Z",
        ),
        NoteEntity(
            id = "pinned-newer",
            userId = "user-order",
            content = "Shared pinned newer note",
            previewPlainText = "Shared pinned newer note",
            createdAt = "2026-08-19T00:00:00Z",
            updatedAt = "2026-08-20T00:00:00Z",
            pinnedAt = "2026-08-25T00:00:00Z",
        ),
    )
}
