from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter


ROOT = Path("/Users/luwenting/development/ChillNote")
OUT_DIR = ROOT / "screenshots" / "app_store_preview_draft"
OUT_DIR.mkdir(parents=True, exist_ok=True)
ASSET_DIR = OUT_DIR / "assets"

W, H = 1290, 2796
TITLE_SIZE = 112
TITLE_Y = 120
TITLE_LINE_GAP = 10
SHARE_TITLE_SIZE = 132
SHARE_TITLE_Y = 300
PHONE_W = 850
PHONE_H = 1848
PHONE_X = (W - PHONE_W) // 2
PHONE_Y = 500

BG = (247, 249, 252)
INK = (24, 35, 54)
MUTED = (111, 120, 132)
BLUE = (67, 135, 255)
TEAL = (16, 184, 192)

FONT_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_REG = "/System/Library/Fonts/Supplemental/Arial.ttf"
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


def font(size, bold=False):
    return ImageFont.truetype(FONT_BOLD if bold else FONT_REG, size)


def display_font(size):
    return ImageFont.truetype(FONT_DISPLAY, size, index=8)


def title_font(text, size):
    if has_korean(text):
        return ImageFont.truetype(FONT_KO_DISPLAY, size, index=14)
    if has_japanese(text):
        return ImageFont.truetype(FONT_JA_DISPLAY, size)
    if has_cjk(text):
        return ImageFont.truetype(FONT_CJK_DISPLAY, size, index=2)
    return display_font(size)


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


def draw_display_title(draw, text, y, max_width, size, accent, highlight=None, line_gap=12):
    # Preserve the intentional localized line breaks. Only reduce unusually long
    # titles slightly instead of letting one line spill into an awkward extra row.
    lines = text.split("\n")
    fitted_size = size
    while fitted_size > 84:
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
        total_w = sum(w for _, w, _ in segments)
        x = (W - total_w) // 2
        for segment, segment_w, is_highlighted in segments:
            draw.text((x, cy), segment, font=f, fill=accent if is_highlighted else INK)
            x += segment_w
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


def draw_platform_pill(canvas, label, x, y):
    draw = ImageDraw.Draw(canvas)
    fill, outline, text_fill = platform_colors(label)
    f = font(40, True)
    bbox = draw.textbbox((0, 0), label, font=f)
    icon = platform_icon(label)
    pad_x = 30
    icon_gap = 16
    width = icon.width + icon_gap + bbox[2] - bbox[0] + pad_x * 2
    height = 92

    shadow = Image.new("RGBA", (width + 50, height + 50), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((25, 18, 25 + width, 18 + height), radius=46, fill=(24, 38, 56, 28))
    shadow = shadow.filter(ImageFilter.GaussianBlur(13))
    canvas.alpha_composite(shadow, (x - 25, y - 18))

    draw.rounded_rectangle(
        (x, y, x + width, y + height),
        radius=46,
        fill=fill,
        outline=outline,
        width=3,
    )
    icon_y = y + (height - icon.height) // 2
    canvas.alpha_composite(icon, (x + pad_x, icon_y))
    draw.text((x + pad_x + icon.width + icon_gap, y + 23), label, font=f, fill=text_fill)
    return width


def draw_platform_pills(canvas, y):
    draw = ImageDraw.Draw(canvas)
    labels = ("TikTok", "YouTube", "Reels")
    widths = []
    for label in labels:
        f = font(40, True)
        bbox = draw.textbbox((0, 0), label, font=f)
        widths.append(platform_icon(label).width + 16 + bbox[2] - bbox[0] + 60)
    gap = 24
    x = (W - sum(widths) - gap * (len(labels) - 1)) // 2
    for label, width in zip(labels, widths):
        draw_platform_pill(canvas, label, x, y)
        x += width + gap


def draw_saved_hero_card(canvas, y):
    x, width, height = 105, 1080, 800
    source = Image.open("/Users/luwenting/Downloads/Share Extension tiktok.PNG").convert("RGB")
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
            + draw.textbbox((0, 0), "Note", font=wordmark_italic)[2]
        )
        label_widths = [
            wordmark_width if label == "ChillNote" else draw.textbbox((0, 0), label, font=f)[2]
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
        if label == "ChillNote":
            draw.text((x, y), "Chill", font=wordmark_regular, fill=BLUE)
            chill_width = draw.textbbox((0, 0), "Chill", font=wordmark_regular)[2]
            draw.text((x + chill_width, y), "Note", font=wordmark_italic, fill=BLUE)
        else:
            draw.text((x, y), label, font=f, fill=INK)
        x += width
        if index < len(labels) - 1:
            x += gap
            draw.text((x, y), "→", font=arrow_f, fill=BLUE)
            x += arrow_width + gap


def make_multi_share_slide(
    output_dir,
    title="Save Videos\nFrom Anywhere",
    highlight="Anywhere",
    process_text="Share → ChillNote → Saved",
):
    canvas = Image.new("RGBA", (W, H), BG + (255,))
    draw = ImageDraw.Draw(canvas)

    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((-250, 260, 620, 1120), fill=BLUE + (42,))
    gd.ellipse((720, 340, 1540, 1220), fill=TEAL + (30,))
    gd.ellipse((250, 1420, 1120, 2320), fill=(255, 86, 170, 24))
    glow = glow.filter(ImageFilter.GaussianBlur(96))
    canvas.alpha_composite(glow)

    title_bottom = draw_display_title(
        draw,
        title,
        SHARE_TITLE_Y,
        1200,
        SHARE_TITLE_SIZE,
        BLUE,
        highlight=highlight,
        line_gap=TITLE_LINE_GAP,
    )

    pills_y = title_bottom + 130
    draw_platform_pills(canvas, pills_y)

    card_y = pills_y + 300
    card_bottom = draw_saved_hero_card(canvas, card_y)
    draw_process_cue(draw, process_text, max(card_bottom + 230, 2100))
    canvas.convert("RGB").save(output_dir / "03-save-any-video-idea.png", quality=96)


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

    # Soft brand wash.
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((-250, 250, 520, 1020), fill=accent + (35,))
    gd.ellipse((770, 320, 1530, 1120), fill=TEAL + (26,))
    glow = glow.filter(ImageFilter.GaussianBlur(90))
    canvas.alpha_composite(glow)

    title_bottom = draw_display_title(
        draw,
        title,
        TITLE_Y,
        1120,
        TITLE_SIZE,
        accent,
        highlight=highlight,
        line_gap=TITLE_LINE_GAP,
    )
    phone_y = max(PHONE_Y, title_bottom + 70)
    draw_phone(canvas, screenshot, crop_top=crop_top, crop_bottom=crop_bottom, zoom=zoom, y=phone_y, fit=fit)

    canvas.convert("RGB").save(output_dir / filename, quality=96)


def prepare_output_dir(output_dir):
    output_dir.mkdir(parents=True, exist_ok=True)
    for png in output_dir.glob("*.png"):
        png.unlink()


slides = [
    (
        "01-turn-videos-into-notes.png",
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
        "02-build-your-content-vault.png",
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
        "04-creator-ai-skills.png",
        "/Users/luwenting/Downloads/Creator AI Skills 页面.PNG",
        "Use Skills Built\nFor Creators",
        "SKILLS",
        (239, 150, 42),
        0,
        90,
        1.0,
        "cover",
        "Creators",
    ),
    (
        "05-create-scripts-from-notes.png",
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
        "06-ask-ai-about-ideas.png",
        "/Users/luwenting/Downloads/Ask AI.PNG",
        "Ask AI About\nYour Ideas",
        "REMIX",
        (125, 92, 246),
        0,
        90,
        1.0,
        "cover",
        "AI",
    ),
]

localized_titles = {
    "en": [
        ("Save Videos\nFrom Anywhere", "Anywhere"),
        ("Turn Videos\nInto Notes", "Notes"),
        ("Build Your\nContent Vault", "Vault"),
        ("Use Skills Built\nFor Creators", "Creators"),
        ("Create Scripts\nFrom Your Notes", "Scripts"),
        ("Ask AI About\nYour Ideas", "AI"),
    ],
    "zh-Hans": [
        ("随手保存\n任意视频", "保存"),
        ("把视频\n变成笔记", "笔记"),
        ("打造你的\n内容库", "内容库"),
        ("创作者专属\nAI 技能", "创作者"),
        ("用笔记\n生成脚本", "脚本"),
        ("让 AI 帮你\n整理想法", "AI"),
    ],
    "zh-Hant": [
        ("隨手儲存\n任何影片", "儲存"),
        ("把影片\n變成筆記", "筆記"),
        ("打造你的\n內容庫", "內容庫"),
        ("創作者專屬\nAI 技能", "創作者"),
        ("用筆記\n生成腳本", "腳本"),
        ("讓 AI 幫你\n整理想法", "AI"),
    ],
    "ja": [
        ("どこからでも\n動画を保存", "保存"),
        ("動画を\nノート化", "ノート"),
        ("コンテンツを\nまとめて管理", "コンテンツ"),
        ("クリエイター向け\nAI スキル", "クリエイター"),
        ("ノートから\n台本を作成", "台本"),
        ("アイデアを\nAI に相談", "AI"),
    ],
    "fr": [
        ("Enregistrez vos vidéos\noù qu’elles soient", "vidéos"),
        ("Transformez vos\nvidéos en notes", "notes"),
        ("Créez votre\nbibliothèque\nde contenu", "contenu"),
        ("Des outils conçus\npour les créateurs", "créateurs"),
        ("Créez des scripts\nà partir de vos notes", "scripts"),
        ("Interrogez l’IA\nsur vos idées", "IA"),
    ],
    "es": [
        ("Guarda videos\ndesde cualquier lugar", "videos"),
        ("Convierte\nvideos en notas", "notas"),
        ("Crea tu biblioteca\nde contenido", "contenido"),
        ("Usa herramientas\npara creadores", "creadores"),
        ("Crea guiones\ndesde tus notas", "guiones"),
        ("Pregunta a la IA\nsobre tus ideas", "IA"),
    ],
    "de": [
        ("Videos von überall\nspeichern", "Videos"),
        ("Videos in Notizen\nverwandeln", "Notizen"),
        ("Baue deine\nInhaltsbibliothek auf", "Inhaltsbibliothek"),
        ("Tools für\nCreator nutzen", "Creator"),
        ("Aus Notizen\nSkripte erstellen", "Skripte"),
        ("Frag die KI\nzu deinen Ideen", "KI"),
    ],
    "ko": [
        ("어디서나\n동영상 저장", "저장"),
        ("동영상을\n노트로", "노트"),
        ("나만의 콘텐츠\n보관함", "보관함"),
        ("크리에이터용\nAI 스킬", "크리에이터"),
        ("노트로\n스크립트 만들기", "스크립트"),
        ("아이디어를\nAI에게 물어보기", "AI"),
    ],
}

localized_share_steps = {
    "en": "Share → ChillNote → Saved",
    "zh-Hans": "分享 → ChillNote → 已保存",
    "zh-Hant": "分享 → ChillNote → 已儲存",
    "ja": "共有 → ChillNote → 保存完了",
    "fr": "Partager → ChillNote → Enregistré",
    "es": "Compartir → ChillNote → Guardado",
    "de": "Teilen → ChillNote → Gespeichert",
    "ko": "공유 → ChillNote → 저장 완료",
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
