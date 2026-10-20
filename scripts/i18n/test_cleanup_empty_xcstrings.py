import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from scripts.i18n.cleanup_empty_xcstrings import cleanup_blank_keys
from scripts.i18n import lint_i18n


class BlankCatalogCleanupTests(unittest.TestCase):
    def clean(self, text):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'Localizable.xcstrings'
            path.write_text(text, encoding='utf-8')
            removed = cleanup_blank_keys(path)
            result = path.read_text(encoding='utf-8')
            self.assertEqual(cleanup_blank_keys(path), [])
            self.assertEqual(path.read_text(encoding='utf-8'), result)
            return removed, result

    def test_removes_blank_identifiers_in_any_position(self):
        for keys in [['', 'named'], ['named', ' '], ['', '\t'], ['named', '', '\n'], ['']]:
            with self.subTest(keys=keys):
                data = {'sourceLanguage': 'en', 'strings': {key: {} for key in keys}, 'version': '1.0'}
                for indent in [None, 2]:
                    removed, result = self.clean(json.dumps(data, indent=indent))
                    self.assertEqual(set(removed), {key for key in keys if not key.strip()})
                    self.assertEqual(json.loads(result)['strings'], {key: {} for key in keys if key.strip()})

    def test_preserves_named_entries_and_formatting(self):
        text = '{\n  "strings" : {\n    "" : {\n\n    },\n    "named" : { "localizations" : {} }\n  }\n}\n'
        removed, result = self.clean(text)
        self.assertEqual(removed, [''])
        self.assertEqual(result, '{\n  "strings" : {\n    "named" : { "localizations" : {} }\n  }\n}\n')

    def test_leaves_incomplete_translations_untouched(self):
        text = '{ "strings": {"missing": {}, "empty_translation": {"localizations": {"en": {"stringUnit": {"value": ""}}}}}}'
        removed, result = self.clean(text)
        self.assertEqual(removed, [])
        self.assertEqual(result, text)

    def test_linter_cleans_before_validating(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'Localizable.xcstrings'
            path.write_text('{"strings": {"": {}}}', encoding='utf-8')
            def check():
                self.assertEqual(json.loads(path.read_text())['strings'], {})
                return []
            with patch.object(lint_i18n, 'CATALOG_PATH', path), \
                 patch.object(lint_i18n, 'check_catalog', side_effect=check), \
                 patch.object(lint_i18n, 'check_swift_sources', return_value=[]), \
                 patch.object(lint_i18n, 'check_permission_descriptions', return_value=[]):
                self.assertEqual(lint_i18n.main(), 0)


if __name__ == '__main__':
    unittest.main()
