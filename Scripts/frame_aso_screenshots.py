#!/usr/bin/env python3
"""Compose 3D-framed ASO marketing screenshots on #0F1217 with #F26B47 captions.

No numpy required — uses a mild rotate + scale for depth, plus a phone bezel.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

BG = (15, 18, 23)  # #0F1217
CAPTION = (242, 107, 71)  # #F26B47
BEZEL = (28, 30, 34)
BEZEL_EDGE = (55, 58, 64)

# App Store 6.7" portrait marketing canvas
CANVAS = (1290, 2796)

FRAMES = [
    ("01-sharing-network", "See who they share with"),
    ("02-radar-map", "Fetched. Facing. Honest."),
    ("03-place-score", "Your block, graded in seconds"),
    ("04-share-card", "Share how watched you are"),
    ("05-ar-camera", "Point at the street — see the cameras"),
    ("06-map-fov", "See every mapped camera"),
    ("07-safest-drive", "One-tap safest drive"),
    ("08-drive-mode", "Live countdown while you drive"),
]


def load_font(size: int) -> ImageFont.ImageFont:
    for path in (
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/Library/Fonts/Arial Bold.ttf",
        "/System/Library/Fonts/SFNS.ttf",
    ):
        try:
            return ImageFont.truetype(path, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def rounded_screen(shot: Image.Image, size: tuple[int, int], radius: int) -> Image.Image:
    screen = ImageOps.fit(shot.convert("RGBA"), size, method=Image.Resampling.LANCZOS)
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.paste(screen, (0, 0), mask)
    return out


def make_phone(shot: Image.Image, body: tuple[int, int] = (780, 1600)) -> Image.Image:
    bw, bh = body
    pad = 28
    radius = 78
    screen_size = (bw - pad * 2, bh - pad * 2 - 18)
    screen = rounded_screen(shot, screen_size, radius=62)

    phone = Image.new("RGBA", (bw + 80, bh + 100), (0, 0, 0, 0))

    shadow = Image.new("RGBA", phone.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (40, 48, 40 + bw, 48 + bh),
        radius=radius + 8,
        fill=(0, 0, 0, 150),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(32))
    phone = Image.alpha_composite(phone, shadow)

    draw = ImageDraw.Draw(phone)
    ox, oy = 30, 20
    draw.rounded_rectangle(
        (ox, oy, ox + bw, oy + bh),
        radius=radius,
        fill=BEZEL,
        outline=BEZEL_EDGE,
        width=3,
    )
    draw.line((ox + 5, oy + 100, ox + 5, oy + bh - 100), fill=(78, 82, 90, 200), width=3)
    draw.line((ox + bw - 5, oy + 120, ox + bw - 5, oy + bh - 120), fill=(18, 18, 20, 220), width=3)

    island_w, island_h = 148, 44
    ix = ox + (bw - island_w) // 2
    iy = oy + 28
    draw.rounded_rectangle((ix, iy, ix + island_w, iy + island_h), radius=22, fill=(8, 8, 10))

    phone.paste(screen, (ox + pad, oy + pad + 12), screen)
    return phone


def tilt_3d(img: Image.Image, degrees: float = -7.5) -> Image.Image:
    """Mild yaw via rotate + slight horizontal compress for a 3D read."""
    tilted = img.rotate(degrees, resample=Image.Resampling.BICUBIC, expand=True)
    # Compress width a touch after rotate to sell perspective
    w, h = tilted.size
    return tilted.resize((max(1, int(w * 0.92)), h), Image.Resampling.LANCZOS)


def wrap_caption(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.ImageFont, max_width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        trial = f"{current} {word}".strip()
        if draw.textlength(trial, font=font) <= max_width:
            current = trial
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def compose(shot_path: Path, caption: str, out_path: Path) -> None:
    shot = Image.open(shot_path).convert("RGBA")
    phone = tilt_3d(make_phone(shot))

    canvas = Image.new("RGB", CANVAS, BG)
    max_phone_h = int(CANVAS[1] * 0.74)
    max_phone_w = int(CANVAS[0] * 0.84)
    scale = min(max_phone_w / phone.width, max_phone_h / phone.height)
    phone_r = phone.resize(
        (max(1, int(phone.width * scale)), max(1, int(phone.height * scale))),
        Image.Resampling.LANCZOS,
    )

    px = (CANVAS[0] - phone_r.width) // 2
    py = int(CANVAS[1] * 0.20)
    canvas.paste(phone_r, (px, py), phone_r)

    draw = ImageDraw.Draw(canvas)
    font = load_font(64)
    lines = wrap_caption(draw, caption, font, max_width=int(CANVAS[0] * 0.88))
    y = 100
    for line in lines:
        tw = draw.textlength(line, font=font)
        draw.text(((CANVAS[0] - tw) / 2, y), line, font=font, fill=CAPTION)
        y += 78

    out_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out_path, format="PNG", optimize=True)
    print(f"wrote {out_path} ({canvas.size[0]}x{canvas.size[1]})")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw-dir", type=Path, default=Path("docs/aso-captures/raw"))
    parser.add_argument("--out-dir", type=Path, default=Path("docs/aso-captures/framed"))
    args = parser.parse_args()

    for stem, caption in FRAMES:
        src = None
        for ext in (".png", ".jpg", ".jpeg"):
            candidate = args.raw_dir / f"{stem}{ext}"
            if candidate.exists():
                src = candidate
                break
        if src is None:
            legacy = args.raw_dir.parent / f"{stem}.jpg"
            if legacy.exists():
                src = legacy
        if src is None:
            print(f"skip missing {stem}")
            continue
        compose(src, caption, args.out_dir / f"{stem}.png")


if __name__ == "__main__":
    main()
