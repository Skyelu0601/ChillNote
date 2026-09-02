#!/usr/bin/env python3
"""Validate local Fastlane metadata without contacting Google Play."""

from __future__ import annotations

from pathlib import Path

from PIL import Image


GOOGLE_PLAY_ROOT = Path(__file__).resolve().parents[1]
FASTLANE_ROOT = GOOGLE_PLAY_ROOT / "fastlane"
LISTING_ROOT = FASTLANE_ROOT / "metadata" / "listing" / "en-US"
SCREENSHOTS_ROOT = FASTLANE_ROOT / "metadata" / "screenshots"

EXPECTED_LOCALES = (
    "de-DE",
    "en-US",
    "es-419",
    "es-ES",
    "fr-FR",
    "ja-JP",
    "ko-KR",
    "zh-CN",
    "zh-TW",
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def validate_listing() -> None:
    limits = {
        "title.txt": 30,
        "short_description.txt": 80,
        "full_description.txt": 4000,
    }
    for filename, limit in limits.items():
        path = LISTING_ROOT / filename
        require(path.is_file(), f"Missing listing file: {path}")
        content = path.read_text(encoding="utf-8").strip()
        require(content, f"Listing file is empty: {path}")
        require(len(content) <= limit, f"{filename} exceeds Google Play's {limit}-character limit")

    images = LISTING_ROOT / "images"
    require((images / "icon.png").is_file(), "Missing Fastlane icon link")
    require((images / "featureGraphic.png").is_file(), "Missing Fastlane feature graphic link")


def validate_screenshots() -> None:
    locales = tuple(sorted(path.name for path in SCREENSHOTS_ROOT.iterdir() if path.is_dir()))
    require(locales == EXPECTED_LOCALES, f"Unexpected Fastlane locales: {locales}")

    for locale in EXPECTED_LOCALES:
        screenshots_dir = SCREENSHOTS_ROOT / locale / "images" / "phoneScreenshots"
        paths = sorted(screenshots_dir.glob("*.png"))
        require(len(paths) == 5, f"{locale} must contain exactly 5 phone screenshots")
        for path in paths:
            with Image.open(path) as image:
                require(image.size == (1080, 1920), f"Unexpected dimensions for {path}: {image.size}")


def main() -> None:
    validate_listing()
    validate_screenshots()
    print("Fastlane metadata valid: English listing and 9 localized screenshot sets")


if __name__ == "__main__":
    main()
