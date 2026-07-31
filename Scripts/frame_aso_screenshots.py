#!/usr/bin/env python3
"""Compose App Store marketing frames (6.9" / 1320x2868) from raw simulator captures.

Structure per frame: coral eyebrow, two-line headline, muted subhead, then a
straight-on device cropped by the bottom edge. Palette tracks AppTheme.swift.

    python3 Scripts/frame_aso_screenshots.py            # all frames
    python3 Scripts/frame_aso_screenshots.py 01 06      # only these stems
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "docs" / "aso-captures" / "raw"
OUT = ROOT / "docs" / "aso-captures" / "appstore"

CANVAS = (1320, 2868)  # iPhone 6.9" portrait

# AppTheme.swift
FOREGROUND = (245, 247, 252)
MUTED = (140, 153, 173)
CORAL = (255, 82, 56)
CYAN = (46, 235, 224)
BG_TOP = (18, 22, 29)
BG_BOTTOM = (8, 9, 16)
BEZEL = (24, 26, 32)

# stem, headline lines, subhead, accent glow
FRAMES = [
    ("01-drive-mode", ["How watched is", "this road?"],
     "Live HUD and Lock Screen Activity while you drive", CORAL),
    ("02-safest-drive", ["Pick the", "quieter route"],
     "Compare drives by mapped ALPR exposure", CYAN),
    ("03-radar-hud", ["Near mapped pins.", "Nothing more."],
     "Honest alerts — never plate reads", CORAL),
    ("04-place-score", ["Your block,", "graded"],
     "Grade where you live in seconds", CORAL),
    ("06-map-fov", ["See every", "mapped camera"],
     "Clusters, filters, and coverage confidence", CYAN),
    ("08-sharing-network", ["See who", "they share with"],
     "Hub-and-spoke partners from public FOIA records", CORAL),
]


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    for path in (
        f"/System/Library/Fonts/Supplemental/{name}.ttf",
        f"/Library/Fonts/{name}.ttf",
        "/System/Library/Fonts/SFNS.ttf",
    ):
        try:
            return ImageFont.truetype(path, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def background(accent: tuple[int, int, int]) -> Image.Image:
    w, h = CANVAS
    bg = Image.new("RGB", CANVAS, BG_BOTTOM)
    draw = ImageDraw.Draw(bg)
    for y in range(h):
        t = y / h
        draw.line(
            [(0, y), (w, y)],
            fill=tuple(int(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * t) for i in range(3)),
        )
    # soft accent bloom behind the device shoulder
    glow = Image.new("RGB", CANVAS, (0, 0, 0))
    ImageDraw.Draw(glow).ellipse((w // 2 - 620, 620, w // 2 + 620, 1700), fill=accent)
    glow = glow.filter(ImageFilter.GaussianBlur(260))
    return Image.blend(bg, Image.blend(bg, glow, 0.5), 0.22)


def centered(draw: ImageDraw.ImageDraw, y: int, text: str, f, fill, tracking: int = 0) -> int:
    if tracking:
        widths = [draw.textlength(ch, font=f) + tracking for ch in text]
        x = (CANVAS[0] - (sum(widths) - tracking)) / 2
        for ch, adv in zip(text, widths):
            draw.text((x, y), ch, font=f, fill=fill)
            x += adv
    else:
        draw.text((CANVAS[0] / 2, y), text, font=f, fill=fill, anchor="ma")
    box = draw.textbbox((0, 0), text or "X", font=f)
    return y + (box[3] - box[1]) + box[1]


def device(shot: Image.Image, screen_w: int = 968) -> Image.Image:
    ratio = shot.height / shot.width
    screen = shot.resize((screen_w, int(screen_w * ratio)), Image.Resampling.LANCZOS)

    pad, radius = 15, 74
    body = Image.new("RGBA", (screen.width + pad * 2, screen.height + pad * 2), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle(
        (0, 0, body.width - 1, body.height - 1), radius=radius + pad, fill=BEZEL + (255,)
    )

    mask = Image.new("L", screen.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, screen.width - 1, screen.height - 1), radius=radius, fill=255
    )
    body.paste(screen.convert("RGBA"), (pad, pad), mask)
    return body


def compose(stem: str, lines: list[str], subhead: str, accent) -> Path | None:
    src = RAW / f"{stem}.png"
    if not src.exists():
        print(f"  skip {stem} — no raw capture")
        return None

    canvas = background(accent)
    draw = ImageDraw.Draw(canvas)

    eyebrow = font("Arial Bold", 30)
    headline = font("Arial Black", 86)
    sub = font("Arial", 38)

    y = 168
    centered(draw, y, "OVERWATCH", eyebrow, CORAL, tracking=9)
    y += 88
    for line in lines:
        centered(draw, y, line, headline, FOREGROUND)
        y += 106
    y += 22
    centered(draw, y, subhead, sub, MUTED)

    phone = device(Image.open(src))
    x = (CANVAS[0] - phone.width) // 2
    top = 700

    shadow = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x + 16, top + 26, x + phone.width - 16, CANVAS[1]), radius=96, fill=(0, 0, 0, 190)
    )
    canvas.paste(
        Image.alpha_composite(canvas.convert("RGBA"), shadow.filter(ImageFilter.GaussianBlur(48))).convert("RGB"),
        (0, 0),
    )
    canvas.paste(phone, (x, top), phone)

    OUT.mkdir(parents=True, exist_ok=True)
    dest = OUT / f"{stem}.png"
    canvas.save(dest)
    print(f"  wrote {dest.relative_to(ROOT)}  {canvas.width}x{canvas.height}")
    return dest


def main() -> None:
    wanted = sys.argv[1:]
    for stem, lines, subhead, accent in FRAMES:
        if wanted and not any(stem.startswith(w) for w in wanted):
            continue
        compose(stem, lines, subhead, accent)


if __name__ == "__main__":
    main()
