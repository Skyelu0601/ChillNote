#!/usr/bin/env python3
from __future__ import annotations

from collections import Counter
import json
import plistlib
import re
import sys
from pathlib import Path

CATALOG_PATH = Path("ios/chillnote/Resources/Localizable.xcstrings")
REQUIRED_LOCALES = ("en", "zh-Hans", "zh-Hant", "ja", "fr", "de", "es", "ko")
SWIFT_ROOTS = (Path("ios/chillnote"), Path("ios/ChillNoteWidget"), Path("ios/ChillNoteShareExtension"))
PLURAL_KEYS = {
    "home.notes.trash.days_left", "note_detail.trash.deleted_in_days",
    "sidebar.stats.streak", "subscription.onboarding.cta.try_free_days",
    "subscription.onboarding.plan.annual_trial_days", "weekly_topics.count.sources",
    "weekly_topics.count.topics",
}
PERMISSION_KEYS = {
    "NSMicrophoneUsageDescription", "NSSpeechRecognitionUsageDescription",
    "NSCameraUsageDescription", "NSPhotoLibraryAddUsageDescription",
}
UI_LITERAL_PATTERN = re.compile(
    r'\b(Text|Button|Label|TextField)\(\s*"((?:\\.|[^"\\])*)"|'
    r'\.alert\(\s*"((?:\\.|[^"\\])*)"|'
    r'\.navigationTitle\(\s*"((?:\\.|[^"\\])*)"|'
    r'\.accessibility(?:Label|Hint)\(\s*"((?:\\.|[^"\\])*)"'
)
L10N_KEY_PATTERN = re.compile(r'\bL10n\.text\(\s*"([^"]+)"')
IOS_FORMAT_TOKEN = re.compile(
    r'%(?:(?P<index>\d+)\$)?[-+ 0#,(]*\d*(?:\.\d+)?'
    r'(?P<length>hh|h|ll|l|q|z|t|j)?(?P<conversion>[diuoxXfFeEgGaAcCsSp@])|%%'
)
MALFORMED_MARKDOWN_LINK = re.compile(r"\]\s+\(https?://", re.IGNORECASE)
LEGACY_VISIBLE_BRAND = re.compile(r"\bChillNote\b")
INFOPLIST_LINE = re.compile(r'^\s*"([^"]+)"\s*=\s*"((?:\\.|[^"\\])*)"\s*;\s*$')


def load_catalog() -> dict:
    return json.loads(CATALOG_PATH.read_text(encoding="utf-8"))


def unit_map(locale_data: dict) -> dict[str, dict]:
    result: dict[str, dict] = {}

    def visit(node: object, path: tuple[str, ...]) -> None:
        if not isinstance(node, dict):
            return
        unit = node.get("stringUnit")
        if isinstance(unit, dict):
            result[".".join(path) or "direct"] = unit
        variations = node.get("variations")
        if isinstance(variations, dict):
            for variation_type, choices in variations.items():
                if isinstance(choices, dict):
                    for choice, child in choices.items():
                        visit(child, (*path, variation_type, choice))

    visit(locale_data, ())
    return result


def placeholder_signature(value: str) -> Counter[tuple[str, str]]:
    signature: Counter[tuple[str, str]] = Counter()
    implicit_index = 0
    for match in IOS_FORMAT_TOKEN.finditer(value):
        if match.group(0) == "%%":
            continue
        if match.group("index") is None:
            implicit_index += 1
            reference = f"implicit-{implicit_index}"
        else:
            reference = f'index-{match.group("index")}'
        conversion = (match.group("length") or "") + (match.group("conversion") or "")
        signature[(reference, conversion)] += 1
    return signature


def expected_unit(english_units: dict[str, dict], path: str) -> dict | None:
    if path in english_units:
        return english_units[path]
    if path.startswith("plural."):
        return english_units.get("plural.other")
    return english_units.get("direct")


def check_catalog() -> list[str]:
    errors: list[str] = []
    strings = load_catalog().get("strings", {})
    for key, entry in strings.items():
        if not key:
            errors.append("[catalog] empty key is not allowed")
        localizations = entry.get("localizations", {})
        unexpected = sorted(set(localizations) - set(REQUIRED_LOCALES))
        if unexpected:
            errors.append(f'[catalog] key="{key}" has unsupported locales: {", ".join(unexpected)}')
        english_units = unit_map(localizations.get("en", {}))
        if key in PLURAL_KEYS:
            english_plural = localizations.get("en", {}).get("variations", {}).get("plural")
            if not isinstance(english_plural, dict) or "other" not in english_plural:
                errors.append(f'[catalog] key="{key}" must use plural variations')

        for locale in REQUIRED_LOCALES:
            locale_data = localizations.get(locale)
            if not isinstance(locale_data, dict):
                errors.append(f'[catalog] key="{key}" missing locale="{locale}"')
                continue
            units = unit_map(locale_data)
            if not units:
                errors.append(f'[catalog] key="{key}" locale="{locale}" has no string unit')
                continue
            plural = locale_data.get("variations", {}).get("plural")
            if isinstance(plural, dict) and "other" not in plural:
                errors.append(f'[catalog] key="{key}" locale="{locale}" missing plural.other')
            for path, unit in units.items():
                value = unit.get("value")
                label = f'[catalog] key="{key}" locale="{locale}" unit="{path}"'
                if unit.get("state") == "new":
                    errors.append(f"{label} state=new")
                if not isinstance(value, str) or not value:
                    errors.append(f"{label} empty value")
                    continue
                if MALFORMED_MARKDOWN_LINK.search(value):
                    errors.append(f"{label} has whitespace between Markdown label and URL")
                if LEGACY_VISIBLE_BRAND.search(value):
                    errors.append(f"{label} contains legacy user-visible brand ChillNote")
                expected = expected_unit(english_units, path)
                if expected and isinstance(expected.get("value"), str):
                    actual = placeholder_signature(value)
                    wanted = placeholder_signature(expected["value"])
                    if actual != wanted:
                        errors.append(f"{label} placeholders {dict(actual)} do not match English {dict(wanted)}")

    missing = sorted(PLURAL_KEYS - set(strings))
    if missing:
        errors.append("[catalog] missing required plural keys: " + ", ".join(missing))
    return errors


def check_swift_sources() -> list[str]:
    errors: list[str] = []
    keys = set((load_catalog().get("strings") or {}).keys())
    for root in SWIFT_ROOTS:
        if not root.exists():
            continue
        for path in root.rglob("*.swift"):
            content = path.read_text(encoding="utf-8")
            for match in L10N_KEY_PATTERN.finditer(content):
                key = match.group(1)
                if "\\(" in key:
                    continue
                if key not in keys:
                    line = content.count("\n", 0, match.start()) + 1
                    errors.append(f'[swift] {path}:{line} unknown localization key: "{key}"')
            for match in UI_LITERAL_PATTERN.finditer(content):
                literal = next((group for group in match.groups()[1:] if group), None)
                if not literal:
                    continue
                literal = literal.replace("\\n", "\n").replace('\\"', '"')
                if "\\(" in literal or literal in keys:
                    continue
                line = content.count("\n", 0, match.start()) + 1
                errors.append(f'[swift] {path}:{line} literal not in catalog: "{literal}"')
    return errors


def parse_infoplist_strings(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if match := INFOPLIST_LINE.match(line):
            result[match.group(1)] = match.group(2)
    return result


def check_permission_descriptions() -> list[str]:
    errors: list[str] = []
    base = plistlib.loads(Path("ios/chillnote/Info.plist").read_bytes())
    localized: dict[str, dict[str, str]] = {}
    for locale in REQUIRED_LOCALES:
        path = Path(f"ios/chillnote/{locale}.lproj/InfoPlist.strings")
        if not path.exists():
            errors.append(f"[permissions] missing {path}")
            continue
        localized[locale] = parse_infoplist_strings(path)
        missing = sorted(PERMISSION_KEYS - set(localized[locale]))
        if missing:
            errors.append(f'[permissions] locale="{locale}" missing keys: {", ".join(missing)}')
        for key in PERMISSION_KEYS & set(localized[locale]):
            value = localized[locale][key]
            if not value:
                errors.append(f'[permissions] locale="{locale}" key="{key}" is empty')
            if LEGACY_VISIBLE_BRAND.search(value):
                errors.append(f'[permissions] locale="{locale}" key="{key}" contains ChillNote')
    english = localized.get("en", {})
    for key in PERMISSION_KEYS:
        if base.get(key) != english.get(key):
            errors.append(f'[permissions] Info.plist and en.lproj disagree for key="{key}"')
    project = Path("ios/chillnote.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
    for key in ("NSMicrophoneUsageDescription", "NSSpeechRecognitionUsageDescription"):
        expected = english.get(key)
        declaration = f'INFOPLIST_KEY_{key} = "{expected}";'
        if expected and project.count(declaration) != 2:
            errors.append(
                f'[permissions] Debug/Release project settings disagree with en.lproj for key="{key}"'
            )
    return errors


def main() -> int:
    errors = check_catalog() + check_swift_sources() + check_permission_descriptions()
    if errors:
        print("\n".join(errors))
        print(f"\nFAIL: {len(errors)} i18n issue(s) found.")
        return 1
    print("PASS: i18n checks succeeded.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
