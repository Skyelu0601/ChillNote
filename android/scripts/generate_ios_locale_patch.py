#!/usr/bin/env python3
"""Generate an apply_patch payload for Android strings backed by iOS xcstrings.

The script only prints a patch. It intentionally skips Android-only copy when no
safe iOS semantic equivalent exists, allowing Android's English resources to be
used as the fallback instead of attaching an incorrect translation.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

from validate_localizations import (
    format_token_errors,
    placeholder_signature,
    scan_format_tokens,
)


ROOT = Path(__file__).resolve().parents[2]
ANDROID_STRINGS = ROOT / "android/app/src/main/res/values/strings.xml"
IOS_STRINGS = ROOT / "ios/chillnote/Resources/Localizable.xcstrings"

LOCALES = {
    "de": ("de", "values-de"),
    "es": ("es", "values-es"),
    "fr": ("fr", "values-fr"),
    "ja": ("ja", "values-ja"),
    "ko": ("ko", "values-ko"),
    "zh-Hans": ("zh-Hans", "values-zh-rCN"),
    "zh-Hant": ("zh-Hant", "values-zh-rTW"),
}

# These mappings connect Android resource names to the exact, currently used
# iOS semantic key. Android's base copy must stay identical to the iOS English
# value (apart from platform-specific terms and placeholder syntax); do not use
# this table to justify divergent wording.
SEMANTIC_KEY_OVERRIDES = {
    "home_create_note": "home.header.accessibility.create_blank_note",
    "common_retry": "common.retry",
    "common_ok": "common.ok",
    "common_undo": "common.undo",
    "common_continue": "common.continue",
    "common_cancel": "common.cancel",
    "common_delete": "common.delete",
    "common_save": "common.save",
    "home_empty_title": "home.notes.empty.default",
    "home_notes_syncing": "home.notes.syncing",
    "sidebar_tags_release_to_unnest": "sidebar.tags.release_to_unnest",
    "sidebar_trash_drag_to_delete": "sidebar.trash.drag_to_delete",
    "sidebar_trash_release_to_delete": "sidebar.trash.release_to_delete",
    "sidebar_stats_today": "sidebar.stats.today",
    "note_source_accessibility_open": "note_source.accessibility.open",
    "note_pin_action": "home.notes.action.pin",
    "note_unpin_action": "home.notes.action.unpin",
    "note_detail_recording_duration_progress": "note_detail.recording.duration_progress",
    "settings_export_failed_title": "settings.alert.export_failed.title",
    "note_actions": "note_detail.header.accessibility.more_actions",
    "note_move_to_published": "home.notes.action.mark_published",
    "home_section_trash": "sidebar.nav.recycle_bin",
    "tags_add": "note_detail.tag.add",
    "tags_create_title": "note_detail.add_tag.title",
    "note_tags_title": "sidebar.tags.title",
    "auth_login_send_code": "auth.login.send_code",
    "auth_login_code_sent_to_format": "auth.login.code_sent_to_format",
    "auth_login_back_to_options": "auth.login.back_to_options",
    "auth_login_email_button": "auth.login.email_button",
    "auth_login_email_title": "auth.login.email_title",
    "auth_login_email_help": "auth.login.email_help",
    "auth_login_email_placeholder": "auth.login.email_placeholder",
    "auth_login_email_invalid": "auth.login.email_invalid",
    "auth_login_code_title": "auth.login.code_title",
    "auth_login_change_email": "auth.login.change_email",
    "auth_login_verification_code_placeholder": "auth.login.verification_code_placeholder",
    "auth_login_verify_button": "auth.login.verify_button",
    "auth_login_resend_code": "auth.login.resend_code",
    "auth_login_resend_countdown_format": "auth.login.resend_countdown_format",
    "auth_login_legal_markdown": "auth.login.legal_markdown",
    "quick_capture_link_import_placeholder_title": "quick_capture.link_import.placeholder.title",
    "quick_capture_link_import_placeholder_format": "quick_capture.link_import.placeholder.body",
    "share_extension_unknown_source": "share_extension.unknown_source",
    "share_extension_reading_content": "share_extension.reading_content",
    "share_extension_saving": "share_extension.saving",
    "share_extension_saved": "share_extension.saved",
    "share_extension_failed": "share_extension.failed",
    "share_extension_no_link": "share_extension.no_link",
    "share_extension_source_format": "share_extension.source_format",
    "link_import_processing": "quick_capture.link_import.status.processing",
    "link_import_failed": "quick_capture.link_import.status.failed",
    "home_select_notes": "home.header.title_menu.select_notes",
    "home_search_placeholder": "home.search.placeholder",
    "home_accessibility_open_sidebar": "home.header.accessibility.title_menu",
    "home_accessibility_search": "home.header.accessibility.search",
    "home_accessibility_empty_recycle_bin": "home.header.accessibility.empty_recycle_bin",
    "quick_capture_paste_link": "quick_capture.more.paste_link.title",
    "quick_capture_text": "quick_capture.accessibility.text",
    "note_pinned_accessibility": "home.notes.accessibility.pinned",
    "note_workspace_note": "note_detail.workspace.tab.note",
    "note_workspace_create": "note_detail.workspace.tab.create",
    "note_workspace_record": "note_detail.workspace.tab.record",
    "note_workspace_manage_skills": "note_detail.ai_skills.manage",
    "note_workspace_script_ready": "note_detail.record.script_ready",
    "note_workspace_start_recording": "note_detail.record.action.start",
    "note_workspace_record_metadata": "note_detail.record.metadata",
    "onboarding_first_action_create_tab": "onboarding.first_action.create_tab",
    "onboarding_first_action_ai_skills": "onboarding.first_action.ai_skills",
    "onboarding_first_action_record_tab": "onboarding.first_action.record_tab",
    "onboarding_first_action_teleprompter": "onboarding.first_action.teleprompter",
    "onboarding_first_action_transcript_review_title": "onboarding.first_action.transcript_review.title",
    "onboarding_first_action_transcript_review_action": "onboarding.first_action.transcript_review.action",
    "onboarding_first_action_step_progress": "onboarding.first_action.step_progress",
    "note_detail_trash_deleted_in_days": "note_detail.trash.deleted_in_days",
    "note_detail_trash_deleted_today": "note_detail.trash.deleted_today",
    "note_header_add_topic": "note_detail.tag.add",
    "note_header_export_markdown": "note_detail.header.action.export_markdown",
    "note_header_delete_note": "note_detail.header.action.delete_note",
    "note_detail_delete_confirmation_title": "note_detail.alert.delete.title",
    "note_detail_delete_confirmation_message": "note_detail.alert.delete.message",
    "note_header_restore_action": "home.notes.action.restore",
    "note_header_accessibility_back": "note_detail.header.accessibility.back",
    "note_header_accessibility_restore_note": "note_detail.header.accessibility.restore_note",
    "note_header_accessibility_more_actions": "note_detail.header.accessibility.more_actions",
    "sidebar_membership_upgrade": "sidebar.membership.upgrade",
    "sidebar_credits_locked": "sidebar.credits.locked",
    "sidebar_credits_remaining": "sidebar.credits.remaining",
    "sidebar_stats_streak": "sidebar.stats.streak",
    "sidebar_stats_week_up": "sidebar.stats.week.up",
    "sidebar_stats_week_down": "sidebar.stats.week.down",
    "sidebar_stats_week_new_start": "sidebar.stats.week.new_start",
    "sidebar_stats_week_same": "sidebar.stats.week.same",
    "sidebar_tags_empty": "sidebar.tags.empty",
    "home_batch_tag_empty": "home.batch_tag.empty",
    "home_batch_tag_partial": "home.batch_tag.partial",
    "home_batch_delete_title": "home.alert.delete_notes.title",
    "home_ask_large_selection_title": "home.alert.large_selection.title",
    "home_ask_soft_limit_message": "home.alert.ask_soft_limit.message",
    "home_ask_too_many_notes_title": "home.alert.too_many_notes.title",
    "home_ask_hard_limit_message": "home.alert.ask_hard_limit.message",
    "auth_login_google_button": "auth.login.google_button",
    "auth_login_apple_button": "auth.login.apple_button",
    "auth_apple_failed": "error.auth.apple_init_failed",
    "auth_login_error_invalid_verification_code": "auth.login.error.invalid_verification_code",
    "auth_login_error_network": "auth.login.error.network",
    "auth_login_error_send_failed": "auth.login.error.send_failed",
    "auth_login_error_too_many_requests": "auth.login.error.too_many_requests",
    "auth_login_error_verification_failed": "auth.login.error.verification_failed",
    "settings_account_section": "settings.account.title",
    "settings_unknown_email": "settings.account.unknown_email",
    "settings_ui_account_title": "settings.account.title",
    "settings_ui_subscription_plan": "settings.account.subscription_plan",
    "settings_ui_pro_active": "settings.account.pro_active",
    "settings_ui_free_plan": "settings.account.free_plan",
    "settings_ui_manage": "settings.account.manage",
    "settings_ui_upgrade": "settings.account.upgrade",
    "settings_ui_permissions": "settings.data.permissions",
    "settings_ui_user_agreement": "settings.support.user_agreement",
    "settings_ui_delete_account": "settings.account.delete_account",
    "settings_ui_sign_out": "settings.account.sign_out",
    "settings_sign_out_confirm_message": "settings.alert.sign_out.message",
    "settings_terms": "subscription.terms_of_use",
    "settings_permissions": "settings.data.permissions",
    "settings_delete_account_confirm_title": "settings.alert.delete_account.title",
    "settings_delete_account_confirm_message": "settings.alert.delete_account.message",
    "settings_export_progress_packaging": "notes_export.progress.packaging_zip",
    "settings_export_progress_preparing": "notes_export.progress.preparing_package",
    "settings_export_progress_writing": "notes_export.progress.writing_markdown_files",
    "subscription_free": "sidebar.membership.free_plan",
    "subscription_current_pro": "subscription.brand.pro_title",
    "subscription_products_unavailable": "subscription.unavailable",
    "subscription_manage": "subscription.manage",
    "subscription_upgrade_title": "subscription.upgrade_title",
    "subscription_restore_purchases": "subscription.restore_purchases",
    "subscription_onboarding_no_payment": "subscription.onboarding.no_payment_due_now",
    "subscription_onboarding_trial_title": "subscription.onboarding.trial_title_fallback",
    "subscription_onboarding_annual_price": "subscription.onboarding.annual_billing_after_trial",
    "subscription_onboarding_feature_video": "subscription.onboarding.feature.video_to_text",
    "subscription_onboarding_feature_capture": "subscription.onboarding.feature.capture_anywhere",
    "subscription_onboarding_feature_skills": "subscription.onboarding.feature.ai_skills",
    "subscription_active_privileges": "subscription.active_privileges",
    "subscription_badge_best_value": "subscription.badge.best_value",
    "subscription_badge_flexible": "subscription.badge.flexible",
    "subscription_badge_free_trial_format": "subscription.badge.free_trial",
    "subscription_benefit_custom_skills_title": "subscription.benefit.custom_skills.title",
    "subscription_benefit_custom_skills_subtitle": "subscription.benefit.custom_skills.subtitle",
    "subscription_benefit_flexible_capture_title": "subscription.benefit.flexible_capture.title",
    "subscription_benefit_flexible_capture_subtitle": "subscription.benefit.flexible_capture.subtitle",
    "subscription_benefit_unlimited_chat_title": "subscription.benefit.unlimited_chat.title",
    "subscription_benefit_unlimited_chat_subtitle": "subscription.benefit.unlimited_chat.subtitle",
    "subscription_benefit_deep_dives_title": "subscription.benefit.deep_dives.title",
    "subscription_benefit_deep_dives_subtitle": "subscription.benefit.deep_dives.subtitle",
    "subscription_billing_period_monthly": "subscription.billing_period.monthly",
    "subscription_billing_period_yearly": "subscription.billing_period.yearly",
    "subscription_cta_start_free_trial_format": "subscription.cta.start_free_trial",
    "subscription_cta_start_monthly": "subscription.cta.start_monthly",
    "subscription_discount_save_percent": "subscription.discount.save_percent",
    "subscription_equivalent_monthly_billed_yearly_format": "subscription.equivalent_monthly_billed_yearly",
    "subscription_free_trial_then_price_format": "subscription.free_trial_then_price",
    "subscription_interval_monthly": "subscription.interval.monthly",
    "subscription_interval_yearly": "subscription.interval.yearly",
    "subscription_loading_prices": "subscription.loading_prices",
    "subscription_onboarding_cta_next": "subscription.onboarding.cta.next",
    "subscription_onboarding_trial_title_format": "subscription.onboarding.trial_title",
    "subscription_onboarding_weekly_price_after_trial_format": "subscription.onboarding.weekly_price_after_trial",
    "subscription_plan_annual": "subscription.plan.annual",
    "subscription_plan_monthly": "subscription.plan.monthly",
    "subscription_price_per_year_format": "subscription.price_per_year",
    "subscription_privacy_policy": "subscription.privacy_policy",
    "subscription_renews_on": "subscription.renews_on",
    "subscription_status_active": "subscription.status.active",
    "subscription_terms_of_use": "subscription.terms_of_use",
    "subscription_footer_renewal_disclaimer": "subscription.footer.renewal_disclaimer",
    "voice_error_permission": "speech_recognizer.error.microphone_permission_required",
    "voice_error_start": "speech_recognizer.error.failed_to_start_recording_short",
    "voice_error_empty": "error.recording.pending.audio_empty",
    "voice_processing_error": "error.recording.pending.unknown",
    "voice_processing_stage_transcribing_title": "voice_processing.stage.transcribing.title",
    "voice_processing_stage_transcribing_subtitle": "voice_processing.stage.transcribing.subtitle",
    "voice_processing_stage_refining_title": "voice_processing.stage.refining.title",
    "voice_processing_stage_refining_subtitle": "voice_processing.stage.refining.subtitle",
    "voice_processing_persistent_hint": "voice_processing.persistent_hint",
    "voice_start": "quick_capture.accessibility.record",
    "voice_refined": "note_detail.overlay.refined",
    "voice_show_original": "note_detail.overlay.show_original",
    "pending_recordings_title": "pending_recordings.title",
    "pending_recordings_empty": "pending_recordings.empty",
    "pending_recordings_save_as_note": "pending_recordings.save_as_note",
    "pending_recordings_saving": "pending_recordings.saving",
    "pending_recordings_saved": "pending_recordings.saved",
    "pending_recordings_toast_note_saved": "pending_recordings.toast.note_saved",
    "pending_recordings_toast_save_failed": "pending_recordings.toast.save_failed",
    "pending_recordings_error_unable_to_prepare_playback": "pending_recordings.error.unable_to_prepare_playback",
    "pending_recordings_error_unable_to_start_playback": "pending_recordings.error.unable_to_start_playback",
    "pending_recordings_error_transcription_failed": "error.recording.pending.unknown",
    "transcription_failure_title": "transcription.failure.title",
    "onboarding_login_prompt": "onboarding.flow.login.prompt",
    "onboarding_login_action": "onboarding.flow.login.action",
    "onboarding_page_save_video_title": "onboarding.flow.save_video.title",
    "onboarding_page_extract_title": "onboarding.flow.extract_ideas.title",
    "onboarding_page_hooks_title": "onboarding.flow.generate_hooks.stage.title",
    "onboarding_page_skills_title": "onboarding.flow.ai_skills.title",
    "onboarding_welcome_note_content": "onboarding.welcome_note.content",
    "subscription_onboarding_title": "subscription.onboarding.title",
    "subscription_cta_start_annual": "subscription.cta.start_annual",
    "creator_skills_title": "home.creator_skills.title",
    "recipes_title": "recipes.title",
    "note_detail_ai_skills_title": "note_detail.ai_skills.sheet.title",
    "note_detail_ai_skills_empty_title": "note_detail.ai_skills.empty.title",
    "note_detail_ai_skills_empty_message": "note_detail.ai_skills.empty.message",
    "creator_skills_no_notes": "home.recipe_picker.empty.message",
    "creator_skills_translate_title": "translate_sheet.title",
    "creator_skills_category_think": "agent_recipe.category.think",
    "creator_skills_category_shape": "agent_recipe.category.shape",
    "creator_skills_category_publish": "note_section.published",
    "creator_skills_installed": "recipes.section.installed",
    "creator_skills_available": "recipes.section.available",
    "creator_skills_add": "recipes.action.add",
    "creator_skills_remove": "recipes.action.remove",
    "creator_skills_custom_description": "recipes.custom_skill",
    "creator_skills_custom_name": "recipes.create_sheet.name_placeholder",
    "creator_skills_custom_instruction": "recipes.create_sheet.prompt",
    "creator_skills_choose_note": "home.recipe_picker.choose_notes",
    "creator_skills_custom_create": "recipes.custom.create.title",
    "creator_skills_custom_badge": "recipes.custom.create.badge",
    "creator_skills_custom_subtitle": "recipes.custom.create.subtitle",
    "ai_skill_preview_title": "note_detail.ai_skills.preview.title",
    "ai_skill_preview_context_note": "note_detail.ai_skills.preview.note_context",
    "ai_skill_preview_context_selection": "note_detail.ai_skills.preview.selection_context",
    "ai_skill_error_title": "note_detail.ai_skills.error.title",
    "ai_skills_result_copy_action": "ai_skills.result.action.copy_block",
    "ai_skills_result_copied": "ai_skills.result.copy_success",
    "recipes_delete_skill_title": "recipes.alert.delete_skill.title",
    "recipes_delete_skill_message": "recipes.alert.delete_skill.message",
    "recipe_why_viral_description": "agent_recipe.why_viral.description",
    "recipe_summarize_description": "agent_recipe.summarize.description",
    "recipe_translate_description": "agent_recipe.translate.description",
    "recipe_humanizer_description": "agent_recipe.humanizer.description",
    "recipe_rewrite_description": "agent_recipe.rewrite.description",
    "recipe_style_match_description": "agent_recipe.style_match.description",
    "recipe_hook_generator_description": "agent_recipe.hook_generator.description",
    "recipe_caption_pack_description": "agent_recipe.caption_pack.description",
    "recipe_timed_script_description": "agent_recipe.timed_script.description",
    "recipe_repurpose_pack_description": "agent_recipe.repurpose_pack.description",
    "caption_pack_settings_title": "caption_pack.settings.title",
    "caption_pack_settings_platforms": "caption_pack.settings.platforms",
    "caption_pack_platform_tiktok": "caption_pack.platform.tiktok",
    "caption_pack_platform_instagram_reels": "caption_pack.platform.instagram_reels",
    "caption_pack_platform_youtube_shorts": "caption_pack.platform.youtube_shorts",
    "caption_pack_platform_youtube_long_video": "caption_pack.platform.youtube_long_video",
    "caption_pack_settings_goal": "caption_pack.settings.goal",
    "caption_pack_goal_start_discussion": "caption_pack.goal.start_discussion",
    "caption_pack_goal_get_saves": "caption_pack.goal.get_saves",
    "caption_pack_goal_get_shares": "caption_pack.goal.get_shares",
    "caption_pack_goal_drive_follows": "caption_pack.goal.drive_follows",
    "caption_pack_settings_tone": "caption_pack.settings.tone",
    "caption_pack_tone_casual_useful": "caption_pack.tone.casual_useful",
    "caption_pack_tone_educational": "caption_pack.tone.educational",
    "caption_pack_tone_bold": "caption_pack.tone.bold",
    "caption_pack_tone_story_driven": "caption_pack.tone.story_driven",
    "caption_pack_tone_creator_voice": "caption_pack.tone.creator_voice",
    "caption_pack_settings_output_style": "caption_pack.settings.output_style",
    "caption_pack_output_style_concise": "caption_pack.output_style.concise",
    "caption_pack_output_style_balanced": "caption_pack.output_style.balanced",
    "caption_pack_output_style_detailed": "caption_pack.output_style.detailed",
    "timed_script_settings_title": "timed_script.settings.title",
    "timed_script_settings_duration": "timed_script.settings.duration",
    "timed_script_duration_30": "timed_script.duration.30",
    "timed_script_duration_45": "timed_script.duration.45",
    "timed_script_duration_60": "timed_script.duration.60",
    "brand_voice_settings_title": "brand_voice.settings.title",
    "brand_voice_settings_tone_label": "brand_voice.settings.tone_label",
    "brand_voice_settings_tone_placeholder": "brand_voice.settings.tone_placeholder",
    "brand_voice_settings_tone_help": "brand_voice.settings.tone_help",
    "brand_voice_settings_audience_label": "brand_voice.settings.audience_label",
    "brand_voice_settings_audience_placeholder": "brand_voice.settings.audience_placeholder",
    "brand_voice_settings_audience_help": "brand_voice.settings.audience_help",
    "brand_voice_settings_cta_label": "brand_voice.settings.cta_label",
    "brand_voice_settings_cta_placeholder": "brand_voice.settings.cta_placeholder",
    "brand_voice_settings_cta_help": "brand_voice.settings.cta_help",
    "brand_voice_settings_avoid_label": "brand_voice.settings.avoid_label",
    "brand_voice_settings_avoid_help": "brand_voice.settings.avoid_help",
    "brand_voice_settings_sample_label": "brand_voice.settings.sample_label",
    "brand_voice_settings_sample_help": "brand_voice.settings.sample_help",
    "repurpose_pack_settings_title": "repurpose_pack.settings.title",
    "repurpose_pack_settings_formats": "repurpose_pack.settings.formats",
    "repurpose_pack_settings_thread_length": "repurpose_pack.settings.thread_length",
    "repurpose_pack_settings_tone": "repurpose_pack.settings.tone",
    "repurpose_pack_settings_cta": "repurpose_pack.settings.cta",
    "repurpose_pack_format_x_post": "repurpose_pack.format.x_post",
    "repurpose_pack_format_linkedin": "repurpose_pack.format.linkedin",
    "repurpose_pack_format_threads": "repurpose_pack.format.threads",
    "repurpose_pack_format_facebook_page": "repurpose_pack.format.facebook_page",
    "repurpose_pack_format_newsletter": "repurpose_pack.format.newsletter",
    "repurpose_pack_format_instagram_carousel": "repurpose_pack.format.instagram_carousel",
    "repurpose_pack_format_pinterest_pin": "repurpose_pack.format.pinterest_pin",
    "repurpose_pack_format_youtube_community": "repurpose_pack.format.youtube_community",
    "repurpose_pack_thread_length_short": "repurpose_pack.thread_length.short",
    "repurpose_pack_thread_length_medium": "repurpose_pack.thread_length.medium",
    "repurpose_pack_thread_length_long": "repurpose_pack.thread_length.long",
    "ai_chat_context_notes_format": "ai_chat.context_notes_format",
    "ai_chat_empty_title": "ai_chat.empty.ready_title",
    "ai_chat_empty_message": "ai_chat.empty.ready_message",
    "ai_chat_empty_no_notes_title": "ai_chat.empty.no_notes_title",
    "ai_chat_empty_no_notes_message": "ai_chat.empty.no_notes_message",
    "ai_chat_input_placeholder": "ai_chat.input_placeholder",
    "ai_chat_saved": "ai_chat.message.saved",
    "ai_chat_skills_title": "ai_chat.skills_title",
    "ai_chat_skills_empty": "ai_chat.skills_empty",
    "ai_chat_thinking": "ai_chat.thinking",
    "teleprompter_title": "note_detail.header.action.teleprompter",
    "teleprompter_action_open": "note_detail.header.action.teleprompter",
    "teleprompter_accessibility_camera_settings": "teleprompter.accessibility.camera_settings",
    "teleprompter_accessibility_close": "teleprompter.accessibility.close",
    "teleprompter_action_edit_script": "teleprompter.action.edit_script",
    "teleprompter_action_preview": "teleprompter.action.preview",
    "teleprompter_action_prompt_settings": "teleprompter.action.prompt_settings",
    "teleprompter_script_empty_placeholder": "teleprompter.script.empty_placeholder",
    "teleprompter_camera_resolution": "teleprompter.camera.resolution",
    "teleprompter_prompt_speed": "teleprompter.prompt.speed",
    "teleprompter_prompt_font_size": "teleprompter.prompt.font_size",
    "teleprompter_prompt_text_color": "teleprompter.prompt.text_color",
    "teleprompter_prompt_slow": "teleprompter.prompt.slow",
    "teleprompter_prompt_fast": "teleprompter.prompt.fast",
    "teleprompter_prompt_small": "teleprompter.prompt.small",
    "teleprompter_prompt_large": "teleprompter.prompt.large",
    "teleprompter_camera_countdown": "teleprompter.camera.countdown",
    "teleprompter_camera_switch": "teleprompter.camera.switch",
    "teleprompter_countdown_none": "teleprompter.countdown.off",
    "teleprompter_countdown_three": "teleprompter.countdown.three",
    "teleprompter_countdown_five": "teleprompter.countdown.five",
    "teleprompter_start_recording": "teleprompter.accessibility.start_recording",
    "teleprompter_stop_recording": "teleprompter.accessibility.stop_recording",
    "teleprompter_clip_delete": "teleprompter.clip.delete",
    "teleprompter_text_color_white": "teleprompter.color.white",
    "teleprompter_text_color_yellow": "teleprompter.color.yellow",
    "teleprompter_text_color_black": "teleprompter.color.black",
    "teleprompter_text_color_pink": "teleprompter.color.pink",
    "teleprompter_text_color_green": "teleprompter.color.green",
    "teleprompter_text_color_blue": "teleprompter.color.blue",
    "teleprompter_text_color_purple": "teleprompter.color.purple",
    "teleprompter_editor_title": "teleprompter.editor.title",
    "teleprompter_export_processing": "teleprompter.export.processing",
    "teleprompter_preview_title": "teleprompter.preview.title",
    "teleprompter_preview_save_to_gallery": "teleprompter.preview.save_to_photos",
    "teleprompter_preview_saved": "teleprompter.preview.save_success",
    "teleprompter_preview_save_failed": "teleprompter.preview.save_failed",
    "teleprompter_preview_save_permission_denied": "teleprompter.preview.save_permission_denied",
    "teleprompter_preview_share": "teleprompter.preview.share",
    "teleprompter_permission_title": "teleprompter.permission.title",
    "teleprompter_permission_message": "teleprompter.permission.message",
    "teleprompter_permission_open_settings": "teleprompter.permission.open_settings",
    "teleprompter_error_title": "teleprompter.error.title",
    "teleprompter_error_camera_unavailable": "teleprompter.error.camera_unavailable",
    "teleprompter_error_export_failed": "teleprompter.error.export_failed",
    "teleprompter_error_low_storage": "teleprompter.error.low_storage",
    "teleprompter_error_permission_required": "teleprompter.error.permission_required",
    "teleprompter_error_record_failed": "teleprompter.error.record_failed",
    "teleprompter_error_recording_interrupted": "teleprompter.error.recording_interrupted",
    "teleprompter_error_too_many_clips": "teleprompter.error.too_many_clips",
    "note_export_markdown": "settings.export.format_markdown",
    "note_export_failed_title": "note_detail.alert.export_failed.title",
    "note_export_failed_message": "note_detail.export.error.unable_to_export_note",
    "settings_export_all_notes": "settings.data.export_all_notes",
    "settings_export_no_notes": "settings.export.no_notes",
    "settings_export_failed": "export.error.unable_to_export_notes",
    "settings_export_benefit_ai_body": "settings.export.benefit_ai_body",
    "settings_export_benefit_ai_title": "settings.export.benefit_ai_title",
    "settings_export_benefit_move_body": "settings.export.benefit_move_body",
    "settings_export_benefit_move_title": "settings.export.benefit_move_title",
    "settings_export_benefit_portable_body": "settings.export.benefit_portable_body",
    "settings_export_benefit_portable_title": "settings.export.benefit_portable_title",
    "settings_export_benefits_title": "settings.export.benefits_title",
    "settings_export_cta": "settings.export.cta",
    "settings_export_sheet_exporting": "settings.export.exporting",
    "settings_export_format": "settings.export.format",
    "settings_export_format_markdown": "settings.export.format_markdown",
    "settings_export_nav_title": "settings.export.nav_title",
    "settings_export_subtitle": "settings.export.subtitle",
    "settings_export_title": "settings.export.title",
    "settings_export_total_notes": "settings.export.total_notes",
    "export_progress_summary_format": "export.progress.summary",
    "export_success_summary": "export.success.summary",
    "export_progress_cancelled": "export.progress.cancelled",
    "export_progress_complete": "export.progress.complete",
    "settings_voice_language": "settings.voice.title",
    "settings_voice_title": "settings.voice.title",
    "settings_voice_auto": "settings.voice.mode.auto_detect",
    "settings_voice_prefer": "settings.voice.mode.preferred_language",
    "settings_voice_auto_help": "settings.voice.auto_help",
    "settings_voice_preferred_help": "settings.voice.preferred_help",
    "settings_voice_search": "settings.voice.search_placeholder",
    "settings_voice_not_set": "settings.voice.summary.not_set",
    "settings_media_sections": "settings.media_link_sections.title",
    "settings_media_sections_title": "settings.media_link_sections.title",
    "settings_media_sections_help": "settings.media_link_sections.subtitle",
    "settings_send_feedback": "settings.support.send_feedback",
    "about_brand": "about.brand",
    "about_intro": "about.intro",
    "about_section_1_body_1": "about.section.1.body.1",
    "about_section_1_body_2": "about.section.1.body.2",
    "about_section_1_body_3": "about.section.1.body.3",
    "about_section_1_quote": "about.section.1.quote",
    "about_section_1_title": "about.section.1.title",
    "about_section_2_body_1": "about.section.2.body.1",
    "about_section_2_body_2": "about.section.2.body.2",
    "about_section_2_body_3": "about.section.2.body.3",
    "about_section_2_quote": "about.section.2.quote",
    "about_section_2_title": "about.section.2.title",
    "about_section_3_body_1": "about.section.3.body.1",
    "about_section_3_body_2": "about.section.3.body.2",
    "about_section_3_body_3": "about.section.3.body.3",
    "about_section_3_quote": "about.section.3.quote",
    "about_section_3_title": "about.section.3.title",
    "about_section_4_body_1": "about.section.4.body.1",
    "about_section_4_body_2": "about.section.4.body.2",
    "about_section_4_body_3": "about.section.4.body.3",
    "about_section_4_quote": "about.section.4.quote",
    "about_section_4_title": "about.section.4.title",
    "about_subtitle": "about.subtitle",
    "about_tagline": "about.tagline",
    "about_vision_body": "about.vision.body",
    "about_vision_title": "about.vision.title",
    "about_workflow_ai_body": "about.workflow.ai.body",
    "about_workflow_ai_title": "about.workflow.ai.title",
    "about_workflow_capture_body": "about.workflow.capture.body",
    "about_workflow_capture_title": "about.workflow.capture.title",
    "about_workflow_reuse_body": "about.workflow.reuse.body",
    "about_workflow_reuse_title": "about.workflow.reuse.title",
    "about_workflow_subtitle": "about.workflow.subtitle",
    "about_workflow_title": "about.workflow.title",
    "home_credit_gift_message": "home.credit_gift.message",
    "home_credit_gift_balance_hint": "home.credit_gift.balance_hint",
    "weekly_topics_title": "weekly_topics.title",
    "weekly_topics_preview_title": "weekly_topics.preview.title",
    "weekly_topics_preview_headline": "weekly_topics.preview.headline",
    "weekly_topics_preview_headline_highlight": "weekly_topics.preview.headline_highlight",
    "weekly_topics_preview_message": "weekly_topics.preview.message",
    "weekly_topics_preview_sources_label": "weekly_topics.preview.sources_label",
    "weekly_topics_preview_result_label": "weekly_topics.preview.result_label",
    "weekly_topics_preview_illustration_label": "weekly_topics.preview.illustration_label",
    "weekly_topics_preview_illustration_accessibility": "weekly_topics.preview.illustration_accessibility",
    "weekly_topics_preview_try_action": "weekly_topics.preview.try_action",
    "weekly_topics_preview_skip_action": "weekly_topics.preview.skip_action",
    "weekly_topics_more_actions": "weekly_topics.more_actions",
    "weekly_topics_history_title": "weekly_topics.history.title",
    "weekly_topics_enable_title": "weekly_topics.enable.title",
    "weekly_topics_enable_message": "weekly_topics.enable.message",
    "weekly_topics_enable_action": "weekly_topics.enable.action",
    "weekly_topics_waiting_title": "weekly_topics.waiting.title",
    "weekly_topics_waiting_no_sources": "weekly_topics.waiting.no_sources",
    "weekly_topics_waiting_ready": "weekly_topics.waiting.ready",
    "weekly_topics_error_title": "weekly_topics.error.title",
    "weekly_topics_error_load": "weekly_topics.error.load",
    "weekly_topics_error_save": "weekly_topics.error.save",
    "weekly_topics_error_regenerate": "weekly_topics.error.regenerate",
    "weekly_topics_report_inspiration_label": "weekly_topics.report.inspiration_label",
    "weekly_topics_report_date_range": "weekly_topics.report.date_range",
    "weekly_topics_report_summary": "weekly_topics.report.summary",
    "weekly_topics_history_summary": "weekly_topics.history.summary",
    "weekly_topics_history_empty": "weekly_topics.history.empty",
    "weekly_topics_topic_progress": "weekly_topics.topic.progress",
    "weekly_topics_topic_related_sources": "weekly_topics.topic.related_sources",
    "weekly_topics_topic_expand_hint": "weekly_topics.topic.expand_hint",
    "weekly_topics_topic_collapse_hint": "weekly_topics.topic.collapse_hint",
    "weekly_topics_source_deleted": "weekly_topics.source.deleted",
    "weekly_topics_source_in_trash": "weekly_topics.source.in_trash",
    "weekly_topics_source_open": "weekly_topics.source.open",
    "weekly_topics_regenerate_confirm_title": "weekly_topics.regenerate.confirm_title",
    "weekly_topics_regenerate_confirm_message": "weekly_topics.regenerate.confirm_message",
    "weekly_topics_regenerate_action": "weekly_topics.regenerate.action",
    "weekly_topics_regenerate_progress": "weekly_topics.regenerate.progress",
    "weekly_topics_schedule_title": "weekly_topics.schedule.title",
    "weekly_topics_schedule_message": "weekly_topics.schedule.message",
    "weekly_topics_schedule_action": "weekly_topics.schedule.action",
    "weekly_topics_settings_title": "weekly_topics.settings.title",
    "weekly_topics_settings_enabled": "weekly_topics.settings.enabled",
    "weekly_topics_settings_weekday": "weekly_topics.settings.weekday",
    "weekly_topics_settings_time": "weekly_topics.settings.time",
    "weekly_topics_settings_source_scope": "weekly_topics.settings.source_scope",
    "notification_import_ready_title": "notification.import_ready.title",
    "notification_import_ready_body": "notification.import_ready.body",
    "notification_first_creation_title": "notification.first_creation.title",
    "notification_first_creation_body": "notification.first_creation.body",
    "notification_weekly_topics_title": "notification.weekly_topics.title",
    "notification_weekly_topics_body": "notification.weekly_topics.body",
    "notification_permission_import_title": "notification.permission.import.title",
    "notification_permission_import_message": "notification.permission.import.message",
    "notification_permission_import_enable": "notification.permission.import.enable",
    "notification_permission_import_not_now": "notification.permission.import.not_now",
    "tags_color_option_format": "tag.color.accessibility",
    "trash_empty_confirm_title": "home.alert.empty_recycle_bin.title",
    "trash_empty_confirm_message": "home.alert.empty_recycle_bin.message",
}

# The iOS capture heading is intentionally styled as three adjacent spans. Keep
# Android's single Text resource sourced from the same three active iOS keys.
COMPOSITE_KEY_OVERRIDES = {
    "onboarding_page_capture_title": (
        "onboarding.flow.capture.title.prefix",
        "onboarding.flow.capture.title.highlight",
        "onboarding.flow.capture.title.suffix",
    ),
}


def normalized(value: str) -> str:
    value = value.replace("%1$s", "%@").replace("%2$s", "%@")
    value = value.replace("%1$d", "%lld").replace("%2$d", "%lld")
    value = value.replace("…", "...").replace("’", "'")
    return re.sub(r"\s+", " ", value).strip().lower()


def key_tokens(key: str) -> set[str]:
    ignored = {"action", "title", "message", "label", "placeholder", "format", "common"}
    return set(re.split(r"[._]+", key)) - ignored


def localized_value(entry: dict, language: str) -> str | None:
    unit = entry.get("localizations", {}).get(language, {}).get("stringUnit", {})
    return unit.get("value")


def restore_android_placeholders(localized: str, english: str) -> str:
    android_tokens, _ = scan_format_tokens(english)
    placeholders = [token for token in android_tokens if token.consumes_argument]
    if not placeholders:
        return localized
    by_type = {
        "s": [token.raw for token in placeholders if token.conversion.lower() == "s"],
        "d": [token.raw for token in placeholders if token.conversion.lower() == "d"],
    }
    by_index = {
        token.index: (token.raw, token.conversion.lower())
        for token in placeholders
        if token.index is not None and token.conversion.lower() in {"s", "d"}
    }
    positions = {"s": 0, "d": 0}

    def replace(match: re.Match[str]) -> str:
        kind = "s" if match.group("kind") == "@" else "d"
        index_text = match.group("index")
        if index_text:
            indexed = by_index.get(int(index_text))
            if indexed:
                indexed_placeholder, indexed_kind = indexed
                if indexed_kind == kind:
                    return indexed_placeholder
            return match.group(0)
        choices = by_type[kind]
        if not choices:
            return match.group(0)
        index = min(positions[kind], len(choices) - 1)
        positions[kind] += 1
        return choices[index]

    return re.sub(
        r"%(?:(?P<index>\d+)\$)?[-+ 0#,(]*\d*(?:\.\d+)?(?P<kind>lld|ld|d|@)",
        replace,
        localized,
    )


def android_xml_escape(value: str) -> str:
    value = value.replace("\n", "\\n")
    value = value.replace("'", "\\'")
    return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def choose_exact_key(android_name: str, english: str, ios_strings: dict) -> str | None:
    candidates = []
    for key, entry in ios_strings.items():
        ios_english = localized_value(entry, "en")
        if ios_english and normalized(ios_english) == normalized(english):
            overlap = len(key_tokens(android_name) & key_tokens(key))
            candidates.append((overlap, key))
    return max(candidates)[1] if candidates else None


def safe_localized_value(
    android_name: str,
    english: str,
    ios_key: str | None,
    ios_language: str,
    ios_strings: dict,
) -> str:
    """Return a compatible translation, falling back safely when iOS data is stale."""
    if not ios_key:
        return english

    ios_entry = ios_strings.get(ios_key)
    if ios_entry is None:
        print(
            f"warning: {android_name}: iOS key {ios_key!r} no longer exists; keeping English",
            file=sys.stderr,
        )
        return english

    value = localized_value(ios_entry, ios_language) or english
    value = restore_android_placeholders(value, english)
    token_errors = format_token_errors(value)
    if token_errors or placeholder_signature(value) != placeholder_signature(english):
        details = "; ".join(token_errors) if token_errors else "placeholder signature differs"
        print(
            f"warning: {android_name}: unsafe translation from {ios_key!r} ({details}); "
            "keeping English",
            file=sys.stderr,
        )
        return english
    return value


def safe_composite_localized_value(
    android_name: str,
    english: str,
    ios_keys: tuple[str, ...],
    ios_language: str,
    ios_strings: dict,
) -> str:
    """Join the active iOS styled spans into one safe Android string."""
    parts: list[str] = []
    for ios_key in ios_keys:
        ios_entry = ios_strings.get(ios_key)
        if ios_entry is None:
            print(
                f"warning: {android_name}: iOS key {ios_key!r} no longer exists; keeping English",
                file=sys.stderr,
            )
            return english
        value = localized_value(ios_entry, ios_language)
        if value is None:
            value = localized_value(ios_entry, "en")
        if value is None:
            return english
        parts.append(value)

    combined = "".join(parts).strip()
    combined = restore_android_placeholders(combined, english)
    token_errors = format_token_errors(combined)
    if token_errors or placeholder_signature(combined) != placeholder_signature(english):
        return english
    return combined


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("locale", choices=LOCALES)
    parser.add_argument(
        "--update-existing",
        action="store_true",
        help="Print an apply_patch payload that replaces only English fallbacks in an existing locale file.",
    )
    args = parser.parse_args()
    ios_language, values_dir = LOCALES[args.locale]

    ios_strings = json.loads(IOS_STRINGS.read_text())["strings"]
    android_root = ET.parse(ANDROID_STRINGS).getroot()
    plural_count = len(android_root.findall("plurals"))
    if plural_count and not args.update_existing:
        parser.error(
            f"full locale generation is disabled because the Android source contains "
            f"{plural_count} plurals; add strings and plurals manually, then run "
            "--update-existing and validate_localizations.py"
        )
    if plural_count:
        print(
            f"note: leaving {plural_count} existing plural resources unchanged; "
            "validate them with validate_localizations.py",
            file=sys.stderr,
        )

    translated = []
    for node in android_root.findall("string"):
        name = node.attrib["name"]
        english = "".join(node.itertext())
        composite_keys = COMPOSITE_KEY_OVERRIDES.get(name)
        if composite_keys:
            value = safe_composite_localized_value(
                name,
                english,
                composite_keys,
                ios_language,
                ios_strings,
            )
        else:
            ios_key = SEMANTIC_KEY_OVERRIDES.get(name) or choose_exact_key(name, english, ios_strings)
            value = safe_localized_value(name, english, ios_key, ios_language, ios_strings)
        translated.append((name, android_xml_escape(value)))

    target = f"android/app/src/main/res/{values_dir}/strings.xml"
    if args.update_existing:
        target_root = ET.parse(ROOT / target).getroot()
        current_values = {
            node.attrib["name"]: "".join(node.itertext())
            for node in target_root.findall("string")
        }
        changes = [
            (name, current_values[name], value)
            for name, value in translated
            if name in current_values
            and current_values[name] == next(
                "".join(node.itertext())
                for node in android_root.findall("string")
                if node.attrib["name"] == name
            )
            and android_xml_escape(current_values[name]) != value
        ]
        print("*** Begin Patch")
        print(f"*** Update File: {target}")
        for name, current, value in changes:
            print("@@")
            print(f'-    <string name="{name}">{android_xml_escape(current)}</string>')
            print(f'+    <string name="{name}">{value}</string>')
        print("*** End Patch")
        return

    print("*** Begin Patch")
    print(f"*** Add File: {target}")
    print("+<resources>")
    for name, value in translated:
        print(f'+    <string name="{name}">{value}</string>')
    print("+</resources>")
    print("*** End Patch")


if __name__ == "__main__":
    main()
