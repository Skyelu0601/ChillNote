#!/usr/bin/env python3
"""Validate Android locale completeness, placeholders, and English fallbacks."""

from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RES = ROOT / "android/app/src/main/res"
SOURCE = RES / "values/strings.xml"
LOCALES = {
    "values-de": {"note_tags_title", "teleprompter_camera_countdown", "teleprompter_clip_format", "settings_version_format"},
    "values-es": {"tags_color_title", "teleprompter_clip_format"},
    "values-fr": {"settings_media_description", "teleprompter_clip_format", "settings_version_format"},
    "values-ja": set(),
    "values-ko": set(),
    "values-zh-rCN": set(),
    "values-zh-rTW": set(),
}
UNIVERSALLY_UNCHANGED = {
    "app_name",
    "subscription_pro",
    "subscription_current_pro",
    "markdown_toolbar_h1",
    "markdown_toolbar_h2",
    "note_export_json",
    "note_export_markdown",
}
PLACEHOLDER = re.compile(r"%\d+\$[a-zA-Z]")
ENGLISH_WORD = re.compile(r"[a-z]+", re.IGNORECASE)


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


def main() -> int:
    source = strings(SOURCE)
    source_plurals = plurals(SOURCE)
    failures: list[str] = []

    for directory, locale_allowlist in LOCALES.items():
        localized = strings(RES / directory / "strings.xml")
        localized_plurals = plurals(RES / directory / "strings.xml")
        missing = sorted(source.keys() - localized.keys())
        extra = sorted(localized.keys() - source.keys())
        if missing:
            failures.append(f"{directory}: missing keys: {', '.join(missing)}")
        if extra:
            failures.append(f"{directory}: unknown keys: {', '.join(extra)}")

        for key in sorted(source.keys() & localized.keys()):
            expected = PLACEHOLDER.findall(source[key])
            actual = PLACEHOLDER.findall(localized[key])
            if expected != actual:
                failures.append(
                    f"{directory}/{key}: placeholders {actual} do not match {expected}"
                )
            source_english_words = ENGLISH_WORD.findall(source[key].lower())
            localized_english_words = ENGLISH_WORD.findall(localized[key].lower())
            equivalent_english = localized[key] == source[key] or (
                len(source_english_words) >= 2
                and localized_english_words == source_english_words
            )
            if (
                equivalent_english
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
                expected_placeholders = PLACEHOLDER.findall(expected)
                actual_placeholders = PLACEHOLDER.findall(actual)
                if expected_placeholders != actual_placeholders:
                    failures.append(
                        f"{directory}/{key}[{quantity}]: placeholders {actual_placeholders} "
                        f"do not match {expected_placeholders}"
                    )
                source_english_words = ENGLISH_WORD.findall(expected.lower())
                localized_english_words = ENGLISH_WORD.findall(actual.lower())
                equivalent_english = actual == expected or (
                    len(source_english_words) >= 2
                    and localized_english_words == source_english_words
                )
                if equivalent_english and any(character.isalpha() for character in expected):
                    failures.append(
                        f"{directory}/{key}[{quantity}]: still uses the English fallback"
                    )

    if failures:
        print("Android localization validation failed:")
        print("\n".join(f"- {failure}" for failure in failures))
        return 1

    print(
        f"Validated {len(source)} strings and {len(source_plurals)} plurals "
        f"across {len(LOCALES)} Android locales."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
