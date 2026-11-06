#!/usr/bin/env python3
"""Builds the launcher icon from the Player art in design/avatars/player.

Writes design/avatars/logo/{icon,foreground}.svg and PNGs via rsvg-convert:
icon.png (full square, dark background) and foreground.png (transparent,
inside Android's adaptive-icon safe zone).

    python3 -I tools/build_logo.py
"""
import os
import re
import subprocess

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "design", "avatars", "player")
OUT = os.path.join(ROOT, "design", "avatars", "logo")
BLUE = "#4FB3FF"


def inner(name):
    s = open(os.path.join(SRC, name)).read()
    s = re.sub(r"<!--.*?-->", "", s, flags=re.S)
    return s[s.index(">", s.index("<svg")) + 1 : s.rindex("</svg>")]


def compose(view_box, background):
    glow = inner("glow.svg").replace("#FFFFFF", BLUE)
    bg = (
        '<rect x="-1000" y="-1000" width="3000" height="3000" fill="url(#bg)"/>'
        if background
        else ""
    )
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="{view_box}" width="1024" height="1024">
  <defs>
    <radialGradient id="bg" cx="280" cy="190" r="260" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#0E2142"/>
      <stop offset="1" stop-color="#05070D"/>
    </radialGradient>
    <filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur stdDeviation="3.5" result="b"/>
      <feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>
  {bg}
  <circle cx="276" cy="200" r="118" fill="none" stroke="{BLUE}" stroke-opacity=".35" stroke-width="2"/>
  {inner("base.svg")}
  <g filter="url(#glow)">{glow}</g>
</svg>
"""


os.makedirs(OUT, exist_ok=True)
# Full icon: head and collar fill the square.
open(os.path.join(OUT, "icon.svg"), "w").write(compose("150 72 252 252", True))
# Adaptive foreground: same framing scaled into the central 66%.
open(os.path.join(OUT, "foreground.svg"), "w").write(compose("85 7 382 382", False))
for name in ("icon", "foreground"):
    subprocess.run(
        ["rsvg-convert", "-w", "1024", "-h", "1024",
         os.path.join(OUT, f"{name}.svg"), "-o", os.path.join(OUT, f"{name}.png")],
        check=True,
    )
print("wrote", OUT)
