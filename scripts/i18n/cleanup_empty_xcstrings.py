#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

CATALOG = Path("chillnote/Resources/Localizable.xcstrings")
SEARCH_ROOTS = [
    Path("chillnote"),
    Path("ChillNoteWidget"),
    Path("chillnoteTests"),
]
SEARCH_SUFFIXES = {
    ".swift",
    ".strings",
    ".storyboard",
    ".xib",
}
REQUIRED_LOCALES = ["en", "zh-Hans", "zh-Hant", "ja", "fr", "de", "es", "ko"]


def load_catalog() -> dict:
    return json.loads(CATALOG.read_text(encoding="utf-8"))


def iter_search_files() -> list[Path]:
    files: list[Path] = []
    for root in SEARCH_ROOTS:
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if path.is_file() and path.suffix in SEARCH_SUFFIXES:
                files.append(path)
    return files


def build_search_blob(files: list[Path]) -> str:
    parts: list[str] = []
    for path in files:
        parts.append(path.read_text(encoding="utf-8"))
    return "\n".join(parts)


def source_contains_key(blob: str, key: str) -> bool:
    if key in blob:
        return True

    escaped_key = (
        key.replace("\\", "\\\\")
        .replace("\"", "\\\"")
        .replace("\n", "\\n")
        .replace("\t", "\\t")
    )
    return escaped_key in blob


def is_empty_or_incomplete(value: dict) -> bool:
    localizations = value.get("localizations")
    if not isinstance(localizations, dict) or not localizations:
        return True

    for locale in REQUIRED_LOCALES:
        locale_data = localizations.get(locale, {})
        if not isinstance(locale_data, dict):
            return True
        unit = locale_data.get("stringUnit")
        if not isinstance(unit, dict) or not unit.get("value"):
            return True

    return False


def find_removable_empty_keys(strings: dict, blob: str) -> tuple[list[str], list[str]]:
    removable: list[str] = []
    retained: list[str] = []

    for key, value in strings.items():
        if not is_empty_or_incomplete(value):
            continue
        if source_contains_key(blob, key):
            retained.append(key)
        else:
            removable.append(key)

    return removable, retained


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Find and optionally remove empty or incomplete xcstrings entries that are no longer referenced."
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Delete removable empty or incomplete keys from the string catalog.",
    )
    args = parser.parse_args()

    data = load_catalog()
    strings = data.get("strings", {})
    files = iter_search_files()
    blob = build_search_blob(files)
    removable, retained = find_removable_empty_keys(strings, blob)

    print(f"Scanned {len(files)} source files.")
    print(f"Found {len(removable) + len(retained)} empty or incomplete entries in {CATALOG}.")
    print(f"Safe to remove: {len(removable)}")
    print(f"Still referenced somewhere in source: {len(retained)}")

    if removable:
        print("\nRemovable empty or incomplete keys:")
        for key in removable:
            print(f"- {key}")

    if args.apply and removable:
        for key in removable:
            strings.pop(key, None)
        CATALOG.write_text(
            json.dumps(data, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"\nRemoved {len(removable)} empty or incomplete keys from {CATALOG}.")
    elif args.apply:
        print("\nNo removable empty or incomplete keys found. Catalog left unchanged.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
