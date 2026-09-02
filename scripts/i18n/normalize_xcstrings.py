#!/usr/bin/env python3
import copy
import json
from pathlib import Path

CATALOG = Path('ios/chillnote/Resources/Localizable.xcstrings')
REQUIRED_LOCALES = ['en', 'zh-Hans', 'zh-Hant', 'ja', 'fr', 'de', 'es', 'ko']


def fallback_entry(key: str, localizations: dict) -> dict:
    english = localizations.get('en')
    if isinstance(english, dict) and (
        isinstance(english.get('stringUnit'), dict)
        or isinstance(english.get('variations'), dict)
    ):
        return copy.deepcopy(english)
    return {'stringUnit': {'state': 'translated', 'value': key}}


def normalize_units(node: object, fallback_value: str) -> None:
    if not isinstance(node, dict):
        return
    unit = node.get('stringUnit')
    if isinstance(unit, dict):
        if not unit.get('value'):
            unit['value'] = fallback_value
        if unit.get('state') in (None, 'new'):
            unit['state'] = 'translated'
    variations = node.get('variations')
    if isinstance(variations, dict):
        for choices in variations.values():
            if isinstance(choices, dict):
                for child in choices.values():
                    normalize_units(child, fallback_value)


def ensure_entry(localizations: dict, locale: str, fallback: dict, key: str) -> None:
    entry = localizations.get(locale)
    if not isinstance(entry, dict) or not (
        isinstance(entry.get('stringUnit'), dict)
        or isinstance(entry.get('variations'), dict)
    ):
        entry = copy.deepcopy(fallback)
        localizations[locale] = entry
    normalize_units(entry, key)


def main() -> None:
    data = json.loads(CATALOG.read_text(encoding='utf-8'))
    strings = data.get('strings', {})

    for key, value in strings.items():
        localizations = value.setdefault('localizations', {})
        default_entry = fallback_entry(key, localizations)
        for locale in REQUIRED_LOCALES:
            ensure_entry(localizations, locale, default_entry, key)

        # Keep state consistent for already present units
        for locale_data in localizations.values():
            normalize_units(locale_data, key)

    CATALOG.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Normalized {len(strings)} keys in {CATALOG}')


if __name__ == '__main__':
    main()
