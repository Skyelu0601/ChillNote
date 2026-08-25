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
}
