from __future__ import annotations

from contextlib import redirect_stderr
import io
import re
import sys
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
from unittest.mock import patch


sys.path.insert(0, str(Path(__file__).resolve().parent))

import generate_ios_locale_patch as generator


def ios_entry(language: str, value: str) -> dict:
    return {
        "localizations": {
            language: {
                "stringUnit": {
                    "state": "translated",
                    "value": value,
                }
            }
        }
    }


class GeneratorSafetyTests(unittest.TestCase):
    def test_all_semantic_override_targets_exist_in_current_ios_catalog(self) -> None:
        ios_strings = generator.json.loads(generator.IOS_STRINGS.read_text())["strings"]
        missing = set(generator.SEMANTIC_KEY_OVERRIDES.values()) - set(ios_strings)
        self.assertEqual(missing, set())

        composite_targets = {
            key
            for keys in generator.COMPOSITE_KEY_OVERRIDES.values()
            for key in keys
        }
        self.assertEqual(composite_targets - set(ios_strings), set())

    def test_simplified_chinese_is_a_supported_target(self) -> None:
        self.assertEqual(generator.LOCALES["zh-Hans"], ("zh-Hans", "values-zh-rCN"))

    def test_confirmed_unsafe_semantic_overrides_are_removed(self) -> None:
        unsafe_names = {
            "ai_chat_error_format",
            "auth_google_invalid_credential",
            "auth_login_legal_plain",
            "creator_skills_add_more",
            "creator_skills_choose_note_message",
            "note_delete",
            "note_export",
            "trash_empty_action",
            "voice_processing",
        }
        self.assertTrue(unsafe_names.isdisjoint(generator.SEMANTIC_KEY_OVERRIDES))

    def test_ios_aligned_chat_and_skill_copy_keep_semantic_overrides(self) -> None:
        self.assertEqual(
            generator.SEMANTIC_KEY_OVERRIDES["ai_chat_empty_title"],
            "ai_chat.empty.ready_title",
        )
        self.assertEqual(
            generator.SEMANTIC_KEY_OVERRIDES["ai_chat_skills_empty"],
            "ai_chat.skills_empty",
        )
        self.assertEqual(
            generator.SEMANTIC_KEY_OVERRIDES["ai_skills_result_copied"],
            "ai_skills.result.copy_success",
        )
        self.assertEqual(
            generator.SEMANTIC_KEY_OVERRIDES["recipes_title"],
            "recipes.title",
        )

    def test_active_android_copy_matches_current_ios_canonical_values(self) -> None:
        active_resources = {
            "common_cancel",
            "common_continue",
            "common_delete",
            "common_save",
            "note_actions",
            "note_move_to_published",
            "quick_capture_link_import_placeholder_title",
            "quick_capture_link_import_placeholder_format",
            "link_import_processing",
            "link_import_failed",
            "home_select_notes",
            "home_notes_syncing",
            "sidebar_tags_release_to_unnest",
            "sidebar_trash_drag_to_delete",
            "sidebar_trash_release_to_delete",
            "sidebar_stats_today",
            "note_source_accessibility_open",
            "settings_export_failed_title",
            "home_batch_tag_empty",
            "home_batch_tag_partial",
            "home_batch_delete_title",
            "home_ask_large_selection_title",
            "home_ask_soft_limit_message",
            "home_ask_too_many_notes_title",
            "home_ask_hard_limit_message",
            "auth_apple_failed",
            "auth_login_error_invalid_verification_code",
            "auth_login_error_network",
            "auth_login_error_send_failed",
            "auth_login_error_too_many_requests",
            "auth_login_error_verification_failed",
            "voice_start",
            "voice_error_permission",
            "voice_error_start",
            "voice_error_empty",
            "pending_recordings_title",
            "pending_recordings_empty",
            "pending_recordings_save_as_note",
            "pending_recordings_saving",
            "pending_recordings_saved",
            "pending_recordings_toast_note_saved",
            "pending_recordings_toast_save_failed",
            "pending_recordings_error_unable_to_prepare_playback",
            "pending_recordings_error_unable_to_start_playback",
            "pending_recordings_error_transcription_failed",
            "transcription_failure_title",
            "creator_skills_no_notes",
            "creator_skills_translate_title",
            "creator_skills_category_think",
            "creator_skills_category_shape",
            "creator_skills_category_publish",
            "creator_skills_installed",
            "creator_skills_available",
            "creator_skills_add",
            "creator_skills_remove",
            "creator_skills_custom_description",
            "creator_skills_choose_note",
            "ai_skill_preview_context_note",
            "ai_skill_preview_context_selection",
            "ai_skill_error_title",
            "recipe_why_viral_description",
            "recipe_summarize_description",
            "recipe_translate_description",
            "recipe_humanizer_description",
            "recipe_rewrite_description",
            "recipe_style_match_description",
            "recipe_hook_generator_description",
            "recipe_caption_pack_description",
            "recipe_timed_script_description",
            "recipe_repurpose_pack_description",
            "ai_chat_thinking",
            "settings_account_section",
            "settings_terms",
            "settings_permissions",
            "settings_delete_account_confirm_title",
            "settings_delete_account_confirm_message",
            "note_export_markdown",
            "note_export_failed_title",
            "note_export_failed_message",
            "note_detail_delete_confirmation_title",
            "note_detail_delete_confirmation_message",
            "settings_export_all_notes",
            "settings_export_failed",
            "export_success_summary",
            "export_progress_cancelled",
            "export_progress_complete",
            "settings_voice_language",
            "settings_voice_title",
            "settings_voice_auto",
            "settings_voice_prefer",
            "settings_voice_auto_help",
            "settings_voice_preferred_help",
            "settings_voice_search",
            "settings_voice_not_set",
            "settings_media_sections",
            "settings_media_sections_title",
            "settings_media_sections_help",
        }
        active_resources.update(
            name
            for name in generator.SEMANTIC_KEY_OVERRIDES
            if name.startswith(
                (
                    "caption_pack_",
                    "timed_script_",
                    "brand_voice_settings_",
                    "repurpose_pack_",
                )
            )
        )
        ios_strings = generator.json.loads(generator.IOS_STRINGS.read_text())["strings"]
        android_root = ET.parse(generator.ANDROID_STRINGS).getroot()
        android_values = {
            node.attrib["name"]: "".join(node.itertext())
            for node in android_root.findall("string")
        }

        def runtime_text(value: str) -> str:
            return value.replace("\\n", "\n").replace("\\'", "'")

        for resource_name in sorted(active_resources):
            with self.subTest(resource=resource_name):
                ios_key = generator.SEMANTIC_KEY_OVERRIDES[resource_name]
                ios_english = generator.localized_value(ios_strings[ios_key], "en")
                self.assertIsNotNone(ios_english)
                expected = generator.restore_android_placeholders(
                    ios_english,
                    android_values[resource_name],
                )
                self.assertEqual(
                    runtime_text(android_values[resource_name]),
                    runtime_text(expected),
                )

    def test_every_mapped_resource_used_by_kotlin_matches_ios_english(self) -> None:
        """Keep reachable Android copy from silently drifting from the iOS source."""
        used_resources: set[str] = set()
        for path in (generator.ROOT / "android/app/src").rglob("*.kt"):
            used_resources.update(
                re.findall(r"R\.string\.([A-Za-z0-9_]+)", path.read_text())
            )

        ios_strings = generator.json.loads(generator.IOS_STRINGS.read_text())["strings"]
        android_root = ET.parse(generator.ANDROID_STRINGS).getroot()
        android_values = {
            node.attrib["name"]: "".join(node.itertext())
            for node in android_root.findall("string")
        }

        def runtime_text(value: str) -> str:
            return value.replace("\\n", "\n").replace("\\'", "'")

        mapped_resources = used_resources & generator.SEMANTIC_KEY_OVERRIDES.keys()
        self.assertGreater(len(mapped_resources), 400)
        for resource_name in sorted(mapped_resources):
            with self.subTest(resource=resource_name):
                ios_key = generator.SEMANTIC_KEY_OVERRIDES[resource_name]
                ios_english = generator.localized_value(ios_strings[ios_key], "en")
                self.assertIsNotNone(ios_english)
                android_value = android_values[resource_name]
                expected = generator.restore_android_placeholders(
                    ios_english,
                    android_value,
                )
                self.assertEqual(runtime_text(android_value), runtime_text(expected))

    def test_note_detail_delete_confirmation_matches_ios_in_every_locale(self) -> None:
        resource_names = (
            "note_detail_delete_confirmation_title",
            "note_detail_delete_confirmation_message",
        )
        ios_strings = generator.json.loads(generator.IOS_STRINGS.read_text())["strings"]
        locale_directories = {"en": "values"}
        locale_directories.update(
            {
                language: directory
                for language, directory in generator.LOCALES.values()
            }
        )

        for language, directory in locale_directories.items():
            path = generator.ROOT / f"android/app/src/main/res/{directory}/strings.xml"
            root = ET.parse(path).getroot()
            localized = {
                node.attrib["name"]: "".join(node.itertext())
                for node in root.findall("string")
            }
            for resource_name in resource_names:
                with self.subTest(language=language, resource=resource_name):
                    ios_key = generator.SEMANTIC_KEY_OVERRIDES[resource_name]
                    expected = generator.localized_value(ios_strings[ios_key], language)
                    if expected is None:
                        expected = generator.localized_value(ios_strings[ios_key], "en")
                    self.assertEqual(
                        localized[resource_name].replace("\\'", "'"),
                        expected,
                    )

    def test_reachable_semantic_copy_matches_ios_in_every_locale(self) -> None:
        resource_names = (
            "creator_skills_custom_instruction",
            "creator_skills_custom_name",
            "note_detail_recording_duration_progress",
            "note_pin_action",
            "note_unpin_action",
            "onboarding_first_action_step_progress",
            "settings_export_progress_packaging",
            "settings_export_progress_preparing",
            "settings_export_progress_writing",
            "tags_color_option_format",
            "trash_empty_confirm_message",
            "trash_empty_confirm_title",
            "voice_processing_error",
            "voice_processing_stage_transcribing_title",
            "voice_processing_stage_transcribing_subtitle",
            "voice_processing_stage_refining_title",
            "voice_processing_stage_refining_subtitle",
            "voice_processing_persistent_hint",
        )
        ios_strings = generator.json.loads(generator.IOS_STRINGS.read_text())["strings"]
        locale_directories = {"en": "values"}
        locale_directories.update(
            {
                language: directory
                for language, directory in generator.LOCALES.values()
            }
        )
        base_root = ET.parse(generator.ANDROID_STRINGS).getroot()
        base_values = {
            node.attrib["name"]: "".join(node.itertext())
            for node in base_root.findall("string")
        }

        for language, directory in locale_directories.items():
            path = generator.ROOT / f"android/app/src/main/res/{directory}/strings.xml"
            root = ET.parse(path).getroot()
            localized = {
                node.attrib["name"]: "".join(node.itertext())
                for node in root.findall("string")
            }
            for resource_name in resource_names:
                with self.subTest(language=language, resource=resource_name):
                    ios_key = generator.SEMANTIC_KEY_OVERRIDES[resource_name]
                    expected = generator.localized_value(ios_strings[ios_key], language)
                    if expected is None:
                        expected = generator.localized_value(ios_strings[ios_key], "en")
                    expected = generator.restore_android_placeholders(
                        expected,
                        base_values[resource_name],
                    )
                    self.assertEqual(
                        localized[resource_name].replace("\\'", "'"),
                        expected,
                    )

    def test_capture_heading_matches_joined_ios_spans_in_every_locale(self) -> None:
        resource_name = "onboarding_page_capture_title"
        ios_keys = generator.COMPOSITE_KEY_OVERRIDES[resource_name]
        ios_strings = generator.json.loads(generator.IOS_STRINGS.read_text())["strings"]
        locale_directories = {"en": "values"}
        locale_directories.update(
            {
                language: directory
                for language, directory in generator.LOCALES.values()
            }
        )

        for language, directory in locale_directories.items():
            path = generator.ROOT / f"android/app/src/main/res/{directory}/strings.xml"
            root = ET.parse(path).getroot()
            localized = {
                node.attrib["name"]: "".join(node.itertext())
                for node in root.findall("string")
            }
            expected = "".join(
                generator.localized_value(ios_strings[key], language)
                or generator.localized_value(ios_strings[key], "en")
                or ""
                for key in ios_keys
            ).strip()
            self.assertEqual(localized[resource_name], expected)

    def test_pending_recordings_copy_matches_ios_in_every_locale(self) -> None:
        resource_names = (
            "pending_recordings_title",
            "pending_recordings_empty",
            "pending_recordings_save_as_note",
            "pending_recordings_saving",
            "pending_recordings_saved",
            "pending_recordings_toast_note_saved",
            "pending_recordings_toast_save_failed",
            "pending_recordings_error_unable_to_prepare_playback",
            "pending_recordings_error_unable_to_start_playback",
            "pending_recordings_error_transcription_failed",
            "transcription_failure_title",
        )
        ios_strings = generator.json.loads(generator.IOS_STRINGS.read_text())["strings"]
        locale_directories = {"en": "values"}
        locale_directories.update(
            {
                language: directory
                for language, directory in generator.LOCALES.values()
            }
        )

        for language, directory in locale_directories.items():
            path = generator.ROOT / f"android/app/src/main/res/{directory}/strings.xml"
            root = ET.parse(path).getroot()
            localized = {
                node.attrib["name"]: "".join(node.itertext())
                for node in root.findall("string")
            }
            for resource_name in resource_names:
                with self.subTest(language=language, resource=resource_name):
                    ios_key = generator.SEMANTIC_KEY_OVERRIDES[resource_name]
                    expected = generator.localized_value(ios_strings[ios_key], language)
                    if expected is None:
                        expected = generator.localized_value(ios_strings[ios_key], "en")
                    self.assertEqual(
                        localized[resource_name].replace("\\'", "'"),
                        expected,
                    )

    def test_creator_configuration_copy_matches_ios_in_every_locale(self) -> None:
        prefixes = (
            "caption_pack_",
            "timed_script_",
            "brand_voice_settings_",
            "repurpose_pack_",
        )
        resource_names = sorted(
            name
            for name in generator.SEMANTIC_KEY_OVERRIDES
            if name.startswith(prefixes)
        )
        ios_strings = generator.json.loads(generator.IOS_STRINGS.read_text())["strings"]
        locale_directories = {"en": "values"}
        locale_directories.update(
            {
                language: directory
                for language, directory in generator.LOCALES.values()
            }
        )

        for language, directory in locale_directories.items():
            path = generator.ROOT / f"android/app/src/main/res/{directory}/strings.xml"
            root = ET.parse(path).getroot()
            localized = {
                node.attrib["name"]: "".join(node.itertext())
                for node in root.findall("string")
            }
            for resource_name in resource_names:
                with self.subTest(language=language, resource=resource_name):
                    ios_key = generator.SEMANTIC_KEY_OVERRIDES[resource_name]
                    expected = generator.localized_value(ios_strings[ios_key], language)
                    if expected is None:
                        expected = generator.localized_value(ios_strings[ios_key], "en")
                    self.assertEqual(
                        localized[resource_name].replace("\\'", "'"),
                        expected,
                    )

    def test_export_completion_copy_matches_ios_in_every_locale(self) -> None:
        resource_names = (
            "export_success_summary",
            "export_progress_cancelled",
            "export_progress_complete",
        )
        ios_strings = generator.json.loads(generator.IOS_STRINGS.read_text())["strings"]
        locale_directories = {"en": "values"}
        locale_directories.update(
            {
                language: directory
                for language, directory in generator.LOCALES.values()
            }
        )
        base_root = ET.parse(generator.ANDROID_STRINGS).getroot()
        base_values = {
            node.attrib["name"]: "".join(node.itertext())
            for node in base_root.findall("string")
        }

        for language, directory in locale_directories.items():
            path = generator.ROOT / f"android/app/src/main/res/{directory}/strings.xml"
            root = ET.parse(path).getroot()
            localized = {
                node.attrib["name"]: "".join(node.itertext())
                for node in root.findall("string")
            }
            for resource_name in resource_names:
                with self.subTest(language=language, resource=resource_name):
                    ios_key = generator.SEMANTIC_KEY_OVERRIDES[resource_name]
                    expected = generator.localized_value(ios_strings[ios_key], language)
                    if expected is None:
                        expected = generator.localized_value(ios_strings[ios_key], "en")
                    expected = generator.restore_android_placeholders(
                        expected,
                        base_values[resource_name],
                    )
                    self.assertEqual(localized[resource_name], expected)

    def test_active_onboarding_copy_maps_to_complete_ios_strings(self) -> None:
        self.assertEqual(
            generator.SEMANTIC_KEY_OVERRIDES["onboarding_login_prompt"],
            "onboarding.flow.login.prompt",
        )
        self.assertEqual(
            generator.SEMANTIC_KEY_OVERRIDES["onboarding_page_skills_title"],
            "onboarding.flow.ai_skills.title",
        )
        self.assertEqual(
            generator.SEMANTIC_KEY_OVERRIDES["onboarding_login_action"],
            "onboarding.flow.login.action",
        )

    def test_missing_ios_key_warns_and_keeps_english(self) -> None:
        stderr = io.StringIO()
        with redirect_stderr(stderr):
            value = generator.safe_localized_value(
                "example",
                "English",
                "removed.key",
                "de",
                {},
            )
        self.assertEqual(value, "English")
        self.assertIn("no longer exists", stderr.getvalue())

    def test_ios_placeholder_is_converted_when_compatible(self) -> None:
        value = generator.safe_localized_value(
            "welcome_format",
            "Welcome, %1$s",
            "welcome.key",
            "de",
            {"welcome.key": ios_entry("de", "Willkommen, %@")},
        )
        self.assertEqual(value, "Willkommen, %1$s")

    def test_ios_placeholder_indices_and_width_are_preserved(self) -> None:
        value = generator.safe_localized_value(
            "report_format",
            "%1$02d topics from %2$s",
            "report.key",
            "ja",
            {"report.key": ios_entry("ja", "%2$@から%1$02lld件")},
        )
        self.assertEqual(value, "%2$sから%1$02d件")

    def test_unsafe_placeholder_falls_back_to_english(self) -> None:
        stderr = io.StringIO()
        with redirect_stderr(stderr):
            value = generator.safe_localized_value(
                "plain_message",
                "Continue",
                "plain.key",
                "de",
                {"plain.key": ios_entry("de", "Weiter mit %@")},
            )
        self.assertEqual(value, "Continue")
        self.assertIn("unsafe translation", stderr.getvalue())

    def test_full_generation_fails_clearly_when_source_has_plurals(self) -> None:
        stderr = io.StringIO()
        with patch.object(sys, "argv", ["generate_ios_locale_patch.py", "de"]):
            with redirect_stderr(stderr):
                with self.assertRaises(SystemExit) as raised:
                    generator.main()
        self.assertEqual(raised.exception.code, 2)
        self.assertIn("full locale generation is disabled", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
