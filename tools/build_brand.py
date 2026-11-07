#!/usr/bin/env python3
"""Builds the brand images from the app emblem (EmblemPainter's geometry).

Writes to design/brand/: icon.png (1024, launcher source), foreground.png
(1024, transparent, inside the adaptive-icon safe zone), play_icon.png
(512, Play Store listing) and feature_graphic.png (1024 x 500).
Needs rsvg-convert (brew install librsvg).

    python3 -I tools/build_brand.py
"""
import os
import subprocess

OUT = os.path.join(os.path.dirname(__file__), "..", "design", "brand")
SYS, HI = "#4FB3FF", "#A9DCFF"


def emblem(cx, cy, s):
    """The emblem on a 160-unit grid, centred at (cx, cy), scaled by s."""
    def d(r):
        return f"M{cx},{cy - r * s} L{cx + r * s},{cy} L{cx},{cy + r * s} L{cx - r * s},{cy} Z"
    def ln(x1, y1, x2, y2, w, c):
        return (f'<line x1="{cx + (x1 - 80) * s}" y1="{cy + (y1 - 80) * s}" '
                f'x2="{cx + (x2 - 80) * s}" y2="{cy + (y2 - 80) * s}" '
                f'stroke="{c}" stroke-width="{w * s}" stroke-linecap="round"/>')
    return f"""<g filter="url(#glow)" fill="none">
    <path d="{d(64)}" stroke="{SYS}" stroke-width="{2.6 * s}"/>
    <path d="{d(38)}" stroke="{HI}" stroke-width="{2.6 * s}"/>
    {ln(80, 2, 80, 30, 2, SYS)}{ln(80, 130, 80, 158, 2, SYS)}
    {ln(2, 80, 22, 80, 2, SYS)}{ln(138, 80, 158, 80, 2, SYS)}
    {ln(80, 50, 80, 64, 1.4, HI)}{ln(80, 96, 80, 110, 1.4, HI)}
    <path d="{d(8)}" fill="{HI}" stroke="none"/>
  </g>"""


def svg(w, h, body, background=True, extra=""):
    bg = (f'<rect width="{w}" height="{h}" fill="url(#bg)"/>'
          '<rect width="100%" height="100%" fill="url(#grid)" opacity=".5"/>'
          if background else "")
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
  <defs>
    <radialGradient id="bg" cx="50%" cy="45%" r="70%">
      <stop offset="0" stop-color="#0E2142"/><stop offset="1" stop-color="#05070D"/>
    </radialGradient>
    <pattern id="grid" width="{w / 16}" height="{w / 16}" patternUnits="userSpaceOnUse">
      <path d="M {w / 16} 0 L 0 0 0 {w / 16}" fill="none" stroke="#4FB3FF" stroke-opacity=".07" stroke-width="2"/>
    </pattern>
    <filter id="glow" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur stdDeviation="{w / 160}" result="b"/>
      <feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>
  {bg}{body}{extra}
</svg>"""


def write(name, content, w, h):
    path = os.path.join(OUT, name)
    open(path + ".svg", "w").write(content)
    subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(h), path + ".svg", "-o", path + ".png"], check=True)
    os.remove(path + ".svg")


os.makedirs(OUT, exist_ok=True)
write("icon", svg(1024, 1024, emblem(512, 512, 4.6)), 1024, 1024)
write("foreground", svg(1024, 1024, emblem(512, 512, 3.0), background=False), 1024, 1024)
write("play_icon", svg(512, 512, emblem(256, 256, 2.3)), 512, 512)
title = ('<text x="470" y="240" font-family="Chakra Petch, Helvetica" font-weight="700" '
         'font-size="66" letter-spacing="7" fill="#DBE7FF">DO OR DIE</text>'
         '<text x="473" y="292" font-family="JetBrains Mono, Menlo" font-size="19" '
         'letter-spacing="3.5" fill="#7D8BA8">THE SYSTEM ISSUES YOUR QUEST</text>')
write("feature_graphic", svg(1024, 500, emblem(250, 250, 2.5), extra=title), 1024, 500)
print("wrote", sorted(os.listdir(OUT)))
