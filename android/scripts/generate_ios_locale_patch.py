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
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ANDROID_STRINGS = ROOT / "android/app/src/main/res/values/strings.xml"
IOS_STRINGS = ROOT / "chillnote/Resources/Localizable.xcstrings"

LOCALES = {
    "de": ("de", "values-de"),
    "es": ("es", "values-es"),
    "fr": ("fr", "values-fr"),
    "ja": ("ja", "values-ja"),
    "ko": ("ko", "values-ko"),
    "zh-Hant": ("zh-Hant", "values-zh-rTW"),
}

# These mappings are deliberately semantic. The English wording may differ,
# but the control or message has the same job on both platforms.
SEMANTIC_KEY_OVERRIDES = {
    "home_create_note": "home.header.accessibility.create_blank_note",
    "common_retry": "common.retry",
    "common_undo": "common.undo",
    "home_empty_title": "home.notes.empty.default",
    "note_delete": "note_detail.header.action.delete_note",
    "note_actions": "note_detail.header.accessibility.more_actions",
    "note_move_to_published": "home.notes.action.mark_published",
    "home_section_trash": "sidebar.nav.recycle_bin",
    "home_selection_count_format": "settings.media_link_sections.summary.count",
    "tags_add": "note_detail.tag.add",
    "tags_create_title": "note_detail.add_tag.title",
    "note_tags_title": "sidebar.tags.title",
    "auth_login_send_code": "auth.login.send_code",
    "auth_login_code_sent_to_format": "auth.login.code_sent_to_format",
    "auth_login_legal_plain": "auth.login.legal_markdown",
    "quick_capture_link_import_placeholder_title": "quick_capture.link_import.placeholder.title",
    "quick_capture_link_import_placeholder_format": "quick_capture.link_import.placeholder.body",
    "link_import_processing": "quick_capture.link_import.status.processing",
    "link_import_failed": "quick_capture.link_import.status.failed",
    "home_select_notes": "home.header.title_menu.select_notes",
    "home_batch_tag_empty": "home.batch_tag.empty",
    "home_batch_tag_partial": "home.batch_tag.partial",
    "home_batch_delete_title": "home.alert.delete_notes.title",
    "home_batch_delete_message": "home.alert.delete_notes.message",
    "note_pin": "home.notes.action.pin",
    "trash_empty_action": "home.notes.empty.trash",
    "auth_login_google_button": "auth.login.google_button",
    "auth_login_apple_button": "auth.login.apple_button",
    "auth_google_invalid_credential": "error.auth.invalid_apple_credential",
    "auth_apple_failed": "error.auth.apple_init_failed",
    "settings_account_section": "settings.account.title",
    "settings_unknown_email": "settings.account.unknown_email",
    "settings_sign_out_confirm_message": "settings.alert.sign_out.message",
    "settings_terms": "subscription.terms_of_use",
    "settings_permissions": "settings.data.permissions",
    "settings_delete_account_confirm_title": "settings.alert.delete_account.title",
    "settings_delete_account_confirm_message": "settings.alert.delete_account.message",
    "subscription_active_message": "subscription.status.active",
    "subscription_free": "sidebar.membership.free_plan",
    "subscription_current_pro": "subscription.brand.pro_title",
    "subscription_products_unavailable": "subscription.unavailable",
    "voice_processing": "voice_input.processing",
    "voice_error_permission": "speech_recognizer.error.microphone_permission_required",
    "voice_error_start": "speech_recognizer.error.failed_to_start_recording_short",
    "voice_error_empty": "error.recording.pending.audio_empty",
    "voice_start": "quick_capture.accessibility.record",
    "voice_refined": "note_detail.overlay.refined",
    "voice_show_original": "note_detail.overlay.show_original",
    "onboarding_login_prompt": "onboarding.flow.login.prompt",
    "onboarding_page_save_video_title": "onboarding.flow.save_video.title",
    "onboarding_page_extract_title": "onboarding.flow.extract_ideas.title",
    "onboarding_page_hooks_title": "onboarding.flow.generate_hooks.stage.title",
    "onboarding_page_skills_title": "onboarding.flow.ai_skills.title.highlight",
    "onboarding_welcome_note_content": "onboarding.welcome_note.content",
    "subscription_onboarding_title": "subscription.onboarding.title",
    "subscription_cta_start_annual": "subscription.cta.start_annual",
    "creator_skills_title": "home.creator_skills.title",
    "creator_skills_add_more": "home.creator_skills.add_more",
    "creator_skills_choose_note_message": "home.recipe_picker.title",
    "creator_skills_no_notes": "home.recipe_picker.empty.message",
    "creator_skills_translate_title": "translate_sheet.title",
    "creator_skills_category_publish": "note_section.published",
    "ai_skill_preview_title": "note_detail.ai_skills.preview.title",
    "ai_skill_preview_context_note": "note_detail.ai_skills.preview.note_context",
    "ai_skill_preview_context_selection": "note_detail.ai_skills.preview.selection_context",
    "ai_skill_save_as_draft": "home.ai_skills.preview.action.save_as_draft",
    "ai_skill_error_title": "note_detail.ai_skills.error.title",
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
    "ai_chat_title": "ai_chat.title",
    "ai_chat_start": "ai_chat.title",
    "ai_chat_context_notes_format": "ai_chat.context_notes_format",
    "ai_chat_empty_title": "ai_chat.empty.ready_title",
    "ai_chat_empty_message": "ai_chat.empty.ready_message",
    "ai_chat_input_placeholder": "ai_chat.input_placeholder",
    "ai_chat_thinking": "ai_chat.thinking",
    "ai_chat_saved": "ai_chat.message.saved",
    "ai_chat_error_format": "ai_chat.error.issue_format",
    "teleprompter_title": "note_detail.header.action.teleprompter",
    "teleprompter_action_open": "note_detail.header.action.teleprompter",
    "teleprompter_prompt_speed": "teleprompter.prompt.speed",
    "teleprompter_camera_countdown": "teleprompter.camera.countdown",
    "teleprompter_camera_switch": "teleprompter.camera.switch",
    "teleprompter_export_processing": "teleprompter.export.processing",
    "teleprompter_preview_save_to_gallery": "teleprompter.preview.save_to_photos",
    "teleprompter_preview_saved": "teleprompter.preview.save_success",
    "teleprompter_preview_save_failed": "teleprompter.preview.save_failed",
    "teleprompter_permission_title": "teleprompter.permission.title",
    "teleprompter_error_record_failed": "teleprompter.error.record_failed",
    "note_export": "note_detail.header.action.export_markdown",
    "note_export_markdown": "settings.export.format_markdown",
    "settings_export_no_notes": "settings.export.no_notes",
    "settings_export_failed": "export.error.unable_to_export_notes",
    "settings_voice_language": "settings.voice.title",
    "settings_voice_auto_help": "settings.voice.auto_help",
    "settings_voice_preferred_help": "settings.voice.preferred_help",
    "settings_voice_search": "settings.voice.search_placeholder",
    "settings_media_sections": "settings.media_link_sections.title",
    "settings_media_sections_title": "settings.media_link_sections.title",
    "settings_media_sections_help": "settings.media_link_sections.subtitle",
    "settings_send_feedback": "settings.support.send_feedback",
    "home_credit_gift_title": "home.credit_gift.title",
    "home_credit_gift_message": "home.credit_gift.message",
    "home_credit_gift_balance_hint": "home.credit_gift.balance_hint",
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
    placeholders = re.findall(r"%\d+\$[sd]", english)
    if not placeholders:
        return localized
    by_type = {
        "s": [item for item in placeholders if item.endswith("s")],
        "d": [item for item in placeholders if item.endswith("d")],
    }
    positions = {"s": 0, "d": 0}

    def replace(match: re.Match[str]) -> str:
        kind = "s" if match.group(0).endswith("@") else "d"
        choices = by_type[kind]
        if not choices:
            return match.group(0)
        index = min(positions[kind], len(choices) - 1)
        positions[kind] += 1
        return choices[index]

    return re.sub(r"%(?:\d+\$)?(?:lld|ld|d|@)", replace, localized)


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
    translated = []
    for node in android_root.findall("string"):
        name = node.attrib["name"]
        english = "".join(node.itertext())
        ios_key = SEMANTIC_KEY_OVERRIDES.get(name) or choose_exact_key(name, english, ios_strings)
        value = localized_value(ios_strings[ios_key], ios_language) if ios_key else None
        # Android lint requires every declared locale to provide every string.
        # Keep the source English when iOS has no safe translation yet.
        value = value or english
        value = restore_android_placeholders(value, english)
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
