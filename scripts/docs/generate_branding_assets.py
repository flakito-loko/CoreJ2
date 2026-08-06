#!/usr/bin/env python3
"""Regenerate CoreJ2 branding SVG/PNG assets.

Requires:
  - Pillow in the active Python env
  - OFL fonts under assets/branding/fonts/ (gitignored):
      Inter extras/ttf/*.ttf
      SpaceGrotesk-*/ttf/static/*.ttf
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "branding"

PRIMARY = "#2563EB"
SECONDARY = "#60A5FA"
BG = "#0B1220"
WHITE = "#FFFFFF"
GRAY = "#94A3B8"

INTER = ROOT / "assets/branding/fonts/Inter/extras/ttf/Inter-SemiBold.ttf"
INTER_REG = ROOT / "assets/branding/fonts/Inter/extras/ttf/Inter-Regular.ttf"
INTER_BOLD = ROOT / "assets/branding/fonts/Inter/extras/ttf/Inter-Bold.ttf"
SG = ROOT / "assets/branding/fonts/SpaceGrotesk/SpaceGrotesk-2.0.0/ttf/static/SpaceGrotesk-Bold.ttf"


def font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size)


ISOTYPE_SVG = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" role="img" aria-label="CoreJ2 isotype">
  <defs>
    <linearGradient id="lcd" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="{PRIMARY}"/>
      <stop offset="100%" stop-color="{SECONDARY}"/>
    </linearGradient>
  </defs>
  <rect x="34" y="14" width="60" height="100" rx="12" fill="{BG}" stroke="{PRIMARY}" stroke-width="4"/>
  <rect x="54" y="22" width="20" height="4" rx="2" fill="{GRAY}" opacity="0.55"/>
  <rect x="42" y="32" width="44" height="52" rx="6" fill="url(#lcd)"/>
  <path d="M64 42 L74 52 L64 62 L54 52 Z" fill="{WHITE}" opacity="0.95"/>
  <rect x="58" y="50" width="12" height="4" rx="1" fill="{BG}" opacity="0.35"/>
  <circle cx="50" cy="96" r="3.2" fill="{SECONDARY}"/>
  <circle cx="64" cy="96" r="3.2" fill="{SECONDARY}"/>
  <circle cx="78" cy="96" r="3.2" fill="{SECONDARY}"/>
  <circle cx="50" cy="106" r="3.2" fill="{GRAY}"/>
  <circle cx="64" cy="106" r="3.2" fill="{GRAY}"/>
  <circle cx="78" cy="106" r="3.2" fill="{GRAY}"/>
</svg>
"""


def logo_svg(bg: str | None, word_fill: str, tag_fill: str) -> str:
    bg_rect = f'<rect width="512" height="160" rx="24" fill="{bg}"/>' if bg else ""
    phone_fill = "#060A14" if bg == BG else BG
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 160" role="img" aria-label="CoreJ2">
  <defs>
    <linearGradient id="lcd" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="{PRIMARY}"/>
      <stop offset="100%" stop-color="{SECONDARY}"/>
    </linearGradient>
  </defs>
  {bg_rect}
  <g transform="translate(24,16)">
    <rect x="34" y="14" width="60" height="100" rx="12" fill="{phone_fill}" stroke="{PRIMARY}" stroke-width="4"/>
    <rect x="54" y="22" width="20" height="4" rx="2" fill="{GRAY}" opacity="0.55"/>
    <rect x="42" y="32" width="44" height="52" rx="6" fill="url(#lcd)"/>
    <path d="M64 42 L74 52 L64 62 L54 52 Z" fill="{WHITE}" opacity="0.95"/>
    <rect x="58" y="50" width="12" height="4" rx="1" fill="{BG}" opacity="0.35"/>
    <circle cx="50" cy="96" r="3.2" fill="{SECONDARY}"/>
    <circle cx="64" cy="96" r="3.2" fill="{SECONDARY}"/>
    <circle cx="78" cy="96" r="3.2" fill="{SECONDARY}"/>
    <circle cx="50" cy="106" r="3.2" fill="{GRAY}"/>
    <circle cx="64" cy="106" r="3.2" fill="{GRAY}"/>
    <circle cx="78" cy="106" r="3.2" fill="{GRAY}"/>
  </g>
  <text x="168" y="92" font-family="Space Grotesk, Inter, Helvetica, Arial, sans-serif" font-size="64" font-weight="700" fill="{word_fill}">CoreJ2</text>
  <text x="172" y="124" font-family="Inter, Helvetica, Arial, sans-serif" font-size="16" font-weight="500" fill="{tag_fill}" letter-spacing="0.08em">JAVA ME ON IPHONE & IPAD</text>
</svg>
"""


def draw_isotype(draw: ImageDraw.ImageDraw, ox: int, oy: int, scale: float = 1.0) -> None:
    def s(v: float) -> int:
        return int(v * scale)

    draw.rounded_rectangle(
        [ox + s(34), oy + s(14), ox + s(94), oy + s(114)],
        radius=s(12),
        outline=PRIMARY,
        width=max(2, s(4)),
        fill="#060A14",
    )
    draw.rounded_rectangle(
        [ox + s(54), oy + s(22), ox + s(74), oy + s(26)], radius=s(2), fill=GRAY
    )
    draw.rounded_rectangle(
        [ox + s(42), oy + s(32), ox + s(86), oy + s(84)], radius=s(6), fill=PRIMARY
    )
    draw.rectangle([ox + s(42), oy + s(58), ox + s(86), oy + s(84)], fill=SECONDARY)
    draw.polygon(
        [
            (ox + s(64), oy + s(42)),
            (ox + s(74), oy + s(52)),
            (ox + s(64), oy + s(62)),
            (ox + s(54), oy + s(52)),
        ],
        fill=WHITE,
    )
    for cx in (50, 64, 78):
        draw.ellipse(
            [ox + s(cx - 3.2), oy + s(96 - 3.2), ox + s(cx + 3.2), oy + s(96 + 3.2)],
            fill=SECONDARY,
        )
        draw.ellipse(
            [ox + s(cx - 3.2), oy + s(106 - 3.2), ox + s(cx + 3.2), oy + s(106 + 3.2)],
            fill=GRAY,
        )


def render_app_icon(path: Path, size: int = 1024) -> None:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    m = int(size * 0.02)
    draw.rounded_rectangle([m, m, size - m, size - m], radius=int(size * 0.22), fill=BG)
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        [size * 0.15, size * 0.1, size * 0.85, size * 0.7], fill=(37, 99, 235, 70)
    )
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(size * 0.08)))
    draw = ImageDraw.Draw(img)
    scale = size / 128 * 0.72
    ox = int((size - 128 * scale) / 2)
    oy = int((size - 128 * scale) / 2) - int(size * 0.02)
    draw_isotype(draw, ox, oy, scale)
    img.save(path, "PNG")


def render_splash(path: Path, w: int = 1284, h: int = 2778) -> None:
    img = Image.new("RGB", (w, h), BG)
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        [w * 0.1, h * 0.18, w * 0.9, h * 0.55], fill=(37, 99, 235, 55)
    )
    img = Image.alpha_composite(img.convert("RGBA"), glow.filter(ImageFilter.GaussianBlur(80))).convert(
        "RGB"
    )
    draw = ImageDraw.Draw(img)
    scale = min(w, h) / 128 * 0.35
    ox = int((w - 128 * scale) / 2)
    oy = int(h * 0.32)
    draw_isotype(draw, ox, oy, scale)
    title = font(SG, int(w * 0.07))
    tag = font(INTER_REG, int(w * 0.028))
    tw = draw.textbbox((0, 0), "CoreJ2", font=title)
    draw.text(((w - (tw[2] - tw[0])) / 2, oy + 128 * scale + h * 0.04), "CoreJ2", font=title, fill=WHITE)
    tagline = "Java ME on iPhone & iPad"
    tb = draw.textbbox((0, 0), tagline, font=tag)
    draw.text(((w - (tb[2] - tb[0])) / 2, oy + 128 * scale + h * 0.09), tagline, font=tag, fill=GRAY)
    img.save(path, "PNG")


def render_banner(path: Path, w: int = 1280, h: int = 640) -> None:
    img = Image.new("RGB", (w, h), BG)
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([-80, -40, 520, 520], fill=(37, 99, 235, 60))
    gd.ellipse([w - 480, h - 360, w + 80, h + 80], fill=(96, 165, 250, 40))
    img = Image.alpha_composite(img.convert("RGBA"), glow.filter(ImageFilter.GaussianBlur(60))).convert(
        "RGB"
    )
    draw = ImageDraw.Draw(img)
    draw_isotype(draw, 40, 90, 3.2)
    x = 420
    draw.text((x, 150), "CoreJ2", font=font(SG, 72), fill=WHITE)
    draw.text(
        (x, 240),
        "Run classic Java ME games on iPhone & iPad",
        font=font(INTER_BOLD, 28),
        fill=SECONDARY,
    )
    y = 310
    for line in (
        "Run classic MIDlets using",
        "Embedded OpenJDK Mobile",
        "and FreeJ2ME.",
    ):
        draw.text((x, y), line, font=font(INTER_REG, 24), fill=GRAY)
        y += 36
    draw.rounded_rectangle([x, 430, x + 180, 438], radius=4, fill=PRIMARY)
    img.save(path, "PNG")


def render_social(path: Path, w: int = 1200, h: int = 630) -> None:
    img = Image.new("RGB", (w, h), BG)
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([w * 0.4, -100, w * 1.1, h * 0.8], fill=(37, 99, 235, 50))
    img = Image.alpha_composite(img.convert("RGBA"), glow.filter(ImageFilter.GaussianBlur(70))).convert(
        "RGB"
    )
    draw = ImageDraw.Draw(img)
    draw_isotype(draw, 70, 140, 2.8)
    x = 380
    draw.text((x, 180), "CoreJ2", font=font(SG, 68), fill=WHITE)
    draw.text(
        (x, 270),
        "Run classic Java ME games on iPhone & iPad",
        font=font(INTER_BOLD, 26),
        fill=SECONDARY,
    )
    draw.text(
        (x, 340),
        "Run classic MIDlets using Embedded OpenJDK Mobile",
        font=font(INTER_REG, 22),
        fill=GRAY,
    )
    draw.text((x, 378), "and FreeJ2ME.", font=font(INTER_REG, 22), fill=GRAY)
    draw.rounded_rectangle([x, 450, x + 160, 458], radius=4, fill=PRIMARY)
    img.save(path, "PNG")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "isotype.svg").write_text(ISOTYPE_SVG)
    (OUT / "favicon.svg").write_text(ISOTYPE_SVG)
    (OUT / "logo-square.svg").write_text(
        ISOTYPE_SVG.replace('aria-label="CoreJ2 isotype"', 'aria-label="CoreJ2 square logo"')
    )
    (OUT / "logo.svg").write_text(logo_svg(None, PRIMARY, GRAY))
    (OUT / "logo-dark.svg").write_text(logo_svg(BG, WHITE, GRAY))
    (OUT / "logo-light.svg").write_text(logo_svg(WHITE, BG, "#64748B"))

    missing = [p for p in (INTER, INTER_REG, INTER_BOLD, SG) if not p.is_file()]
    if missing:
        raise SystemExit(f"Missing fonts: {missing}")

    render_app_icon(OUT / "app-icon-concept.png")
    render_splash(OUT / "splash.png")
    render_banner(OUT / "banner-github.png")
    render_social(OUT / "social-preview.png")

    docs = ROOT / "docs" / "assets" / "branding"
    docs.mkdir(parents=True, exist_ok=True)
    for p in OUT.glob("*"):
        if p.suffix.lower() in {".svg", ".png"}:
            (docs / p.name).write_bytes(p.read_bytes())
    print(f"branding assets written → {OUT} and mirrored to {docs}")


if __name__ == "__main__":
    main()
