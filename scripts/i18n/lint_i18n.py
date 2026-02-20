#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

CATALOG_PATH = Path('chillnote/Resources/Localizable.xcstrings')
REQUIRED_LOCALES = ['en', 'zh-Hans', 'zh-Hant', 'ja', 'fr', 'de', 'es', 'ko']
SWIFT_ROOT = Path('chillnote')

UI_LITERAL_PATTERN = re.compile(
    r'\b(Text|Button|Label|TextField)\(\s*"((?:\\.|[^"\\])*)"|'
    r'\.alert\(\s*"((?:\\.|[^"\\])*)"|'
    r'\.navigationTitle\(\s*"((?:\\.|[^"\\])*)"|'
    r'\.accessibility(?:Label|Hint)\(\s*"((?:\\.|[^"\\])*)"'
)


def check_catalog() -> list[str]:
    errors: list[str] = []
    data = json.loads(CATALOG_PATH.read_text(encoding='utf-8'))
    strings = data.get('strings', {})

    for key, value in strings.items():
        localizations = value.get('localizations', {})
        for locale in REQUIRED_LOCALES:
            unit = localizations.get(locale, {}).get('stringUnit')
            if not isinstance(unit, dict):
                errors.append(f'[catalog] key="{key}" missing locale="{locale}"')
                continue
            if unit.get('state') == 'new':
                errors.append(f'[catalog] key="{key}" locale="{locale}" state=new')
            if not unit.get('value'):
                errors.append(f'[catalog] key="{key}" locale="{locale}" empty value')

    return errors


def check_swift_literals() -> list[str]:
    errors: list[str] = []
    data = json.loads(CATALOG_PATH.read_text(encoding='utf-8'))
    keys = set((data.get('strings') or {}).keys())

    for path in SWIFT_ROOT.rglob('*.swift'):
        content = path.read_text(encoding='utf-8')
        for match in UI_LITERAL_PATTERN.finditer(content):
            literal = next((group for group in match.groups()[1:] if group), None)
            if not literal:
                continue
            literal = literal.replace('\\n', '\n')
            literal = literal.replace('\\"', '"')
            if '\\(' in literal:
                # interpolation should be handled via formatted keys
                continue
            if literal in keys:
                continue
            line = content.count('\n', 0, match.start()) + 1
            errors.append(f'[swift] {path}:{line} literal not in catalog: "{literal}"')

    return errors


def main() -> int:
    errors = []
    errors.extend(check_catalog())
    errors.extend(check_swift_literals())

    if errors:
        print('\n'.join(errors))
        print(f'\nFAIL: {len(errors)} i18n issue(s) found.')
        return 1

    print('PASS: i18n checks succeeded.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
