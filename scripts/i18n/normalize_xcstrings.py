#!/usr/bin/env python3
import json
from pathlib import Path

CATALOG = Path('chillnote/Resources/Localizable.xcstrings')
REQUIRED_LOCALES = ['en', 'zh-Hans', 'zh-Hant', 'ja', 'fr', 'de', 'es', 'ko']


def fallback_value(key: str, localizations: dict) -> str:
    en_val = localizations.get('en', {}).get('stringUnit', {}).get('value')
    if isinstance(en_val, str) and en_val:
        return en_val
    return key


def ensure_unit(localizations: dict, locale: str, value: str) -> None:
    entry = localizations.setdefault(locale, {})
    unit = entry.get('stringUnit')
    if not isinstance(unit, dict):
        unit = {}
        entry['stringUnit'] = unit
    if not unit.get('value'):
        unit['value'] = value
    if unit.get('state') in (None, 'new'):
        unit['state'] = 'translated'


def main() -> None:
    data = json.loads(CATALOG.read_text(encoding='utf-8'))
    strings = data.get('strings', {})

    for key, value in strings.items():
        localizations = value.setdefault('localizations', {})
        default_val = fallback_value(key, localizations)
        for locale in REQUIRED_LOCALES:
            ensure_unit(localizations, locale, default_val)

        # Keep state consistent for already present units
        for locale_data in localizations.values():
            unit = locale_data.get('stringUnit')
            if isinstance(unit, dict) and unit.get('state') == 'new':
                unit['state'] = 'translated'

    CATALOG.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Normalized {len(strings)} keys in {CATALOG}')


if __name__ == '__main__':
    main()
