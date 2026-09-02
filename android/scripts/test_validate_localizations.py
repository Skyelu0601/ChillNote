from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parent))

import validate_localizations as validator


class FormatTokenTests(unittest.TestCase):
    def test_rejects_ios_and_unknown_format_tokens(self) -> None:
        for token in ("%@", "%1$@", "%ld", "%lld", "%1$lld", "%1$02lld", "%zu"):
            with self.subTest(token=token):
                self.assertTrue(validator.format_token_errors(f"Value: {token}"))
        self.assertTrue(validator.format_token_errors("Value: %1$q"))

    def test_detects_full_java_formatter_syntax(self) -> None:
        value = "Value %2$,.2f, %1$s, %<S, %3$tF, %% and %n"
        tokens, errors = validator.scan_format_tokens(value)
        self.assertEqual(errors, [])
        self.assertEqual(
            [token.raw for token in tokens],
            ["%2$,.2f", "%1$s", "%<S", "%3$tF", "%%", "%n"],
        )

    def test_indexed_placeholders_may_reorder_but_types_must_match(self) -> None:
        source = "%1$s: %2$04d"
        reordered = "%2$04d · %1$s"
        wrong_type = "%2$04s · %1$s"
        self.assertEqual(
            validator.placeholder_signature(source),
            validator.placeholder_signature(reordered),
        )
        self.assertNotEqual(
            validator.placeholder_signature(source),
            validator.placeholder_signature(wrong_type),
        )

    def test_plain_percentage_is_not_treated_as_a_placeholder(self) -> None:
        self.assertEqual(validator.format_token_errors("Save 20%"), [])
        self.assertEqual(validator.placeholder_signature("Save 20%"), {})


class ContentGuardTests(unittest.TestCase):
    def test_plain_key_rejects_markdown_url(self) -> None:
        failures = validator.value_format_failures(
            "values-de",
            "auth_login_legal_plain",
            "Akzeptiere die [Bedingungen](https://example.com/terms).",
        )
        self.assertTrue(any("Markdown URL" in failure for failure in failures))
        self.assertEqual(
            validator.value_format_failures(
                "values-de",
                "auth_login_legal_plain",
                "Bedingungen: https://example.com/terms",
            ),
            [],
        )

    def test_rejects_malformed_markdown_link(self) -> None:
        failures = validator.value_format_failures(
            "values-ko",
            "auth_login_legal_markdown",
            "[약관] (https://example.com/terms)",
        )
        self.assertTrue(any("whitespace separates" in failure for failure in failures))

    def test_rejects_legacy_visible_brand(self) -> None:
        failures = validator.value_format_failures(
            "values-fr",
            "weekly_topics_preview_message",
            "Chaque semaine, ChillNote prépare vos idées.",
        )
        self.assertTrue(any("legacy user-visible brand" in failure for failure in failures))

    def test_locale_config_must_match_resource_directories(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            res = root / "res"
            locale_dir = res / "values-de"
            locale_dir.mkdir(parents=True)
            (locale_dir / "strings.xml").write_text("<resources />", encoding="utf-8")
            config = res / "xml" / "locales_config.xml"
            config.parent.mkdir()
            config.write_text(
                '<?xml version="1.0"?><locale-config '
                'xmlns:android="http://schemas.android.com/apk/res/android">'
                '<locale android:name="en" /></locale-config>',
                encoding="utf-8",
            )
            failures = validator.locale_configuration_failures(
                res,
                config,
                {"values-de"},
            )
            self.assertTrue(any("missing resource locales: de" in failure for failure in failures))

            config.write_text(
                '<?xml version="1.0"?><locale-config '
                'xmlns:android="http://schemas.android.com/apk/res/android">'
                '<locale android:name="en" /><locale android:name="de" /></locale-config>',
                encoding="utf-8",
            )
            self.assertEqual(
                validator.locale_configuration_failures(res, config, {"values-de"}),
                [],
            )

    def test_android_chinese_directories_map_to_script_locales(self) -> None:
        self.assertEqual(validator.resource_locale_tag("values-zh-rCN"), "zh-Hans")
        self.assertEqual(validator.resource_locale_tag("values-zh-rTW"), "zh-Hant")
        self.assertEqual(validator.resource_locale_tag("values-b+zh+Hans"), "zh-Hans")


if __name__ == "__main__":
    unittest.main()
