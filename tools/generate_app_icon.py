#!/usr/bin/env python3
"""Generate the Topiary AppIcon asset set — v4 "legible at every size".

Design lineage
--------------
* v1.17 and earlier: "leaf" artwork (deprecated, purged in e5f4b2d).
* v1.18 – v1.26.x (v1 icon): photograph of a frosted-glass slider panel,
  cropped via a measured box and masked to a squircle. The photograph lived
  only in a transient upload directory and is lost; the naive RGB-invert
  dark variant and weak 16–32 px contrast were its known weaknesses.
* v1.27 (v2 icon): artwork redrawn procedurally — the source of truth is
  code. Identity kept (frosted glass panel, two rails, left knob high /
  right knob low, squircle radius on the macOS 26 grid); v2a-crisp shipped,
  v2b-studio runner-up, v2c-bold rejected (heavy at 1024).
* v3 (this file): refinement round. v2a reviewed in situ had two real
  weaknesses: (a) purely achromatic — in the Dock, Launchpad and App Store
  it reads as generic grey chrome with zero brand recall; (b) at 16–32 px
  the thin light rails all but vanish on the light panel. v3 keeps the
  identity and answers both: one restrained "topiary green" anchors the
  left (value-anchor) knob — a nod to the name — and small sizes draw from
  size-tiered masters with proportionally heavier stroke. Glass depth is
  enriched (inner refraction ring, livelier sheen) and the v2 blur dial,
  which was interpreted as a fraction of the side (~an order of magnitude
  too large, softening every edge), is rebased to sane pixel radii for v3
  variants; v2 entries keep the legacy path so the record stays exact.
* v4 (this file): the v3a mark is right, two things about it are not. First
  the small tier was still the SAME drawing with heavier strokes — measured at
  16 px the light panel's rails dissolve into mush and the white right knob
  disappears into the white panel, so "heavier" was never going to fix a
  rendering built from gradients, sheens and speculars. v4 draws sizes <= 32
  from an independent simplified master: flat fills, a solid dark recess, one
  saturated brand-green knob, hard edge — same geometry and the same
  high-left / low-right diagonal, only the shading vocabulary is dropped, the
  way platform icon grids simplify rather than rescale. Second, the mark had
  no silhouette: on a white desktop, in Finder or on the App Store's white
  pages the panel bottom (216,220,227) and the rim alpha (95) let the squircle
  bleed into the page. v4 darkens the panel base, firms the rim (and lifts the
  LIT rim in dark mode, where the risk is the reverse — vanishing into a black
  Dock), and gives the right knob a grey face with a dark rim so it survives a
  light panel. v4-plain is the control: both fixes, but the old stroke-tier
  small master, so the sheet shows exactly what the simplified tier buys.

Geometry (unchanged — identity constants)
-----------------------------------------
* Full-bleed canvas; corner radius = 0.2257 * side (the macOS 26 "Tahoe"
  grid v1 already used; also what macOS 12–15 render).
* Two vertical rails at x = 38.5% / 61.5%, slots recessed into the glass.
* Left knob high, right knob low — the diagonal is the mark.

Size tiers
----------
One 1024 master downsampled leaves 16–32 px underweight. Sizes <= 32 draw
from the small tier and 64 px from a mid tier (x1.15-ish strokes); everything
else uses the standard master. Since v4 the small tier is a genuinely
different drawing (see `draw_small_master`) instead of a heavier copy —
`small: "simplified"` opts a variant in, `small: "tier"` keeps the v3
stroke-only behaviour. Same geometry and diagonal in both.

Brand hue
---------
v3's single "topiary green" is now the product's brand colour and has one
canonical swatch (BRAND_GREEN below) shared with Theme.Color.brand in the app
and --brand in the website stylesheet. `--check-brand` fails if the three
sources drift apart.

Variants (candidates kept for the record)
-----------------------------------------
* v4a-refined  — silhouette + knob fixes, simplified small master. ← shipped
* v4b-plain    — same fixes, v3 stroke-tier small master (control).
* v3a-accent   — neutral glass, green left knob, depth + tiers. (v1.27 round)
* v3b-graphite — strictly achromatic control: depth + tiers, no hue.
* v3c-verdant  — green-tinted glass AND green knob; boldest brand read.
* v2a/v2b/v2c  — the v2 monochrome round, still drawable for the record.

Usage
-----
    python3 tools/generate_app_icon.py                  # draw v4a + asset set
    python3 tools/generate_app_icon.py --variant v3c    # any v2*/v3*/v4* variant
    python3 tools/generate_app_icon.py --sheet          # candidate review sheet
    python3 tools/generate_app_icon.py --review         # small-size + silhouette
    python3 tools/generate_app_icon.py --measure        # legibility ratios
    python3 tools/generate_app_icon.py --verify-assets  # asset set still matches code
    python3 tools/generate_app_icon.py --check-brand    # brand hue in sync

Two shapes, one source of truth (v4.1)
--------------------------------------
macOS 26+ reads `CFBundleIconName` and applies the icon SHAPE ITSELF, so the
asset catalog must be fed full-bleed opaque squares; pre-rounded artwork comes
back double-masked, shrunk and clipped into a near-circle at 16 px (measured on
a real Finder list row, and independently reported upstream — see
design/icon/README.md). macOS 14/15 read `CFBundleIconFile` and do NOT mask, so
the `.icns` fallback must carry the squircle. One run therefore writes both:

    Sources/.../Assets.xcassets/AppIcon.appiconset   full-bleed  -> actool  -> Assets.car
    Sources/.../Resources/AppIcon.iconset            masked      -> iconutil -> AppIcon.icns

Both are committed and both are pinned by --verify-assets, so the release
scripts need nothing but actool + iconutil — no Python, no Pillow at build time.

Dark variants
-------------
Not shippable as PNGs. actool refuses `appearances` on mac app-icon slots —
both the ten-slot layout and the single-size `universal` layout come back as
"unassigned children" — so the dark artwork lives only in design/icon/source/
as a record. A real dark app icon means Icon Composer's layered `.icon` format,
which has no CLI. Do not reintroduce dark/ entries into the catalog.

Masters (1024 px, light+dark) for EVERY candidate are written to
design/icon/source/ so the design process stays in the repo; the asset set
is resampled straight down from the tier-appropriate master (never up from
a smaller PNG). The small-tier masters are written alongside as
`*-small-1024.png`. The 256 px web assets (docs/assets/icon-256*) are refreshed
from the selected master and KEEP the squircle — a browser applies no mask.
Bump the ?v= cache-buster in the docs HTML when the artwork changes.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

# ---------------------------------------------------------------- constants

ROOT = Path(__file__).resolve().parent.parent
APPSET = ROOT / "Sources/topiary-bar/Resources/Assets.xcassets/AppIcon.appiconset"
# Masked sibling of the catalog, consumed by iconutil (see write_iconset).
ICONSET = ROOT / "Sources/topiary-bar/Resources/AppIcon.iconset"
MASTERS = ROOT / "design/icon/source"

RADIUS_RATIO = 0.2257          # squircle radius on the macOS 26 grid (v1)
SUPERSAMPLE = 4                # draw at 4x, box down — clean AA edges
S = 1024                       # master size

SIZES = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}

# ---------------------------------------------------------------- palette
#
# All greys are near-neutral (slight cool cast) so the icon sits calmly next
# to macOS system-blue accents without competing with them.

PALETTES = {
    "light": {
        "panel_top": (250, 251, 253),
        "panel_bottom": (216, 220, 227),
        "slot": (168, 173, 181),
        "slot_top_shadow": (120, 125, 134),
        "slot_bottom_light": (236, 239, 243),
        "rail_top": (252, 253, 255),
        "rail_bottom": (176, 181, 190),
        "knobA_face": (62, 66, 74),
        "knobA_edge": (120, 125, 134),
        "knobA_rim": (36, 38, 44),
        "knobB_face": (238, 240, 244),
        "knobB_edge": (142, 147, 156),
        "knobB_rim": (96, 101, 110),
        "shadow": (30, 34, 42),
        "shadow_alpha": 80,
        "rim_light": (255, 255, 255),
        "rim_light_alpha": 170,
        "rim_dark": (40, 44, 52),
        "rim_dark_alpha": 95,
    },
    "dark": {
        "panel_top": (44, 45, 50),
        "panel_bottom": (16, 17, 20),
        "slot": (10, 11, 13),
        "slot_top_shadow": (5, 5, 7),
        "slot_bottom_light": (86, 90, 98),
        "rail_top": (240, 242, 246),
        "rail_bottom": (120, 125, 134),
        "knobA_face": (126, 131, 141),
        "knobA_edge": (176, 181, 190),
        "knobA_rim": (8, 9, 11),
        "knobB_face": (236, 238, 242),
        "knobB_edge": (120, 125, 134),
        "knobB_rim": (10, 11, 13),
        "shadow": (0, 0, 0),
        "shadow_alpha": 150,
        "rim_light": (255, 255, 255),
        "rim_light_alpha": 60,
        "rim_dark": (0, 0, 0),
        "rim_dark_alpha": 130,
    },
}

# ---------------------------------------------------------------- accent
#
# v3 introduces the single brand hue: a restrained topiary green on the
# left (dark, value-anchor) knob. Everything else stays neutral so the
# green reads as a signature, not a theme, and keeps its distance from
# the macOS system-blue interactive accents. Values keep v2's face/edge/
# rim structure with the hue rotated; saturation stays low. v3c instead
# tints the whole glass — the boldest candidate, kept for comparison.

ACCENTS = {
    "v3a-accent": {
        "light": {
            "knobA_face": (56, 94, 72),
            "knobA_edge": (98, 138, 114),
            "knobA_rim": (28, 52, 40),
        },
        "dark": {
            "knobA_face": (122, 172, 142),
            "knobA_edge": (170, 208, 182),
            "knobA_rim": (10, 24, 16),
        },
    },
    "v3b-graphite": None,
    "v4a-refined": {
        "light": {
            "knobA_face": (56, 94, 72),
            "knobA_edge": (98, 138, 114),
            "knobA_rim": (28, 52, 40),
        },
        "dark": {
            "knobA_face": (122, 172, 142),
            "knobA_edge": (170, 208, 182),
            "knobA_rim": (10, 24, 16),
        },
    },
    "v4b-plain": {
        "light": {
            "knobA_face": (56, 94, 72),
            "knobA_edge": (98, 138, 114),
            "knobA_rim": (28, 52, 40),
        },
        "dark": {
            "knobA_face": (122, 172, 142),
            "knobA_edge": (170, 208, 182),
            "knobA_rim": (10, 24, 16),
        },
    },
    "v3c-verdant": {
        "light": {
            "panel_top": (242, 250, 245),
            "panel_bottom": (208, 226, 215),
            "slot": (154, 175, 162),
            "slot_top_shadow": (108, 130, 117),
            "slot_bottom_light": (230, 243, 235),
            "rail_bottom": (168, 190, 177),
            "knobA_face": (50, 90, 68),
            "knobA_edge": (92, 132, 108),
            "knobA_rim": (24, 46, 34),
            "shadow": (26, 40, 32),
        },
        "dark": {
            "panel_top": (40, 50, 44),
            "panel_bottom": (14, 19, 16),
            "slot": (9, 14, 11),
            "slot_top_shadow": (4, 7, 5),
            "slot_bottom_light": (82, 102, 90),
            "rail_top": (236, 246, 240),
            "rail_bottom": (116, 138, 125),
            "knobA_face": (118, 170, 138),
            "knobA_edge": (164, 204, 178),
            "knobA_rim": (8, 18, 12),
        },
    },
}

# ---------------------------------------------------------------- v4 fixes
#
# Per-variant palette overrides for the v4 round. They are overrides rather
# than edits to PALETTES so that v2/v3 keep rendering exactly as they did when
# they were reviewed — the record stays falsifiable.
#
#   * silhouette — darker panel base + firmer dark rim (light mode) and a
#     brighter LIT rim (dark mode), so the squircle holds its edge against a
#     white page or a black Dock.
#   * knob B     — the right knob was pure white on a near-white panel; it now
#     carries a grey face and a dark rim so the diagonal's second dot survives.
#
# The silhouette numbers are v4.1, walked back from the first v4 values. On a
# real 16 px Finder list row (1x display, legacy .icns path) the v4 rim read as
# a black frame around the icon — `--measure`'s `edge` metric had rewarded it
# because that metric only asks "is there a step against the ground", never
# "does the step look like a drawn outline". These are the values that keep the
# white-page separation without the frame.

REFINES = {
    "light": {
        "panel_bottom": (205, 210, 219),
        "rim_dark_alpha": 112,
        "knobB_face": (225, 229, 236),
        "knobB_edge": (132, 138, 148),
        "knobB_rim": (58, 62, 70),
    },
    "dark": {
        "panel_bottom": (10, 11, 13),
        "rim_light_alpha": 86,
        "rim_dark_alpha": 140,
        "knobB_face": (228, 231, 237),
        "knobB_rim": (4, 5, 6),
    },
}

# The simplified <=32 px master (see draw_small_master): flat fills only, no
# sheen / refraction / specular / gradient rails. The recess becomes a solid
# dark capsule and the rail a solid light one inside it — the same read as the
# large artwork, minus a shading vocabulary that cannot survive 16 pixels.
# The green is pushed harder than the large-size accent because a desaturated
# forest green and a dark grey are the same pixel at that size.

SMALL_PALETTE = {
    "light": {
        "panel_top": (252, 253, 255),
        "panel_bottom": (190, 196, 206),
        "slot": (116, 122, 132),
        "rail": (246, 247, 250),
        "knobA_face": (24, 116, 68),
        "knobA_rim": (8, 54, 32),
        "knobB_face": (244, 246, 249),
        "knobB_rim": (52, 56, 64),
        "rim": (44, 48, 56),
        "rim_alpha": 150,
    },
    "dark": {
        "panel_top": (76, 79, 88),
        "panel_bottom": (12, 13, 15),
        "slot": (6, 7, 8),
        "rail": (232, 235, 240),
        "knobA_face": (96, 200, 140),
        "knobA_rim": (4, 34, 20),
        "knobB_face": (238, 240, 245),
        "knobB_rim": (2, 3, 4),
        # On a black Dock the LIT rim is the only silhouette available, and a
        # sub-pixel stroke at 16 px loses most of its alpha to antialiasing —
        # hence a brighter, heavier rim than the light tier needs.
        "rim": (198, 204, 214),
        "rim_alpha": 200,
    },
}

SMALL_GEOMETRY = {
    "slot_w": 0.152,     # vs 0.118 standard — the recess is the read at 16 px
    "rail_w": 0.070,     # narrower than the slot, so dark stays on both edges
    "knob_d": 0.238,
    "rail_top": 0.205,
    "rail_bottom": 0.795,
    "knob_y": (0.305, 0.695),
}

# Canonical brand swatch — the two values the app (Theme.Color.brand) and the
# website (--brand) share with the icon. Derived from the large-size accent
# (56,94,72 light / 122,172,142 dark face) lifted to a mid tone. The ratios
# below are measured (WCAG relative luminance), not estimated:
#   #2E7D52 = 5.03:1 on #ffffff, 4.62:1 on #f5f5f7   -> light-mode text
#   #7CBE96 = 7.83:1 on #1c1c1e                      -> dark-mode text
# Neither green is used as text on the *other* mode's ground: on dark,
# #2E7D52 only reaches 3.38:1, and on light, #7CBE96 only 2.17:1. --check-brand
# treats both hexes as the contract and fails if either surface drifts.
BRAND_GREEN = {
    "brand_500": "#2E7D52",
    "brand_300": "#7CBE96",
}
BRAND_CONSUMERS = (
    "Sources/topiary-bar/Views/Theme.swift",
    "docs/assets/site.css",
)

# Geometry in fractions of the side (identity constants + per-candidate dials).
GEOMETRY = {
    "rail_x": (0.385, 0.615),   # rail centre lines
    "rail_top": 0.215,          # slot top
    "rail_bottom": 0.785,       # slot bottom
    "knob_y": (0.315, 0.685),   # left high, right low
}

VARIANTS = {
    # -- v4 (current round): legibility at the small end + a mark that holds
    #    its own silhouette. `refine` opts into the REFINES palette override;
    #    `small` picks the <=32 px strategy ("simplified" = own master).
    "v4a-refined": {"slot_w": 0.118, "rail_w": 0.082, "knob_d": 0.155, "blur": 0.016,
                    "depth": True, "refine": True, "small": "simplified"},
    "v4b-plain": {"slot_w": 0.118, "rail_w": 0.082, "knob_d": 0.155, "blur": 0.016,
                  "depth": True, "refine": True, "small": "tier"},
    # -- v3: brand accent + size tiers + glass depth.
    #    `blur` here is a fraction of the side (0.016 ~= 16 px at 1024);
    #    v2 entries keep their legacy values and legacy rendering path.
    "v3a-accent": {"slot_w": 0.118, "rail_w": 0.082, "knob_d": 0.155, "blur": 0.016, "depth": True},
    "v3b-graphite": {"slot_w": 0.118, "rail_w": 0.082, "knob_d": 0.155, "blur": 0.016, "depth": True},
    "v3c-verdant": {"slot_w": 0.118, "rail_w": 0.082, "knob_d": 0.155, "blur": 0.016, "depth": True},
    # -- v2 (monochrome round, kept drawable for the record). There `blur`
    #    was read as a fraction of the side — an order too large, which
    #    softened v2's shadows and knob speculars; one of v3's fixes.
    "v2a-crisp": {"slot_w": 0.118, "rail_w": 0.082, "knob_d": 0.155, "blur": 0.9},
    "v2b-studio": {"slot_w": 0.112, "rail_w": 0.078, "knob_d": 0.148, "blur": 1.4},
    "v2c-bold": {"slot_w": 0.132, "rail_w": 0.096, "knob_d": 0.175, "blur": 0.9},
}

# ---------------------------------------------------------------- helpers


def squircle_mask(size: int) -> Image.Image:
    """Anti-aliased rounded-rectangle alpha mask for a `size` x `size` icon."""
    radius = max(1, round(RADIUS_RATIO * size))
    big = size * SUPERSAMPLE
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, big - 1, big - 1), radius=radius * SUPERSAMPLE, fill=255
    )
    return mask.resize((size, size), Image.LANCZOS)


def v_gradient(size: int, top, bottom) -> Image.Image:
    """Vertical gradient image (top colour -> bottom colour)."""
    grad = Image.linear_gradient("L").resize((size, size), Image.BILINEAR)
    a = Image.new("RGB", (size, size), top)
    b = Image.new("RGB", (size, size), bottom)
    return Image.composite(b, a, grad)


def scaled(v: float) -> int:
    return round(v * S)


def _mix(c: tuple, target: tuple, f: float) -> tuple:
    """Linear blend between two RGB colours (small-tier contrast nudges)."""
    return tuple(round(a + (b - a) * f) for a, b in zip(c, target))


def draw_variant(variant: str, mode: str, size_class: int = 0) -> Image.Image:
    """Draw one 1024 px master at 4x supersampling, then box down.

    `size_class` is the asset size this master resamples to: sizes <= 32
    draw from the small tier (heavier stroke, tighter blur, boosted slot
    contrast), <= 64 from a mid tier — same geometry, heavier stroke. 0
    selects the standard master.
    """
    p = dict(PALETTES[mode])
    accent = (ACCENTS.get(variant) or {}).get(mode)
    if accent:
        p.update(accent)
    g = GEOMETRY
    d = dict(VARIANTS[variant])
    depth = d.pop("depth", False)
    if d.pop("refine", False):
        p.update(REFINES[mode])
    d.pop("small", None)  # handled by master_for, which routes the small tier
    if size_class and size_class <= 32:
        d = {
            "slot_w": d["slot_w"] * 1.35,
            "rail_w": d["rail_w"] * 1.7,
            "knob_d": d["knob_d"] * 1.45,
            "blur": d["blur"] * 0.7,
        }
        if mode == "light":
            p["slot"] = _mix(p["slot"], (0, 0, 0), 0.20)
            p["slot_top_shadow"] = _mix(p["slot_top_shadow"], (0, 0, 0), 0.15)
        else:
            p["slot_bottom_light"] = _mix(p["slot_bottom_light"], (255, 255, 255), 0.22)
    elif size_class and size_class <= 64:
        d = {
            "slot_w": d["slot_w"] * 1.10,
            "rail_w": d["rail_w"] * 1.20,
            "knob_d": d["knob_d"] * 1.12,
            "blur": d["blur"] * 0.85,
        }
    W = S * SUPERSAMPLE
    s = lambda v: round(v * W)

    img = v_gradient(W, p["panel_top"], p["panel_bottom"]).convert("RGBA")

    # Sheen: a soft light pooling at the top-left of the glass (v3 lifts
    # it slightly so the panel reads polished rather than flat).
    sheen = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ImageDraw.Draw(sheen).ellipse(
        (-s(0.25), -s(0.45), s(1.15), s(0.85)),
        fill=(255, 255, 255, (26 if mode == "light" else 18) + (12 if depth else 0)),
    )
    sheen = sheen.filter(ImageFilter.GaussianBlur(s(0.06)))
    img.alpha_composite(sheen)

    def capsule(cx_px: int, top_px: int, bottom_px: int, w_px: int) -> tuple:
        return (cx_px - w_px // 2, top_px, cx_px + w_px // 2, bottom_px)

    for i, cx in enumerate(g["rail_x"]):
        cx_px = s(cx)
        top = s(g["rail_top"])
        bottom = s(g["rail_bottom"])
        slot = capsule(cx_px, top, bottom, s(d["slot_w"]))
        knob_cy = g["knob_y"][i]
        knob_r = d["knob_d"] / 2
        blur = s(d["blur"])

        # Contact shadow cast by rail + knob onto the glass.
        sh = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle(
            (slot[0] + s(0.006), slot[1] + s(0.012), slot[2] + s(0.006), slot[3] + s(0.012)),
            radius=s(d["slot_w"] / 2),
            fill=(*p["shadow"], p["shadow_alpha"]),
        )
        img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(blur * 2)))

        # Recessed slot: darker well; shadowed top lip and lit bottom lip are
        # clipped to the slot capsule so their corners never poke outside.
        slot_mask = Image.new("L", (W, W), 0)
        ImageDraw.Draw(slot_mask).rounded_rectangle(
            slot, radius=s(d["slot_w"] / 2), fill=255
        )
        slot_img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        sd = ImageDraw.Draw(slot_img)
        sd.rounded_rectangle(slot, radius=s(d["slot_w"] / 2), fill=(*p["slot"], 255))
        lips = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        ld = ImageDraw.Draw(lips)
        ld.rounded_rectangle(
            (slot[0], slot[1], slot[2], slot[1] + s(0.05)),
            radius=s(d["slot_w"] / 4),
            fill=(*p["slot_top_shadow"], 200),
        )
        ld.rounded_rectangle(
            (slot[0], slot[3] - s(0.035), slot[2], slot[3]),
            radius=s(d["slot_w"] / 4),
            fill=(*p["slot_bottom_light"], 190),
        )
        slot_img.paste(lips, (0, 0), Image.composite(lips.split()[3], Image.new("L", (W, W), 0), slot_mask))
        img.alpha_composite(slot_img)

        # Rail: bright capsule with a specular edge on the lit side.
        rail = capsule(cx_px, top + s(0.012), bottom - s(0.012), s(d["rail_w"]))
        rail_box = (rail[2] - rail[0], rail[3] - rail[1])
        rail_grad = (
            v_gradient(S, p["rail_top"], p["rail_bottom"])
            .resize(rail_box, Image.BILINEAR)
        )
        rail_img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        rail_mask = Image.new("L", (W, W), 0)
        ImageDraw.Draw(rail_mask).rounded_rectangle(
            rail, radius=s(d["rail_w"] / 2), fill=255
        )
        rail_img.paste(rail_grad, (rail[0], rail[1]), rail_mask.crop(rail))
        spec = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        ImageDraw.Draw(spec).rounded_rectangle(
            (rail[0] + s(0.008), rail[1] + s(0.01), rail[0] + s(0.016), rail[3] - s(0.01)),
            radius=s(0.004),
            fill=(255, 255, 255, 120),
        )
        rail_img.alpha_composite(spec)
        img.alpha_composite(rail_img)

        # Knobs: left = dark chrome (the value anchor), right = light. Face,
        # offset highlight/shade, rim and contact shadow per knob.
        kx = s(cx)
        ky = s(knob_cy)
        kr = s(knob_r)
        kp = p["knobA_face"] if i == 0 else p["knobB_face"]
        ke = p["knobA_edge"] if i == 0 else p["knobB_edge"]
        kr_c = p["knobA_rim"] if i == 0 else p["knobB_rim"]
        ksh = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        ImageDraw.Draw(ksh).ellipse(
            (kx - kr + s(0.004), ky - kr + s(0.026), kx + kr + s(0.004), ky + kr + s(0.026)),
            fill=(*p["shadow"], p["shadow_alpha"] + (10 if i == 0 else 50)),
        )
        img.alpha_composite(ksh.filter(ImageFilter.GaussianBlur(blur * 2)))

        knob = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        kd = ImageDraw.Draw(knob)
        kd.ellipse((kx - kr, ky - kr, kx + kr, ky + kr), fill=(*kp, 255))
        hl = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        ImageDraw.Draw(hl).ellipse(
            (kx - kr * 0.72, ky - kr * 0.86, kx + kr * 0.34, ky + kr * 0.10),
            fill=(255, 255, 255, 130 if mode == "light" else 165),
        )
        knob.alpha_composite(hl.filter(ImageFilter.GaussianBlur(blur)))
        shd = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        ImageDraw.Draw(shd).ellipse(
            (kx - kr * 0.35, ky + kr * 0.10, kx + kr * 0.86, ky + kr * 0.92),
            fill=(*ke, 130),
        )
        knob.alpha_composite(shd.filter(ImageFilter.GaussianBlur(blur)))
        kd.ellipse(
            (kx - kr, ky - kr, kx + kr, ky + kr),
            outline=(*kr_c, 255 if mode == "light" else 140),
            width=s(0.004),
        )
        img.alpha_composite(knob)

    # v3 depth: a faint dark ring just inside the rim — the refraction line
    # that makes the glass read as a solid, polished edge.
    if depth:
        inner = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        ImageDraw.Draw(inner).rounded_rectangle(
            (s(0.010), s(0.010), W - s(0.010), W - s(0.010)),
            radius=s(RADIUS_RATIO - 0.010),
            outline=(*p["rim_dark"], 70),
            width=s(0.005),
        )
        img.alpha_composite(inner.filter(ImageFilter.GaussianBlur(s(0.002))))

    # Squircle rim: lit top edge, shaded bottom edge — glass thickness.
    rim = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rim)
    box = (s(0.0015), s(0.0015), W - s(0.0015), W - s(0.0015))
    radius = s(RADIUS_RATIO)
    rd.rounded_rectangle(
        (box[0], box[1] + s(0.004), box[2], box[3] + s(0.004)),
        radius=radius,
        outline=(*p["rim_dark"], p["rim_dark_alpha"]),
        width=s(0.004),
    )
    rd.rounded_rectangle(
        box, radius=radius, outline=(*p["rim_light"], p["rim_light_alpha"]), width=s(0.004)
    )
    img.alpha_composite(rim)

    return img.resize((S, S), Image.LANCZOS)


def draw_small_master(variant: str, mode: str) -> Image.Image:
    """The independent <=32 px master: the same mark, stripped of shading.

    No sheen, no recessed-slot lips, no rail gradient, no knob specular, no
    inner refraction, no blur anywhere. What survives at 16 px is the
    geometry — two dark recesses, two light rails, the high-left / low-right
    diagonal of the knobs — so that is all this draws. Contrast is bought with
    flat value steps instead of edges, and the brand green is pushed to a
    saturation that still reads as green when the whole knob is 3 pixels wide.
    """
    sp = dict(SMALL_PALETTE[mode])
    accent = (ACCENTS.get(variant) or {}).get(mode)
    if accent and "knobA_face" in accent:
        # An accented variant keeps its own hue identity, boosted for size.
        boost = 0.45 if mode == "light" else 0.30
        target = (255, 255, 255) if mode == "dark" else (0, 128, 60)
        sp["knobA_face"] = _mix(accent["knobA_face"], target, boost)
    g, geo = GEOMETRY, SMALL_GEOMETRY
    W = S * SUPERSAMPLE
    s = lambda v: round(v * W)

    img = v_gradient(W, sp["panel_top"], sp["panel_bottom"]).convert("RGBA")

    for i, cx in enumerate(g["rail_x"]):
        cx_px = s(cx)
        top, bottom = s(geo["rail_top"]), s(geo["rail_bottom"])
        slot_w, rail_w = s(geo["slot_w"]), s(geo["rail_w"])

        ImageDraw.Draw(img).rounded_rectangle(
            (cx_px - slot_w // 2, top, cx_px + slot_w // 2, bottom),
            radius=slot_w // 2, fill=(*sp["slot"], 255),
        )
        ImageDraw.Draw(img).rounded_rectangle(
            (cx_px - rail_w // 2, top + s(0.014), cx_px + rail_w // 2, bottom - s(0.014)),
            radius=rail_w // 2, fill=(*sp["rail"], 255),
        )

        kr = s(geo["knob_d"] / 2)
        ky = s(geo["knob_y"][i])
        face = sp["knobA_face"] if i == 0 else sp["knobB_face"]
        rim = sp["knobA_rim"] if i == 0 else sp["knobB_rim"]
        ImageDraw.Draw(img).ellipse(
            (cx_px - kr, ky - kr, cx_px + kr, ky + kr), fill=(*face, 255)
        )
        # Outlines are drawn after the fill so the recess never bleeds over a
        # knob edge — at 16 px a single stray pixel closes the diagonal.
        ImageDraw.Draw(img).ellipse(
            (cx_px - kr, ky - kr, cx_px + kr, ky + kr),
            outline=(*rim, 255), width=s(0.006),
        )

    # The rim carries the silhouette at this size. It is drawn as a stroke
    # centred on the inset path, so half of it falls outside the canvas and the
    # alpha mask clips the rest: at 16 px a hairline stroke contributes a
    # tenth of a pixel and buys nothing. The width below is the least that
    # survives the downsample — any heavier and the real 16 px Finder row shows
    # it as a drawn black frame rather than an edge (v4.1 walk-back).
    ImageDraw.Draw(img).rounded_rectangle(
        (s(0.002), s(0.002), W - s(0.002), W - s(0.002)),
        radius=s(RADIUS_RATIO), outline=(*sp["rim"], sp["rim_alpha"]), width=s(0.012),
    )
    return img.resize((S, S), Image.LANCZOS)


def apply_mask(master: Image.Image, size: int) -> Image.Image:
    icon = master.resize((size, size), Image.LANCZOS).convert("RGBA")
    icon.putalpha(squircle_mask(size))
    return icon


_master_cache: dict = {}


def master_for(variant: str, mode: str, size: int) -> Image.Image:
    """The 1024 master for an asset — tier-appropriate, cached.

    A variant that opts into `small: "simplified"` gets its own drawing below
    32 px; every other variant falls back to the v3 stroke-tier behaviour.
    """
    tier = 32 if size <= 32 else (64 if size <= 64 else 0)
    simplified = tier == 32 and VARIANTS[variant].get("small") == "simplified"
    key = (variant, mode, "small" if simplified else tier)
    if key not in _master_cache:
        _master_cache[key] = (
            draw_small_master(variant, mode) if simplified
            else draw_variant(variant, mode, size_class=tier)
        )
    return _master_cache[key]


def render_icon(variant: str, mode: str, size: int, mask: bool = True) -> Image.Image:
    """Ship-path icon: tier-appropriate master, masked, resampled once.

    `mask=False` skips the squircle and returns an opaque full-bleed square.
    That is what the asset catalog needs on macOS 26+, where the system applies
    the shape itself — feeding it pre-rounded artwork gets it double-masked,
    shrunk and re-clipped into a near-circle (measured on a real 16 px Finder
    list row; see design/icon/README.md).
    """
    icon = apply_mask(master_for(variant, mode, size), size)
    if mask:
        return icon
    flat = Image.new("RGBA", icon.size, (0, 0, 0, 255))
    flat.paste(master_for(variant, mode, size).resize((size, size), Image.LANCZOS),
               (0, 0))
    return flat


def write_asset_set(variant: str) -> None:
    """Write the committed asset catalog: full-bleed, light only.

    Full-bleed because this catalog is compiled by actool into `Assets.car` and
    macOS 26+ applies the icon shape itself (see `render_icon`). Light only
    because actool refuses `appearances` on mac app-icon slots — both the
    ten-slot and the single-size layouts come back as "unassigned children",
    so the dark artwork cannot be shipped this way at all. It stays in
    design/icon/source/ as artwork, and the pre-Tahoe dark story is an Icon
    Composer `.icon` problem, not a PNG problem.
    """
    APPSET.mkdir(parents=True, exist_ok=True)
    for name, size in SIZES.items():
        render_icon(variant, "light", size, mask=False).convert("RGB").save(APPSET / name)
        print(f"  {name} ({size}px, full-bleed)")
    write_catalog_contents(variant)
    # Pre-Tahoe fallback: macOS 14/15 read CFBundleIconFile and do NOT mask the
    # artwork, so the .icns has to carry its own squircle. Committed next to the
    # catalog rather than regenerated at release time, so script/release.sh
    # needs nothing but actool + iconutil; verify_assets pins both sets.
    write_iconset(variant, ICONSET)
    print(f"AppIcon catalog (full-bleed) written to {APPSET}")

    # Website brand assets (favicon + hero): the browser applies no mask, so
    # these keep the squircle. Same masters as the app set.
    docs = ROOT / "docs" / "assets"
    render_icon(variant, "light", 256).save(docs / "icon-256.png")
    render_icon(variant, "dark", 256).save(docs / "icon-256-dark.png")
    print(f"web 256 px assets refreshed in {docs}")


def write_catalog_contents(variant: str) -> None:
    """Contents.json for the full-bleed, light-only catalog."""
    entries = []
    for name in SIZES:
        stem = Path(name).stem                       # icon_128x128 / icon_16x16@2x
        scale = "2x" if stem.endswith("@2x") else "1x"
        logical = stem.split("icon_", 1)[1].removesuffix("@2x")
        entries.append({"size": logical, "idiom": "mac", "scale": scale, "filename": name})
    (APPSET / "Contents.json").write_text(
        json.dumps({"images": entries,
                    "info": {"author": "xcode", "version": 1}}, indent=2) + "\n",
        encoding="utf-8")


def write_iconset(variant: str, out_dir: Path) -> None:
    """Write a masked `.iconset` for `iconutil` — the pre-Tahoe fallback.

    macOS 14/15 read `CFBundleIconFile` and do NOT mask the artwork, so this
    copy has to carry its own squircle. Two shapes from one source of truth:
    full-bleed for the catalog, masked for the .icns.
    """
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, size in SIZES.items():
        render_icon(variant, "light", size).save(out_dir / name)
    print(f"masked iconset (for iconutil) -> {out_dir}")


def contact_sheet(variants: list) -> Image.Image:
    """Review sheet: candidates x modes x sizes on light & dark grounds."""
    grounds = {"light": (245, 246, 248), "dark": (28, 28, 30)}
    sizes = [128, 64, 32, 16]
    cell = 160
    rows = []
    for variant in variants:
        row = Image.new("RGB", (cell * (len(sizes) + 1) * 2 + 30, cell + 24), (255, 255, 255))
        for mi, mode in enumerate(("light", "dark")):
            ox = mi * (cell * (len(sizes) + 1) + 10)
            bg = Image.new("RGB", (cell * (len(sizes) + 1), cell), grounds[mode])
            big = render_icon(variant, mode, cell - 16)
            bg.paste(big, (8, 8), big)
            for si, size in enumerate(sizes):
                ic = render_icon(variant, mode, size)
                x = cell + si * cell + (cell - size) // 2
                bg.paste(ic, (x, (cell - size) // 2), ic)
            row.paste(bg, (ox, 12))
        rows.append(row)
    sheet = Image.new("RGB", (rows[0].width, len(rows) * (cell + 24) + 8), (255, 255, 255))
    for i, r in enumerate(rows):
        sheet.paste(r, (0, i * (cell + 24) + 4))
    return sheet


def small_review(variants: list) -> Image.Image:
    """Pixel-level review: real 16/32/64 px, magnified, on white and black.

    Two things the contact sheet cannot show — whether the small tier is
    actually legible, and whether the squircle holds an edge against the two
    grounds it is really composited on (a white desktop, a black Dock). The
    magnified strips use NEAREST so the pixels stay the compositor's pixels;
    a Lanczos zoom would hide a bad tier behind its own softness.
    """
    zoom = 6
    row_h = 210
    block_w = 520
    grounds = {"light": (255, 255, 255), "dark": (0, 0, 0)}
    rows = []
    for variant in variants:
        row = Image.new("RGB", (block_w * 2 + 24, row_h), (128, 128, 128))
        for bi, mode in enumerate(("light", "dark")):
            ox = bi * (block_w + 24)
            card = Image.new("RGB", (block_w, row_h), grounds[mode])
            x = 14
            for size in (16, 32, 64):
                ic = render_icon(variant, mode, size)
                card.paste(ic, (x, 14 + (64 - size) // 2), ic)
                x += 74
            x = 14
            for size in (16, 32):
                big = render_icon(variant, mode, size).resize(
                    (size * zoom, size * zoom), Image.NEAREST
                )
                card.paste(big, (x, 100), big)
                x += size * zoom + 22
            # 128 px on the extreme ground: the silhouette test.
            ic = render_icon(variant, mode, 128)
            card.paste(ic, (block_w - 142, 14), ic)
            row.paste(card, (ox, 0))
        rows.append(row)
    sheet = Image.new("RGB", (rows[0].width, len(rows) * (row_h + 8) + 8), (255, 255, 255))
    for i, r in enumerate(rows):
        sheet.paste(r, (0, i * (row_h + 8) + 4))
    return sheet


def _rel_lum(rgb: tuple) -> float:
    """WCAG relative luminance (0..1) of an RGB triple."""
    def chan(v: float) -> float:
        v /= 255.0
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = rgb[:3]
    return 0.2126 * chan(r) + 0.7152 * chan(g) + 0.0722 * chan(b)


def _ratio(a: float, b: float) -> float:
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)


def measure_legibility(variants: list) -> None:
    """Print the numbers the small tier and the silhouette fix are about.

    Three metrics, all on WCAG relative luminance so they can be checked
    instead of admired:

    * `mark`   — how far the left recess band departs from the panel beside it,
      taking whichever end of the band is farther away. A single-point sample of
      the rail is meaningless at 16 px (the rail is one pixel wide, so the
      reading depends on where the rounding lands), and a band MINIMUM alone
      would be light-mode-centric: on the dark panel the structure that survives
      is the bright rail, not the black recess.
    * `detail` — mean absolute horizontal luminance step along the mid-height
      scanline, x100. How much structure survives the downsample at all.
    * `edge`   — the stronger of the top and bottom panel-versus-ground ratios.
      Light mode separates from a white desktop at the bottom; dark mode has to
      separate from a black Dock at the LIT top rim, so taking one corner
      measures the wrong edge for one of the two.

    Grounds are what the icon is really composited on: white desktop for the
    light icon, black Dock for the dark one.
    """
    g = GEOMETRY
    print(f"{'variant':14} {'mode':6} {'size':5} {'mark':>7} {'detail':>7} {'edge':>7}")
    for variant in variants:
        for mode, ground in (("light", (255, 255, 255)), ("dark", (0, 0, 0))):
            for size in (16, 32):
                icon = render_icon(variant, mode, size)
                canvas = Image.new("RGB", (size, size), ground)
                canvas.paste(icon, (0, 0), icon)
                px = canvas.load()
                lum = [[_rel_lum(px[x, y]) for x in range(size)] for y in range(size)]

                mid = size // 2
                half = max(1, round(0.118 * size / 2))
                cx = round(g["rail_x"][0] * size)
                band = [lum[mid][x] for x in range(max(0, cx - half), min(size, cx + half + 1))]
                panel = lum[mid][round(0.18 * size)]
                mark = max(_ratio(min(band), panel), _ratio(max(band), panel))
                steps = [abs(lum[mid][x + 1] - lum[mid][x]) for x in range(size - 1)]
                detail = (sum(steps) / len(steps)) * 100
                edge = max(
                    _ratio(lum[1][size // 2], _rel_lum(ground)),
                    _ratio(lum[size - 2][size // 2], _rel_lum(ground)),
                )
                print(f"{variant:14} {mode:6} {size:<5} "
                      f"{mark:7.2f} {detail:7.2f} {edge:7.2f}")


def verify_assets(variant: str) -> int:
    """Fail if the committed asset set no longer matches this file.

    The whole premise of the v2 rewrite was that the code is the source of
    truth; a hand-patched PNG silently breaks that, and the breakage only
    shows up the next time someone regenerates and wonders where their edit
    went. This is the check that keeps the premise true — it also pins the
    delivery contract, since the catalog must be FULL-BLEED (a masked PNG here
    is exactly the double-mask bug macOS 26 punishes) and light-only (actool
    cannot compile dark app-icon slots).
    """
    bad = []
    for name, size in SIZES.items():
        path = APPSET / name
        if not path.exists():
            bad.append(f"missing {path.relative_to(ROOT)}")
            continue
        img = Image.open(path)
        if img.mode != "RGB":
            bad.append(f"{path.relative_to(ROOT)}: has alpha ({img.mode}); "
                       "the catalog must be full-bleed opaque")
            continue
        expected = render_icon(variant, "light", size, mask=False).convert("RGB").tobytes()
        if img.convert("RGB").tobytes() != expected:
            bad.append(f"drifted {path.relative_to(ROOT)}")
    dark_dir = APPSET / "dark"
    if dark_dir.exists():
        bad.append(f"{dark_dir.relative_to(ROOT)}: dark slots cannot be compiled "
                   "by actool for the mac idiom; keep the artwork in design/ instead")
    for name, size in SIZES.items():
        path = ICONSET / name
        if not path.exists():
            bad.append(f"missing {path.relative_to(ROOT)}")
            continue
        img = Image.open(path)
        if img.mode != "RGBA":
            bad.append(f"{path.relative_to(ROOT)}: must be masked (RGBA)")
            continue
        expected = render_icon(variant, "light", size).tobytes()
        if img.convert("RGBA").tobytes() != expected:
            bad.append(f"drifted {path.relative_to(ROOT)} (masked iconset)")
    if bad:
        for line in bad:
            print(f"  asset mismatch: {line}")
        print(f"  regenerate with: python3 tools/generate_app_icon.py --variant {variant}")
        return 1
    print(f"  asset set matches {variant} "
          f"({len(SIZES)} full-bleed catalog + {len(SIZES)} masked iconset files)")
    return 0


def check_brand() -> int:
    """Guard the brand hue against drift between icon, app and website.

    The failure this prevents is the ordinary one: someone retints one surface
    and the three quietly diverge, so the Dock icon no longer matches the site
    and the app's accent matches neither. Every hex in BRAND_GREEN must appear
    verbatim in every consumer file.
    """
    bad = []
    for rel in BRAND_CONSUMERS:
        path = ROOT / rel
        if not path.exists():
            bad.append(f"{rel}: missing")
            continue
        text = path.read_text(encoding="utf-8")
        for name, hexv in BRAND_GREEN.items():
            if hexv.lower() not in text.lower():
                bad.append(f"{rel}: {name} {hexv} not found")
    if bad:
        for line in bad:
            print(f"  brand drift: {line}")
        return 1
    print("  brand hue in sync across " + ", ".join(BRAND_CONSUMERS))
    return 0


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--variant", choices=sorted(VARIANTS), default="v4a-refined")
    ap.add_argument("--sheet", action="store_true", help="emit design/icon/contact-sheet.png")
    ap.add_argument("--review", action="store_true",
                    help="emit design/icon/review-small-sizes.png")
    ap.add_argument("--check-brand", action="store_true",
                    help="verify the brand hue matches app + website, then exit")
    ap.add_argument("--verify-assets", action="store_true",
                    help="verify the committed asset set still matches this file")
    ap.add_argument("--measure", action="store_true",
                    help="print small-size legibility + silhouette ratios, then exit")
    args = ap.parse_args()

    if args.check_brand:
        sys.exit(check_brand())

    if args.verify_assets:
        sys.exit(verify_assets(args.variant))

    if args.measure:
        measure_legibility(sorted(VARIANTS))
        return

    MASTERS.mkdir(parents=True, exist_ok=True)

    # Record every candidate's standard 1024 masters so the design process
    # stays inspectable — including variants that never ship. Variants with
    # their own small tier get that master recorded too, under -small-1024.
    for variant in sorted(VARIANTS):
        for m in ("light", "dark"):
            master_for(variant, m, 1024).save(MASTERS / f"{variant}-{m}-1024.png")
            if VARIANTS[variant].get("small") == "simplified":
                draw_small_master(variant, m).save(MASTERS / f"{variant}-{m}-small-1024.png")
    print(f"masters (all candidates) -> {MASTERS}")

    if args.sheet:
        sheet = contact_sheet(sorted(VARIANTS))
        out = MASTERS.parent / "contact-sheet.png"
        sheet.save(out)
        print(f"review sheet -> {out}")

    if args.review:
        # v3a stays in the strip as the "before" of the small-tier comparison.
        review = small_review(["v3a-accent", "v4b-plain", "v4a-refined"])
        out = MASTERS.parent / "review-small-sizes.png"
        review.save(out)
        print(f"small-size review -> {out}")

    write_asset_set(args.variant)


if __name__ == "__main__":
    main()
