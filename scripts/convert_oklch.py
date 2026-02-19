#!/usr/bin/env python3
"""Convert oklch() color values to rgb() in a CSS file for old browser compatibility."""
import math
import re
import sys


def oklch_to_rgb(L_pct, C, H):
    L = L_pct / 100.0
    H_rad = H * math.pi / 180.0
    a = C * math.cos(H_rad)
    b = C * math.sin(H_rad)

    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b

    l = l_ ** 3
    m = m_ ** 3
    s = s_ ** 3

    r_lin =  4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g_lin = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    b_lin = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

    def to_srgb(c):
        c = max(0.0, c)
        if c <= 0.0031308:
            return 12.92 * c
        return 1.055 * (c ** (1 / 2.4)) - 0.055

    r = max(0, min(255, round(to_srgb(r_lin) * 255)))
    g = max(0, min(255, round(to_srgb(g_lin) * 255)))
    bv = max(0, min(255, round(to_srgb(b_lin) * 255)))
    return r, g, bv


pattern = re.compile(r'oklch\(\s*([\d.]+)%?\s+([\d.]+)\s+([\d.]+)\s*\)')


def replace_oklch(m):
    L = float(m.group(1))
    C = float(m.group(2))
    H = float(m.group(3))
    r, g, b = oklch_to_rgb(L, C, H)
    return f"rgb({r}, {g}, {b})"


path = sys.argv[1] if len(sys.argv) > 1 else "assets/css/app.css"
css = open(path).read()
count = len(pattern.findall(css))
new_css = pattern.sub(replace_oklch, css)
open(path, "w").write(new_css)
print(f"Converted {count} oklch() values to rgb() in {path}")
