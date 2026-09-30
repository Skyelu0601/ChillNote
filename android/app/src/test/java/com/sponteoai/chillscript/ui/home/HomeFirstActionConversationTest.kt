package com.sponteoai.chillscript.ui.home

import org.junit.Assert.*
import org.junit.Test

class HomeFirstActionConversationTest {
    @Test fun failedRequestCanRetryAndSuccessAdvancesDirectlyToRecord() {
        val waiting = HomeFirstActionGuideState(HomeFirstActionStage.WaitingForAISkillsDismissal, "note")
        val retry = waiting.reconcileConversation("note", false)
        assertEquals(HomeFirstActionStage.TapAISkills, retry.stage)
        val reply = retry.reconcileConversation("note", true)
        assertEquals(HomeFirstActionStage.TapRecordTab, reply.stage)
        assertEquals(reply, reply.reconcileConversation("note", true))
    }

    @Test fun restoredReviewWithoutHistoryReturnsToSkillInsteadOfDeadEnding() {
        val review = HomeFirstActionGuideState(HomeFirstActionStage.ReviewAIReply, "note")
        assertEquals(HomeFirstActionStage.TapAISkills, review.reconcileConversation("note", false).stage)
        assertEquals(HomeFirstActionStage.TapRecordTab, review.reconcileConversation("note", true).stage)
    }

    @Test fun otherNotesAndInactiveStagesCannotBeAdvancedByConversation() {
        for (stage in listOf(HomeFirstActionStage.SharePrompt, HomeFirstActionStage.ReviewTranscript,
                HomeFirstActionStage.Completed, HomeFirstActionStage.Dismissed)) {
            val state = HomeFirstActionGuideState(stage, "note")
            assertEquals(state, state.reconcileConversation("note", true))
        }
        val waiting = HomeFirstActionGuideState(HomeFirstActionStage.WaitingForAISkillsDismissal, "note")
        assertEquals(waiting, waiting.reconcileConversation("other-note", true))
    }
}
