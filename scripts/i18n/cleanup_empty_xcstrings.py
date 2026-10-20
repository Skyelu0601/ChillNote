#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

CATALOG = Path("ios/chillnote/Resources/Localizable.xcstrings")
SEARCH_ROOTS = [
    Path("ios/chillnote"),
    Path("ios/ChillNoteWidget"),
    Path("ios/ChillNoteShareExtension"),
    Path("ios/chillnoteTests"),
    Path("ios/chillnoteUITests"),
]
SEARCH_SUFFIXES = {
    ".swift",
    ".strings",
    ".storyboard",
    ".xib",
}
REQUIRED_LOCALES = ["en", "zh-Hans", "zh-Hant", "ja", "fr", "de", "es", "ko"]


def object_members(text: str, start: int):
    """Yield JSON object member offsets without reformatting the catalog."""
    decoder = json.JSONDecoder()
    cursor = start + 1
    while True:
        while text[cursor].isspace():
            cursor += 1
        if text[cursor] == "}":
            return
        key_start = cursor
        key, cursor = decoder.raw_decode(text, cursor)
        while text[cursor].isspace():
            cursor += 1
        if text[cursor] != ":":
            raise ValueError("Expected JSON object separator")
        cursor += 1
        while text[cursor].isspace():
            cursor += 1
        value_start = cursor
        _, cursor = decoder.raw_decode(text, cursor)
        value_end = cursor
        while text[cursor].isspace():
            cursor += 1
        comma = cursor if text[cursor] == "," else None
        yield key, key_start, value_start, value_end, comma
        if comma is None:
            return
        cursor += 1


def cleanup_blank_keys(path: Path = CATALOG) -> list[str]:
    """Remove only blank identifiers; preserve named entries and file formatting."""
    text = path.read_text(encoding="utf-8")
    data = json.loads(text)
    blank = [key for key in data.get("strings", {}) if not key.strip()]
    if not blank:
        return []
    root_start = len(text) - len(text.lstrip())
    strings_start = next(member[2] for member in object_members(text, root_start) if member[0] == "strings")
    members = list(object_members(text, strings_start))
    removals = []
    for index, (key, start, _, end, comma) in enumerate(members):
        if key not in blank:
            continue
        if comma is not None:
            end = comma + 1
            line_start = text.rfind("\n", 0, start) + 1
            line_end = text.find("\n", end)
            if line_end >= 0 and not text[line_start:start].strip() and not text[end:line_end].strip():
                start, end = line_start, line_end + 1
        elif index > 0:
            previous = next((member for member in reversed(members[:index]) if member[0] not in blank), None)
            start = previous[4] if previous else members[0][1]
        removals.append((start, end))
    # Merge adjacent ranges, including a last blank entry's preceding comma.
    merged = []
    for start, end in sorted(removals):
        if merged and start <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(end, merged[-1][1]))
        else:
            merged.append((start, end))
    for start, end in reversed(merged):
        text = text[:start] + text[end:]
    json.loads(text)
    path.write_text(text, encoding="utf-8")
    return blank


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
    if not key:
        return False
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
        units: list[dict] = []

        def collect_units(node: object) -> None:
            if not isinstance(node, dict):
                return
            unit = node.get("stringUnit")
            if isinstance(unit, dict):
                units.append(unit)
            variations = node.get("variations")
            if isinstance(variations, dict):
                for choices in variations.values():
                    if isinstance(choices, dict):
                        for child in choices.values():
                            collect_units(child)

        collect_units(locale_data)
        if not units or any(not unit.get("value") for unit in units):
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
