#!/usr/bin/env python3
"""Validate Android locale completeness, formatting, and locale declarations."""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RES = ROOT / "android/app/src/main/res"
SOURCE = RES / "values/strings.xml"
LOCALE_CONFIG = RES / "xml/locales_config.xml"
LOCALES = {
    "values-de": {"share_extension_unknown_source", "note_tags_title", "note_workspace_record_metadata", "onboarding_capture_links_title", "onboarding_capture_text_title", "onboarding_extract_link", "onboarding_highlight_save_video", "repurpose_pack_format_newsletter", "teleprompter_camera_countdown", "teleprompter_clip_format", "teleprompter_text_color_cyan", "teleprompter_text_color_pink", "settings_ui_upgrade", "settings_version_format"},
    "values-es": {"note_detail_add_tag_color_label", "onboarding_capture_links_title", "subscription_badge_flexible", "tags_color_title", "tags_color_option_format", "teleprompter_clip_format"},
    "values-fr": {"share_extension_source_format", "brand_voice_settings_audience_label", "creator_skills_custom_instruction", "export_success_summary", "note_workspace_note", "onboarding_extract_description", "repurpose_pack_format_newsletter", "repurpose_pack_settings_formats", "repurpose_pack_thread_length_long", "settings_media_description", "subscription_badge_flexible", "teleprompter_clip_format", "teleprompter_text_color_cyan", "settings_version_format"},
    "values-ja": set(),
    "values-ko": set(),
    "values-zh-rCN": set(),
    "values-zh-rTW": set(),
}
UNIVERSALLY_UNCHANGED = {
    "app_name",
    "about_brand",
    "export_progress_summary_format",
    "settings_export_format_markdown",
    "creator_skills_custom_badge",
    "caption_pack_platform_instagram_reels",
    "caption_pack_platform_tiktok",
    "caption_pack_platform_youtube_long_video",
    "caption_pack_platform_youtube_shorts",
    "note_detail_ai_skills_title",
    "note_detail_recording_duration_progress",
    "subscription_pro",
    "subscription_current_pro",
    "teleprompter_clip_format",
    "common_ok",
    "markdown_toolbar_h1",
    "markdown_toolbar_h2",
    "note_export_json",
    "note_export_markdown",
    "onboarding_skills_pro",
    "repurpose_pack_format_facebook_page",
    "repurpose_pack_format_instagram_carousel",
    "repurpose_pack_format_linkedin",
    "repurpose_pack_format_pinterest_pin",
    "repurpose_pack_format_threads",
    "repurpose_pack_format_x_post",
    "repurpose_pack_format_youtube_community",
    "weekly_topics_report_date_range",
    "weekly_topics_topic_progress",
    "weekly_topics_preview_illustration_label",
}
ENGLISH_WORD = re.compile(r"[a-z]+", re.IGNORECASE)
MARKDOWN_URL = re.compile(r"\[[^\]\n]+\]\([^)]*https?://[^)]*\)", re.IGNORECASE)
ANDROID_NAMESPACE = "http://schemas.android.com/apk/res/android"
RESOURCE_LOCALE_ALIASES = {"zh-rCN": "zh-Hans", "zh-rTW": "zh-Hant"}

# Java Formatter syntax. Literal %% and %n are recognized but do not consume an
# argument. Date/time tokens include both the t/T prefix and suffix.
JAVA_FORMAT_TOKEN = re.compile(
    r"%(?:(?P<index>\d+)\$)?"
    r"(?P<flags>[-#+ 0,(<]*)"
    r"(?P<width>\d+)?"
    r"(?P<precision>\.\d+)?"
    r"(?:"
    r"(?P<date_prefix>[tT])(?P<date_suffix>[HIklMSLNpzZsQBbhAaCYyjmdeRTrDFc])"
    r"|(?P<conversion>[bBhHsScCdoxXeEfgGaA%n])"
    r")"
)
IOS_FORMAT_TOKEN = re.compile(
    r"%(?:\d+\$)?[-+ 0#,(]*\d*(?:\.\d+)?"
    r"(?:@|(?:hh|h|ll|l|q|z|t|j)[diuoxXfFeEgGaAcCsSp])"
)
POTENTIAL_FORMAT_TOKEN = re.compile(
    r"%(?:\d+\$)?[-#+0,(<]*\d*(?:\.\d+)?(?:[A-Za-z@]|$)"
)


@dataclass(frozen=True)
class FormatToken:
    raw: str
    index: int | None
    flags: str
    conversion: str
    consumes_argument: bool


def strings(path: Path) -> dict[str, str]:
    root = ET.parse(path).getroot()
    return {
        node.attrib["name"]: "".join(node.itertext())
        for node in root.findall("string")
    }


def plurals(path: Path) -> dict[str, dict[str, str]]:
    root = ET.parse(path).getroot()
    return {
        node.attrib["name"]: {
            item.attrib["quantity"]: "".join(item.itertext())
            for item in node.findall("item")
        }
        for node in root.findall("plurals")
    }


def scan_format_tokens(value: str) -> tuple[list[FormatToken], list[str]]:
    """Return every Java printf token plus unsafe/invalid token diagnostics."""
    tokens: list[FormatToken] = []
    errors: list[str] = []
    position = 0
    previous_argument_seen = False

    while position < len(value):
        percent = value.find("%", position)
        if percent < 0:
            break

        java_match = JAVA_FORMAT_TOKEN.match(value, percent)
        if java_match:
            raw = java_match.group(0)
            index_text = java_match.group("index")
            flags = java_match.group("flags") or ""
            conversion = (
                (java_match.group("date_prefix") or "")
                + (java_match.group("date_suffix") or "")
                or (java_match.group("conversion") or "")
            )
            consumes_argument = conversion not in {"%", "n"}
            index = int(index_text) if index_text else None

            if "<" in flags and not previous_argument_seen:
                errors.append(f"format token {raw!r} reuses an argument before one is defined")
            if "<" in flags and index is not None:
                errors.append(f"format token {raw!r} cannot combine an argument index with '<'")
            if not consumes_argument and (index is not None or "<" in flags):
                errors.append(f"format token {raw!r} must not reference an argument")

            tokens.append(FormatToken(raw, index, flags, conversion, consumes_argument))
            if consumes_argument:
                previous_argument_seen = True
            position = java_match.end()
            continue

        ios_match = IOS_FORMAT_TOKEN.match(value, percent)
        if ios_match:
            errors.append(f"iOS format token {ios_match.group(0)!r} is not valid in Android resources")
            position = ios_match.end()
            continue

        potential = POTENTIAL_FORMAT_TOKEN.match(value, percent)
        if potential and potential.group(0) != "%":
            errors.append(f"unsupported format token {potential.group(0)!r}")
            position = potential.end()
        else:
            # A lone percent (for example, "20%") is ordinary localized text.
            position = percent + 1

    return tokens, errors


def format_token_errors(value: str) -> list[str]:
    return scan_format_tokens(value)[1]


def placeholder_signature(value: str) -> Counter[tuple[str, str]]:
    """Describe argument identity/type while allowing indexed arguments to reorder."""
    tokens, _ = scan_format_tokens(value)
    signature: Counter[tuple[str, str]] = Counter()
    implicit_index = 0
    previous_reference: str | None = None

    for token in tokens:
        if not token.consumes_argument:
            continue
        if "<" in token.flags:
            reference = previous_reference or "invalid-reuse"
        elif token.index is not None:
            reference = f"index-{token.index}"
        else:
            implicit_index += 1
            reference = f"implicit-{implicit_index}"
        previous_reference = reference
        signature[(reference, token.conversion)] += 1
    return signature


def resource_locale_tag(directory: str) -> str | None:
    if not directory.startswith("values-"):
        return None
    qualifier = directory.removeprefix("values-")
    if qualifier in RESOURCE_LOCALE_ALIASES:
        return RESOURCE_LOCALE_ALIASES[qualifier]
    if qualifier.startswith("b+"):
        subtags = qualifier.removeprefix("b+").split("+")
        if subtags and re.fullmatch(r"[a-z]{2,3}", subtags[0]):
            normalized = [subtags[0]]
            for subtag in subtags[1:]:
                if re.fullmatch(r"[A-Z][a-z]{3}", subtag):
                    normalized.append(subtag)
                elif re.fullmatch(r"[A-Z]{2}|\d{3}", subtag):
                    normalized.append(subtag)
                else:
                    return None
            return "-".join(normalized)
    if re.fullmatch(r"[a-z]{2,3}", qualifier):
        return qualifier
    region_match = re.fullmatch(r"([a-z]{2,3})-r([A-Z]{2}|\d{3})", qualifier)
    if region_match:
        return f"{region_match.group(1)}-{region_match.group(2)}"
    return None


def locale_configuration_failures(
    res: Path = RES,
    config: Path = LOCALE_CONFIG,
    validated_directories: set[str] | None = None,
) -> list[str]:
    failures: list[str] = []
    validated = validated_directories if validated_directories is not None else set(LOCALES)
    resource_directories = {
        path.parent.name for path in res.glob("values-*/strings.xml")
    }
    unrecognized_directories = sorted(
        directory
        for directory in resource_directories
        if resource_locale_tag(directory) is None
    )
    if unrecognized_directories:
        failures.append(
            "cannot derive locale tags from resource directories: "
            + ", ".join(unrecognized_directories)
        )

    missing_validation = sorted(resource_directories - validated)
    stale_validation = sorted(validated - resource_directories)
    if missing_validation:
        failures.append(
            "locale resources are not covered by the validator: " + ", ".join(missing_validation)
        )
    if stale_validation:
        failures.append(
            "validator declares missing locale resources: " + ", ".join(stale_validation)
        )

    resource_tags = {"en"}
    resource_tags.update(
        tag
        for directory in resource_directories
        if (tag := resource_locale_tag(directory)) is not None
    )
    try:
        config_root = ET.parse(config).getroot()
    except (FileNotFoundError, ET.ParseError) as error:
        failures.append(f"localeConfig cannot be read: {error}")
        return failures

    configured_list = [
        node.attrib.get(f"{{{ANDROID_NAMESPACE}}}name", "")
        for node in config_root.findall("locale")
    ]
    configured_tags = {tag for tag in configured_list if tag}
    if len(configured_list) != len(configured_tags):
        failures.append("localeConfig contains an empty or duplicate locale entry")
    missing_from_config = sorted(resource_tags - configured_tags)
    extra_in_config = sorted(configured_tags - resource_tags)
    if missing_from_config:
        failures.append(
            "localeConfig is missing resource locales: " + ", ".join(missing_from_config)
        )
    if extra_in_config:
        failures.append(
            "localeConfig declares locales without resources: " + ", ".join(extra_in_config)
        )
    return failures


def value_format_failures(label: str, key: str, value: str) -> list[str]:
    failures = [f"{label}/{key}: {error}" for error in format_token_errors(value)]
    if key.endswith("_plain") and MARKDOWN_URL.search(value):
        failures.append(f"{label}/{key}: _plain string contains a Markdown URL")
    return failures


def equivalent_to_english(source_value: str, localized_value: str) -> bool:
    source_english_words = ENGLISH_WORD.findall(source_value.lower())
    localized_english_words = ENGLISH_WORD.findall(localized_value.lower())
    return localized_value == source_value or (
        len(source_english_words) >= 2
        and localized_english_words == source_english_words
    )


def validate(
    res: Path = RES,
    source_path: Path = SOURCE,
    locale_config: Path = LOCALE_CONFIG,
) -> tuple[list[str], int, int]:
    source = strings(source_path)
    source_plurals = plurals(source_path)
    failures = locale_configuration_failures(res, locale_config)

    for key, value in source.items():
        failures.extend(value_format_failures("values", key, value))
    for key, items in source_plurals.items():
        for quantity, value in items.items():
            failures.extend(value_format_failures("values", f"{key}[{quantity}]", value))

    for directory, locale_allowlist in LOCALES.items():
        localized_path = res / directory / "strings.xml"
        localized = strings(localized_path)
        localized_plurals = plurals(localized_path)
        missing = sorted(source.keys() - localized.keys())
        extra = sorted(localized.keys() - source.keys())
        if missing:
            failures.append(f"{directory}: missing keys: {', '.join(missing)}")
        if extra:
            failures.append(f"{directory}: unknown keys: {', '.join(extra)}")

        for key in sorted(source.keys() & localized.keys()):
            failures.extend(value_format_failures(directory, key, localized[key]))
            expected = placeholder_signature(source[key])
            actual = placeholder_signature(localized[key])
            if expected != actual:
                failures.append(
                    f"{directory}/{key}: placeholders {dict(actual)} do not match {dict(expected)}"
                )
            if (
                equivalent_to_english(source[key], localized[key])
                and any(character.isalpha() for character in source[key])
                and key not in UNIVERSALLY_UNCHANGED
                and key not in locale_allowlist
            ):
                failures.append(f"{directory}/{key}: still uses the English fallback")

        missing_plurals = sorted(source_plurals.keys() - localized_plurals.keys())
        extra_plurals = sorted(localized_plurals.keys() - source_plurals.keys())
        if missing_plurals:
            failures.append(f"{directory}: missing plurals: {', '.join(missing_plurals)}")
        if extra_plurals:
            failures.append(f"{directory}: unknown plurals: {', '.join(extra_plurals)}")

        for key in sorted(source_plurals.keys() & localized_plurals.keys()):
            expected_items = source_plurals[key]
            actual_items = localized_plurals[key]
            if "other" not in actual_items:
                failures.append(f"{directory}/{key}: missing required 'other' plural")
            for quantity, actual in actual_items.items():
                expected = expected_items.get(quantity, expected_items.get("other", ""))
                item_label = f"{key}[{quantity}]"
                failures.extend(value_format_failures(directory, item_label, actual))
                expected_placeholders = placeholder_signature(expected)
                actual_placeholders = placeholder_signature(actual)
                if expected_placeholders != actual_placeholders:
                    failures.append(
                        f"{directory}/{item_label}: placeholders {dict(actual_placeholders)} "
                        f"do not match {dict(expected_placeholders)}"
                    )
                if equivalent_to_english(expected, actual) and any(
                    character.isalpha() for character in expected
                ):
                    failures.append(
                        f"{directory}/{item_label}: still uses the English fallback"
                    )

    return failures, len(source), len(source_plurals)


def main() -> int:
    failures, string_count, plural_count = validate()
    if failures:
        print("Android localization validation failed:")
        print("\n".join(f"- {failure}" for failure in failures))
        return 1

    print(
        f"Validated {string_count} strings and {plural_count} plurals "
        f"across {len(LOCALES)} Android locales."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
