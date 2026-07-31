#!/usr/bin/env python3
"""Compose App Store marketing frames from raw simulator captures.

Structure per frame: coral eyebrow, two-line headline, muted subhead, then a
straight-on device cropped by the bottom edge. Palette tracks AppTheme.swift.

    python3 Scripts/frame_aso_screenshots.py                # every profile
    python3 Scripts/frame_aso_screenshots.py iphone         # one profile
    python3 Scripts/frame_aso_screenshots.py ipad 03        # one frame
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
CAPTURES = ROOT / "docs" / "aso-captures"

# AppTheme.swift
FOREGROUND = (245, 247, 252)
MUTED = (140, 153, 173)
CORAL = (255, 82, 56)
CYAN = (46, 235, 224)
BG_TOP = (18, 22, 29)
BG_BOTTOM = (8, 9, 16)
BEZEL = (24, 26, 32)

PROFILES = {
    # iPhone 6.9" — App Store 1320x2868
    "iphone": {
        "canvas": (1320, 2868),
        "src": CAPTURES / "raw",
        "out": CAPTURES / "appstore",
        "eyebrow_size": 30,
        "eyebrow_y": 168,
        "headline_size": 86,
        "headline_leading": 106,
        "sub_size": 38,
        "screen_w": 968,
        "device_top": 700,
        "radius": 74,
        "bezel": 15,
        "frames": [
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
        ],
    },
    # iPad 13" — App Store 2064x2752
    "ipad": {
        "canvas": (2064, 2752),
        "src": CAPTURES / "raw-ipad",
        "out": CAPTURES / "appstore-ipad",
        "eyebrow_size": 40,
        "eyebrow_y": 176,
        "headline_size": 112,
        "headline_leading": 138,
        "sub_size": 50,
        "screen_w": 1500,
        "device_top": 780,
        "radius": 62,
        "bezel": 18,
        "frames": [
            ("01-map", ["The whole grid,", "at a glance"],
             "Community-mapped ALPR pins from OpenStreetMap", CORAL),
            ("02-intel", ["Know what", "you're looking at"],
             "Short, sharp context on ALPRs and networks", CYAN),
            ("03-sharing-network", ["See who", "they share with"],
             "1,575 partner agencies from public FOIA records", CORAL),
        ],
    },
}


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


def background(canvas: tuple[int, int], accent) -> Image.Image:
    w, h = canvas
    bg = Image.new("RGB", canvas, BG_BOTTOM)
    draw = ImageDraw.Draw(bg)
    for y in range(h):
        t = y / h
        draw.line(
            [(0, y), (w, y)],
            fill=tuple(int(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * t) for i in range(3)),
        )
    glow = Image.new("RGB", canvas, (0, 0, 0))
    span = int(w * 0.47)
    ImageDraw.Draw(glow).ellipse(
        (w // 2 - span, int(h * 0.22), w // 2 + span, int(h * 0.60)), fill=accent
    )
    glow = glow.filter(ImageFilter.GaussianBlur(int(w * 0.2)))
    return Image.blend(bg, Image.blend(bg, glow, 0.5), 0.22)


def centered(draw, width: int, y: int, text: str, f, fill, tracking: int = 0) -> None:
    if tracking:
        widths = [draw.textlength(ch, font=f) + tracking for ch in text]
        x = (width - (sum(widths) - tracking)) / 2
        for ch, adv in zip(text, widths):
            draw.text((x, y), ch, font=f, fill=fill)
            x += adv
    else:
        draw.text((width / 2, y), text, font=f, fill=fill, anchor="ma")


def device(shot: Image.Image, screen_w: int, radius: int, pad: int) -> Image.Image:
    ratio = shot.height / shot.width
    screen = shot.resize((screen_w, int(screen_w * ratio)), Image.Resampling.LANCZOS)

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


def compose(p: dict, stem: str, lines: list[str], subhead: str, accent) -> None:
    src = p["src"] / f"{stem}.png"
    if not src.exists():
        print(f"  skip {stem} — no raw capture")
        return

    w, h = p["canvas"]
    canvas = background(p["canvas"], accent)
    draw = ImageDraw.Draw(canvas)

    y = p["eyebrow_y"]
    centered(draw, w, y, "OVERWATCH", font("Arial Bold", p["eyebrow_size"]), CORAL,
             tracking=max(6, p["eyebrow_size"] // 3))
    y += int(p["eyebrow_size"] * 2.9)

    headline = font("Arial Black", p["headline_size"])
    for line in lines:
        centered(draw, w, y, line, headline, FOREGROUND)
        y += p["headline_leading"]

    centered(draw, w, y + int(p["sub_size"] * 0.6), subhead, font("Arial", p["sub_size"]), MUTED)

    phone = device(Image.open(src), p["screen_w"], p["radius"], p["bezel"])
    x = (w - phone.width) // 2
    top = p["device_top"]

    shadow = Image.new("RGBA", p["canvas"], (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (x + 16, top + 26, x + phone.width - 16, h), radius=96, fill=(0, 0, 0, 190)
    )
    canvas.paste(
        Image.alpha_composite(
            canvas.convert("RGBA"), shadow.filter(ImageFilter.GaussianBlur(48))
        ).convert("RGB"),
        (0, 0),
    )
    canvas.paste(phone, (x, top), phone)

    p["out"].mkdir(parents=True, exist_ok=True)
    dest = p["out"] / f"{stem}.png"
    canvas.save(dest)
    print(f"  wrote {dest.relative_to(ROOT)}  {canvas.width}x{canvas.height}")


def main() -> None:
    args = [a.lower() for a in sys.argv[1:]]
    names = [a for a in args if a in PROFILES] or list(PROFILES)
    stems = [a for a in args if a not in PROFILES]

    for name in names:
        p = PROFILES[name]
        print(f"{name}:")
        for stem, lines, subhead, accent in p["frames"]:
            if stems and not any(stem.startswith(s) for s in stems):
                continue
            compose(p, stem, lines, subhead, accent)


if __name__ == "__main__":
    main()
