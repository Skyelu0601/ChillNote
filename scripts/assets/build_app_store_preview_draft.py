from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter


ROOT = Path("/Users/luwenting/development/ChillNote")
OUT_DIR = ROOT / "screenshots" / "app_store_preview_draft"
OUT_DIR.mkdir(parents=True, exist_ok=True)

W, H = 1290, 2796
PHONE_W = 850
PHONE_H = 1848
PHONE_X = (W - PHONE_W) // 2
PHONE_Y = 540

BG = (247, 249, 252)
INK = (24, 35, 54)
MUTED = (111, 120, 132)
BLUE = (67, 135, 255)
TEAL = (16, 184, 192)

FONT_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_REG = "/System/Library/Fonts/Supplemental/Arial.ttf"
FONT_DISPLAY = "/System/Library/Fonts/Avenir Next.ttc"


def font(size, bold=False):
    return ImageFont.truetype(FONT_BOLD if bold else FONT_REG, size)


def display_font(size):
    return ImageFont.truetype(FONT_DISPLAY, size, index=8)


def rounded_rect_mask(size, radius):
    mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def draw_wrapped_center(draw, text, y, max_width, size, line_gap=18):
    f = display_font(size)
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


def draw_display_title(draw, text, y, max_width, size, accent, highlight=None, line_gap=12):
    f = display_font(size)
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

    cy = y
    for line in lines:
        parts = line.split(" ")
        widths = []
        for i, word in enumerate(parts):
            token = word if i == 0 else " " + word
            bbox = draw.textbbox((0, 0), token, font=f)
            widths.append((token, bbox[2] - bbox[0], word))
        total_w = sum(w for _, w, _ in widths)
        x = (W - total_w) // 2
        for token, token_w, bare_word in widths:
            fill = accent if highlight and bare_word.strip(".,&") == highlight else INK
            draw.text((x, cy), token, font=f, fill=fill)
            x += token_w
        cy += size + line_gap
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
    if label == "Instagram Reels":
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


def draw_saved_hero_card(canvas):
    x, y, width = 105, 665, 1080
    img = crop_lower_share_sheet("/Users/luwenting/Downloads/Share Extension tiktok.PNG")
    height = int(width * img.height / img.width)
    img = img.resize((width, height), Image.LANCZOS)

    shadow = Image.new("RGBA", (width + 130, height + 150), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((65, 40, 65 + width, 40 + height), radius=86, fill=(24, 38, 56, 64))
    shadow = shadow.filter(ImageFilter.GaussianBlur(30))
    canvas.alpha_composite(shadow, (x - 65, y - 40))

    mask = rounded_rect_mask((width, height), 82)
    canvas.paste(img, (x, y), mask)


def make_multi_share_slide():
    canvas = Image.new("RGBA", (W, H), BG + (255,))
    draw = ImageDraw.Draw(canvas)

    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((-250, 260, 620, 1120), fill=BLUE + (42,))
    gd.ellipse((720, 340, 1540, 1220), fill=TEAL + (30,))
    gd.ellipse((250, 1420, 1120, 2320), fill=(255, 86, 170, 24))
    glow = glow.filter(ImageFilter.GaussianBlur(96))
    canvas.alpha_composite(glow)

    draw_display_title(draw, "Save Ideas\nFrom Anywhere", 135, 1120, 92, BLUE, highlight="Anywhere", line_gap=8)

    draw_share_card(canvas, "/Users/luwenting/Downloads/Share Extension tiktok.PNG", 195, 590, 900, angle=0)
    draw_share_card(canvas, "/Users/luwenting/Downloads/share extension youtube.PNG", 195, 1180, 900, angle=0)
    draw_share_card(canvas, "/Users/luwenting/Downloads/share extension reels.PNG", 195, 1770, 900, angle=0)
    canvas.convert("RGB").save(OUT_DIR / "01-save-any-video-idea.png", quality=96)


def make_slide(
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

    # Soft brand wash.
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((-250, 250, 520, 1020), fill=accent + (35,))
    gd.ellipse((770, 320, 1530, 1120), fill=TEAL + (26,))
    glow = glow.filter(ImageFilter.GaussianBlur(90))
    canvas.alpha_composite(glow)

    draw_display_title(draw, title, 135, 1120, 92, accent, highlight=highlight, line_gap=8)
    draw_phone(canvas, screenshot, crop_top=crop_top, crop_bottom=crop_bottom, zoom=zoom, fit=fit)

    canvas.convert("RGB").save(OUT_DIR / filename, quality=96)


slides = [
    (
        "02-turn-videos-into-notes.png",
        "/Users/luwenting/Downloads/笔记详情页.PNG",
        "Turn Videos\nInto Notes",
        "EXTRACT",
        TEAL,
        24,
        80,
        1.0,
        "cover",
        "Notes",
    ),
    (
        "03-create-scripts-from-notes.png",
        "/Users/luwenting/Downloads/AI 生成结果页.PNG",
        "Create Scripts\nFrom Your Notes",
        "CREATE",
        BLUE,
        0,
        120,
        1.0,
        "cover",
        "Scripts",
    ),
    (
        "04-build-your-content-vault.png",
        "/Users/luwenting/Downloads/首页 : 内容库页面.PNG",
        "Build Your\nContent Vault",
        "ORGANIZE",
        (45, 104, 230),
        0,
        120,
        1.0,
        "cover",
        "Vault",
    ),
    (
        "05-ask-ai-about-ideas.png",
        "/Users/luwenting/Downloads/Ask AI.PNG",
        "Ask AI\nAbout Your Ideas",
        "REMIX",
        (125, 92, 246),
        0,
        90,
        1.0,
        "cover",
        "AI",
    ),
    (
        "06-creator-ai-skills.png",
        "/Users/luwenting/Downloads/Creator AI Skills 页面.PNG",
        "Use Skills Built For Creators",
        "SKILLS",
        (239, 150, 42),
        0,
        90,
        1.0,
        "cover",
        "Creators",
    ),
]

make_multi_share_slide()

for slide in slides:
    make_slide(*slide)

print(OUT_DIR)
