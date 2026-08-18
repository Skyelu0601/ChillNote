from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter


ROOT = Path("/Users/luwenting/development/ChillNote")
OUT_DIR = ROOT / "screenshots" / "app_store_preview_draft"
OUT_DIR.mkdir(parents=True, exist_ok=True)
ASSET_DIR = OUT_DIR / "assets"

W, H = 1290, 2796
CONTENT_X = 84
TITLE_SIZE = 126
TITLE_Y = 292
TITLE_LINE_GAP = 18
SHARE_TITLE_SIZE = 126
SHARE_TITLE_Y = 292
PHONE_W = 850
PHONE_H = 1848
PHONE_X = (W - PHONE_W) // 2
PHONE_Y = 640

BG = (247, 246, 242)
INK = (21, 23, 26)
MUTED = (154, 154, 150)
BLUE = (56, 103, 232)
TEAL = (16, 184, 192)

FONT_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_REG = "/System/Library/Fonts/Supplemental/Arial.ttf"
FONT_SF = "/System/Library/Fonts/SFNS.ttf"
FONT_DISPLAY = "/System/Library/Fonts/Avenir Next.ttc"
FONT_CJK_DISPLAY = "/System/Library/Fonts/Hiragino Sans GB.ttc"
FONT_JA_DISPLAY = "/System/Library/Fonts/ヒラギノ角ゴシック W7.ttc"
FONT_KO_DISPLAY = "/System/Library/Fonts/AppleSDGothicNeo.ttc"


def has_cjk(text):
    return any(
        "\u3040" <= ch <= "\u30ff"
        or "\u3400" <= ch <= "\u9fff"
        or "\uac00" <= ch <= "\ud7af"
        for ch in text
    )


def has_japanese(text):
    return any("\u3040" <= ch <= "\u30ff" for ch in text)


def has_korean(text):
    return any("\uac00" <= ch <= "\ud7af" for ch in text)


def sf_font(size, weight="Regular"):
    f = ImageFont.truetype(FONT_SF, size)
    try:
        f.set_variation_by_name(weight)
    except (AttributeError, OSError):
        pass
    return f


def font(size, bold=False):
    return sf_font(size, "Bold" if bold else "Regular")


def display_font(size):
    return ImageFont.truetype(FONT_DISPLAY, size, index=8)


def title_font(text, size):
    if has_korean(text):
        return ImageFont.truetype(FONT_KO_DISPLAY, size, index=14)
    if has_japanese(text):
        return ImageFont.truetype(FONT_JA_DISPLAY, size)
    if has_cjk(text):
        return ImageFont.truetype(FONT_CJK_DISPLAY, size, index=2)
    return sf_font(size, "Bold")


def text_width(draw, text, font):
    if not text:
        return 0
    bbox = draw.textbbox((0, 0), text, font=font)
    return bbox[2] - bbox[0]


def highlighted_segments(line, highlight):
    if not highlight or highlight not in line:
        return [(line, False)]
    segments = []
    start = 0
    while True:
        index = line.find(highlight, start)
        if index == -1:
            if start < len(line):
                segments.append((line[start:], False))
            break
        if index > start:
            segments.append((line[start:index], False))
        segments.append((line[index : index + len(highlight)], True))
        start = index + len(highlight)
    return segments


def rounded_rect_mask(size, radius):
    mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def draw_wrapped_center(draw, text, y, max_width, size, line_gap=18):
    f = title_font(text, size)
    lines = []
    for paragraph in text.split("\n"):
        words = paragraph.split()
        current = ""
        for word in words:
            trial = f"{current} {word}".strip()
            if draw.textbbox((0, 0), trial, font=f)[2] <= max_width:
                current = trial
            else:
                if current:
                    lines.append(current)
                current = word
        if current:
            lines.append(current)
    total_h = len(lines) * size + (len(lines) - 1) * line_gap
    cy = y
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=f)
        x = (W - (bbox[2] - bbox[0])) // 2
        draw.text((x, cy), line, font=f, fill=INK)
        cy += size + line_gap
    return y + total_h


def draw_display_title(draw, text, y, max_width, size, accent, highlight=None, line_gap=18, x=CONTENT_X):
    # Prefer the intentional two-line composition. Reduce unusually long
    # localized headlines before allowing an explicitly authored third line.
    lines = text.split("\n")
    fitted_size = size
    while fitted_size > 96:
        f = title_font(text, fitted_size)
        if all(text_width(draw, line, f) <= max_width for line in lines):
            break
        fitted_size -= 2
    f = title_font(text, fitted_size)

    cy = y
    for line in lines:
        segments = [
            (segment, text_width(draw, segment, f), is_highlighted)
            for segment, is_highlighted in highlighted_segments(line, highlight)
        ]
        line_x = x
        for segment, segment_w, is_highlighted in segments:
            draw.text((line_x, cy), segment, font=f, fill=accent if is_highlighted else INK)
            line_x += segment_w
        cy += fitted_size + line_gap
    return cy


def draw_pill(draw, text, x, y, fill, outline, text_fill):
    f = font(34, True)
    tw = draw.textbbox((0, 0), text, font=f)[2]
    pad_x, pad_y = 32, 16
    draw.rounded_rectangle((x, y, x + tw + pad_x * 2, y + 70), radius=35, fill=fill, outline=outline, width=2)
    draw.text((x + pad_x, y + pad_y), text, font=f, fill=text_fill)


def cover_resize(img, size):
    src_w, src_h = img.size
    dst_w, dst_h = size
    scale = max(dst_w / src_w, dst_h / src_h)
    resized = img.resize((int(src_w * scale), int(src_h * scale)), Image.LANCZOS)
    left = (resized.width - dst_w) // 2
    top = (resized.height - dst_h) // 2
    return resized.crop((left, top, left + dst_w, top + dst_h))


def contain_resize(img, size, fill=(255, 255, 255)):
    src_w, src_h = img.size
    dst_w, dst_h = size
    scale = min(dst_w / src_w, dst_h / src_h)
    resized = img.resize((int(src_w * scale), int(src_h * scale)), Image.LANCZOS)
    base = Image.new("RGB", size, fill)
    x = (dst_w - resized.width) // 2
    y = (dst_h - resized.height) // 2
    base.paste(resized, (x, y))
    return base


def draw_phone(canvas, screenshot_path, crop_top=0, crop_bottom=0, zoom=1.0, y=PHONE_Y, fit="cover"):
    img = Image.open(screenshot_path).convert("RGB")
    if crop_top or crop_bottom:
        img = img.crop((0, crop_top, img.width, img.height - crop_bottom))
    target = (PHONE_W, PHONE_H)
    if fit == "contain":
        img = contain_resize(img, target)
    elif zoom != 1.0:
        z_w = int(target[0] / zoom)
        z_h = int(target[1] / zoom)
        cropped = cover_resize(img, (z_w, z_h))
        img = cropped.resize(target, Image.LANCZOS)
    else:
        img = cover_resize(img, target)

    shadow = Image.new("RGBA", (PHONE_W + 140, PHONE_H + 160), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((70, 50, 70 + PHONE_W, 50 + PHONE_H), radius=90, fill=(30, 50, 70, 60))
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    canvas.alpha_composite(shadow, (PHONE_X - 70, y - 50))

    frame = Image.new("RGBA", (PHONE_W + 46, PHONE_H + 46), (0, 0, 0, 0))
    fd = ImageDraw.Draw(frame)
    fd.rounded_rectangle((0, 0, PHONE_W + 46, PHONE_H + 46), radius=108, fill=(235, 242, 247, 255))
    fd.rounded_rectangle((23, 23, PHONE_W + 23, PHONE_H + 23), radius=84, fill=(255, 255, 255, 255))
    canvas.alpha_composite(frame, (PHONE_X - 23, y - 23))

    mask = rounded_rect_mask(target, 72)
    canvas.paste(img, (PHONE_X, y), mask)


def crop_lower_share_sheet(screenshot_path):
    img = Image.open(screenshot_path).convert("RGB")
    # Keep only the lower saved sheet: logo, source badge, checkmark, and saved state.
    filename = Path(screenshot_path).name.lower()
    top = 1000
    if "youtube" in filename or "reels" in filename:
        top = 1060
    return img.crop((0, top, img.width, 1880))


def draw_share_card(canvas, screenshot_path, x, y, width, angle=0):
    img = crop_lower_share_sheet(screenshot_path)
    height = int(width * img.height / img.width)
    img = img.resize((width, height), Image.LANCZOS)

    card = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    mask = rounded_rect_mask((width, height), 68)
    card.paste(img, (0, 0), mask)

    shadow = Image.new("RGBA", (width + 80, height + 90), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((40, 30, 40 + width, 30 + height), radius=72, fill=(24, 38, 56, 54))
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))

    if angle:
        shadow = shadow.rotate(angle, expand=True, resample=Image.BICUBIC)
        card = card.rotate(angle, expand=True, resample=Image.BICUBIC)

    canvas.alpha_composite(shadow, (x - 40, y - 30))
    canvas.alpha_composite(card, (x, y))


def platform_colors(label):
    if label == "YouTube":
        return (255, 239, 239), (255, 169, 169), (237, 28, 36)
    if label in ("Instagram Reels", "Reels"):
        return (255, 237, 248), (241, 179, 221), (218, 64, 169)
    return (231, 253, 255), (175, 234, 238), (20, 176, 186)


def draw_source_badge(canvas, label, x, y, scale=1.0):
    fill, outline, text_fill = platform_colors(label)
    draw = ImageDraw.Draw(canvas)
    f = font(int(34 * scale), True)
    text = f"Source: {label}"
    bbox = draw.textbbox((0, 0), text, font=f)
    pad_x = int(30 * scale)
    pad_y = int(17 * scale)
    w = bbox[2] - bbox[0] + pad_x * 2
    h = bbox[3] - bbox[1] + pad_y * 2

    shadow = Image.new("RGBA", (w + 70, h + 70), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((35, 26, 35 + w, 26 + h), radius=h // 2, fill=(25, 45, 70, 42))
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    canvas.alpha_composite(shadow, (x - 35, y - 26))

    draw.rounded_rectangle((x, y, x + w, y + h), radius=h // 2, fill=fill, outline=outline, width=max(2, int(2 * scale)))
    draw.text((x + pad_x, y + pad_y - 3), text, font=f, fill=text_fill)


def tint_icon(icon, color):
    tinted = Image.new("RGBA", icon.size, color)
    tinted.putalpha(icon.getchannel("A"))
    return tinted


def platform_icon(label, size=48):
    filename = {
        "TikTok": "tiktok.png",
        "YouTube": "youtube.png",
        "Reels": "reels.png",
    }[label]
    icon = Image.open(ASSET_DIR / filename).convert("RGBA").resize((size, size), Image.LANCZOS)

    if label == "YouTube":
        return tint_icon(icon, (255, 0, 0, 255))
    if label == "TikTok":
        layered = Image.new("RGBA", (size + 8, size + 8), (0, 0, 0, 0))
        layered.alpha_composite(tint_icon(icon, (37, 244, 238, 255)), (1, 4))
        layered.alpha_composite(tint_icon(icon, (254, 44, 85, 255)), (7, 1))
        layered.alpha_composite(tint_icon(icon, (18, 18, 22, 255)), (4, 3))
        return layered
    return icon


def draw_platform_list(canvas, y=760):
    draw = ImageDraw.Draw(canvas)
    icon_x = 104
    text_x = 344
    icon_size = 140
    row_gap = 290
    f = sf_font(92, "Semibold")

    for index, label in enumerate(("TikTok", "YouTube", "Reels")):
        row_y = y + index * row_gap
        icon = platform_icon(label, size=icon_size)
        canvas.alpha_composite(icon, (icon_x, row_y))
        bbox = draw.textbbox((0, 0), label, font=f)
        text_y = row_y + (icon.height - (bbox[3] - bbox[1])) // 2 - bbox[1]
        draw.text((text_x, text_y), label, font=f, fill=INK)


def saved_check_icon(size=210):
    source = Image.open("/Users/luwenting/Downloads/IMG_0021.PNG").convert("RGBA")
    icon = source.crop((510, 1338, 696, 1524)).resize((size, size), Image.LANCZOS)
    pixels = icon.load()
    for py in range(icon.height):
        for px in range(icon.width):
            r, g, b, a = pixels[px, py]
            if g > r * 1.25 and g > b * 1.15 and g > 110:
                pixels[px, py] = BLUE + (a,)
            if (px - size / 2) ** 2 + (py - size / 2) ** 2 > (size / 2 - 2) ** 2:
                pixels[px, py] = (r, g, b, 0)
    return icon


def draw_minimal_saved_card(canvas, y=1638):
    draw = ImageDraw.Draw(canvas)
    x = 145
    width = W - x
    height = H - y + 180
    radius = 64

    shadow = Image.new("RGBA", (width + 100, height + 100), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((50, 34, 50 + width, 34 + height), radius=radius, fill=(20, 24, 30, 22))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    canvas.alpha_composite(shadow, (x - 50, y - 34))
    draw.rounded_rectangle((x, y, x + width, y + height), radius=radius, fill=(255, 255, 255))

    wordmark_y = y + 102
    wordmark_font = sf_font(66, "Bold")
    draw.text((x + 92, wordmark_y), "Chill", font=wordmark_font, fill=INK)
    chill_width = text_width(draw, "Chill", wordmark_font)
    draw.text((x + 92 + chill_width, wordmark_y), "Script", font=wordmark_font, fill=BLUE)

    source_font = sf_font(44, "Regular")
    source_text = "Source: TikTok"
    source_width = text_width(draw, source_text, source_font)
    draw.text((W - 82 - source_width, wordmark_y + 7), source_text, font=source_font, fill=MUTED)

    icon = saved_check_icon(size=250)
    icon_x = x + 92
    icon_y = y + 430
    icon_shadow = Image.new("RGBA", (icon.width + 70, icon.height + 70), (0, 0, 0, 0))
    isd = ImageDraw.Draw(icon_shadow)
    isd.ellipse((35, 25, 35 + icon.width, 25 + icon.height), fill=(35, 70, 160, 24))
    icon_shadow = icon_shadow.filter(ImageFilter.GaussianBlur(18))
    canvas.alpha_composite(icon_shadow, (icon_x - 35, icon_y - 25))
    canvas.alpha_composite(icon, (icon_x, icon_y))

    saved_font = sf_font(80, "Semibold")
    draw.text((x + 92, y + 740), "Saved to ChillScript", font=saved_font, fill=INK)


def draw_interface_panel(canvas, screenshot_path, crop_top=0, crop_bottom=0, y=816):
    source = Image.open(screenshot_path).convert("RGB")
    if crop_top or crop_bottom:
        source = source.crop((0, crop_top, source.width, source.height - crop_bottom))

    width = W - 56
    scale = width / source.width
    height = round(source.height * scale)
    source = source.resize((width, height), Image.LANCZOS)
    x = (W - width) // 2

    radius = 68
    shadow = Image.new("RGBA", (width + 80, height + 90), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((40, 26, 40 + width, 26 + height), radius=radius, fill=(25, 30, 38, 18))
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    canvas.alpha_composite(shadow, (x - 40, y - 26))

    mask = rounded_rect_mask((width, height), radius)
    canvas.paste(source, (x, y), mask)
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle((x, y, x + width - 1, y + height - 1), radius=radius, outline=(220, 220, 216), width=2)


def platform_pill_metrics(draw, label):
    f = font(54, True)
    bbox = draw.textbbox((0, 0), label, font=f)
    icon = platform_icon(label, size=72)
    pad_x = 42
    icon_gap = 24
    width = icon.width + icon_gap + bbox[2] - bbox[0] + pad_x * 2
    return f, icon, width, 128, pad_x, icon_gap


def draw_platform_pill(canvas, label, x, y):
    draw = ImageDraw.Draw(canvas)
    fill, outline, text_fill = platform_colors(label)
    f, icon, width, height, pad_x, icon_gap = platform_pill_metrics(draw, label)

    shadow = Image.new("RGBA", (width + 50, height + 50), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((25, 18, 25 + width, 18 + height), radius=46, fill=(24, 38, 56, 28))
    shadow = shadow.filter(ImageFilter.GaussianBlur(13))
    canvas.alpha_composite(shadow, (x - 25, y - 18))

    draw.rounded_rectangle(
        (x, y, x + width, y + height),
        radius=height // 2,
        fill=fill,
        outline=outline,
        width=4,
    )
    icon_y = y + (height - icon.height) // 2
    canvas.alpha_composite(icon, (x + pad_x, icon_y))
    text_bbox = draw.textbbox((0, 0), label, font=f)
    text_y = y + (height - (text_bbox[3] - text_bbox[1])) // 2 - text_bbox[1]
    draw.text((x + pad_x + icon.width + icon_gap, text_y), label, font=f, fill=text_fill)
    return width


def draw_platform_pills(canvas, y):
    draw = ImageDraw.Draw(canvas)
    labels = ("TikTok", "YouTube", "Reels")
    gap = 24
    height = 128
    for index, label in enumerate(labels):
        _, _, width, _, _, _ = platform_pill_metrics(draw, label)
        x = (W - width) // 2
        draw_platform_pill(canvas, label, x, y)
        y += height + gap
    return y - gap


def draw_saved_hero_card(canvas, y):
    x, width, height = 105, 1080, 800
    source = Image.open("/Users/luwenting/Downloads/IMG_0021.PNG").convert("RGB")
    crop_height = round(height * source.width / width)
    img = source.crop((0, 1000, source.width, 1000 + crop_height))
    img = img.resize((width, height), Image.LANCZOS)

    shadow = Image.new("RGBA", (width + 130, height + 150), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((65, 40, 65 + width, 40 + height), radius=86, fill=(24, 38, 56, 64))
    shadow = shadow.filter(ImageFilter.GaussianBlur(30))
    canvas.alpha_composite(shadow, (x - 65, y - 40))

    mask = rounded_rect_mask((width, height), 82)
    canvas.paste(img, (x, y), mask)
    return y + height


def draw_process_cue(draw, text, y):
    labels = text.split(" → ")
    cue_size = 70
    while True:
        f = title_font(text, cue_size)
        arrow_f = ImageFont.truetype(FONT_CJK_DISPLAY, cue_size)
        wordmark_regular = ImageFont.truetype(FONT_DISPLAY, cue_size, index=8)
        wordmark_italic = ImageFont.truetype(FONT_DISPLAY, cue_size, index=9)
        wordmark_width = (
            draw.textbbox((0, 0), "Chill", font=wordmark_regular)[2]
            + draw.textbbox((0, 0), "Script", font=wordmark_italic)[2]
        )
        label_widths = [
            wordmark_width if label == "ChillScript" else draw.textbbox((0, 0), label, font=f)[2]
            for label in labels
        ]
        arrow_width = draw.textbbox((0, 0), "→", font=arrow_f)[2]
        gap = round(cue_size * 0.4)
        total_width = sum(label_widths) + (len(labels) - 1) * (arrow_width + gap * 2)
        if total_width <= 1180 or cue_size <= 54:
            break
        cue_size -= 2
    x = (W - total_width) // 2
    for index, (label, width) in enumerate(zip(labels, label_widths)):
        if label == "ChillScript":
            draw.text((x, y), "Chill", font=wordmark_regular, fill=BLUE)
            chill_width = draw.textbbox((0, 0), "Chill", font=wordmark_regular)[2]
            draw.text((x + chill_width, y), "Script", font=wordmark_italic, fill=BLUE)
        else:
            draw.text((x, y), label, font=f, fill=INK)
        x += width
        if index < len(labels) - 1:
            x += gap
            draw.text((x, y), "→", font=arrow_f, fill=BLUE)
            x += arrow_width + gap


def make_multi_share_slide(
    output_dir,
    filename="01-share-any-video-get-transcript.png",
    title="Share Any Video\nGet the Transcript",
    highlight="Transcript",
    process_text="Share → ChillScript → Saved",
):
    canvas = Image.new("RGBA", (W, H), BG + (255,))
    draw = ImageDraw.Draw(canvas)

    draw_display_title(
        draw,
        title,
        SHARE_TITLE_Y,
        W - CONTENT_X * 2,
        SHARE_TITLE_SIZE,
        BLUE,
        highlight=highlight,
        line_gap=TITLE_LINE_GAP,
    )
    draw_platform_list(canvas)
    draw_minimal_saved_card(canvas)
    canvas.convert("RGB").save(output_dir / filename, quality=96)


def make_slide(
    output_dir,
    filename,
    screenshot,
    title,
    eyebrow=None,
    accent=BLUE,
    crop_top=0,
    crop_bottom=0,
    zoom=1.0,
    fit="cover",
    highlight=None,
):
    canvas = Image.new("RGBA", (W, H), BG + (255,))
    draw = ImageDraw.Draw(canvas)

    draw_display_title(
        draw,
        title,
        TITLE_Y,
        W - CONTENT_X * 2,
        TITLE_SIZE,
        accent,
        highlight=highlight,
        line_gap=TITLE_LINE_GAP,
    )
    draw_interface_panel(canvas, screenshot, crop_top=crop_top, crop_bottom=crop_bottom)

    canvas.convert("RGB").save(output_dir / filename, quality=96)


def prepare_output_dir(output_dir):
    output_dir.mkdir(parents=True, exist_ok=True)
    for png in output_dir.glob("*.png"):
        png.unlink()


slides = [
    (
        "02-save-viral-video-as-text.png",
        "/Users/luwenting/Downloads/IMG_0973.PNG",
        "Study Viral Videos\nWord for Word",
        "SAVE",
        BLUE,
        150,
        80,
        1.0,
        "cover",
        "Word for Word",
    ),
    (
        "03-never-run-out-of-post-ideas.png",
        "/Users/luwenting/Downloads/IMG_0796.PNG",
        "Never Run Out of\nContent Ideas",
        "IDEAS",
        BLUE,
        120,
        90,
        1.0,
        "cover",
        "Content Ideas",
    ),
    (
        "04-build-your-content-vault.png",
        "/Users/luwenting/Downloads/IMG_0976.PNG",
        "Keep Every Idea\nin One Place",
        "ORGANIZE",
        BLUE,
        130,
        120,
        1.0,
        "cover",
        "One Place",
    ),
    (
        "05-generate-hooks-that-stop-the-scroll.png",
        "/Users/luwenting/Downloads/IMG_0594.PNG",
        "Generate Hooks That\nStop the Scroll",
        "CREATE",
        BLUE,
        120,
        120,
        1.0,
        "cover",
        "Stop the Scroll",
    ),
    (
        "06-create-faster-with-ai-skills.png",
        "/Users/luwenting/Downloads/IMG_0193.PNG",
        "Create Faster With\nAI Skills",
        "SKILLS",
        BLUE,
        120,
        90,
        1.0,
        "cover",
        "AI Skills",
    ),
]

localized_titles = {
    "en": [
        ("Share Any Video\nGet the Transcript", "Transcript"),
        ("Study Viral Videos\nWord for Word", "Word for Word"),
        ("Never Run Out of\nContent Ideas", "Content Ideas"),
        ("Keep Every Idea\nin One Place", "One Place"),
        ("Generate Hooks That\nStop the Scroll", "Stop the Scroll"),
        ("Create Faster With\nAI Skills", "AI Skills"),
    ],
    "zh-Hans": [
        ("分享任意视频\n获取视频转写", "转写"),
        ("逐字拆解\n爆款视频", "逐字拆解"),
        ("永远不缺\n内容灵感", "内容灵感"),
        ("把每个灵感\n都收在一处", "收在一处"),
        ("生成吸睛开场\n让人停下滑动", "让人停下滑动"),
        ("用 AI 技能\n更快创作", "更快创作"),
    ],
    "zh-Hant": [
        ("分享任何影片\n取得影片轉錄", "轉錄"),
        ("逐字拆解\n爆款影片", "逐字拆解"),
        ("永遠不缺\n內容靈感", "內容靈感"),
        ("將每個靈感\n集中收在一處", "收在一處"),
        ("生成吸睛開場\n讓人停止滑動", "讓人停止滑動"),
        ("用 AI 技能\n加速創作", "加速創作"),
    ],
    "ja": [
        ("あらゆる動画を共有\n文字起こしを取得", "文字起こし"),
        ("バズ動画を\n一言一句分析", "一言一句分析"),
        ("コンテンツのアイデアに\nもう困らない", "コンテンツのアイデア"),
        ("すべてのアイデアを\nひとつに整理", "ひとつに整理"),
        ("スクロールを止める\nフックを生成", "スクロールを止める"),
        ("AI スキルで\n創作を効率化", "AI スキル"),
    ],
    "fr": [
        ("Partagez n’importe quelle vidéo\nObtenez la transcription", "transcription"),
        ("Étudiez les vidéos virales\nmot pour mot", "mot pour mot"),
        ("Ne manquez jamais\nd’idées de contenu", "idées de contenu"),
        ("Toutes vos idées\nau même endroit", "au même endroit"),
        ("Générez des accroches\nqui captent l’attention", "captent l’attention"),
        ("Créez plus vite\navec les outils IA", "outils IA"),
    ],
    "es": [
        ("Comparte cualquier vídeo\nObtén la transcripción", "transcripción"),
        ("Estudia videos virales\npalabra por palabra", "palabra por palabra"),
        ("Nunca te quedes sin\nideas de contenido", "ideas de contenido"),
        ("Todas tus ideas\nen un solo lugar", "un solo lugar"),
        ("Genera hooks que\ndetienen el scroll", "detienen el scroll"),
        ("Crea más rápido\ncon herramientas de IA", "herramientas de IA"),
    ],
    "de": [
        ("Teile jedes Video\nErhalte das Transkript", "Transkript"),
        ("Virale Videos\nWort für Wort analysieren", "Wort für Wort"),
        ("Nie wieder ohne\nContent-Ideen", "Content-Ideen"),
        ("Alle Ideen\nan einem Ort", "an einem Ort"),
        ("Erstelle Hooks, die\nden Scroll stoppen", "den Scroll stoppen"),
        ("Schneller erstellen\nmit KI-Tools", "KI-Tools"),
    ],
    "ko": [
        ("어떤 영상이든 공유\n트랜스크립트 받기", "트랜스크립트"),
        ("바이럴 영상을\n한마디씩 분석하세요", "한마디씩 분석하세요"),
        ("콘텐츠 아이디어가\n끊이지 않아요", "콘텐츠 아이디어"),
        ("모든 아이디어를\n한곳에 보관하세요", "한곳에 보관하세요"),
        ("스크롤을 멈추는\n훅을 생성하세요", "스크롤을 멈추는"),
        ("AI 스킬로\n더 빠르게 제작하세요", "AI 스킬"),
    ],
}

localized_share_steps = {
    "en": "Share → ChillScript → Saved",
    "zh-Hans": "分享 → ChillScript → 已保存",
    "zh-Hant": "分享 → ChillScript → 已儲存",
    "ja": "共有 → ChillScript → 保存完了",
    "fr": "Partager → ChillScript → Enregistré",
    "es": "Compartir → ChillScript → Guardado",
    "de": "Teilen → ChillScript → Gespeichert",
    "ko": "공유 → ChillScript → 저장 완료",
}

prepare_output_dir(OUT_DIR)
make_multi_share_slide(OUT_DIR)

for slide in slides:
    make_slide(OUT_DIR, *slide)

for locale, titles in localized_titles.items():
    locale_dir = OUT_DIR / locale
    prepare_output_dir(locale_dir)
    make_multi_share_slide(
        locale_dir,
        title=titles[0][0],
        highlight=titles[0][1],
        process_text=localized_share_steps[locale],
    )
    for slide, (title, highlight) in zip(slides, titles[1:]):
        filename, screenshot, _title, eyebrow, accent, crop_top, crop_bottom, zoom, fit, _highlight = slide
        make_slide(
            locale_dir,
            filename,
            screenshot,
            title,
            eyebrow,
            accent,
            crop_top,
            crop_bottom,
            zoom,
            fit,
            highlight,
        )

print(OUT_DIR)
