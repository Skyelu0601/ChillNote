#!/usr/bin/env python3
"""Build Google Play screenshots from real Pixel 7 captures.

The composition intentionally follows the existing ChillScript App Store
artwork: warm background, two-line benefit headline, blue accent, and a real
product screen in a softly rounded panel. No app UI is generated or redrawn.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


WIDTH = 1080
HEIGHT = 1920
BACKGROUND = (247, 246, 242)
INK = (21, 23, 26)
BLUE = (56, 103, 232)
BORDER = (218, 218, 214)

FONT_PATH = Path("/System/Library/Fonts/SFNS.ttf")
ASSET_DIR = Path(__file__).resolve().parents[3] / "screenshots" / "app_store_preview_draft" / "assets"

CAPTURES = {
    "transcript": "Screenshot_20260825-094425.png",
    "skills": "Screenshot_20260825-094514.png",
    "skill_result": "Screenshot_20260825-094530.png",
    "record": "Screenshot_20260825-094549.png",
    "home": "Screenshot_20260825-094618.png",
    "weekly": "Screenshot_20260825-094627.png",
}


def sf_font(size: int, weight: str = "Bold") -> ImageFont.FreeTypeFont:
    result = ImageFont.truetype(str(FONT_PATH), size)
    try:
        result.set_variation_by_name(weight)
    except (AttributeError, OSError):
        pass
    return result


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def add_headline(canvas: Image.Image, line_one: str, line_two: str, *, y: int = 110) -> None:
    draw = ImageDraw.Draw(canvas)
    size = 88
    max_width = WIDTH - 112
    while size >= 66:
        title_font = sf_font(size)
        widths = [draw.textbbox((0, 0), line, font=title_font)[2] for line in (line_one, line_two)]
        if max(widths) <= max_width:
            break
        size -= 2

    title_font = sf_font(size)
    draw.text((56, y), line_one, font=title_font, fill=INK)
    draw.text((56, y + size + 8), line_two, font=title_font, fill=BLUE)


def crop_capture(path: Path, crop_top: int, crop_bottom: int = 0) -> Image.Image:
    source = Image.open(path).convert("RGB")
    bottom = source.height - crop_bottom if crop_bottom else source.height
    return source.crop((0, crop_top, source.width, bottom))


def add_panel(
    canvas: Image.Image,
    source: Image.Image,
    *,
    x: int,
    y: int,
    width: int,
    radius: int = 56,
    shadow_alpha: int = 34,
) -> tuple[int, int]:
    height = round(source.height * width / source.width)
    source = source.resize((width, height), Image.Resampling.LANCZOS)

    shadow_pad = 60
    shadow = Image.new("RGBA", (width + shadow_pad * 2, height + shadow_pad * 2), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (shadow_pad, shadow_pad, shadow_pad + width, shadow_pad + height),
        radius=radius,
        fill=(30, 42, 58, shadow_alpha),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    canvas.alpha_composite(shadow, (x - shadow_pad, y - shadow_pad))

    canvas.paste(source, (x, y), rounded_mask((width, height), radius))
    ImageDraw.Draw(canvas).rounded_rectangle(
        (x, y, x + width - 1, y + height - 1),
        radius=radius,
        outline=BORDER,
        width=2,
    )
    return width, height


def platform_icon(label: str, size: int = 58) -> Image.Image:
    filename = {"TikTok": "tiktok.png", "YouTube": "youtube.png", "Reels": "reels.png"}[label]
    icon = Image.open(ASSET_DIR / filename).convert("RGBA")
    icon.thumbnail((size, size), Image.Resampling.LANCZOS)
    if label == "YouTube":
        red = Image.new("RGBA", icon.size, (255, 0, 0, 255))
        red.putalpha(icon.getchannel("A"))
        icon = red
    base = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    base.alpha_composite(icon, ((size - icon.width) // 2, (size - icon.height) // 2))
    return base


def add_platform_row(canvas: Image.Image, y: int = 350) -> None:
    draw = ImageDraw.Draw(canvas)
    label_font = sf_font(31, "Semibold")
    items = (("TikTok", 75), ("YouTube", 395), ("Reels", 750))
    for label, x in items:
        icon = platform_icon(label)
        canvas.alpha_composite(icon, (x, y))
        bbox = draw.textbbox((0, 0), label, font=label_font)
        text_y = y + (58 - (bbox[3] - bbox[1])) // 2 - bbox[1]
        draw.text((x + 72, text_y), label, font=label_font, fill=INK)


def new_canvas() -> Image.Image:
    return Image.new("RGBA", (WIDTH, HEIGHT), BACKGROUND + (255,))


def slide_transcript(source_dir: Path) -> Image.Image:
    canvas = new_canvas()
    add_headline(canvas, "Share Any Video.", "Get the Transcript.")
    add_platform_row(canvas)
    source = crop_capture(source_dir / CAPTURES["transcript"], 250)
    add_panel(canvas, source, x=55, y=470, width=970)
    return canvas


def slide_skills(source_dir: Path) -> Image.Image:
    canvas = new_canvas()
    add_headline(canvas, "Rewrite, Repurpose,", "and Create More.")

    skills = crop_capture(source_dir / CAPTURES["skills"], 250, 80)
    add_panel(canvas, skills, x=35, y=410, width=770, radius=52, shadow_alpha=28)

    result = crop_capture(source_dir / CAPTURES["skill_result"], 85, 530)
    add_panel(canvas, result, x=425, y=1035, width=625, radius=50, shadow_alpha=45)
    return canvas


def slide_record(source_dir: Path) -> Image.Image:
    canvas = new_canvas()
    add_headline(canvas, "Record With a", "Teleprompter.")
    source = crop_capture(source_dir / CAPTURES["record"], 250, 80)
    add_panel(canvas, source, x=55, y=415, width=970)
    return canvas


def slide_home(source_dir: Path) -> Image.Image:
    canvas = new_canvas()
    add_headline(canvas, "Never Lose a", "Content Idea Again.")
    source = crop_capture(source_dir / CAPTURES["home"], 105)
    add_panel(canvas, source, x=55, y=415, width=970)
    return canvas


def slide_weekly(source_dir: Path) -> Image.Image:
    canvas = new_canvas()
    add_headline(canvas, "New Post Ideas.", "Ready Every Week.")
    source = crop_capture(source_dir / CAPTURES["weekly"], 105)
    add_panel(canvas, source, x=55, y=415, width=970)
    return canvas


def save_contact_sheet(images: list[Image.Image], path: Path) -> None:
    thumb_width = 270
    thumb_height = round(HEIGHT * thumb_width / WIDTH)
    sheet = Image.new("RGB", (thumb_width * len(images), thumb_height), BACKGROUND)
    for index, image in enumerate(images):
        thumb = image.convert("RGB").resize((thumb_width, thumb_height), Image.Resampling.LANCZOS)
        sheet.paste(thumb, (index * thumb_width, 0))
    sheet.save(path, "PNG", optimize=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source-dir",
        type=Path,
        default=Path("/Users/luwenting/Downloads/QuickShare-Craft的Pixel-7"),
        help="Directory containing the six Pixel 7 PNG captures.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "screenshots" / "en-US",
        help="Directory for upload-ready PNG files.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    missing = [name for name in CAPTURES.values() if not (args.source_dir / name).is_file()]
    if missing:
        raise FileNotFoundError(f"Missing source captures: {', '.join(missing)}")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    slides = [
        ("01-share-any-video-get-the-transcript.png", slide_transcript(args.source_dir)),
        ("02-rewrite-repurpose-and-create-more.png", slide_skills(args.source_dir)),
        ("03-record-with-a-teleprompter.png", slide_record(args.source_dir)),
        ("04-never-lose-a-content-idea-again.png", slide_home(args.source_dir)),
        ("05-new-post-ideas-ready-every-week.png", slide_weekly(args.source_dir)),
    ]

    for filename, image in slides:
        image.convert("RGB").save(args.output_dir / filename, "PNG", optimize=True)

    preview_dir = args.output_dir.parent / "previews"
    preview_dir.mkdir(parents=True, exist_ok=True)
    save_contact_sheet([image for _, image in slides], preview_dir / "en-US-contact-sheet.png")
    print(f"Generated {len(slides)} upload-ready screenshots in {args.output_dir}")


if __name__ == "__main__":
    main()
