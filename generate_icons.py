#!/usr/bin/env python3
"""
Generate Veritas app icon set from the source logo.
- Background: pure black (#000000)
- Symbol: gold (#C9B47A = 201, 180, 122)
- Logo occupies 60% of canvas, centered
"""

from PIL import Image, ImageEnhance, ImageFilter, ImageOps
import os

SOURCE = "project-integrity/Assets.xcassets/veritas-logo.imageset/veritas-logo.png"
OUT_DIR = "project-integrity/Assets.xcassets/AppIcon.appiconset"

GOLD = (201, 180, 122)
BLACK = (0, 0, 0)

# (filename, pixel_size)
SIZES = [
    ("AppIcon-1024.png",    1024),
    ("AppIcon-60@2x.png",   120),
    ("AppIcon-60@3x.png",   180),
    ("AppIcon-76.png",       76),
    ("AppIcon-76@2x.png",   152),
    ("AppIcon-83.5@2x.png", 167),
    ("AppIcon-40@2x.png",    80),
    ("AppIcon-40@3x.png",   120),   # same px as 60@2x, different slot
    ("AppIcon-29@2x.png",    58),
    ("AppIcon-29@3x.png",    87),
    ("AppIcon-20@2x.png",    40),
    ("AppIcon-20@3x.png",    60),
]

def make_icon(source_img, canvas_size):
    """
    Create a canvas_size x canvas_size RGBA icon.
    source_img is the original RGBA logo (black on white with alpha).
    Symbol target = 60% of canvas, centered.
    """
    logo_px = int(canvas_size * 0.60)
    # High-quality downscale
    logo = source_img.resize((logo_px, logo_px), Image.LANCZOS)

    # Convert to RGBA if needed
    logo = logo.convert("RGBA")
    r, g, b, a = logo.split()

    # Source is a transparent PNG: black symbol on transparent background.
    # The alpha channel IS the symbol mask (alpha=0 → background, alpha=255 → symbol).
    # Tint: replace the black symbol colour with gold, preserving alpha as-is.
    _, _, _, alpha = logo.split()

    # Solid gold image with source alpha as its opacity mask
    gold_layer = Image.new("RGBA", (logo_px, logo_px), (GOLD[0], GOLD[1], GOLD[2], 255))
    gold_logo = Image.new("RGBA", (logo_px, logo_px), (0, 0, 0, 0))
    gold_logo.paste(gold_layer, mask=alpha)

    # Black canvas
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 255))

    # Center paste
    x = (canvas_size - logo_px) // 2
    y = (canvas_size - logo_px) // 2
    canvas.alpha_composite(gold_logo, dest=(x, y))

    # Flatten to RGB (PNG for App Store must be RGB, no alpha needed)
    final = Image.new("RGB", (canvas_size, canvas_size), BLACK)
    final.paste(canvas.convert("RGB"), (0, 0))
    return final


def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    src = Image.open(SOURCE).convert("RGBA")

    generated = []
    # Track files we actually write (duplicates get the same file written twice, that's fine)
    for filename, size in SIZES:
        icon = make_icon(src, size)
        out_path = os.path.join(OUT_DIR, filename)
        icon.save(out_path, "PNG")
        generated.append((filename, size))
        print(f"  Generated {filename} ({size}x{size}px)")

    print(f"\nAll {len(generated)} icons written to {OUT_DIR}/")


if __name__ == "__main__":
    main()
