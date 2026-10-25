#!/usr/bin/env python3
import datetime
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
TRAITS = os.path.join(ROOT, "avatar-traits.json")
PARTIES = os.path.join(ROOT, "party-palette.json")
OUT = os.path.join(ROOT, "animations", "avatars")
BUNDLE = os.path.join(ROOT, "..", "FiscalKit", "Sources", "FiscalResource", "Assets", "fiscal-portraits.json")
PREVIEW = os.path.join(ROOT, "avatars-preview.html")

SIDE, FPS, END = 200, 30, 150
CX = SIDE / 2
PIVOT = (CX, 146)
STEP = 6
RIG = 30
ZOOM = 112
LINEAR = {"i": {"x": [1], "y": [1]}, "o": {"x": [0], "y": [0]}}

INK = "#2A2320"
PAPER = "#FFFFFF"
SHIRT = "#F6F1E8"
LIPS = "#8E4A43"
BLUSH = "#F0907C"
LENS = "#2B2624"

FACES = {
    "oval": {"w": 72, "top": 50, "chin": 140, "jaw": 0.45},
    "round": {"w": 78, "top": 52, "chin": 137, "jaw": 0.7},
    "long": {"w": 68, "top": 47, "chin": 142, "jaw": 0.4},
    "square": {"w": 76, "top": 50, "chin": 139, "jaw": 0.95},
}
BROWS = {"light": 2.6, "medium": 3.4, "strong": 4.3}


# --- Colors -----------------------------------------------------------------------------------


def hex_rgb(value):
    value = value.lstrip("#")
    return [int(value[i:i + 2], 16) / 255 for i in (0, 2, 4)]


def mix(first, second, amount):
    a, b = hex_rgb(first), hex_rgb(second)
    return "#" + "".join("%02X" % round((x + (y - x) * amount) * 255) for x, y in zip(a, b))


def color(value):
    return hex_rgb(value) + [1]


def luminance(value):
    r, g, b = hex_rgb(value)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


# --- Lottie primitives ------------------------------------------------------------------------


def const(value):
    return {"a": 0, "k": value}


def sampled(function, size=1):
    keys = []
    for frame in list(range(0, END, STEP)) + [END]:
        value = function(frame)
        values = [round(v, 2) for v in (value if isinstance(value, (list, tuple)) else [value])]
        key = {"t": frame, "s": values}
        if frame < END:
            key.update({"i": {"x": [1] * len(values), "y": [1] * len(values)},
                        "o": {"x": [0] * len(values), "y": [0] * len(values)}})
        keys.append(key)
    return {"a": 1, "k": keys}


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


def fill(value, opacity=100):
    return {"ty": "fl", "c": const(color(value)), "o": const(opacity), "r": 1}


def stroke(value, width, opacity=100):
    return {"ty": "st", "c": const(color(value)), "o": const(opacity), "w": const(width), "lc": 2, "lj": 2}


def gradient(first, second, start, end, opacity=100):
    a, b = hex_rgb(first), hex_rgb(second)
    return {"ty": "gf", "t": 1, "o": const(opacity), "r": 1, "s": const(list(start)), "e": const(list(end)),
            "g": {"p": 2, "k": const([0] + a + [1] + b)}}


def shade(start, end, top, bottom):
    return {"ty": "gf", "t": 1, "o": const(100), "r": 1, "s": const(list(start)), "e": const(list(end)),
            "g": {"p": 2, "k": const([0, 1, 1, 1, 1, 0, 0, 0, 0, top, 1, bottom])}}


def transform(position=(0, 0), anchor=(0, 0), scale=None, rotation=None, opacity=None):
    return {"ty": "tr", "p": position if isinstance(position, dict) else const(list(position)),
            "a": const(list(anchor)), "s": scale or const([100, 100]), "r": rotation or const(0),
            "o": opacity or const(100)}


def group(name, items):
    return {"ty": "gr", "nm": name, "it": items + [transform()]}


def layer(index, name, shapes, position=None, anchor=(0, 0), scale=None, rotation=None, opacity=None, parent=None):
    item = {
        "ddd": 0, "ind": index, "ty": 4, "nm": name, "sr": 1, "ao": 0, "ip": 0, "op": END, "st": 0, "bm": 0,
        "ks": {
            "o": opacity or const(100), "r": rotation or const(0),
            "p": position or const([anchor[0], anchor[1], 0]), "a": const([anchor[0], anchor[1], 0]),
            "s": scale or const([100, 100, 100]),
        },
        "shapes": shapes,
    }
    if parent is not None:
        item["parent"] = parent
    return item


def document(name, layers, width=SIDE, height=SIDE):
    ordered = sorted(layers, key=lambda item: item["ind"])
    return {"v": "5.9.0", "fr": FPS, "ip": 0, "op": END, "w": width, "h": height, "nm": name, "ddd": 0,
            "assets": [], "layers": ordered}


# --- Motion (the same for every person) -------------------------------------------------------


def wave(frame, period, phase=0.0):
    return math.sin(2 * math.pi * (frame / period + phase))


def breath(frame):
    return -1.3 * (1 - math.cos(2 * math.pi * frame / 75)) / 2


def nod(frame):
    if 92 <= frame <= 120:
        return 2.4 * math.sin(math.pi * (frame - 92) / 28)
    return 0.0


def smile(frame):
    if 84 <= frame <= 128:
        return math.sin(math.pi * (frame - 84) / 44) ** 2
    return 0.0


def turn(frame):
    return 1.8 * wave(frame, END)


def roll(frame):
    return 1.6 * wave(frame, END, 0.08)


def head_position():
    return sampled(lambda f: [PIVOT[0], PIVOT[1] + breath(f) + nod(f), 0])


def head_rotation():
    return sampled(roll)


def feature_position(depth=1.0, lift=0.0):
    return sampled(lambda f: [turn(f) * depth, -smile(f) * lift, 0])


def blink():
    frames = [(0, 100), (50, 100), (53, 8), (57, 100), (134, 100), (137, 8), (141, 100), (END, 100)]
    return held([(frame, [100, value]) for frame, value in frames])


def breathe_scale(amount):
    return sampled(lambda f: [100 - breath(f) * amount, 100 - breath(f) * amount, 100])


# --- Rig ----------------------------------------------------------------------------------------


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
    if style == "wavy":
        right = [(CX + h + 12, 66), (CX + h + 18, 104), (CX + h + 12, 132), (CX + h + 20, 160), (CX + h + 12, 198, "c")]
        left = [(2 * CX - x, y, *rest) for x, y, *rest in reversed(right)]
        return [(CX, top - 10)] + right + left
    return None


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


def brow_color(hair):
    if luminance(hair) > 0.55:
        return mix(hair, INK, 0.38)
    return mix(hair, INK, 0.15)


def palette_of(party, parties):
    key = party.lower().replace(" ", "")
    for source, target in (("ã", "a"), ("á", "a"), ("é", "e"), ("í", "i"), ("ó", "o"), ("ú", "u"), ("ç", "c")):
        key = key.replace(source, target)
    entry = parties["parties"].get(key) or parties["fallback"][0]
    return entry["primary"], entry["secondary"]


def backdrop_layers(index, primary, secondary):
    back = layer(index, "backdrop", [group("backdrop", [rect((CX, CX), (SIDE, SIDE), 0),
                                                       gradient(primary, secondary, (0, 0), (SIDE, SIDE))])])
    gloss = layer(index - 1, "gloss", [group("gloss", [rect((CX, CX), (SIDE, SIDE), 0),
                                                      shade((CX, 0), (CX, SIDE), 0.16, 0.0)])])
    halo = layer(index - 2, "halo", [group("halo", [ellipse((0, 0), (150, 150)), fill(PAPER, 14)])],
                 position=const([CX, 98, 0]), anchor=(0, 0), scale=breathe_scale(1.2))
    return [back, gloss, halo]


def body_layer(index, primary, secondary):
    jacket = mix(primary, INK, 0.18)
    lapel = mix(primary, PAPER, 0.12)
    shoulders = [(26, 206, "c"), (28, 180), (40, 162), (72, 151), (128, 151), (160, 162), (172, 180), (174, 206, "c")]
    shirt = [(84, 150, "c"), (116, 150, "c"), (100, 178, "c")]
    left_lapel = [(84, 150, "c"), (100, 178, "c"), (92, 196, "c"), (72, 156, "c")]
    right_lapel = [(2 * CX - x, y, "c") for x, y, _ in left_lapel]
    collar_left = [(85, 149, "c"), (99, 160, "c"), (92, 164, "c")]
    collar_right = [(2 * CX - x, y, "c") for x, y, _ in collar_left]
    seam = [(CX, 178, "c"), (CX, 206, "c")]
    shapes = [
        group("collar", [path(collar_left), path(collar_right), fill(PAPER)]),
        group("seam", [path(seam, closed=False), stroke(mix(jacket, INK, 0.3), 1.6, 60)]),
        group("piping", [path([(72, 156, "c"), (92, 196, "c")], closed=False),
                         path([(128, 156, "c"), (108, 196, "c")], closed=False), stroke(secondary, 2.4)]),
        group("lapels", [path(left_lapel), path(right_lapel), fill(lapel)]),
        group("shirt", [path(shirt), fill(SHIRT)]),
        group("jacket", [path(shoulders), fill(jacket), stroke(PAPER, 2.2, 22)]),
    ]
    position = sampled(lambda f: [CX, 200 + breath(f) * 0.5, 0])
    return layer(index, "party", shapes, position=position, anchor=(CX, 200), parent=RIG)


def neck_layer(index, skin):
    neck = mix(skin, INK, 0.12)
    shapes = [group("neck", [rect((CX, 136), (30, 36), 12), fill(neck)]),
              group("shadow", [ellipse((CX, 128), (34, 12)), fill(mix(skin, INK, 0.2), 45)])]
    position = sampled(lambda f: [CX, 150 + breath(f) * 0.7, 0])
    return layer(index, "skin", shapes, position=position, anchor=(CX, 150), parent=RIG)


def head_layer(index, face, skin):
    w = face["w"]
    ear = mix(skin, INK, 0.06)
    inner = mix(skin, INK, 0.18)
    shapes = [
        group("face", [path(face_points(face)), fill(skin)]),
        group("ears", [ellipse((CX - w / 2 + 1, 100), (13, 19)), ellipse((CX + w / 2 - 1, 100), (13, 19)), fill(ear)]),
        group("earInner", [ellipse((CX - w / 2 + 1, 101), (6, 10)), ellipse((CX + w / 2 - 1, 101), (6, 10)), fill(inner, 70)]),
    ]
    return layer(index, "skin", shapes, position=head_position(), anchor=PIVOT, rotation=head_rotation(), parent=RIG)


def eyes_layer(index, head):
    shapes = []
    for x in (CX - 14.5, CX + 14.5):
        shapes += [group("shine", [ellipse((x + 1.6, 94.2), (2.6, 2.6)), fill(PAPER, 90)]),
                   group("eye", [ellipse((x, 96), (7.4, 9.4)), fill(INK)])]
    return layer(index, "ink", shapes, position=sampled(lambda f: [CX + turn(f), 96, 0]), anchor=(CX, 96),
                 scale=blink(), parent=head)


def brows_layer(index, head, weight, tone):
    shapes = []
    for side in (-1, 1):
        x = CX + side * 14.5
        points = [(x - 7 * side, 86.5), (x - side, 83.6), (x + 7 * side, 85.2)]
        shapes.append(group("brow", [path(points, closed=False), stroke(tone, weight)]))
    return layer(index, "hair", shapes, position=sampled(lambda f: [CX + turn(f), 85 - smile(f) * 1.6, 0]),
                 anchor=(CX, 85), parent=head)


def nose_layer(index, head, skin):
    shapes = [group("nose", [path([(CX - 4, 110), (CX, 112.6), (CX + 4, 110)], closed=False),
                             stroke(mix(skin, INK, 0.32), 2.2, 80)])]
    return layer(index, "skin", shapes, position=feature_position(1.25), anchor=(0, 0), parent=head)


def cheeks_layer(index, head, w):
    shapes = [group("cheeks", [ellipse((CX - w * 0.33, 112), (12, 7)), ellipse((CX + w * 0.33, 112), (12, 7)),
                               fill(BLUSH)])]
    opacity = sampled(lambda f: 22 + smile(f) * 12)
    return layer(index, "blush", shapes, position=feature_position(0.9, 1.0), opacity=opacity, parent=head)


def mouth_layer(index, head):
    smile_path = [(CX - 9, 121), (CX, 125.6), (CX + 9, 121)]
    shapes = [group("mouth", [path(smile_path, closed=False), stroke(LIPS, 3.0)])]
    scale = sampled(lambda f: [100 + smile(f) * 16, 100 + smile(f) * 22, 100])
    return layer(index, "lips", shapes, position=sampled(lambda f: [CX + turn(f), 123, 0]), anchor=(CX, 123),
                 scale=scale, parent=head)


def beard_layer(index, head, face, style, tone, skin):
    shade_tone = tone if style == "full" else mix(tone, skin, 0.42)
    shapes = [group("mustache", [path(mustache()), fill(shade_tone)]),
              group("beard", [path(beard_shape(face)), fill(shade_tone)])]
    return layer(index, "hair", shapes, position=feature_position(0.6), parent=head)


def glasses_layer(index, head):
    shapes = [group("frames", [rect((CX - 14.5, 96), (20, 14), 5), rect((CX + 14.5, 96), (20, 14), 5),
                               path([(CX - 4.5, 95), (CX, 93.6), (CX + 4.5, 95)], closed=False), stroke(LENS, 2.4)]),
              group("lens", [rect((CX - 14.5, 96), (20, 14), 5), rect((CX + 14.5, 96), (20, 14), 5), fill(PAPER, 16)])]
    return layer(index, "ink", shapes, position=feature_position(1.05), parent=head)


def hair_layers(front_index, back_index, head, style, face, tone):
    layers = []
    back = hair_back(style, face)
    if back:
        sway = sampled(lambda f: 0.8 * wave(f, END, 0.2))
        layers.append(layer(back_index, "hair", [group("hairBack", [path(back), fill(mix(tone, INK, 0.12))])],
                            position=const([CX, 60, 0]), anchor=(CX, 60), rotation=sway, parent=head))
    pieces = hair_front(style, face)
    if pieces:
        highlight = mix(tone, PAPER, 0.18)
        shapes = [group("hairFront", [path(piece) for piece in pieces] + [fill(tone)])]
        if style not in ("receding",):
            shapes.insert(0, group("shine", [ellipse((CX + face["w"] * 0.2, face["top"] + 3), (13, 4)), fill(highlight, 30)]))
        else:
            shapes.append(group("thinning", [path(thinning(face)), fill(tone, 38)]))
        layers.append(layer(front_index, "hair", shapes, position=feature_position(0.35), parent=head))
    return layers


def rig():
    return {"ddd": 0, "ind": RIG, "ty": 3, "nm": "rig", "sr": 1, "ao": 0, "ip": 0, "op": END, "st": 0, "bm": 0,
            "ks": {"o": const(100), "r": const(0), "p": const([CX, 124, 0]), "a": const([CX, 120, 0]),
                   "s": const([ZOOM, ZOOM, 100])}}


def portrait(person, traits, parties):
    skin = traits["scales"]["skin"][person["skin"] - 1]
    tone = traits["scales"]["hair"][person["hairColor"]]
    beard_tone = traits["scales"]["hair"].get(person.get("beardColor") or person["hairColor"])
    face = FACES[person["face"]]
    primary, secondary = palette_of(person["party"], parties)
    head = 20
    layers = [
        glasses_layer(1, head) if person.get("glasses") == "rectangle" else None,
        brows_layer(2, head, BROWS[person["brows"]], brow_color(tone)),
        eyes_layer(4, head),
        mouth_layer(5, head),
        beard_layer(6, head, face, person["beard"], beard_tone, skin) if person.get("beard") in ("full", "short") else None,
        nose_layer(7, head, skin),
        cheeks_layer(8, head, face["w"]),
        head_layer(head, face, skin),
        neck_layer(21, skin),
        body_layer(22, primary, secondary),
    ]
    layers += hair_layers(3, 23, head, person["hair"], face, tone)
    layers += backdrop_layers(26, primary, secondary) + [rig()]
    return document(person["slug"], [item for item in layers if item])


def generic(parties):
    primary, secondary = parties["fallback"][0]["primary"], parties["fallback"][0]["secondary"]
    head = layer(10, "silhouette", [group("head", [ellipse((CX, 92), (64, 72)), fill(PAPER, 34)])],
                 position=head_position(), anchor=PIVOT, rotation=head_rotation(), parent=RIG)
    body = layer(11, "silhouette", [group("body", [path([(34, 206, "c"), (36, 182), (50, 162), (80, 150), (120, 150),
                                                          (150, 162), (164, 182), (166, 206, "c")]), fill(PAPER, 34)])],
                 position=sampled(lambda f: [CX, 200 + breath(f) * 0.5, 0]), anchor=(CX, 200), parent=RIG)
    return document("generic", [head, body] + backdrop_layers(14, primary, secondary) + [rig()])


def seal():
    width, height = 240, 120
    capsule = (200, 84)
    center = [width / 2, height / 2, 0]
    radius = capsule[1] / 2
    pulse = held([(0, [100, 100]), (30, [103, 103]), (60, [100, 100]), (120, [100, 100]), (135, [102, 102]),
                  (END, [100, 100])])
    ring_scale = held([(0, [100, 100]), (10, [100, 100]), (60, [116, 128]), (61, [100, 100]), (100, [100, 100]),
                       (145, [116, 128]), (146, [100, 100]), (END, [100, 100])])
    ring_opacity = held([(0, 0), (10, 60), (60, 0), (100, 0), (110, 60), (145, 0), (END, 0)])
    left, right = [center[0] - 150, center[1], 0], [center[0] + 150, center[1], 0]
    sweep = held([(0, left), (40, left), (95, right), (96, left), (END, left)])

    def matte(index):
        item = layer(index, "matte", [group("matte", [rect((0, 0), capsule, radius), fill(PAPER)])],
                     position=const(center), scale=pulse)
        item["td"] = 1
        return item

    wave_layer = layer(2, "paper", [group("wave", [rect((0, 0), (36, 180), 18), fill(PAPER, 26)])],
                       position=sweep, rotation=const(20))
    band_layer = layer(4, "secondary", [group("band", [rect((0, 30), (capsule[0], 30), 0), fill("#8E0A12", 70)])],
                       position=const(center), scale=pulse)
    wave_layer["tt"] = 1
    band_layer["tt"] = 1
    body = layer(5, "primary", [group("capsule", [rect((0, 0), capsule, radius), fill("#D7191C")])],
                 position=const(center), scale=pulse)
    ring = layer(6, "primary", [group("ring", [rect((0, 0), capsule, radius), stroke("#D7191C", 3)])],
                 position=const(center), scale=ring_scale, opacity=ring_opacity)
    return document("party-seal", [matte(1), wave_layer, matte(3), band_layer, body, ring], width, height)


# --- Output -------------------------------------------------------------------------------------


def compact(value):
    return json.dumps(value, separators=(",", ":"), ensure_ascii=False)


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text + "\n")


def preview(people, documents, seal_document, parties):
    entries = [{"slug": p["slug"], "name": p["name"], "party": p["party"]} for p in people]
    data = compact({"people": entries, "animations": documents, "seal": seal_document,
                    "parties": parties["parties"]}).replace("</", "<\\/")
    page = PREVIEW_PAGE.replace("__DATA__", data)
    with open(PREVIEW, "w", encoding="utf-8") as handle:
        handle.write(page)


PREVIEW_PAGE = """<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Fiscal portraits</title>
<style>
  body { margin: 0; padding: 24px; background: #F5F1EA; color: #1C1C1E; font: 14px -apple-system, system-ui, sans-serif; }
  main { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 20px; }
  figure { margin: 0; text-align: center; }
  .stage { width: 140px; height: 140px; border-radius: 50%; overflow: hidden; margin: 0 auto; }
  .small { display: flex; gap: 8px; justify-content: center; margin-top: 8px; }
  .small div { width: 36px; height: 36px; border-radius: 50%; overflow: hidden; }
  .seal { width: 120px; height: 60px; position: relative; margin: 0 auto; }
  .seal span { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; color: #fff; font: 800 18px ui-rounded, system-ui; }
  figcaption { margin-top: 8px; }
</style>
</head>
<body>
<h3>Retratos (Ilustração do Fiscal)</h3>
<main id="people"></main>
<h3>Selos</h3>
<main id="seals"></main>
<script src="https://cdnjs.cloudflare.com/ajax/libs/lottie-web/5.12.2/lottie.min.js"></script>
<script>
const data = __DATA__;
const people = document.getElementById("people");
[...data.people, { slug: "generic", name: "Genérico", party: "" }].forEach((person) => {
  const figure = document.createElement("figure");
  figure.innerHTML = `<div class="stage"></div><div class="small"><div></div><div></div></div><figcaption>${person.name} · ${person.party}</figcaption>`;
  people.appendChild(figure);
  const stages = figure.querySelectorAll(".stage, .small div");
  stages.forEach((stage, index) => lottie.loadAnimation({ container: stage, renderer: "svg", loop: true, autoplay: index < 2, animationData: JSON.parse(JSON.stringify(data.animations[person.slug])) }));
});
const seals = document.getElementById("seals");
const hex = (value) => [1, 3, 5].map((i) => parseInt(value.slice(i, i + 2), 16) / 255).concat([1]);
const recolor = (items, rgba) => items.forEach((item) => { if (item.ty === "fl" || item.ty === "st") item.c.k = rgba; if (item.it) recolor(item.it, rgba); });
Object.entries(data.parties).forEach(([key, colors]) => {
  const animation = JSON.parse(JSON.stringify(data.seal));
  animation.layers.forEach((item) => { if (item.nm === "primary") recolor(item.shapes, hex(colors.primary)); if (item.nm === "secondary") recolor(item.shapes, hex(colors.secondary)); });
  const figure = document.createElement("figure");
  figure.innerHTML = `<div class="seal"><span>${key.toUpperCase()}</span></div>`;
  seals.appendChild(figure);
  const stage = figure.querySelector(".seal");
  const player = document.createElement("div");
  player.style.cssText = "position:absolute;inset:0";
  stage.prepend(player);
  lottie.loadAnimation({ container: player, renderer: "svg", loop: true, autoplay: true, animationData: animation });
});
</script>
</body>
</html>
"""


def main():
    traits = json.load(open(TRAITS, encoding="utf-8"))
    parties = json.load(open(PARTIES, encoding="utf-8"))
    stamp = sys.argv[1] if len(sys.argv) > 1 else datetime.date.today().isoformat()
    people = sorted(traits["people"], key=lambda person: person["slug"])
    documents = {person["slug"]: portrait(person, traits, parties) for person in people}
    documents["generic"] = generic(parties)
    seal_document = seal()
    for slug, value in documents.items():
        write(os.path.join(OUT, slug + ".json"), compact(value))
    write(os.path.join(OUT, "party-seal.json"), compact(seal_document))
    index = {"rigVersion": traits["rigVersion"],
             "people": [{"slug": p["slug"], "party": p["party"], "updatedAt": stamp} for p in people]}
    write(os.path.join(OUT, "index.json"), compact(index))
    bundle = dict(index, generic=documents["generic"], seal=seal_document,
                  animations={p["slug"]: documents[p["slug"]] for p in people})
    write(BUNDLE, compact(bundle))
    preview(people, documents, seal_document, parties)
    sizes = [len(compact(value)) for value in documents.values()]
    print("%d portraits (max %d KB), seal, index and %s" % (len(people), max(sizes) // 1024, os.path.abspath(BUNDLE)))


if __name__ == "__main__":
    main()
