#!/usr/bin/env python3
"""Synthesizes the app's original sound effects into assets/sfx/*.wav.

Every sound is generated from sine waves, sweeps and envelopes, so there are
no third-party samples and nothing to license. Re-run after tweaking:

    python3 tools/gen_sfx.py
"""

import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")


def env(i, n, attack=0.005, release=0.6):
    """Linear attack, exponential-ish release over n samples."""
    t = i / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    tail = i / max(1, n)
    return a * (1.0 - tail) ** (1.0 / max(release, 1e-3))


def tone(freq, dur, vol=0.5, attack=0.004, release=0.5, sweep_to=None, harmonics=(1.0,)):
    n = int(RATE * dur)
    out = []
    phase = 0.0
    for i in range(n):
        f = freq if sweep_to is None else freq + (sweep_to - freq) * (i / n)
        phase += 2 * math.pi * f / RATE
        s = sum(h * math.sin(phase * (k + 1)) for k, h in enumerate(harmonics))
        out.append(s * vol * env(i, n, attack, release))
    return out


def mix(*tracks, offsets=None):
    offsets = offsets or [0.0] * len(tracks)
    length = max(int(o * RATE) + len(t) for t, o in zip(tracks, offsets))
    out = [0.0] * length
    for t, o in zip(tracks, offsets):
        start = int(o * RATE)
        for i, s in enumerate(t):
            out[start + i] += s
    return out


def noise(dur, vol=0.2, release=0.3, seed=7):
    rnd = random.Random(seed)
    n = int(RATE * dur)
    return [rnd.uniform(-1, 1) * vol * env(i, n, 0.001, release) for i in range(n)]


def lowpass(samples, alpha=0.15):
    out, y = [], 0.0
    for s in samples:
        y += alpha * (s - y)
        out.append(y)
    return out


def write(name, samples, peak=0.85):
    top = max(1e-9, max(abs(s) for s in samples))
    scale = peak / top
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s * scale * 32767)) for s in samples))
    print(f"{path}  {len(samples) / RATE:.2f}s")


def main():
    # Soft UI click: very short high blip with a breathy edge.
    write("tap", mix(tone(1800, 0.035, 0.5, 0.001, 0.25), lowpass(noise(0.02, 0.15), 0.5)), peak=0.45)

    # Hold-to-confirm complete: quick rising two-step.
    write("confirm", mix(tone(880, 0.09, 0.5, 0.002, 0.4), tone(1320, 0.16, 0.5, 0.002, 0.5), offsets=[0, 0.07]), peak=0.6)

    # Timer start / pause: short sweeps up and down.
    write("timer_start", tone(600, 0.12, 0.5, 0.002, 0.5, sweep_to=1200, harmonics=(1.0, 0.25)), peak=0.55)
    write("timer_stop", tone(1100, 0.12, 0.5, 0.002, 0.5, sweep_to=550, harmonics=(1.0, 0.25)), peak=0.55)

    # One rep logged: dull low thump.
    write("rep", mix(tone(140, 0.09, 0.8, 0.001, 0.3, sweep_to=70), lowpass(noise(0.03, 0.3), 0.08)), peak=0.6)

    # System notice: glassy two-note shimmer as the window powers on.
    write(
        "notice",
        mix(
            tone(660, 0.5, 0.35, 0.01, 0.7, harmonics=(1.0, 0.3, 0.1)),
            tone(990, 0.55, 0.3, 0.01, 0.7, harmonics=(1.0, 0.2)),
            tone(1980, 0.3, 0.08, 0.005, 0.5),
            offsets=[0, 0.06, 0.06],
        ),
        peak=0.6,
    )

    # Level up: bright rising arpeggio into a held chord.
    notes = [523.25, 659.25, 783.99, 1046.5]
    arp = [tone(f, 0.18, 0.4, 0.003, 0.5, harmonics=(1.0, 0.3)) for f in notes]
    chord = [tone(f, 0.9, 0.22, 0.02, 0.8, harmonics=(1.0, 0.25, 0.08)) for f in (523.25, 783.99, 1046.5, 1568.0)]
    write("level_up", mix(*arp, *chord, offsets=[0, 0.08, 0.16, 0.24] + [0.32] * 4), peak=0.75)

    # Penalty Zone: low, heavy throb with a dissonant edge.
    throb = []
    n = int(RATE * 1.2)
    for i in range(n):
        t = i / RATE
        wobble = 0.5 + 0.5 * math.sin(2 * math.pi * 3.5 * t)
        s = math.sin(2 * math.pi * 55 * t) + 0.6 * math.sin(2 * math.pi * 58.3 * t) + 0.25 * math.sin(2 * math.pi * 110 * t)
        s = math.tanh(1.8 * s)  # soft distortion
        throb.append(s * wobble * env(i, n, 0.02, 0.9) * 0.6)

    # Penalty Zone entry: a hard impact (noise crack + deep hit), then a long,
    # heavy throb. Soft-clipped so it plays near full scale without harshness.
    crack = lowpass(noise(0.06, 1.0, 0.25, seed=11), 0.6)
    hit = tone(90, 0.45, 1.0, 0.001, 0.5, sweep_to=40, harmonics=(1.0, 0.5, 0.2))
    long_throb = []
    n = int(RATE * 1.6)
    for i in range(n):
        t = i / RATE
        wobble = 0.55 + 0.45 * math.sin(2 * math.pi * 3.0 * t)
        s = math.sin(2 * math.pi * 50 * t) + 0.7 * math.sin(2 * math.pi * 53.5 * t) + 0.35 * math.sin(2 * math.pi * 100 * t)
        long_throb.append(math.tanh(2.2 * s) * wobble * env(i, n, 0.03, 0.85) * 0.7)
    siren = tone(260, 0.7, 0.18, 0.02, 0.6, sweep_to=170, harmonics=(1.0, 0.4))

    # Phone speakers can't play the 40-55 Hz body, so the same throb is also
    # played at 2x and 3x pitch (100-160 Hz). The ear hears the deep note
    # through these overtones, which makes the sound much louder on a phone.
    overtones = []
    for i in range(n):
        t = i / RATE
        wobble = 0.55 + 0.45 * math.sin(2 * math.pi * 3.0 * t)
        s = (math.sin(2 * math.pi * 100 * t) + 0.7 * math.sin(2 * math.pi * 107 * t)
             + 0.5 * math.sin(2 * math.pi * 150 * t) + 0.35 * math.sin(2 * math.pi * 160.5 * t))
        overtones.append(math.tanh(2.0 * s) * wobble * env(i, n, 0.03, 0.85) * 0.55)
    hit_bright = tone(180, 0.35, 0.6, 0.001, 0.45, sweep_to=90, harmonics=(1.0, 0.5, 0.3))

    penalty = mix(crack, hit, hit_bright, long_throb, overtones, siren,
                  offsets=[0, 0, 0, 0.08, 0.08, 0.12])
    write("penalty", [math.tanh(2.6 * s) for s in penalty], peak=0.98)

    # Panel pop (tab switch): a window popping up in front of you. Short air
    # rush rising into a bright pop, then a soft low "landing" thump.
    rush = lowpass(noise(0.09, 0.5, 0.4, seed=5), 0.35)
    rise = tone(500, 0.08, 0.25, 0.005, 0.7, sweep_to=1600)
    pop = mix(
        tone(1900, 0.06, 0.6, 0.0008, 0.25, harmonics=(1.0, 0.35)),
        tone(2850, 0.04, 0.25, 0.0008, 0.2),
    )
    land = tone(160, 0.12, 0.6, 0.001, 0.35, sweep_to=90)
    write("window", mix(rush, rise, pop, land, offsets=[0, 0.01, 0.075, 0.08]), peak=0.75)

    # Gate opening: a low swell that rises, a rushing tear, then a cold,
    # suspended chord (no third) left hanging.
    swell = tone(70, 1.4, 0.7, 0.6, 0.9, sweep_to=140, harmonics=(1.0, 0.6, 0.3, 0.15))
    tear = lowpass(noise(0.9, 0.55, 0.7, seed=21), 0.12)
    sus = [tone(f, 1.6, 0.18, 0.15, 0.9, harmonics=(1.0, 0.3, 0.1)) for f in (220.0, 329.63, 440.0, 493.88)]
    glint = tone(1760, 0.8, 0.06, 0.05, 0.8, harmonics=(1.0, 0.4))
    write("gate_open", mix(swell, tear, *sus, glint, offsets=[0, 0.5, 0.9, 0.95, 1.0, 1.05, 1.2]), peak=0.85)

    # Rank up: a drum hit, a rising run of fifths, then a wide bright chord.
    drum = mix(tone(110, 0.4, 1.0, 0.001, 0.45, sweep_to=55, harmonics=(1.0, 0.4)), lowpass(noise(0.08, 0.6, 0.3, seed=3), 0.3))
    run_notes = [392.0, 587.33, 783.99, 1174.66, 1567.98]
    run = [tone(f, 0.16, 0.38, 0.002, 0.5, harmonics=(1.0, 0.35, 0.1)) for f in run_notes]
    wide = [tone(f, 1.5, 0.2, 0.03, 0.85, harmonics=(1.0, 0.3, 0.1)) for f in (392.0, 493.88, 587.33, 783.99, 987.77, 1567.98)]
    write("rank_up", mix(drum, *run, *wide, offsets=[0, 0.12, 0.2, 0.28, 0.36, 0.44] + [0.52] * 6), peak=0.85)

    # Dungeon Penalty: two hard impacts, a metallic bell clang, and a deeper,
    # slower throb than the normal Penalty Zone, with phone-speaker overtones.
    hit1 = tone(80, 0.5, 1.0, 0.001, 0.5, sweep_to=35, harmonics=(1.0, 0.6, 0.3))
    hit2 = tone(70, 0.6, 1.0, 0.001, 0.5, sweep_to=30, harmonics=(1.0, 0.6, 0.3))
    crack2 = lowpass(noise(0.08, 1.0, 0.25, seed=13), 0.55)
    bell = mix(*[tone(f, 1.8, a, 0.001, 0.92) for f, a in ((311.0, 0.3), (740.0, 0.18), (1187.0, 0.12), (1653.0, 0.08))])
    deep = []
    n = int(RATE * 2.2)
    for i in range(n):
        t = i / RATE
        wobble = 0.55 + 0.45 * math.sin(2 * math.pi * 2.0 * t)
        s = (math.sin(2 * math.pi * 45 * t) + 0.7 * math.sin(2 * math.pi * 47.5 * t)
             + 0.6 * math.sin(2 * math.pi * 90 * t) + 0.5 * math.sin(2 * math.pi * 135 * t)
             + 0.35 * math.sin(2 * math.pi * 142 * t))
        deep.append(math.tanh(2.2 * s) * wobble * env(i, n, 0.03, 0.88) * 0.7)
    dungeon = mix(crack2, hit1, hit2, bell, deep, offsets=[0, 0, 0.32, 0.05, 0.15])
    write("dungeon_penalty", [math.tanh(2.6 * x) for x in dungeon], peak=0.98)


if __name__ == "__main__":
    main()
