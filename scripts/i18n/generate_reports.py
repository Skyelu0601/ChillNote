#!/usr/bin/env python3
import csv
import json
import re
from pathlib import Path

CATALOG_PATH = Path('chillnote/Resources/Localizable.xcstrings')
OUTPUT_DIR = Path('docs/i18n')
SWIFT_ROOT = Path('chillnote')

UI_LITERAL_PATTERN = re.compile(
    r'\b(Text|Button|Label|TextField)\(\s*"((?:\\.|[^"\\])*)"|'
    r'\.alert\(\s*"((?:\\.|[^"\\])*)"|'
    r'\.navigationTitle\(\s*"((?:\\.|[^"\\])*)"|'
    r'\.accessibility(?:Label|Hint)\(\s*"((?:\\.|[^"\\])*)"'
)


def load_catalog():
    data = json.loads(CATALOG_PATH.read_text(encoding='utf-8'))
    return data.get('strings', {})


def iter_swift_literals():
    for path in SWIFT_ROOT.rglob('*.swift'):
        content = path.read_text(encoding='utf-8')
        for match in UI_LITERAL_PATTERN.finditer(content):
            literal = next((group for group in match.groups()[1:] if group), None)
            if not literal:
                continue
            literal = literal.replace('\\n', '\n')
            literal = literal.replace('\\"', '"')
            line = content.count('\n', 0, match.start()) + 1
            dynamic = '\\(' in literal
            yield {
                'key': literal,
                'file': str(path),
                'line': line,
                'is_dynamic': dynamic,
                'context': match.group(1) or 'modifier',
            }


def risk_level(literal: str) -> str:
    if '\\(' in literal or '%@' in literal or '%lld' in literal:
        return 'high'
    if len(literal) > 48:
        return 'medium'
    return 'low'


def generate_inventory(strings: dict):
    rows = list(iter_swift_literals())
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    csv_path = OUTPUT_DIR / 'string_inventory_v1.csv'

    with csv_path.open('w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(
            f,
            fieldnames=['key', 'file', 'line', 'context', 'is_dynamic', 'in_catalog', 'risk'],
        )
        writer.writeheader()
        for row in rows:
            row['in_catalog'] = row['key'] in strings
            row['risk'] = risk_level(row['key'])
            writer.writerow(row)


def generate_missing_report(strings: dict):
    literals = list(iter_swift_literals())
    keys = set(strings.keys())

    missing = []
    for row in literals:
        if row['key'] in keys:
            continue
        missing.append(row)

    report_path = OUTPUT_DIR / 'missing_keys_report_v1.md'
    lines = [
        '# Missing Localization Keys Report v1',
        '',
        f'- Total missing literals: {len(missing)}',
        '',
        '| Key | File | Line | Dynamic |',
        '| --- | --- | ---: | :---: |',
    ]
    for row in missing[:400]:
        lines.append(
            f"| `{row['key'].replace('|', '\\|')}` | `{row['file']}` | {row['line']} | {'yes' if row['is_dynamic'] else 'no'} |"
        )

    report_path.write_text('\n'.join(lines) + '\n', encoding='utf-8')


def generate_glossary():
    glossary_path = OUTPUT_DIR / 'glossary_v1.md'
    glossary_path.write_text(
        """# ChillNote Glossary v1

## Brand Terms
- ChillNote: 品牌名，不翻译
- Chill AI: 功能品牌名，不翻译
- PRO: 订阅等级标签，可保留大写

## Product Terms
- Note: 笔记
- Tag: 标签
- Recycle Bin: 回收站
- Voice Transcription: 语音转写
- Subscription: 订阅
- Export: 导出
- Pending Recordings: 待处理录音

## Style Rules
- 中文（简/繁）：使用自然口语，不直译英文语序。
- 日语：按钮尽量简短，避免英文夹杂。
- 法/德/西/韩：保持操作文案统一敬语和语气。
- 错误提示：先说问题，再给动作建议。
""",
        encoding='utf-8',
    )


def main():
    strings = load_catalog()
    generate_inventory(strings)
    generate_missing_report(strings)
    generate_glossary()
    print('Generated docs/i18n/string_inventory_v1.csv')
    print('Generated docs/i18n/missing_keys_report_v1.md')
    print('Generated docs/i18n/glossary_v1.md')


if __name__ == '__main__':
    main()
