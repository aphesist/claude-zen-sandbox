#!/usr/bin/env python3
"""Draw the pixel Claude (the one from Panacea's island chat, PanaceaClaudeCritter.qml)
as animated SVGs for Claude's Zen: one per mood, read by profile/chrome/userChrome.css.

    idle     a slow walk in place, a gentle bob, blinks
    reading  eyes up and drifting, "· · ·" filling in above its head
    acting   crab mode: claws up one after the other, quick sidesteps, a hop

    tools/make-critter.py            writes profile/chrome/critter-*.svg
"""
import os

BODY, EYE, DOT = "#d97757", "#141414", "rgba(255,255,255,0.85)"
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "profile", "chrome")


def put(row, col, ch):
    return row[:col] + ch + row[col + 1:]


def build(mood, f, blink):
    """-> (9 rows of 11 chars, hop in pixels). Same grid as the island's critter."""
    top = ["...........", "..........."]
    body = ["..XXXXXXX..", "..XXXXXXX..", "..XXXXXXX..", "XXXXXXXXXXX", "XXXXXXXXXXX", "..XXXXXXX.."]
    stand, step = "..X.X.X.X..", ".X.X.X.X..."
    legs, er, el, eR, hop = stand, 2, 3, 7, 0
    if mood == "idle":
        legs = step if (f // 2) % 2 else stand
        hop = 0.5 if (f // 2) % 2 else 0
    elif mood == "reading":
        er = 1                                            # eyes up, reading
        for i in range(f % 4):                            # · · · filling in
            top[0] = put(top[0], 4 + 2 * i, "D")
    elif mood == "acting":                                # crab: claws up, sidestep
        w = f % 4
        if w in (0, 3):                                   # left claw up
            body[1] = put(put(body[1], 0, "X"), 1, "X"); body[2] = put(put(body[2], 0, "X"), 1, "X")
            body[3] = put(put(body[3], 0, "."), 1, "."); body[4] = put(put(body[4], 0, "."), 1, ".")
            body[0] = put(body[0], 0, "X")                # the claw's tip
        if w in (1, 2):                                   # right claw up
            body[1] = put(put(body[1], 9, "X"), 10, "X"); body[2] = put(put(body[2], 9, "X"), 10, "X")
            body[3] = put(put(body[3], 9, "."), 10, "."); body[4] = put(put(body[4], 9, "."), 10, ".")
            body[0] = put(body[0], 10, "X")
        legs = step if f % 2 else "...X.X.X.X."           # legs scuttle sideways
        hop = 1 if w == 2 else 0
    if not blink:
        body[er] = put(put(body[er], el, "E"), eR, "E")
    return top + body + [legs], hop


def frame_svg(rows, hop):
    out = []
    for y, row in enumerate(rows):
        x = 0
        while x < len(row):                               # one rect per run of a colour
            ch = row[x]
            if ch == ".":
                x += 1
                continue
            end = x
            while end < len(row) and row[end] == ch:
                end += 1
            fill = {"X": BODY, "E": EYE, "D": DOT}[ch]
            out.append(f'<rect x="{x}" y="{y - hop + 1}" width="{end - x}" height="1" fill="{fill}"/>')
            x = end
    return "".join(out)


def svg(mood, frames, interval_ms, blink_frames=()):
    n = len(frames)
    dur = n * interval_ms / 1000
    groups = []
    for i, f in enumerate(frames):
        rows, hop = build(mood, f, i in blink_frames)
        vals = ";".join("1" if j == i else "0" for j in range(n))
        groups.append(f'<g opacity="{1 if i == 0 else 0}"><animate attributeName="opacity" values="{vals}" '
                      f'dur="{dur:g}s" calcMode="discrete" repeatCount="indefinite"/>{frame_svg(rows, hop)}</g>')
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 11 11" width="44" height="44" '
            'shape-rendering="crispEdges">\n<!-- written by tools/make-critter.py (claude-zen-sandbox) -->\n'
            + "\n".join(groups) + "\n</svg>\n")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    moods = {
        "idle": svg("idle", list(range(8)) * 2, 320, blink_frames=(11,)),
        "reading": svg("reading", list(range(8)), 300),
        "acting": svg("acting", list(range(8)), 140),
    }
    for name, body in moods.items():
        with open(os.path.join(OUT, f"critter-{name}.svg"), "w") as fh:
            fh.write(body)
        print("wrote", f"profile/chrome/critter-{name}.svg")
