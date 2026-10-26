#!/usr/bin/env python3
import glob
import json
import math
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
TRAITS = os.path.join(ROOT, "avatar-traits.json")
TRAIT_PARTS = os.path.join(ROOT, "avatar-traits", "*.json")
PARTIES = os.path.join(ROOT, "party-palette.json")
OUT = os.path.join(ROOT, "animations", "avatars")
ASSETS = os.path.join(ROOT, "..", "FiscalKit", "Sources", "FiscalResource", "Assets")
RIG_ASSET = os.path.join(ASSETS, "fiscal-portrait-rig.json")
TRAITS_ASSET = os.path.join(ASSETS, "fiscal-portrait-traits.json")
SEAL_ASSET = os.path.join(ASSETS, "fiscal-party-seal.json")
PREVIEW = os.path.join(ROOT, "avatars-preview.html")

SIDE, FPS = 200, 30
CX = SIDE / 2
PIVOT = (CX, 146)
ZOOM = 112
GAP = 2
IDLE = 150

INK = "#2A2320"
PAPER = "#FFFFFF"
SHIRT = "#F6F1E8"
LIPS = "#8E4A43"
MOUTH = "#5A2723"
BLUSH = "#F0907C"
LENS = "#2B2624"

FACES = {
    "oval": {"w": 72, "top": 50, "chin": 140, "jaw": 0.45},
    "round": {"w": 78, "top": 52, "chin": 137, "jaw": 0.7},
    "long": {"w": 68, "top": 47, "chin": 142, "jaw": 0.4},
    "square": {"w": 76, "top": 50, "chin": 139, "jaw": 0.95},
}
BROWS = {"light": 2.6, "medium": 3.4, "strong": 4.3}
HAIR_FRONT = ("short", "thick", "swept", "receding", "bob", "long", "wavy")
HAIR_BACK = ("bob", "long", "wavy")
FIELDS = ("party", "skin", "face", "hair", "hairColor", "brows", "beard", "beardColor", "glasses")

SEGMENTS = [("idle", IDLE), ("wave", 72), ("thumbsUp", 60), ("nodYes", 48), ("shakeNo", 48), ("smile", 54),
            ("celebrate", 72), ("sad", 60), ("lookAround", 66), ("tilt", 54), ("browRaise", 42),
            ("doubleBlink", 30), ("settle", 72), ("think", 84)]
THINK_HOLD = 14
POSES = {"wave": 18, "thumbsUp": 24, "nodYes": 12, "shakeNo": 20, "smile": 27, "celebrate": 18, "sad": 30,
         "think": 40}


def layout():
    starts, frame = {}, 0
    for name, duration in SEGMENTS:
        starts[name] = (frame, duration)
        frame += duration + GAP
    return starts, frame - GAP


TIMELINE, END = layout()


# --- Colors -----------------------------------------------------------------------------------


def hex_rgb(value):
    value = value.lstrip("#")
    return [int(value[i:i + 2], 16) / 255 for i in (0, 2, 4)]


def mix(first, second, amount):
    a, b = hex_rgb(first), hex_rgb(second)
    return "#" + "".join("%02X" % round((x + (y - x) * amount) * 255) for x, y in zip(a, b))


def color(value):
    return [round(v, 4) for v in hex_rgb(value)] + [1]


def luminance(value):
    r, g, b = hex_rgb(value)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def brow_color(hair):
    if luminance(hair) > 0.55:
        return mix(hair, INK, 0.38)
    return mix(hair, INK, 0.15)


REFERENCE = {"skin": "#E2AE8A", "hair": "#1F1A17", "beard": "#1F1A17", "brow": brow_color("#1F1A17"),
             "primary": "#2A7069", "secondary": "#62ABA2", "ink": INK, "paper": PAPER}


def resolve(token, tones):
    steps = token.split(">")
    value = tones[steps[0]]
    for step in steps[1:]:
        target, amount = step.split("@")
        value = mix(value, tones[target], float(amount))
    return value


# --- Lottie primitives ------------------------------------------------------------------------


def const(value):
    return {"a": 0, "k": value}


def smooth(points, closed=True, tension=1.0):
    count = len(points)
    vertices, ins, outs = [], [], []
    for index, point in enumerate(points):
        x, y = point[0], point[1]
        corner = len(point) > 2 and point[2] == "c"
        vertices.append([round(x, 2), round(y, 2)])
        if corner or (not closed and index in (0, count - 1)):
            ins.append([0, 0])
            outs.append([0, 0])
            continue
        before, after = points[(index - 1) % count], points[(index + 1) % count]
        dx, dy = (after[0] - before[0]) / 6 * tension, (after[1] - before[1]) / 6 * tension
        ins.append([round(-dx, 2), round(-dy, 2)])
        outs.append([round(dx, 2), round(dy, 2)])
    return {"c": closed, "v": vertices, "i": ins, "o": outs}


def path(points, closed=True, tension=1.0):
    return {"ty": "sh", "d": 1, "ks": const(smooth(points, closed, tension))}


def ellipse(center, size):
    return {"ty": "el", "d": 1, "s": const(list(size)), "p": const(list(center))}


def rect(center, size, radius):
    return {"ty": "rc", "d": 1, "s": const(list(size)), "p": const(list(center)), "r": const(radius)}


def fill(tone, opacity=100):
    value = tone if tone.startswith("#") else resolve(tone, REFERENCE)
    item = {"ty": "fl", "c": const(color(value)), "o": const(opacity), "r": 1}
    if not tone.startswith("#"):
        item["nm"] = tone
    return item


def stroke(tone, width, opacity=100):
    item = fill(tone, opacity)
    item.update({"ty": "st", "w": const(width), "lc": 2, "lj": 2})
    item.pop("r")
    return item


def gradient(first, second, start, end):
    a, b = hex_rgb(resolve(first, REFERENCE)), hex_rgb(resolve(second, REFERENCE))
    return {"ty": "gf", "nm": first + "," + second, "t": 1, "o": const(100), "r": 1, "s": const(list(start)),
            "e": const(list(end)), "g": {"p": 2, "k": const([0] + a + [1] + b)}}


def shade(start, end, top, bottom):
    return {"ty": "gf", "t": 1, "o": const(100), "r": 1, "s": const(list(start)), "e": const(list(end)),
            "g": {"p": 2, "k": const([0, 1, 1, 1, 1, 0, 0, 0, 0, top, 1, bottom])}}


def transform(position=(0, 0), anchor=(0, 0), rotation=0):
    return {"ty": "tr", "p": position if isinstance(position, dict) else const(list(position)),
            "a": const(list(anchor)), "s": const([100, 100]),
            "r": rotation if isinstance(rotation, dict) else const(rotation), "o": const(100)}


def group(name, items, position=(0, 0), rotation=0):
    return {"ty": "gr", "nm": name, "it": items + [transform(position, rotation=rotation)]}


# --- Tracks -----------------------------------------------------------------------------------


def fits(values, first, last, tolerance):
    span = last - first
    for middle in range(first + 1, last):
        weight = (middle - first) / span
        for a, b, m in zip(values[first], values[last], values[middle]):
            if abs(a + (b - a) * weight - m) > tolerance:
                return False
    return True


def simplify(values, tolerance, window=120):
    keys, index, count = [0], 0, len(values)
    while index < count - 1:
        last = index + 1
        while last + 1 < count and last + 1 - index <= window and fits(values, index, last + 1, tolerance):
            last += 1
        keys.append(last)
        index = last
    return keys


def track(function, tolerance, first=0, last=None):
    last = END if last is None else last
    frames = list(range(first, last + 1))
    values = []
    for frame in frames:
        value = function(frame)
        values.append([round(v, 3) for v in (value if isinstance(value, (list, tuple)) else [value])])
    if all(value == values[0] for value in values):
        return const(values[0] if len(values[0]) > 1 else values[0][0])
    keys = []
    picks = simplify(values, tolerance)
    for position, pick in enumerate(picks):
        key = {"t": frames[pick], "s": [round(v, 2) for v in values[pick]]}
        if position < len(picks) - 1:
            size = len(values[pick])
            key.update({"i": {"x": [1] * size, "y": [1] * size}, "o": {"x": [0] * size, "y": [0] * size}})
        keys.append(key)
    return {"a": 1, "k": keys}


def shape_track(function, tolerance, first=0, last=None):
    last = END if last is None else last
    frames = list(range(first, last + 1))
    shapes = [function(frame) for frame in frames]
    values = [[c for vertex in shape["v"] for c in vertex] + [c for tangent in shape["i"] + shape["o"] for c in tangent]
              for shape in shapes]
    if all(value == values[0] for value in values):
        return const(shapes[0])
    keys = []
    picks = simplify(values, tolerance)
    for position, pick in enumerate(picks):
        key = {"t": frames[pick], "s": [shapes[pick]]}
        if position < len(picks) - 1:
            key.update({"i": {"x": [1], "y": [1]}, "o": {"x": [0], "y": [0]}})
        keys.append(key)
    return {"a": 1, "k": keys}


# --- Motion -----------------------------------------------------------------------------------


def clamp(value, low=0.0, high=1.0):
    return max(low, min(high, value))


def ease(value):
    value = clamp(value)
    return value * value * (3 - 2 * value)


def back(value):
    value = clamp(value)
    lift = 1.70158
    value -= 1
    return 1 + (lift + 1) * value ** 3 + lift * value ** 2


def envelope(u, duration, rise, fall):
    return ease(u / rise) * ease((duration - u) / fall)


def wave(frame, period, phase=0.0):
    return math.sin(2 * math.pi * (frame / period + phase))


def locate(frame):
    for name, (start, duration) in TIMELINE.items():
        if start <= frame <= start + duration:
            return name, frame - start, duration
    return "idle", 0, IDLE


CHANNELS = ("breath", "headX", "headY", "roll", "turn", "smile", "squint", "blink", "eyeX", "eyeY", "browY",
            "browLeftY", "browRightY", "browLeftTurn", "browRightTurn", "frown", "flat", "side", "open", "blush",
            "bodyY", "sway")


def idle_pose(u):
    pose = dict.fromkeys(CHANNELS, 0.0)
    pose["breath"] = -1.3 * (1 - math.cos(2 * math.pi * u / 75)) / 2
    pose["headY"] = 2.4 * math.sin(math.pi * (u - 92) / 28) if 92 <= u <= 120 else 0.0
    pose["smile"] = math.sin(math.pi * (u - 84) / 44) ** 2 if 84 <= u <= 128 else 0.0
    pose["turn"] = 1.8 * wave(u, IDLE)
    pose["roll"] = 1.6 * wave(u, IDLE, 0.08)
    pose["sway"] = 0.8 * wave(u, IDLE, 0.2)
    pose["blink"] = blink(u, ((50, 100), (53, 8), (57, 100), (134, 100), (137, 8), (141, 100)))
    return pose


def blink(u, keys):
    if u <= keys[0][0] or u >= keys[-1][0]:
        return 100.0
    for (a, va), (b, vb) in zip(keys, keys[1:]):
        if a <= u <= b:
            return va + (vb - va) * ease((u - a) / (b - a)) if b > a else vb
    return 100.0


def wave_pose(u, d, pose):
    e = envelope(u, d, 10, 12)
    pose["roll"] += 3 * e
    pose["smile"] += 1.0 * e
    pose["blush"] += 10 * e
    pose["browY"] -= 1.5 * e
    pose["turn"] += 1.2 * e


def thumbs_pose(u, d, pose):
    e = envelope(u, d, 10, 12)
    pose["headY"] += 1.8 * math.sin(math.pi * (u - 12) / 16) ** 2 if 12 <= u <= 28 else 0
    pose["smile"] += 1.0 * e
    pose["squint"] += 0.35 * e
    pose["blush"] += 10 * e
    pose["browY"] -= 1.2 * e


def nod_pose(u, d, pose):
    dip = math.sin(math.pi * u / 24) ** 2
    pose["headY"] += 4.2 * dip
    pose["eyeY"] += 1.2 * dip
    pose["smile"] += 0.35 * envelope(u, d, 8, 10)


def shake_pose(u, d, pose):
    swing = math.sin(2 * math.pi * u / 16) * envelope(u, d, 6, 10)
    pose["turn"] += 5.5 * swing
    pose["headX"] += 1.2 * swing
    pose["flat"] += envelope(u, d, 6, 10)


def smile_pose(u, d, pose):
    e = envelope(u, d, 10, 14)
    pose["smile"] += 1.4 * e
    pose["squint"] += 0.6 * e
    pose["blush"] += 14 * e
    pose["roll"] += 2.5 * e
    pose["browY"] -= 1.2 * e


def celebrate_pose(u, d, pose):
    e = envelope(u, d, 8, 12)
    hop = -3.2 * abs(math.sin(math.pi * u / 8)) * e
    pose["bodyY"] += hop
    pose["headY"] += hop * 1.1
    pose["open"] += envelope(u, d, 6, 10)
    pose["squint"] += 0.7 * e
    pose["smile"] += 1.0 * e
    pose["blush"] += 16 * e
    pose["browY"] -= 2.2 * e


def sad_pose(u, d, pose):
    e = envelope(u, d, 12, 14)
    pose["headY"] += 2.2 * e
    pose["roll"] -= 2 * e
    pose["browLeftTurn"] -= 11 * e
    pose["browRightTurn"] += 11 * e
    pose["browY"] -= 0.8 * e
    pose["frown"] += e
    pose["eyeY"] += 1.4 * e
    pose["blush"] -= 12 * e
    pose["squint"] += 0.15 * e


def think_pose(u, d, pose):
    p = ease(u / THINK_HOLD)
    loop = (u - THINK_HOLD) / (d - THINK_HOLD) if u >= THINK_HOLD else 0.0
    drift = math.sin(2 * math.pi * loop)
    pose["roll"] -= 4 * p
    pose["headY"] += 1.0 * p
    pose["eyeX"] += -2.6 * p + 0.8 * drift
    pose["eyeY"] -= 2.4 * p
    pose["browRightY"] -= 2.8 * p + 0.5 * drift
    pose["browLeftY"] += 0.6 * p
    pose["side"] += p
    pose["turn"] -= 1.2 * p
    pose["blink"] = blink(u, ((50, 100), (53, 8), (57, 100)))


def look_pose(u, d, pose):
    e = envelope(u, d, 8, 10)
    side = math.sin(2 * math.pi * u / d) * e
    pose["eyeX"] += 3.0 * side
    pose["turn"] += 2.4 * side
    pose["roll"] += 0.8 * side


def tilt_pose(u, d, pose):
    e = envelope(u, d, 14, 16)
    pose["roll"] += 5.5 * e
    pose["headX"] += 1.0 * e
    pose["browLeftY"] -= 0.8 * e


def brow_pose(u, d, pose):
    lift = math.sin(math.pi * u / d) ** 2
    pose["browY"] -= 3.0 * lift
    pose["eyeY"] -= 0.4 * lift


def double_blink_pose(u, d, pose):
    pose["blink"] = blink(u, ((3, 100), (6, 8), (10, 100), (14, 100), (17, 8), (21, 100)))


def settle_pose(u, d, pose):
    breath = math.sin(math.pi * u / d) ** 2
    pose["bodyY"] -= 2.6 * breath
    pose["headY"] -= 2.8 * breath
    pose["eyeY"] -= 0.3 * breath


EXPRESSIONS = {"wave": wave_pose, "thumbsUp": thumbs_pose, "nodYes": nod_pose, "shakeNo": shake_pose,
               "smile": smile_pose, "celebrate": celebrate_pose, "sad": sad_pose, "think": think_pose,
               "lookAround": look_pose, "tilt": tilt_pose, "browRaise": brow_pose, "doubleBlink": double_blink_pose,
               "settle": settle_pose}


def compute(frame):
    name, u, duration = locate(frame)
    if name == "idle":
        return idle_pose(u)
    pose = idle_pose(0)
    EXPRESSIONS[name](u, duration, pose)
    return pose


POSE = [compute(frame) for frame in range(END + 1)]


def channel(name, scale=1.0, offset=0.0):
    return lambda frame: offset + POSE[frame][name] * scale


# --- Arms -------------------------------------------------------------------------------------


ARMS = {
    "waveArm": {"segment": "wave", "side": 1, "hand": "open", "pivot": (157, 180), "turn": 6, "size": 112},
    "thumbArm": {"segment": "thumbsUp", "side": 1, "hand": "thumb", "pivot": (150, 200), "turn": -8, "size": 128},
    "cheerLeft": {"segment": "celebrate", "side": -1, "hand": "fist", "pivot": (52, 168), "turn": 10},
    "cheerRight": {"segment": "celebrate", "side": 1, "hand": "fist", "pivot": (148, 168), "turn": 10},
    "thinkArm": {"segment": "think", "side": 1, "hand": "fist", "pivot": (132, 210), "turn": -26, "size": 108},
}
REACH = 60
DROP = 130


def arm_motion(arm, u, d):
    segment = arm["segment"]
    if segment == "think":
        rise = 1 - ease(u / THINK_HOLD)
        loop = (u - THINK_HOLD) / (d - THINK_HOLD) if u >= THINK_HOLD else 0.0
        return 0.0, DROP * rise, 1.5 * math.sin(4 * math.pi * loop)
    enter = 10 if segment != "wave" else 12
    leave = 12 if segment != "wave" else 14
    drop = DROP * (1 - back(u / enter)) if u < enter else DROP * ease((u - (d - leave)) / leave)
    hold = envelope(u, d, enter, leave)
    if segment == "wave":
        return 0.0, drop, 13 * math.sin(2 * math.pi * (u - enter) / 12) * hold
    if segment == "thumbsUp":
        return 0.0, drop - 2 * math.sin(2 * math.pi * (u - enter) / 19) * hold, 3 * math.sin(
            2 * math.pi * (u - enter) / 19) * hold
    pump = abs(math.sin(math.pi * (u - enter) / 8)) * hold
    return 0.0, drop - 6 * pump, 7 * pump


def hand_shapes(kind, side):
    def x(value):
        return value * side

    if kind == "open":
        parts = [rect((0, -13), (22, 22), 8)]
        parts += [rect((x(cx), cy), (5.6, 15), 2.8) for cx, cy in ((7.2, -27), (2.4, -30), (-2.4, -30), (-7.2, -27.5))]
        thumb = group("thumb", [rect((0, 0), (6, 13), 3), fill("skin")], position=(x(-12.5), -14), rotation=x(-35))
        creases = []
    elif kind == "thumb":
        parts = [rect((0, -12), (22, 20), 7), rect((x(-6), -27), (8.5, 17), 4.2)]
        thumb = None
        creases = [path([(x(-2), -15), (x(9), -15)], closed=False), path([(x(-2), -9), (x(9), -9)], closed=False)]
    else:
        parts = [rect((0, -12), (24, 21), 8)]
        thumb = group("thumb", [rect((x(-4), -6.5), (14, 6), 3), fill("skin>ink@0.04")])
        creases = [path([(x(cx), -21), (x(cx), -15)], closed=False) for cx in (-5, 0, 5)]
    items = []
    if creases:
        items.append(group("creases", creases + [stroke("skin>ink@0.22", 1.2)]))
    if thumb:
        items.append(thumb)
    items.append(group("hand", [dict(part) for part in parts] + [fill("skin")]))
    items.append(group("handShade", [dict(part) for part in parts] + [fill("skin>ink@0.28", 55)],
                       position=(x(1.4), 1.6)))
    return items


def arm_layer(builder, name, arm):
    start, duration = TIMELINE[arm["segment"]]
    side = arm["side"]
    sleeve = [group("cuff", [rect((0, 3.5), (24.5, 7), 3), fill(SHIRT)]),
              group("sleeve", [rect((0, 48), (26, 92), 12), fill("primary>ink@0.18"), stroke(PAPER, 2, 18)])]
    shapes = hand_shapes(arm["hand"], side) + sleeve

    def motion(frame):
        return arm_motion(arm, frame - start, duration)

    px, py = arm["pivot"]
    position = track(lambda f: [px + motion(f)[0], py + motion(f)[1], 0], 0.08, start, start + duration)
    rotation = track(lambda f: side * (arm["turn"] + motion(f)[2]), 0.1, start, start + duration)
    size = arm.get("size", 100)
    builder.add(name, shapes, anchor=(0, REACH), position=position, rotation=rotation, parent="rig",
                scale=const([size, size, 100]), span=(start, start + duration + 1))


# --- Parts ------------------------------------------------------------------------------------


def face_points(face):
    w, top, chin, jaw = face["w"], face["top"], face["chin"], face["jaw"]
    jx, cw = w * (0.22 + 0.17 * jaw), 3 + 9 * jaw
    right = [(CX + 0.40 * w, top + 8), (CX + 0.5 * w, 90), (CX + 0.47 * w, 110), (CX + jx, chin - 13), (CX + cw, chin - 0.5)]
    left = [(2 * CX - x, y) for x, y in reversed(right)]
    return [(CX, top)] + right + left


def hair_front(style, face):
    w, top = face["w"], face["top"]
    h = w / 2
    if style == "receding":
        side = [(CX - h - 1.5, 106, "c"), (CX - h - 3, 88), (CX - h, 72), (CX - h + 7, 63),
                (CX - h + 6, 70), (CX - h + 3.5, 86), (CX - h + 3.5, 106, "c")]
        return [side, [(2 * CX - x, y, *rest) for x, y, *rest in side]]
    if style in ("short", "thick", "swept"):
        lift = {"short": 6, "thick": 10, "swept": 15}[style]
        line = {"short": 66, "thick": 68, "swept": 62}[style]
        outer = [(CX - h - 1, 96, "c"), (CX - h - 3, 74), (CX - h * 0.78, 54), (CX - h * 0.3, top - lift + 1),
                 (CX + h * 0.25, top - lift - (4 if style == "swept" else 0)), (CX + h * 0.8, top - lift / 3 + 6),
                 (CX + h + 3, 72), (CX + h + 1, 96, "c")]
        inner = [(CX + h - 3, 80), (CX + h * 0.62, line), (CX - h * 0.05, line - 3),
                 (CX - h * 0.3, line - 6, "c"), (CX - h * 0.62, line + 1), (CX - h + 3, 82)]
        return [outer + inner]
    if style in ("bob", "long", "wavy"):
        fall = {"bob": 124, "long": 132, "wavy": 132}[style]
        swell = {"bob": 7, "long": 5, "wavy": 9}[style]
        outer = [(CX - h - 2, fall, "c"), (CX - h - swell, 96), (CX - h * 0.92, 60), (CX - h * 0.4, top - 9),
                 (CX + h * 0.3, top - 10), (CX + h * 0.95, 58), (CX + h + swell, 96), (CX + h + 2, fall, "c")]
        if style == "long":
            inner = [(CX + h - 5, 108), (CX + h * 0.72, 72), (CX + h * 0.2, top + 8), (CX, top + 12, "c"),
                     (CX - h * 0.2, top + 8), (CX - h * 0.72, 72), (CX - h + 5, 108)]
        else:
            inner = [(CX + h - 5, 106), (CX + h * 0.72, 74), (CX + h * 0.25, top + 13), (CX - h * 0.25, top + 12, "c"),
                     (CX - h * 0.62, 70), (CX - h + 5, 104)]
        return [outer + inner]
    return []


def thinning(face):
    w, top = face["w"], face["top"]
    h = w / 2
    return [(CX - h + 3, 72), (CX - h * 0.62, top + 1), (CX, top - 3), (CX + h * 0.62, top + 1), (CX + h - 3, 72),
            (CX + h * 0.55, 62), (CX, top + 7), (CX - h * 0.55, 62)]


def hair_back(style, face):
    w, top = face["w"], face["top"]
    h = w / 2
    if style == "bob":
        return [(CX, top - 8), (CX + h + 9, 64), (CX + h + 12, 112), (CX + h + 6, 146), (CX + h - 8, 150),
                (CX - h + 8, 150), (CX - h - 6, 146), (CX - h - 12, 112), (CX - h - 9, 64)]
    if style == "long":
        return [(CX, top - 8), (CX + h + 8, 66), (CX + h + 10, 140), (CX + h + 6, 196, "c"),
                (CX - h - 6, 196, "c"), (CX - h - 10, 140), (CX - h - 8, 66)]
    right = [(CX + h + 12, 66), (CX + h + 18, 104), (CX + h + 12, 132), (CX + h + 20, 160), (CX + h + 12, 198, "c")]
    left = [(2 * CX - x, y, *rest) for x, y, *rest in reversed(right)]
    return [(CX, top - 10)] + right + left


def beard_shape(face):
    w, chin = face["w"], face["chin"]
    h, jx = w / 2, w * (0.22 + 0.17 * face["jaw"])
    outer = [(CX + h - 1, 96, "c"), (CX + h * 0.98, 112), (CX + jx + 2, chin - 10), (CX, chin + 5),
             (CX - jx - 2, chin - 10), (CX - h * 0.98, 112), (CX - h + 1, 96, "c")]
    inner = [(CX - h * 0.8, 102), (CX - h * 0.5, 116), (CX - 12, 128), (CX, 130), (CX + 12, 128), (CX + h * 0.5, 116),
             (CX + h * 0.8, 102)]
    return outer + inner


def mustache():
    return [(CX - 14, 124, "c"), (CX - 9, 116), (CX, 115), (CX + 9, 116), (CX + 14, 124, "c"), (CX + 9, 119.5),
            (CX, 119), (CX - 9, 119.5)]


MOUTHS = {
    "rest": [(-9, 121), (0, 125.6), (9, 121)],
    "frown": [(-8, 125), (0, 121.4), (8, 125)],
    "flat": [(-7, 123.2), (0, 123.8), (7, 123.2)],
    "side": [(-2, 124), (4.5, 123.6), (10, 121.8)],
}


def mouth_shape(frame):
    pose = POSE[frame]
    points = []
    for index, (x, y) in enumerate(MOUTHS["rest"]):
        for key in ("frown", "flat", "side"):
            tx, ty = MOUTHS[key][index]
            x += (tx - MOUTHS["rest"][index][0]) * pose[key]
            y += (ty - MOUTHS["rest"][index][1]) * pose[key]
        points.append((CX + x, y))
    return smooth(points, closed=False)


class Builder:
    def __init__(self):
        self.layers = []
        self.index = {}

    def ind(self, name):
        if name not in self.index:
            self.index[name] = len(self.index) + 1
        return self.index[name]

    def add(self, name, shapes, anchor=(0, 0), position=None, rotation=None, scale=None, opacity=None, parent=None,
            fx=None, span=None, null=False, ind=None):
        item = {"ddd": 0, "ind": ind or self.ind(name + "#" + str(len(self.layers))), "ty": 3 if null else 4,
                "nm": name, "sr": 1, "ao": 0, "ip": span[0] if span else 0, "op": span[1] if span else END + 1,
                "st": 0, "bm": 0,
                "ks": {"o": opacity or const(100), "r": rotation or const(0),
                       "p": position or const([anchor[0], anchor[1], 0]), "a": const([anchor[0], anchor[1], 0]),
                       "s": scale or const([100, 100, 100])}}
        if not null:
            item["shapes"] = shapes
        if parent:
            item["parent"] = self.ind(parent)
        if fx:
            item["fx"] = fx
        self.layers.append(item)
        return item

    def null(self, name, **options):
        return self.add(name, None, null=True, ind=self.ind(name), **options)


def build_rig():
    b = Builder()
    for name, arm in ARMS.items():
        arm_layer(b, name, arm)

    def turn(depth, lift=0.0):
        return track(lambda f: [POSE[f]["turn"] * depth, -POSE[f]["smile"] * lift, 0], 0.06)

    b.add("glasses", [group("frames", [rect((CX - 14.5, 96), (20, 14), 5), rect((CX + 14.5, 96), (20, 14), 5),
                                       path([(CX - 4.5, 95), (CX, 93.6), (CX + 4.5, 95)], closed=False),
                                       stroke(LENS, 2.4)]),
                      group("lens", [rect((CX - 14.5, 96), (20, 14), 5), rect((CX + 14.5, 96), (20, 14), 5),
                                     fill(PAPER, 16)])],
          parent="glassesTurn", fx={"glasses": "rectangle"})
    for side, key in ((-1, "browLeft"), (1, "browRight")):
        for weight, width in BROWS.items():
            points = [(-7 * side, 1.5), (-side, -1.4), (7 * side, 0.2)]
            b.add("brow", [group("brow", [path(points, closed=False), stroke("brow", width)])], parent=key,
                  fx={"brows": weight})
    for style in HAIR_FRONT:
        for face_name, face in FACES.items():
            shapes = [group("hairFront", [path(piece) for piece in hair_front(style, face)] + [fill("hair")])]
            if style == "receding":
                shapes.append(group("thinning", [path(thinning(face)), fill("hair", 38)]))
            else:
                shapes.insert(0, group("shine", [ellipse((CX + face["w"] * 0.2, face["top"] + 3), (13, 4)),
                                                 fill("hair>paper@0.18", 30)]))
            b.add("hairFront", shapes, parent="hairTurn", fx={"hair": style, "face": face_name})
    eyes = []
    for x in (CX - 14.5, CX + 14.5):
        eyes += [group("shine", [ellipse((x + 1.6, 94.2), (2.6, 2.6)), fill(PAPER, 90)]),
                 group("eye", [ellipse((x, 96), (7.4, 9.4)), fill(INK)])]
    b.add("eyes", eyes, anchor=(CX, 96),
          position=track(lambda f: [CX + POSE[f]["turn"] + POSE[f]["eyeX"], 96 + POSE[f]["eyeY"], 0], 0.06),
          scale=track(lambda f: [100, POSE[f]["blink"] * (1 - 0.55 * POSE[f]["squint"]), 100], 0.4), parent="head")
    open_mouth = [(CX - 10, 120, "c"), (CX + 10, 120, "c"), (CX + 7, 127), (CX, 130.5), (CX - 7, 127)]
    b.add("mouthOpen", [group("teeth", [rect((CX, 121.6), (13, 2.8), 1.4), fill(PAPER, 92)]),
                        group("mouth", [path(open_mouth), fill(MOUTH), stroke(LIPS, 2)])],
          anchor=(CX, 120), position=track(lambda f: [CX + POSE[f]["turn"], 120, 0], 0.06),
          scale=track(lambda f: [100, 40 + 60 * POSE[f]["open"], 100], 0.4),
          opacity=track(lambda f: 100 * POSE[f]["open"], 0.5), parent="head")
    b.add("mouth", [group("mouth", [{"ty": "sh", "d": 1, "ks": shape_track(mouth_shape, 0.04)}, stroke(LIPS, 3.0)])],
          anchor=(CX, 123), position=track(lambda f: [CX + POSE[f]["turn"], 123, 0], 0.06),
          scale=track(lambda f: [100 + POSE[f]["smile"] * 16, 100 + POSE[f]["smile"] * 22, 100], 0.3),
          opacity=track(lambda f: 100 * (1 - POSE[f]["open"]), 0.5), parent="head")
    for style, tone in (("full", "beard"), ("short", "beard>skin@0.42")):
        for face_name, face in FACES.items():
            b.add("beard", [group("mustache", [path(mustache()), fill(tone)]),
                            group("beard", [path(beard_shape(face)), fill(tone)])],
                  parent="beardTurn", fx={"beard": style, "face": face_name})
    b.add("nose", [group("nose", [path([(CX - 4, 110), (CX, 112.6), (CX + 4, 110)], closed=False),
                                  stroke("skin>ink@0.32", 2.2, 80)])], parent="noseTurn")
    cheeks = track(lambda f: clamp(22 + POSE[f]["smile"] * 12 + POSE[f]["blush"], 0, 100), 0.5)
    for face_name, face in FACES.items():
        w = face["w"]
        b.add("cheeks", [group("cheeks", [ellipse((CX - w * 0.33, 112), (12, 7)), ellipse((CX + w * 0.33, 112), (12, 7)),
                                          fill(BLUSH)])], opacity=cheeks, parent="cheekTurn", fx={"face": face_name})
    for face_name, face in FACES.items():
        w = face["w"]
        b.add("face", [group("face", [path(face_points(face)), fill("skin")]),
                       group("ears", [ellipse((CX - w / 2 + 1, 100), (13, 19)), ellipse((CX + w / 2 - 1, 100), (13, 19)),
                                      fill("skin>ink@0.06")]),
                       group("earInner", [ellipse((CX - w / 2 + 1, 101), (6, 10)),
                                          ellipse((CX + w / 2 - 1, 101), (6, 10)), fill("skin>ink@0.18", 70)])],
              parent="head", fx={"face": face_name})
    b.add("neck", [group("neck", [rect((CX, 136), (30, 36), 12), fill("skin>ink@0.12")]),
                   group("shadow", [ellipse((CX, 128), (34, 12)), fill("skin>ink@0.2", 45)])],
          anchor=(CX, 150), position=track(lambda f: [CX, 150 + POSE[f]["breath"] * 0.7 + POSE[f]["bodyY"] * 0.9, 0],
                                           0.05), parent="rig")
    b.add("body", body_shapes(), anchor=(CX, 200),
          position=track(lambda f: [CX, 200 + POSE[f]["breath"] * 0.5 + POSE[f]["bodyY"], 0], 0.05), parent="rig")
    for style in HAIR_BACK:
        for face_name, face in FACES.items():
            b.add("hairBack", [group("hairBack", [path(hair_back(style, face)), fill("hair>ink@0.12")])],
                  parent="hairSway", fx={"hair": style, "face": face_name})
    start, duration = TIMELINE["celebrate"]
    b.add("confetti", confetti(start, duration), span=(start, start + duration + 1))
    b.add("halo", [group("halo", [ellipse((0, 0), (150, 150)), fill(PAPER, 14)])], position=const([CX, 98, 0]),
          scale=track(lambda f: [100 - POSE[f]["breath"] * 1.2, 100 - POSE[f]["breath"] * 1.2, 100], 0.05))
    b.add("gloss", [group("gloss", [rect((CX, CX), (SIDE, SIDE), 0), shade((CX, 0), (CX, SIDE), 0.16, 0.0)])])
    b.add("backdrop", [group("backdrop", [rect((CX, CX), (SIDE, SIDE), 0),
                                          gradient("primary", "secondary", (0, 0), (SIDE, SIDE))])])
    b.null("rig", position=const([CX, 124, 0]), anchor=(CX, 120), scale=const([ZOOM, ZOOM, 100]))
    b.null("head", anchor=PIVOT, parent="rig",
           position=track(lambda f: [PIVOT[0] + POSE[f]["headX"], PIVOT[1] + POSE[f]["breath"] + POSE[f]["headY"], 0],
                          0.05),
           rotation=track(lambda f: POSE[f]["roll"], 0.06))
    b.null("hairSway", anchor=(CX, 60), position=const([CX, 60, 0]), parent="head",
           rotation=track(lambda f: POSE[f]["sway"], 0.06))
    for name, depth, lift in (("hairTurn", 0.35, 0), ("beardTurn", 0.6, 0), ("cheekTurn", 0.9, 1.0),
                              ("glassesTurn", 1.05, 0), ("noseTurn", 1.25, 0)):
        b.null(name, position=turn(depth, lift), parent="head")
    for side, key in ((-1, "browLeft"), (1, "browRight")):
        lift = key + "Y"
        b.null(key, parent="head",
               position=track(lambda f, s=side, k=lift: [CX + s * 14.5 + POSE[f]["turn"] + POSE[f]["eyeX"] * 0.3,
                                                       85 - POSE[f]["smile"] * 1.6 + POSE[f]["browY"] + POSE[f][k], 0],
                              0.06),
               rotation=track(lambda f, k=key + "Turn": POSE[f][k], 0.1))
    markers = [{"tm": start, "cm": name, "dr": duration} for name, (start, duration) in TIMELINE.items()]
    think_start, think_duration = TIMELINE["think"]
    markers.append({"tm": think_start + THINK_HOLD, "cm": "thinkLoop", "dr": think_duration - THINK_HOLD})
    markers += [{"tm": TIMELINE[name][0] + frame, "cm": name + "Pose", "dr": 0} for name, frame in POSES.items()]
    return {"v": "5.9.0", "fr": FPS, "ip": 0, "op": END, "w": SIDE, "h": SIDE, "nm": "portrait-rig", "ddd": 0,
            "assets": [], "markers": markers, "layers": b.layers}


def body_shapes():
    shoulders = [(26, 206, "c"), (28, 180), (40, 162), (72, 151), (128, 151), (160, 162), (172, 180), (174, 206, "c")]
    shirt = [(84, 150, "c"), (116, 150, "c"), (100, 178, "c")]
    left_lapel = [(84, 150, "c"), (100, 178, "c"), (92, 196, "c"), (72, 156, "c")]
    right_lapel = [(2 * CX - x, y, "c") for x, y, _ in left_lapel]
    collar_left = [(85, 149, "c"), (99, 160, "c"), (92, 164, "c")]
    collar_right = [(2 * CX - x, y, "c") for x, y, _ in collar_left]
    seam = [(CX, 178, "c"), (CX, 206, "c")]
    return [
        group("collar", [path(collar_left), path(collar_right), fill(PAPER)]),
        group("seam", [path(seam, closed=False), stroke("primary>ink@0.18>ink@0.3", 1.6, 60)]),
        group("piping", [path([(72, 156, "c"), (92, 196, "c")], closed=False),
                         path([(128, 156, "c"), (108, 196, "c")], closed=False), stroke("secondary", 2.4)]),
        group("lapels", [path(left_lapel), path(right_lapel), fill("primary>paper@0.12")]),
        group("shirt", [path(shirt), fill(SHIRT)]),
        group("jacket", [path(shoulders), fill("primary>ink@0.18"), stroke(PAPER, 2.2, 22)]),
    ]


def confetti(start, duration):
    pieces = []
    tones = ("primary", "secondary", "paper", "secondary>paper@0.4")
    for index in range(16):
        x0 = 14 + index * 11.5 + 4 * math.sin(index * 2.3)
        delay = (index * 7) % 13
        speed = 2.6 + (index % 4) * 0.45
        spin = 9 + (index % 5) * 4
        phase = index * 0.37

        def place(frame, x0=x0, delay=delay, speed=speed, phase=phase):
            u = max(0, frame - start - delay)
            return [x0 + 6 * math.sin(u / 7 + phase * 6), -12 + u * speed, 0]

        position = track(lambda f, p=place: p(f)[:2], 0.3, start, start + duration)
        rotation = track(lambda f, s=spin, d=delay: s * max(0, f - start - d), 0.5, start, start + duration)
        size = (4.2, 7) if index % 2 else (5.2, 5.2)
        piece = {"ty": "gr", "nm": "piece", "it": [rect((0, 0), size, 1 if index % 2 else 2.6),
                                                   fill(tones[index % len(tones)], 92),
                                                   transform(position, rotation=rotation)]}
        pieces.append(piece)
    return pieces


# --- Output -------------------------------------------------------------------------------------


def seal():
    width, height = 240, 120
    capsule = (200, 84)
    center = [width / 2, height / 2, 0]
    radius = capsule[1] / 2
    end = IDLE

    def held(frames):
        keys = []
        for index, (frame, value) in enumerate(frames):
            values = value if isinstance(value, list) else [value]
            key = {"t": frame, "s": values}
            if index < len(frames) - 1:
                key.update({"i": {"x": [0.4] * len(values), "y": [1] * len(values)},
                            "o": {"x": [0.6] * len(values), "y": [0] * len(values)}})
            keys.append(key)
        return {"a": 1, "k": keys}

    def item(index, name, shapes, position, scale=None, rotation=None, opacity=None):
        return {"ddd": 0, "ind": index, "ty": 4, "nm": name, "sr": 1, "ao": 0, "ip": 0, "op": end, "st": 0, "bm": 0,
                "ks": {"o": opacity or const(100), "r": rotation or const(0), "p": position, "a": const([0, 0, 0]),
                       "s": scale or const([100, 100, 100])}, "shapes": shapes}

    def plain(value, opacity=100):
        return {"ty": "fl", "c": const(color(value)), "o": const(opacity), "r": 1}

    pulse = held([(0, [100, 100]), (30, [103, 103]), (60, [100, 100]), (120, [100, 100]), (135, [102, 102]),
                  (end, [100, 100])])
    ring_scale = held([(0, [100, 100]), (10, [100, 100]), (60, [116, 128]), (61, [100, 100]), (100, [100, 100]),
                       (145, [116, 128]), (146, [100, 100]), (end, [100, 100])])
    ring_opacity = held([(0, 0), (10, 60), (60, 0), (100, 0), (110, 60), (145, 0), (end, 0)])
    left, right = [center[0] - 150, center[1], 0], [center[0] + 150, center[1], 0]
    sweep = held([(0, left), (40, left), (95, right), (96, left), (end, left)])

    def matte(index):
        layer = item(index, "matte", [group("matte", [rect((0, 0), capsule, radius), plain(PAPER)])], const(center),
                     scale=pulse)
        layer["td"] = 1
        return layer

    wave_layer = item(2, "paper", [group("wave", [rect((0, 0), (36, 180), 18), plain(PAPER, 26)])], sweep,
                      rotation=const(20))
    band_layer = item(4, "secondary", [group("band", [rect((0, 30), (capsule[0], 30), 0), plain("#8E0A12", 70)])],
                      const(center), scale=pulse)
    wave_layer["tt"] = 1
    band_layer["tt"] = 1
    body = item(5, "primary", [group("capsule", [rect((0, 0), capsule, radius), plain("#D7191C")])], const(center),
                scale=pulse)
    ring_stroke = {"ty": "st", "c": const(color("#D7191C")), "o": const(100), "w": const(3), "lc": 2, "lj": 2}
    ring = item(6, "primary", [group("ring", [rect((0, 0), capsule, radius), ring_stroke])], const(center),
                scale=ring_scale, opacity=ring_opacity)
    return {"v": "5.9.0", "fr": FPS, "ip": 0, "op": end, "w": width, "h": height, "nm": "party-seal", "ddd": 0,
            "assets": [], "layers": [matte(1), wave_layer, matte(3), band_layer, body, ring]}


def party_key(party):
    key = party.lower().replace(" ", "")
    for source, target in (("ã", "a"), ("á", "a"), ("â", "a"), ("é", "e"), ("ê", "e"), ("í", "i"), ("ó", "o"),
                           ("ô", "o"), ("ú", "u"), ("ç", "c")):
        key = key.replace(source, target)
    return key


def load_people():
    traits = json.load(open(TRAITS, encoding="utf-8"))
    people, seen = [], set()
    for source in [TRAITS] + sorted(glob.glob(TRAIT_PARTS)):
        for person in json.load(open(source, encoding="utf-8")).get("people", []):
            if person["slug"] in seen:
                continue
            seen.add(person["slug"])
            people.append(person)
    return traits, sorted(people, key=lambda person: person["slug"])


def traits_document(traits, people):
    values = {field: sorted({str(person.get(field) or "") for person in people}) for field in FIELDS}
    rows = [[person["slug"]] + [values[field].index(str(person.get(field) or "")) for field in FIELDS]
            for person in people]
    return {"rigVersion": traits["rigVersion"], "fields": ["slug"] + list(FIELDS), "values": values, "people": rows}


def tones_document(traits, parties):
    hair = traits["scales"]["hair"]
    return {"rigVersion": traits["rigVersion"], "ink": INK, "paper": PAPER, "skin": traits["scales"]["skin"],
            "hair": hair, "brow": {key: brow_color(value) for key, value in hair.items()},
            "parties": {key: [entry["primary"], entry["secondary"]] for key, entry in parties["parties"].items()},
            "fallback": [parties["fallback"][0]["primary"], parties["fallback"][0]["secondary"]]}


def compact(value):
    return json.dumps(value, separators=(",", ":"), ensure_ascii=False)


def write(target, text):
    os.makedirs(os.path.dirname(target), exist_ok=True)
    with open(target, "w", encoding="utf-8") as handle:
        handle.write(text + "\n")


def preview(rig, traits_doc, people, seal_document):
    sample, covered = [], set()
    for person in people:
        key = (person["face"], person["hair"], person["beard"], person["glasses"], person["skin"] // 3)
        if key not in covered:
            covered.add(key)
            sample.append(person["slug"])
    names = {person["slug"]: person["name"] for person in people}
    data = compact({"rig": rig, "traits": traits_doc, "sample": sample[:60], "names": names,
                    "seal": seal_document}).replace("</", "<\\/")
    with open(PREVIEW, "w", encoding="utf-8") as handle:
        handle.write(PREVIEW_PAGE.replace("__DATA__", data))


PREVIEW_PAGE = """<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Fiscal portraits</title>
<style>
  body { margin: 0; padding: 24px; background: #F5F1EA; color: #1C1C1E; font: 14px -apple-system, system-ui, sans-serif; }
  main { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 20px; }
  nav { display: flex; flex-wrap: wrap; gap: 8px; margin: 12px 0 20px; }
  button { font: inherit; padding: 6px 12px; border-radius: 999px; border: 1px solid #0002; background: #fff; }
  button.on { background: #1C1C1E; color: #fff; }
  input { font: inherit; padding: 6px 12px; border-radius: 999px; border: 1px solid #0002; min-width: 220px; }
  figure { margin: 0; text-align: center; }
  .stage { width: 140px; height: 140px; border-radius: 50%; overflow: hidden; margin: 0 auto; }
  figcaption { margin-top: 8px; }
</style>
</head>
<body>
<h3>Retratos (um esqueleto, traços por pessoa)</h3>
<nav id="expressions"></nav>
<nav><input id="search" placeholder="slug, separado por vírgula"></nav>
<main id="people"></main>
<script src="https://cdnjs.cloudflare.com/ajax/libs/lottie-web/5.12.2/lottie.min.js"></script>
<script>
const data = __DATA__;
const rig = data.rig, table = data.traits, tones = rig.fiscal;
const people = {};
table.people.forEach((row) => {
  const person = {};
  table.fields.forEach((field, index) => { person[field] = index === 0 ? row[0] : table.values[field][row[index]]; });
  people[person.slug] = person;
});
const hex = (value) => [1, 3, 5].map((i) => parseInt(value.slice(i, i + 2), 16) / 255);
const toHex = (rgb) => "#" + rgb.map((v) => Math.round(v * 255).toString(16).padStart(2, "0")).join("").toUpperCase();
const mix = (a, b, amount) => toHex(hex(a).map((x, i) => x + (hex(b)[i] - x) * amount));
const partyKey = (party) => party.normalize("NFD").replace(/[\\u0300-\\u036f]/g, "").toLowerCase().replace(/ /g, "");
function palette(person) {
  const hair = tones.hair[person.hairColor] || tones.hair.black;
  const [primary, secondary] = tones.parties[partyKey(person.party)] || tones.fallback;
  return { skin: tones.skin[Number(person.skin) - 1], hair, brow: tones.brow[person.hairColor] || hair,
           beard: tones.hair[person.beardColor] || hair, primary, secondary, ink: tones.ink, paper: tones.paper };
}
function resolve(token, set) {
  const steps = token.split(">");
  return steps.slice(1).reduce((value, step) => { const [target, amount] = step.split("@"); return mix(value, set[target], Number(amount)); }, set[steps[0]]);
}
function tint(items, set) {
  items.forEach((item) => {
    if ((item.ty === "fl" || item.ty === "st") && item.nm) item.c = { a: 0, k: hex(resolve(item.nm, set)).concat([1]) };
    if (item.ty === "gf" && item.nm) { const [a, b] = item.nm.split(",").map((t) => hex(resolve(t, set))); item.g.k.k = [0, ...a, 1, ...b]; }
    if (item.it) tint(item.it, set);
  });
}
function matches(fx, person) { return !fx || Object.entries(fx).every(([key, value]) => person[key] === value); }
function assemble(person) {
  const set = palette(person);
  const layers = rig.layers.filter((layer) => matches(layer.fx, person)).map((layer) => JSON.parse(JSON.stringify(layer)));
  layers.forEach((layer) => layer.shapes && tint(layer.shapes, set));
  const animation = Object.assign({}, rig, { layers });
  delete animation.fiscal;
  return animation;
}
let players = [], current = "idle";
function marker(name) { return rig.markers.find((m) => m.cm === name); }
function play(name) {
  current = name;
  document.querySelectorAll("#expressions button").forEach((b) => b.classList.toggle("on", b.textContent === name));
  players.forEach((player) => {
    const m = marker(name), idle = marker("idle");
    player.removeEventListener("complete", player.back);
    if (name === "idle") { player.loop = true; player.playSegments([idle.tm, idle.tm + idle.dr], true); return; }
    player.loop = false;
    player.back = () => { const next = name === "think" ? marker("thinkLoop") : idle; player.loop = true; player.playSegments([next.tm, next.tm + next.dr], true); };
    player.addEventListener("complete", player.back);
    player.playSegments([m.tm, m.tm + m.dr], true);
  });
}
function render(slugs) {
  players.forEach((player) => player.destroy());
  players = [];
  const main = document.getElementById("people");
  main.innerHTML = "";
  slugs.filter((slug) => people[slug]).forEach((slug) => {
    const person = people[slug];
    const figure = document.createElement("figure");
    figure.innerHTML = `<div class="stage"></div><figcaption>${data.names[slug] || slug} · ${person.party}</figcaption>`;
    main.appendChild(figure);
    players.push(lottie.loadAnimation({ container: figure.querySelector(".stage"), renderer: "svg", loop: true, autoplay: false, animationData: assemble(person) }));
  });
  play(current);
}
const nav = document.getElementById("expressions");
["idle"].concat(rig.markers.filter((m) => m.dr > 0 && m.cm !== "idle" && m.cm !== "thinkLoop").map((m) => m.cm)).forEach((name) => {
  const button = document.createElement("button");
  button.textContent = name;
  button.onclick = () => play(name);
  nav.appendChild(button);
});
document.getElementById("search").addEventListener("change", (event) => {
  const slugs = event.target.value.split(",").map((s) => s.trim()).filter(Boolean);
  render(slugs.length ? slugs : data.sample);
});
render(data.sample);
</script>
</body>
</html>
"""


def main():
    traits, people = load_people()
    parties = json.load(open(PARTIES, encoding="utf-8"))
    rig = build_rig()
    rig["fiscal"] = tones_document(traits, parties)
    traits_doc = traits_document(traits, people)
    seal_document = seal()
    write(RIG_ASSET, compact(rig))
    write(TRAITS_ASSET, compact(traits_doc))
    write(SEAL_ASSET, compact(seal_document))
    write(os.path.join(OUT, "rig.json"), compact(rig))
    write(os.path.join(OUT, "traits.json"), compact(traits_doc))
    write(os.path.join(OUT, "party-seal.json"), compact(seal_document))
    preview(rig, traits_doc, people, seal_document)
    after = sum(os.path.getsize(target) for target in (RIG_ASSET, TRAITS_ASSET, SEAL_ASSET))
    print("%d people, %d rig layers, %d frames; rig %d KB, traits %d KB, seal %d KB (bundle %d KB)" % (
        len(people), len(rig["layers"]), END, os.path.getsize(RIG_ASSET) // 1024,
        os.path.getsize(TRAITS_ASSET) // 1024, os.path.getsize(SEAL_ASSET) // 1024, after // 1024))


if __name__ == "__main__":
    main()
