package com.sponteoai.chillscript.domain

import org.junit.Assert.assertEquals
import org.junit.Test

class SearchQueryBuilderTest {
    @Test fun wordsBecomePrefixAndTerms() {
        assertEquals("creator* AND hooks*", SearchQueryBuilder.build("Creator hooks").match)
    }

    @Test fun likeWildcardsAreEscaped() {
        assertEquals("%100\\%\\_ready\\_%", SearchQueryBuilder.build("100%_ready_").like)
    }
}
