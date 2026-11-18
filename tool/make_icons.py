#!/usr/bin/env python3
"""Genereer alle app-iconen uit de Fantasy-paard-SVG (LGPL, zie third_party/chess_vectors_flutter).
Uitvoeren met: python3 tool/make_icons.py   (vereist: pillow, rsvg-convert)"""
from PIL import Image, ImageDraw, ImageFilter
import json, os, math

S = 1024  # master size

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

TOP = (0x2E, 0x22, 0x52)      # diep indigo linksboven
BOT = (0x10, 0x0A, 0x22)      # bijna zwart onder
GOLD = (0xFF, 0xC5, 0x3D)

def background(size=S, rounded_ratio=0.0, glow=True):
    """Verticale gradient + warme gloed achter het paard."""
    img = Image.new('RGB', (size, size))
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        for x in range(size):
            # lichte horizontale component voor diepte
            t2 = min(1.0, max(0.0, t * 0.85 + (x / size) * 0.15))
            px[x, y] = lerp(TOP, BOT, t2)
    if glow:
        glow_layer = Image.new('L', (size, size), 0)
        gd = ImageDraw.Draw(glow_layer)
        cx, cy, r = size / 2, size * 0.46, size * 0.46
        for i in range(int(r), 0, -2):
            a = int(90 * (1 - i / r) ** 1.7)
            gd.ellipse([cx - i, cy - i, cx + i, cy + i], fill=a)
        gold = Image.new('RGB', (size, size), GOLD)
        img = Image.composite(gold, img, glow_layer.point(lambda v: v))
    if rounded_ratio > 0:
        mask = Image.new('L', (size, size), 0)
        md = ImageDraw.Draw(mask)
        md.rounded_rectangle([0, 0, size - 1, size - 1], radius=int(size * rounded_ratio), fill=255)
        out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        out.paste(img, (0, 0), mask)
        return out
    return img.convert('RGBA')

KNIGHT = Image.open('/tmp/quest_icon/knight_gold_1024.png').convert('RGBA')

def compose(knight_scale, glow=True, rounded=0.0, bg=True):
    base = background(S, rounded, glow=glow) if bg else Image.new('RGBA', (S, S), (0, 0, 0, 0))
    k = KNIGHT.copy()
    kh = int(S * knight_scale)
    kw = int(k.width * (kh / k.height))
    k = k.resize((kw, kh), Image.LANCZOS)
    # zachte slagschaduw voor diepte op de gloed
    shadow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    sil = Image.new('RGBA', (kw, kh), (0, 0, 0, 255))
    shadow.paste(sil, ((S - kw) // 2, int(S * 0.53 - kh / 2) + 10), k.split()[3])
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    shadow = Image.eval(shadow, lambda v: int(v * 0.55))
    base.alpha_composite(shadow)
    base.alpha_composite(k, ((S - kw) // 2, int(S * 0.53 - kh / 2)))
    return base

os.makedirs('/tmp/quest_icon/out', exist_ok=True)

# --- masters
legacy = compose(0.70, glow=True, rounded=0.0)          # full-bleed (oude Android/Play)
rounded = compose(0.70, glow=True, rounded=0.22)        # afgeronde variant (macOS/web)
foreground = compose(0.58, glow=False, bg=False)        # adaptive foreground (transparant)
background_flat = background(S, 0.0, glow=True)          # adaptive background (full bleed)
maskable = compose(0.52, glow=True, rounded=0.0)        # PWA maskable (safe zone)

legacy.save('/tmp/quest_icon/out/icon_legacy_1024.png')
rounded.save('/tmp/quest_icon/out/icon_rounded_1024.png')
foreground.save('/tmp/quest_icon/out/ic_foreground_1024.png')
background_flat.convert('RGB').save('/tmp/quest_icon/out/ic_background_1024.png')
maskable.convert('RGB').save('/tmp/quest_icon/out/icon_maskable_1024.png')
print('masters done')
