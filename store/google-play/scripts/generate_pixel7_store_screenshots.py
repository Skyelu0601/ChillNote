#!/usr/bin/env python3
"""Build ChillScript Google Play screenshots from real Pixel 7 captures.

All inputs belong to the Android project: Pixel captures live under
``store/google-play/source-captures`` and platform marks come from Android app
resources. The exported artwork follows Google Play's portrait requirements;
no app UI is generated or redrawn.
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
PLAY_STORE_DIR = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = Path(__file__).resolve().parents[3]
ANDROID_RESOURCE_DIR = REPOSITORY_ROOT / "android" / "app" / "src" / "main" / "res" / "drawable-nodpi"
DEFAULT_SOURCE_DIR = PLAY_STORE_DIR / "source-captures" / "pixel7"

CAPTURES = {
    "transcript": "Screenshot_20260825-094425.png",
    "skills": "Screenshot_20260825-094514.png",
    "skill_result": "Screenshot_20260825-094530.png",
    "record": "Screenshot_20260825-094549.png",
    "home": "Screenshot_20260825-094618.png",
    "weekly": "Screenshot_20260825-094627.png",
}

LOCALE_HEADLINES: dict[str, dict[str, tuple[str, str]]] = {
    "en-US": {
        "home": ("Never Lose a", "Content Idea Again."),
        "transcript": ("Viral Video In.", "Transcript Out."),
        "skills": ("Rewrite, Repurpose,", "and Create More."),
        "weekly": ("Fresh Post Ideas.", "Every Week."),
        "record": ("Record With a", "Teleprompter."),
    },
    "de-DE": {
        "home": ("Verliere nie wieder", "eine Content-Idee"),
        "transcript": ("Vom viralen Video", "zum Transkript"),
        "skills": ("Neu schreiben", "mehr daraus holen"),
        "weekly": ("Jede Woche", "neue Post-Ideen"),
        "record": ("Mit Teleprompter", "einfach aufnehmen"),
    },
    "es-ES": {
        "home": ("Guarda todas tus", "ideas de contenido"),
        "transcript": ("Del vídeo viral", "a la transcripción"),
        "skills": ("Reescribe, reutiliza", "Crea más contenido"),
        "weekly": ("Ideas de contenido", "cada semana"),
        "record": ("Graba con", "un teleprónter"),
    },
    "es-419": {
        "home": ("Guarda todas tus", "ideas de contenido"),
        "transcript": ("Del video viral", "a la transcripción"),
        "skills": ("Reescribe, reutiliza", "Crea más contenido"),
        "weekly": ("Ideas de contenido", "cada semana"),
        "record": ("Graba con", "un teleprompter"),
    },
    "fr-FR": {
        "home": ("Gardez toutes vos", "idées de contenu"),
        "transcript": ("De la vidéo virale", "à la transcription"),
        "skills": ("Réécrivez, déclinez", "et créez davantage"),
        "weekly": ("Des idées de posts", "chaque semaine"),
        "record": ("Filmez avec", "un téléprompteur"),
    },
    "ja-JP": {
        "home": ("投稿アイデアを", "もう忘れない"),
        "transcript": ("バズ動画から", "文字起こしまで"),
        "skills": ("リライト・再活用", "投稿をもっと作る"),
        "weekly": ("新しい投稿ネタを", "毎週お届け"),
        "record": ("テレプロンプターで", "スムーズに撮影"),
    },
    "ko-KR": {
        "home": ("콘텐츠 아이디어를", "놓치지 마세요"),
        "transcript": ("바이럴 영상에서", "텍스트 변환까지"),
        "skills": ("다시 쓰고 활용해", "콘텐츠를 더 만드세요"),
        "weekly": ("새 콘텐츠 아이디어를", "매주 받아보세요"),
        "record": ("텔레프롬프터로", "편하게 촬영하세요"),
    },
    "zh-CN": {
        "home": ("不再错过", "任何创作灵感"),
        "transcript": ("从爆款视频", "到完整文字稿"),
        "skills": ("改写、再创作", "高效产出更多内容"),
        "weekly": ("每周都有", "全新内容灵感"),
        "record": ("使用提词器", "轻松拍摄"),
    },
    "zh-TW": {
        "home": ("不再錯過", "任何創作靈感"),
        "transcript": ("從爆紅影片", "到完整逐字稿"),
        "skills": ("改寫、再創作", "高效產出更多內容"),
        "weekly": ("每週都有", "全新貼文靈感"),
        "record": ("使用提詞器", "輕鬆拍攝"),
    },
}

SLIDE_FILENAMES = {
    "home": "01-never-lose-a-content-idea-again.png",
    "transcript": "02-viral-video-in-transcript-out.png",
    "skills": "03-rewrite-repurpose-and-create-more.png",
    "weekly": "04-fresh-post-ideas-every-week.png",
    "record": "05-record-with-a-teleprompter.png",
}


def sf_font(size: int, weight: str = "Bold") -> ImageFont.FreeTypeFont:
    result = ImageFont.truetype(str(FONT_PATH), size)
    try:
        result.set_variation_by_name(weight)
    except (AttributeError, OSError):
        pass
    return result


def has_japanese(text: str) -> bool:
    return any("\u3040" <= char <= "\u30ff" for char in text)


def has_korean(text: str) -> bool:
    return any("\uac00" <= char <= "\ud7af" for char in text)


def has_han(text: str) -> bool:
    return any("\u3400" <= char <= "\u9fff" for char in text)


def headline_font(text: str, size: int) -> ImageFont.FreeTypeFont:
    if has_korean(text):
        return ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc", size, index=14)
    if has_japanese(text):
        return ImageFont.truetype("/System/Library/Fonts/ヒラギノ角ゴシック W7.ttc", size)
    if has_han(text):
        return ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc", size, index=2)
    return sf_font(size)


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def add_headline(canvas: Image.Image, line_one: str, line_two: str, *, y: int = 110) -> None:
    draw = ImageDraw.Draw(canvas)
    size = 88
    max_width = WIDTH - 112
    headline = f"{line_one}\n{line_two}"
    while size >= 66:
        title_font = headline_font(headline, size)
        widths = [draw.textbbox((0, 0), line, font=title_font)[2] for line in (line_one, line_two)]
        if max(widths) <= max_width:
            break
        size -= 2

    title_font = headline_font(headline, size)
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


def tint_alpha(source: Image.Image, color: tuple[int, int, int]) -> Image.Image:
    tinted = Image.new("RGBA", source.size, color + (255,))
    tinted.putalpha(source.getchannel("A"))
    return tinted


def reels_gradient_icon(source: Image.Image) -> Image.Image:
    """Color the Android Instagram/Reels mark without another asset dependency."""
    gradient = Image.new("RGBA", source.size, (0, 0, 0, 0))
    pixels = gradient.load()
    for y in range(source.height):
        ratio = y / max(source.height - 1, 1)
        if ratio < 0.5:
            local = ratio * 2
            start, end = (202, 55, 171), (248, 73, 91)
        else:
            local = (ratio - 0.5) * 2
            start, end = (248, 73, 91), (255, 190, 49)
        color = tuple(round(a + (b - a) * local) for a, b in zip(start, end))
        for x in range(source.width):
            pixels[x, y] = color + (255,)
    gradient.putalpha(source.getchannel("A"))
    return gradient


def platform_icon(label: str, size: int = 58) -> Image.Image:
    filename = {
        "TikTok": "source_brand_tiktok.png",
        "YouTube": "source_brand_youtube.png",
        "Reels": "source_brand_instagram.png",
    }[label]
    icon = Image.open(ANDROID_RESOURCE_DIR / filename).convert("RGBA")
    icon.thumbnail((size, size), Image.Resampling.LANCZOS)
    if label == "YouTube":
        icon = tint_alpha(icon, (255, 0, 0))
    elif label == "Reels":
        icon = reels_gradient_icon(icon)
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


def slide_transcript(source_dir: Path, headline: tuple[str, str]) -> Image.Image:
    canvas = new_canvas()
    add_headline(canvas, *headline)
    add_platform_row(canvas)
    source = crop_capture(source_dir / CAPTURES["transcript"], 250)
    add_panel(canvas, source, x=55, y=470, width=970)
    return canvas


def slide_skills(source_dir: Path, headline: tuple[str, str]) -> Image.Image:
    canvas = new_canvas()
    add_headline(canvas, *headline)

    skills = crop_capture(source_dir / CAPTURES["skills"], 250, 80)
    add_panel(canvas, skills, x=35, y=410, width=770, radius=52, shadow_alpha=28)

    # Crop away the Android sheet toolbar ("Cancel / Skill Result") so the
    # supporting card focuses on the Hook type and its first three outputs.
    result = crop_capture(source_dir / CAPTURES["skill_result"], 245, 850)
    add_panel(canvas, result, x=430, y=1130, width=600, radius=48, shadow_alpha=45)
    return canvas


def slide_record(source_dir: Path, headline: tuple[str, str]) -> Image.Image:
    canvas = new_canvas()
    add_headline(canvas, *headline)
    source = crop_capture(source_dir / CAPTURES["record"], 250, 80)
    add_panel(canvas, source, x=55, y=415, width=970)
    return canvas


def slide_home(source_dir: Path, headline: tuple[str, str]) -> Image.Image:
    canvas = new_canvas()
    add_headline(canvas, *headline)
    source = crop_capture(source_dir / CAPTURES["home"], 105)
    add_panel(canvas, source, x=55, y=415, width=970)
    return canvas


def slide_weekly(source_dir: Path, headline: tuple[str, str]) -> Image.Image:
    canvas = new_canvas()
    add_headline(canvas, *headline)
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


def save_locales_overview(
    locale_images: list[tuple[str, list[Image.Image]]],
    path: Path,
) -> None:
    thumb_width = 216
    thumb_height = round(HEIGHT * thumb_width / WIDTH)
    label_height = 54
    row_gap = 18
    sheet = Image.new(
        "RGB",
        (thumb_width * 5, (label_height + thumb_height + row_gap) * len(locale_images) - row_gap),
        BACKGROUND,
    )
    draw = ImageDraw.Draw(sheet)
    label_font = sf_font(30, "Semibold")
    row_y = 0
    for locale, images in locale_images:
        draw.text((16, row_y + 8), locale, font=label_font, fill=INK)
        for index, image in enumerate(images):
            thumb = image.convert("RGB").resize((thumb_width, thumb_height), Image.Resampling.LANCZOS)
            sheet.paste(thumb, (index * thumb_width, row_y + label_height))
        row_y += label_height + thumb_height + row_gap
    sheet.save(path, "PNG", optimize=True)


def prepare_output_dir(output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for png in output_dir.glob("*.png"):
        png.unlink()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source-dir",
        type=Path,
        default=DEFAULT_SOURCE_DIR,
        help="Directory containing the six Android-owned Pixel 7 PNG captures.",
    )
    parser.add_argument(
        "--output-root",
        type=Path,
        default=PLAY_STORE_DIR / "screenshots",
        help="Root directory containing one upload-ready folder per Google Play locale.",
    )
    parser.add_argument(
        "--locale",
        action="append",
        choices=tuple(LOCALE_HEADLINES),
        dest="locales",
        help="Generate only this locale. Repeat to select multiple locales; omit to generate all.",
    )
    return parser.parse_args()


def build_slides(source_dir: Path, headlines: dict[str, tuple[str, str]]) -> list[tuple[str, Image.Image]]:
    return [
        (SLIDE_FILENAMES["home"], slide_home(source_dir, headlines["home"])),
        (SLIDE_FILENAMES["transcript"], slide_transcript(source_dir, headlines["transcript"])),
        (SLIDE_FILENAMES["skills"], slide_skills(source_dir, headlines["skills"])),
        (SLIDE_FILENAMES["weekly"], slide_weekly(source_dir, headlines["weekly"])),
        (SLIDE_FILENAMES["record"], slide_record(source_dir, headlines["record"])),
    ]


def main() -> None:
    args = parse_args()
    missing = [name for name in CAPTURES.values() if not (args.source_dir / name).is_file()]
    if missing:
        raise FileNotFoundError(f"Missing source captures: {', '.join(missing)}")

    locales = args.locales or list(LOCALE_HEADLINES)
    preview_dir = args.output_root / "previews"
    preview_dir.mkdir(parents=True, exist_ok=True)
    locale_images = []

    for locale in locales:
        output_dir = args.output_root / locale
        prepare_output_dir(output_dir)
        slides = build_slides(args.source_dir, LOCALE_HEADLINES[locale])
        images = [image for _, image in slides]
        for filename, image in slides:
            image.convert("RGB").save(output_dir / filename, "PNG", optimize=True)
        save_contact_sheet(images, preview_dir / f"{locale}-contact-sheet.png")
        locale_images.append((locale, images))

    save_locales_overview(locale_images, preview_dir / "all-locales-overview.png")
    print(f"Generated {len(locales) * len(SLIDE_FILENAMES)} screenshots across {len(locales)} locales")


if __name__ == "__main__":
    main()
