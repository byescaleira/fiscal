import json
import math
import random
import re
import shutil
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ICONS = ROOT / "Fiscal" / "Fiscal"
MAP_SOURCE = ICONS / "FiscalIcon.icon"
MAP_FILES = ("9 Map.svg", "9b Rim.svg")
SIZE = 1024
MAX_LAYERS = 10
HEX = re.compile(r"^#[0-9A-F]{6}$")


@dataclass(frozen=True)
class Paint:
    light: str
    dark: str
    tinted: str


@dataclass(frozen=True)
class Layer:
    name: str
    paint: Paint
    paths: tuple[str, ...]
    opacity: float = 1.0


@dataclass(frozen=True)
class Group:
    name: str
    layers: tuple[Layer, ...]
    shadow: float = 0.0


@dataclass(frozen=True)
class Landscape:
    icon: str
    place: str
    light: tuple[str, str]
    dark: tuple[str, str]
    groups: tuple[Group, ...] = field(default_factory=tuple)


@dataclass(frozen=True)
class Scene:
    icon: str
    place: str
    light: tuple[str, str]
    dark: tuple[str, str]
    paints: dict
    seed: int


class LandscapeError(Exception):
    pass


def fmt(value):
    text = f"{value:.1f}"
    return "0.0" if text == "-0.0" else text


def catmull(points, closed):
    count = len(points)
    if closed:
        get = lambda i: points[i % count]
        segments = range(count)
    else:
        padded = [points[0], *points, points[-1]]
        get = lambda i: padded[i + 1]
        segments = range(count - 1)
    commands = [f"M{fmt(get(0)[0])} {fmt(get(0)[1])}"]
    for i in segments:
        p0, p1, p2, p3 = get(i - 1), get(i), get(i + 1), get(i + 2)
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        commands.append(
            f"C{fmt(c1[0])} {fmt(c1[1])} {fmt(c2[0])} {fmt(c2[1])} {fmt(p2[0])} {fmt(p2[1])}"
        )
    if closed:
        commands.append("Z")
    return "".join(commands)


def sample(points, steps):
    padded = [points[0], *points, points[-1]]
    out = []
    for i in range(1, len(padded) - 2):
        p0, p1, p2, p3 = padded[i - 1], padded[i], padded[i + 1], padded[i + 2]
        for s in range(steps):
            t = s / steps
            t2, t3 = t * t, t * t * t
            out.append(
                tuple(
                    0.5
                    * (
                        2 * p1[k]
                        + (-p0[k] + p2[k]) * t
                        + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                        + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3
                    )
                    for k in range(2)
                )
            )
    out.append(points[-1])
    return out


def ribbon(control, width, steps=12, every=3):
    line = sample(control, steps)
    count = len(line)
    left, right = [], []
    for i, p in enumerate(line):
        a = line[max(i - 1, 0)]
        b = line[min(i + 1, count - 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        length = math.hypot(dx, dy) or 1
        half = width(i / (count - 1)) / 2
        left.append((p[0] - dy / length * half, p[1] + dx / length * half))
        right.append((p[0] + dy / length * half, p[1] - dx / length * half))
    outline = left[::every] + [left[-1]] + [right[-1]] + right[::-1][::every]
    return catmull(outline, closed=True), line


def blob(cx, cy, rx, ry, angle, rng, wobble=0.12, count=10):
    cos, sin = math.cos(angle), math.sin(angle)
    phase = rng.uniform(0, math.tau)
    points = []
    for i in range(count):
        t = i / count * math.tau
        scale = 1 + wobble * math.sin(2 * t + phase) + rng.uniform(-wobble, wobble) * 0.5
        x, y = rx * scale * math.cos(t), ry * scale * math.sin(t)
        points.append((cx + x * cos - y * sin, cy + x * sin + y * cos))
    return catmull(points, closed=True)


def circle(cx, cy, r):
    return (
        f"M{fmt(cx - r)} {fmt(cy)}a{fmt(r)} {fmt(r)} 0 1 0 {fmt(2 * r)} 0"
        f"a{fmt(r)} {fmt(r)} 0 1 0 {fmt(-2 * r)} 0Z"
    )


def pad(cx, cy, r, notch):
    a, b = notch - 0.28, notch + 0.28
    start = (cx + r * math.cos(b), cy + r * math.sin(b))
    end = (cx + r * math.cos(a), cy + r * math.sin(a))
    return (
        f"M{fmt(cx)} {fmt(cy)}L{fmt(start[0])} {fmt(start[1])}"
        f"A{fmt(r)} {fmt(r)} 0 1 1 {fmt(end[0])} {fmt(end[1])}Z"
    )


def crescent(cx, cy, radius, start, end, thickness, steps=14):
    outer, inner = [], []
    for i in range(steps + 1):
        t = i / steps
        a = start + (end - start) * t
        h = thickness * math.sin(math.pi * t) ** 0.6 / 2 + 2
        outer.append((cx + (radius + h) * math.cos(a), cy + (radius + h) * math.sin(a)))
        inner.append((cx + (radius - h) * math.cos(a), cy + (radius - h) * math.sin(a)))
    return catmull(outer + inner[::-1], closed=True)


def offset(points, distance):
    area = sum(
        points[i][0] * points[(i + 1) % len(points)][1]
        - points[(i + 1) % len(points)][0] * points[i][1]
        for i in range(len(points))
    )
    sign = 1 if area > 0 else -1
    out = []
    for i, p in enumerate(points):
        a, b = points[i - 1], points[(i + 1) % len(points)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        length = math.hypot(dx, dy) or 1
        out.append((p[0] + sign * dy / length * distance, p[1] - sign * dx / length * distance))
    return out


def shape(points, x=0, y=0, scale=1, angle=0):
    cos, sin = math.cos(angle), math.sin(angle)
    return [
        (x + scale * (px * cos - py * sin), y + scale * (px * sin + py * cos)) for px, py in points
    ]


def distance_to(line, x, y):
    best = math.inf
    for (ax, ay), (bx, by) in zip(line, line[1:]):
        dx, dy = bx - ax, by - ay
        t = max(0, min(1, ((x - ax) * dx + (y - ay) * dy) / ((dx * dx + dy * dy) or 1)))
        best = min(best, math.hypot(x - ax - t * dx, y - ay - t * dy))
    return best


def scatter(rng, count, low, high, keep, spacing, margin=60, tries=60):
    placed = []
    for _ in range(count):
        for _ in range(tries):
            r = rng.uniform(low, high)
            x = rng.uniform(-margin, SIZE + margin)
            y = rng.uniform(-margin, SIZE + margin)
            if not keep(x, y, r):
                continue
            if all(math.hypot(x - px, y - py) > (r + pr) * spacing for px, py, pr in placed):
                placed.append((x, y, r))
                break
    return sorted(placed, key=lambda c: (c[1], c[0]))


def broccoli(rng, x, y, r):
    lobes = [circle(x, y, r * 0.72)]
    turn = rng.uniform(0, math.tau)
    for k in range(5):
        a = turn + k * math.tau / 5 + rng.uniform(-0.3, 0.3)
        lobes.append(circle(x + math.cos(a) * r * 0.42, y + math.sin(a) * r * 0.42, r * 0.5))
    return lobes


def oval(cx, cy, rx, ry, angle=0.0, count=16):
    return catmull(shape([(rx * math.cos(i / count * math.tau), ry * math.sin(i / count * math.tau)) for i in range(count)], cx, cy, 1, angle), True)


def polygon(points):
    head, *rest = points
    return f"M{fmt(head[0])} {fmt(head[1])}" + "".join(f"L{fmt(x)} {fmt(y)}" for x, y in rest) + "Z"


def star(cx, cy, outer, inner, count, turn=0.0):
    points = []
    for i in range(count * 2):
        a = turn + i * math.pi / count
        r = outer if i % 2 == 0 else inner
        points.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return polygon(points)


def canopy(rng, count, low, high, keep, spacing):
    shade, lit = [], []
    for x, y, r in scatter(rng, count, low, high, keep, spacing):
        shade += broccoli(rng, x, y, r)
        lit.append(circle(x - r * 0.18, y - r * 0.22, r * 0.4))
    return tuple(shade), tuple(lit)


def amazon(scene):
    rng = random.Random(scene.seed)
    paints = scene.paints
    river, line = ribbon(
        [
            (-90, 300),
            (70, 340),
            (150, 450),
            (90, 560),
            (130, 690),
            (280, 720),
            (330, 830),
            (470, 870),
            (560, 960),
            (720, 930),
            (850, 990),
            (1120, 940),
        ],
        lambda t: 78 + 22 * t,
    )
    lake = [(780, 70), (880, 100), (930, 170), (900, 230), (840, 190), (790, 150), (740, 130)]
    lake_line = sample(lake, 4)

    def keep(x, y, r):
        return distance_to(line, x, y) > 44 + r * 0.7 and distance_to(lake_line, x, y) > 34 + r * 0.6

    crowns = scatter(rng, 260, 46, 74, keep, 0.78)
    shade, lit = [], []
    for x, y, r in crowns:
        shade += broccoli(rng, x, y, r)
        lit.append(circle(x - r * 0.18, y - r * 0.22, r * 0.4))
    pads = (
        pad(855, 150, 30, 0.6),
        pad(800, 118, 24, 2.4),
        pad(60, 420, 28, 1.2),
        pad(205, 690, 26, 3.6),
    )
    if "canoe" in paints:
        canoe = (blob(430, 856, 62, 15, math.radians(18), rng, 0.0, 12),)
        life = (Layer("5 Canoe", paints["canoe"], canoe), Layer("4 Pads", paints["pad"], pads))
    else:
        body = [
            (84, 0), (62, 5), (46, 12), (28, 22), (0, 25), (-30, 20), (-58, 11), (-74, 7), (-88, 26),
            (-106, 30), (-96, 0), (-106, -30), (-88, -26), (-74, -7), (-58, -11), (-30, -20),
            (0, -25), (28, -22), (46, -12), (62, -5),
        ]
        turn = math.radians(18)
        boto = [catmull(shape(body, 430, 856, 1.05, turn), True)]
        boto += [catmull(shape([(x, y * side) for x, y in [(14, 18), (0, 44), (-16, 50), (-10, 22)]], 430, 856, 1.05, turn), True) for side in (1, -1)]
        back = (catmull(shape([(26, 0), (6, 10), (-40, 7), (-58, 0), (-40, -7), (6, -10)], 430, 856, 1.05, turn), True),)
        life = (Layer("6 Back", paints["back"], back), Layer("5 Boto", paints["boto"], tuple(boto)), Layer("4 Pads", paints["pad"], pads))
    return Landscape(
        scene.icon,
        scene.place,
        scene.light,
        scene.dark,
        (
            Group("Life", life, 0.35),
            Group(
                "Trees",
                (Layer("3 Lit", paints["lit"], tuple(lit)), Layer("2 Crowns", paints["crown"], tuple(shade))),
                0.55,
            ),
            Group("River", (Layer("1 River", paints["river"], (river, catmull(lake, True))),)),
        ),
    )


def lencois(scene):
    rng = random.Random(scene.seed)
    paints = scene.paints
    tilt = math.radians(-16)
    cos, sin = math.cos(tilt), math.sin(tilt)
    crests, greens, blues = [], [], []
    for row in range(-1, 7):
        start = rng.uniform(-300, -120)
        while start < SIZE + 100:
            length = rng.uniform(400, 520)
            base_y = row * 185 + rng.uniform(-16, 16)
            points = []
            for k in range(6):
                t = k / 5
                u = start + length * t
                v = base_y - 60 * math.sin(math.pi * t)
                points.append((u * cos - v * sin + 60, u * sin + v * cos + 120))
            crest, _ = ribbon(points, lambda t: 14 + 44 * math.sin(math.pi * t) ** 0.7, steps=8, every=2)
            crests.append(crest)
            mid_u, mid_v = start + length / 2, base_y + 66
            px, py = mid_u * cos - mid_v * sin + 60, mid_u * sin + mid_v * cos + 120
            pool = blob(px, py, length * rng.uniform(0.3, 0.38), rng.uniform(40, 52), tilt, rng, 0.16, 12)
            if rng.random() < 0.85:
                (blues if rng.random() < 0.45 else greens).append(pool)
            start += length + rng.uniform(-30, 40)
    return Landscape(
        scene.icon,
        scene.place,
        scene.light,
        scene.dark,
        (
            Group(
                "Lagoons",
                (Layer("3 Blue", paints["blue"], tuple(blues)), Layer("2 Green", paints["green"], tuple(greens))),
            ),
            Group("Dunes", (Layer("1 Crest", paints["crest"], tuple(crests)),)),
        ),
    )


def noronha(scene):
    rng = random.Random(scene.seed)
    paints = scene.paints
    island = [
        (-120, 560),
        (40, 590),
        (150, 650),
        (240, 640),
        (320, 690),
        (360, 770),
        (450, 800),
        (520, 870),
        (600, 900),
        (640, 990),
        (600, 1120),
        (-120, 1120),
    ]
    twins = [(760, 860, 62), (890, 905, 54)]
    shallows = [catmull(offset(island, 80), True)] + [circle(x, y, r + 46) for x, y, r in twins]
    foam = [catmull(offset(island, 26), True)] + [circle(x, y, r + 16) for x, y, r in twins]
    rocks = [catmull(offset(island, 8), True)] + [circle(x, y, r) for x, y, r in twins]
    greens = [catmull(island, True)] + [circle(x - r * 0.12, y - r * 0.14, r * 0.8) for x, y, r in twins]
    hills = [
        blob(130, 770, 90, 58, math.radians(20), rng, 0.12),
        blob(320, 880, 70, 50, math.radians(35), rng, 0.12),
        blob(80, 950, 110, 70, math.radians(10), rng, 0.12),
    ]
    hills += [circle(x - r * 0.26, y - r * 0.3, r * 0.42) for x, y, r in twins]
    beach = [crescent(470, 760, 70, math.radians(30), math.radians(150), 38)]
    turtle_shell = [(0, -40), (26, -26), (32, 4), (22, 34), (0, 44), (-22, 34), (-32, 4), (-26, -26)]
    turtle = [catmull(shape(turtle_shell, 790, 150, 1.5, math.radians(-30)), True)]
    for fx, fy, a in [(30, -24, -40), (-30, -24, 220), (24, 30, 40), (-24, 30, 140)]:
        px, py = shape([(fx, fy)], 790, 150, 1.5, math.radians(-30))[0]
        turtle.append(blob(px, py, 26 if fy < 0 else 18, 12, math.radians(a - 30), rng, 0.0, 10))
    hx, hy = shape([(0, -56)], 790, 150, 1.5, math.radians(-30))[0]
    turtle.append(circle(hx, hy, 14))
    spots = [circle(*shape([(0, -12)], 790, 150, 1.5, math.radians(-30))[0], 14)]
    spots += [circle(*shape([(sx, 14)], 790, 150, 1.5, math.radians(-30))[0], 12) for sx in (-14, 14)]
    return Landscape(
        scene.icon,
        scene.place,
        scene.light,
        scene.dark,
        (
            Group(
                "Turtle",
                (Layer("8 Spots", paints["spots"], tuple(spots)), Layer("7 Turtle", paints["turtle"], tuple(turtle))),
                0.4,
            ),
            Group(
                "Island",
                (
                    Layer("6 Hills", paints["hill"], tuple(hills)),
                    Layer("5 Beach", paints["beach"], tuple(beach)),
                    Layer("4 Green", paints["green"], tuple(greens)),
                    Layer("3 Rock", paints["rock"], tuple(rocks)),
                ),
                0.5,
            ),
            Group(
                "Sea",
                (Layer("2 Foam", paints["foam"], tuple(foam)), Layer("1 Shallows", paints["shallow"], tuple(shallows))),
            ),
        ),
    )


def flow_frame(angle):
    d = (math.cos(angle), math.sin(angle))
    n = (-d[1], d[0])
    to_xy = lambda u, v: (512 + u * d[0] + v * n[0], 512 + u * d[1] + v * n[1])
    to_v = lambda x, y: (x - 512) * n[0] + (y - 512) * n[1]
    return to_xy, to_v


def meeting(scene):
    rng = random.Random(scene.seed)
    paints = scene.paints
    to_xy, to_v = flow_frame(math.radians(-22))
    edge = lambda u: 40 + 34 * math.sin(u / 95)
    us = [-960 + 60 * i for i in range(33)]
    solimoes = [catmull([to_xy(u, edge(u)) for u in us] + [to_xy(960, 1000), to_xy(-960, 1000)], True)]
    negro = []
    for i in range(11):
        u = -700 + i * 140 + rng.uniform(-30, 30)
        solimoes.append(blob(*to_xy(u, edge(u) - 34), rng.uniform(60, 84), rng.uniform(14, 20), math.radians(-22), rng, 0.08))
        negro.append(blob(*to_xy(u + 70, edge(u + 70) + 34), rng.uniform(60, 84), rng.uniform(14, 20), math.radians(-22), rng, 0.08))
    top = lambda u: -430 + 26 * math.sin(u / 70 + 1)
    bottom = lambda u: 440 + 26 * math.sin(u / 80)
    banks = (
        catmull([to_xy(u, top(u)) for u in us] + [to_xy(960, -1000), to_xy(-960, -1000)], True),
        catmull([to_xy(u, bottom(u)) for u in us] + [to_xy(960, 1000), to_xy(-960, 1000)], True),
    )

    def keep(x, y, r):
        v = to_v(x, y)
        return v < -440 + r * 0.4 or v > 450 - r * 0.4

    shade, lit = canopy(rng, 160, 46, 70, keep, 0.78)
    return Landscape(
        scene.icon,
        scene.place,
        scene.light,
        scene.dark,
        (
            Group(
                "Forest",
                (Layer("5 Lit", paints["lit"], lit), Layer("4 Crowns", paints["crown"], shade), Layer("3 Bank", paints["bank"], banks)),
                0.55,
            ),
            Group("Waters", (Layer("2 Negro", paints["negro"], tuple(negro)), Layer("1 Solimoes", paints["solimoes"], tuple(solimoes)))),
        ),
    )


def iguacu(scene):
    rng = random.Random(scene.seed)
    paints = scene.paints
    cx, cy, radius = 250, 830, 130
    up = math.radians(-15)
    river, river_line = ribbon([(1150, 1010), (950, 985), (760, 960), (590, 925), (440, 880), (310, 840)], lambda t: 230 + 70 * t)
    canyon, canyon_line = ribbon([(cx, cy), (150, 880), (40, 930), (-120, 990)], lambda t: 190 - 40 * t)
    chasm = (circle(cx, cy, radius), canyon)
    foam = [crescent(cx, cy, radius + 4, up - math.radians(118), up + math.radians(118), 58)]
    for k in range(7):
        a = up + math.radians(-90 + k * 30)
        foam.append(oval(cx + math.cos(a) * radius * 0.72, cy + math.sin(a) * radius * 0.72, 30, 11, a))
    mist = (blob(cx + math.cos(up) * 26, cy + math.sin(up) * 26, radius * 0.62, radius * 0.5, up, rng, 0.14),)
    arcs = [crescent(cx, cy, r, up + math.radians(-68) + math.pi, up + math.radians(68) + math.pi, 20) for r in (112, 92, 72)]

    def keep(x, y, r):
        return (
            distance_to(river_line, x, y) > 140 + r * 0.5
            and distance_to(canyon_line, x, y) > 110 + r * 0.5
            and math.hypot(x - cx, y - cy) > radius + 50 + r * 0.5
        )

    shade, lit = canopy(rng, 220, 44, 70, keep, 0.78)
    return Landscape(
        scene.icon,
        scene.place,
        scene.light,
        scene.dark,
        (
            Group(
                "Falls",
                (
                    Layer("9 Red", paints["red"], (arcs[0],)),
                    Layer("8 Yellow", paints["yellow"], (arcs[1],)),
                    Layer("7 Blue", paints["blue"], (arcs[2],)),
                    Layer("6 Mist", paints["mist"], mist, 0.7),
                ),
                0.25,
            ),
            Group("Forest", (Layer("5 Lit", paints["lit"], lit), Layer("4 Crowns", paints["crown"], shade)), 0.55),
            Group(
                "Water",
                (
                    Layer("3 Foam", paints["foam"], tuple(foam)),
                    Layer("2 Chasm", paints["chasm"], chasm),
                    Layer("1 River", paints["river"], (river,)),
                ),
            ),
        ),
    )


def jalapao(scene):
    rng = random.Random(scene.seed)
    paints = scene.paints
    tilt = math.radians(-14)
    cos, sin = math.cos(tilt), math.sin(tilt)
    crests = []
    for row in range(-1, 7):
        start = rng.uniform(-320, -140)
        while start < SIZE + 100:
            length = rng.uniform(380, 500)
            base_y = row * 170 + rng.uniform(-16, 16)
            points = []
            for k in range(6):
                t = k / 5
                u = start + length * t
                v = base_y - 64 * math.sin(math.pi * t)
                points.append((u * cos - v * sin + 40, u * sin + v * cos + 140))
            crests.append(ribbon(points, lambda t: 14 + 40 * math.sin(math.pi * t) ** 0.7, steps=8, every=2)[0])
            start += length + rng.uniform(-20, 50)
    mesa = [(-300, -40), (-180, -110), (0, -130), (180, -120), (300, -60), (320, 40), (160, 110), (-40, 120), (-240, 90)]
    cliff = (catmull(shape(offset(mesa, 34), 860, 130, 1, math.radians(-24)), True),)
    top = (catmull(shape(mesa, 846, 116, 1, math.radians(-24)), True),)
    sx, sy = 196, 850
    shrubs = [blob(x, y, r, r * 0.8, rng.uniform(0, math.pi), rng, 0.18) for x, y, r in scatter(rng, 10, 18, 30, lambda x, y, r: math.hypot(x - 860, y - 130) < 230, 1.4)]
    palms = [circle(sx, sy, 112)]
    palms += [star(sx + 128 * math.cos(a), sy + 128 * math.sin(a), 52, 18, 8, a) for a in (k * math.tau / 9 + 0.2 for k in range(9))]
    return Landscape(
        scene.icon,
        scene.place,
        scene.light,
        scene.dark,
        (
            Group(
                "Spring",
                (
                    Layer("8 Glint", paints["glint"], (crescent(sx, sy, 40, math.radians(200), math.radians(290), 14),)),
                    Layer("7 Water", paints["water"], (circle(sx, sy, 62),)),
                    Layer("6 Sand", paints["sand"], (circle(sx, sy, 84),)),
                    Layer("5 Palms", paints["palm"], tuple(palms)),
                ),
                0.45,
            ),
            Group("Serra", (Layer("4 Shrubs", paints["shrub"], tuple(shrubs)), Layer("3 Top", paints["top"], top), Layer("2 Cliff", paints["cliff"], cliff)), 0.5),
            Group("Dunes", (Layer("1 Crest", paints["crest"], tuple(crests)),)),
        ),
    )


def pantanal(scene):
    rng = random.Random(scene.seed)
    paints = scene.paints
    centers = [(90, 120), (930, 90), (980, 420), (60, 520), (900, 980), (560, 990), (350, 300), (700, 520), (520, 160)]
    crowns, lit = [], []
    for x, y in centers:
        for _ in range(rng.randint(5, 7)):
            a, d = rng.uniform(0, math.tau), rng.uniform(0, 60)
            r = rng.uniform(32, 50)
            px, py = x + math.cos(a) * d, y + math.sin(a) * d
            crowns += broccoli(rng, px, py, r)
            lit.append(circle(px - r * 0.18, py - r * 0.22, r * 0.4))
    glow = [oval(rng.uniform(0, SIZE), rng.uniform(0, SIZE), rng.uniform(70, 130), rng.uniform(10, 16), math.radians(-8)) for _ in range(14)]
    grass = [blob(x, y, r, r * 0.6, rng.uniform(0, math.pi), rng, 0.2) for x, y, r in scatter(rng, 12, 40, 70, lambda x, y, r: all(math.hypot(x - cx, y - cy) > 120 for cx, cy in centers), 1.2)]
    bx, by, scale, turn = 270, 830, 0.85, math.radians(213)
    wing = [(10, -14), (60, -30), (120, -40), (180, -38), (214, -26), (196, -12), (200, 0), (180, 6), (190, 16), (160, 18), (100, 20), (20, 22)]
    wings = [catmull(shape(wing, bx, by, scale, turn), True), catmull(shape([(-x, y) for x, y in wing], bx, by, scale, turn), True)]
    wings.append(oval(*shape([(0, 0)], bx, by, scale, turn)[0], 26 * scale, 58 * scale, turn))
    wings.append(catmull(shape([(-20, 40), (0, 82), (20, 40)], bx, by, scale, turn), True))
    head = [catmull(shape([(-11, -40), (-10, -100), (0, -116), (10, -100), (11, -40)], bx, by, scale, turn), True)]
    head.append(polygon(shape([(-9, -112), (0, -196), (9, -112)], bx, by, scale, turn)))
    collar = (oval(*shape([(0, -46)], bx, by, scale, turn)[0], 14 * scale, 18 * scale, turn),)
    return Landscape(
        scene.icon,
        scene.place,
        scene.light,
        scene.dark,
        (
            Group(
                "Tuiuiu",
                (Layer("7 Collar", paints["collar"], collar), Layer("6 Head", paints["head"], tuple(head)), Layer("5 Wings", paints["wing"], tuple(wings))),
                0.45,
            ),
            Group("Islands", (Layer("4 Lit", paints["lit"], tuple(lit)), Layer("3 Crowns", paints["crown"], tuple(crowns))), 0.5),
            Group("Flood", (Layer("2 Glow", paints["glow"], tuple(glow), 0.7), Layer("1 Grass", paints["grass"], tuple(grass)))),
        ),
    )


def ipes(scene):
    rng = random.Random(scene.seed)
    paints = scene.paints
    trees = scatter(rng, 40, 68, 104, lambda x, y, r: True, 0.86)
    crowns, lit, shade = [], [], []
    for x, y, r in trees:
        crowns += broccoli(rng, x, y, r)
        lit.append(circle(x - r * 0.18, y - r * 0.22, r * 0.4))
        shade.append(circle(x + r * 0.2, y + r * 0.26, r * 0.95))
    grass = [blob(x, y, r, r * 0.7, rng.uniform(0, math.pi), rng, 0.25) for x, y, r in scatter(rng, 40, 18, 32, lambda x, y, r: all(math.hypot(x - tx, y - ty) > tr + r + 10 for tx, ty, tr in trees), 1.5)]
    petals = [circle(rng.uniform(0, SIZE), rng.uniform(0, SIZE), rng.uniform(5, 9)) for _ in range(70)]
    return Landscape(
        scene.icon,
        scene.place,
        scene.light,
        scene.dark,
        (
            Group("Ipes", (Layer("5 Lit", paints["lit"], tuple(lit)), Layer("4 Crowns", paints["crown"], tuple(crowns))), 0.3),
            Group("Shadow", (Layer("3 Shade", paints["shade"], tuple(shade), 0.55),)),
            Group("Ground", (Layer("2 Grass", paints["grass"], tuple(grass)), Layer("1 Petals", paints["petal"], tuple(petals)))),
        ),
    )


def veadeiros(scene):
    rng = random.Random(scene.seed)
    paints = scene.paints
    cx, cy, radius = 270, 830, 92
    river_points = [(1150, 1000), (930, 965), (720, 930), (540, 890), (400, 850), (cx, cy)]
    out_points = [(cx, cy), (150, 900), (20, 950), (-120, 990)]
    rock_in, line_in = ribbon(river_points, lambda t: 150)
    rock_out, line_out = ribbon(out_points, lambda t: 140)
    river = (ribbon(river_points, lambda t: 66)[0], ribbon(out_points, lambda t: 58)[0])
    up = math.atan2(850 - cy, 400 - cx)
    foam = [crescent(cx, cy, radius - 8, up - math.radians(55), up + math.radians(55), 34)]
    foam.append(ribbon([(400, 850), (340, 838), (cx + math.cos(up) * radius * 0.6, cy + math.sin(up) * radius * 0.6)], lambda t: 40 - 14 * t)[0])

    def keep(x, y, r):
        return distance_to(line_in, x, y) > 100 + r and distance_to(line_out, x, y) > 96 + r and math.hypot(x - cx, y - cy) > radius + 70 + r

    shade, lit = canopy(rng, 70, 26, 42, keep, 1.5)
    return Landscape(
        scene.icon,
        scene.place,
        scene.light,
        scene.dark,
        (
            Group("Cerrado", (Layer("6 Lit", paints["lit"], lit), Layer("5 Trees", paints["tree"], shade)), 0.5),
            Group(
                "Canyon",
                (
                    Layer("4 Foam", paints["foam"], tuple(foam)),
                    Layer("3 Pool", paints["pool"], (circle(cx, cy, radius),)),
                    Layer("2 River", paints["river"], river),
                    Layer("1 Rock", paints["rock"], (rock_in, rock_out, circle(cx, cy, radius + 46))),
                ),
                0.35,
            ),
        ),
    )


def sugarloaf(scene):
    rng = random.Random(scene.seed)
    paints = scene.paints
    loaf = shape([(-130, 0), (-100, -62), (-20, -88), (70, -70), (130, -24), (140, 20), (90, 70), (0, 86), (-90, 60)], 840, 880, 1.15, math.radians(-32))
    urca = shape([(-80, 0), (-50, -50), (20, -60), (76, -20), (70, 34), (10, 56), (-56, 40)], 676, 762, 1, math.radians(-20))
    green = (catmull(offset(loaf, 26), True), catmull(offset(urca, 14), True), ribbon([(720, 790), (760, 830)], lambda t: 70)[0])
    rock = (catmull(loaf, True), blob(690, 752, 44, 30, math.radians(-20), rng, 0.1))
    lit = (crescent(830, 872, 80, math.radians(160), math.radians(280), 48),)
    shore = [(-80, 600), (40, 640), (120, 720), (190, 820), (250, 900), (300, 990), (330, 1120), (-80, 1120)]
    land = (catmull(shore, True),)
    beach = (catmull(offset(shore, 30), True),)
    hills = (blob(70, 820, 80, 60, 0.4, rng, 0.12), blob(150, 980, 70, 50, 0.6, rng, 0.12))
    bx, by, turn = 480, 940, math.radians(-28)
    hull = (catmull(shape([(44, 0), (20, 12), (-34, 12), (-40, 0), (-34, -12), (20, -12)], bx, by, 1.5, turn), True),)
    sail = (catmull(shape([(30, -2), (8, -30), (-26, -40), (-10, -14), (-20, -2)], bx, by, 1.5, turn), True),)
    wake = (polygon(shape([(-38, 10), (-190, 40), (-190, -40), (-38, -10)], bx, by, 1.5, turn)),)
    return Landscape(
        scene.icon,
        scene.place,
        scene.light,
        scene.dark,
        (
            Group(
                "Morros",
                (Layer("8 Lit", paints["lit"], lit), Layer("7 Rock", paints["rock"], rock), Layer("6 Green", paints["green"], green)),
                0.5,
            ),
            Group(
                "Boat",
                (Layer("5 Sail", paints["sail"], sail), Layer("4 Hull", paints["hull"], hull), Layer("3 Wake", paints["wake"], wake, 0.45)),
                0.3,
            ),
            Group("Shore", (Layer("2 Land", paints["land"], land + hills), Layer("1 Beach", paints["beach"], beach)), 0.3),
        ),
    )


def landscapes():
    scenes = [
        amazon(
            Scene(
                "FiscalIcon",
                "Amazônia ao amanhecer",
                ("#1F4F34", "#0F3322"),
                ("#0B2116", "#04110A"),
                {
                    "river": Paint("#F6C46A", "#B98A4E", "#E2E2E2"),
                    "crown": Paint("#3C8A4E", "#1B4A2A", "#5E5E5E"),
                    "lit": Paint("#7DBE5A", "#2F6A38", "#8A8A8A"),
                    "pad": Paint("#58A845", "#2C6A2E", "#7A7A7A"),
                    "canoe": Paint("#8A5A34", "#5A3A22", "#4A4A4A"),
                },
                1,
            )
        ),
        lencois(
            Scene(
                "FiscalIconThemeSand",
                "Lençóis Maranhenses",
                ("#F6E9CB", "#E5CB98"),
                ("#3A3229", "#241E18"),
                {
                    "crest": Paint("#FFFCF4", "#5A4D3C", "#C4C4C4"),
                    "green": Paint("#34C2A4", "#1F6E66", "#8C8C8C"),
                    "blue": Paint("#2385C8", "#16547A", "#5E5E5E"),
                },
                2,
            )
        ),
        noronha(
            Scene(
                "FiscalIconThemeSea",
                "Fernando de Noronha",
                ("#1689B8", "#0A4C7A"),
                ("#0A3550", "#041A2A"),
                {
                    "shallow": Paint("#3FD3CC", "#1D7C84", "#A0A0A0"),
                    "foam": Paint("#EAFBF8", "#9FC4C6", "#F2F2F2"),
                    "rock": Paint("#6B5444", "#3A2C22", "#4A4A4A"),
                    "green": Paint("#4FA45A", "#24572E", "#6E6E6E"),
                    "hill": Paint("#2F7A3E", "#143A1E", "#545454"),
                    "beach": Paint("#F4DFA6", "#8A7650", "#DADADA"),
                    "turtle": Paint("#7A9A54", "#3E5230", "#7C7C7C"),
                    "spots": Paint("#4E6B34", "#26361A", "#5A5A5A"),
                },
                3,
            )
        ),
        amazon(
            Scene(
                "FiscalIconAmazonDay",
                "Amazônia ao meio-dia",
                ("#2C6B3E", "#1B4F2C"),
                ("#0E2A1A", "#06160D"),
                {
                    "river": Paint("#4FA8DC", "#1F5A80", "#D0D0D0"),
                    "crown": Paint("#3F9A4C", "#1D4E2A", "#5E5E5E"),
                    "lit": Paint("#8CCB5E", "#357040", "#8A8A8A"),
                    "pad": Paint("#5DB04A", "#2C6A2E", "#7A7A7A"),
                    "boto": Paint("#F28BA8", "#B05A74", "#9A9A9A"),
                    "back": Paint("#FAC4D3", "#D88AA0", "#BABABA"),
                },
                1,
            )
        ),
        meeting(
            Scene(
                "FiscalIconAmazonRiver",
                "Encontro das Águas",
                ("#2E241A", "#1C150F"),
                ("#16110C", "#0A0806"),
                {
                    "solimoes": Paint("#D29A5C", "#7A5434", "#BDBDBD"),
                    "negro": Paint("#2E241A", "#16110C", "#3A3A3A"),
                    "bank": Paint("#1E5C3B", "#0E2D1D", "#4A4A4A"),
                    "crown": Paint("#2F7A4E", "#164029", "#5E5E5E"),
                    "lit": Paint("#6DB45E", "#2E6A3C", "#8A8A8A"),
                },
                4,
            )
        ),
        iguacu(
            Scene(
                "FiscalIconThemeForest",
                "Cataratas do Iguaçu",
                ("#2E7A45", "#1F5A33"),
                ("#0F2A1A", "#071810"),
                {
                    "river": Paint("#5DB2D0", "#245A70", "#B8B8B8"),
                    "chasm": Paint("#173F4F", "#0A1F28", "#3A3A3A"),
                    "foam": Paint("#FFFFFF", "#CFE6EE", "#F4F4F4"),
                    "crown": Paint("#3F9A55", "#1D4A2A", "#5E5E5E"),
                    "lit": Paint("#86C964", "#356E3C", "#8A8A8A"),
                    "mist": Paint("#FFFFFF", "#BFD8E0", "#E8E8E8"),
                    "red": Paint("#F25C5C", "#B04040", "#9A9A9A"),
                    "yellow": Paint("#FFD34E", "#C9A23A", "#D0D0D0"),
                    "blue": Paint("#4F8FE0", "#2E5A9A", "#6A6A6A"),
                },
                5,
            )
        ),
        jalapao(
            Scene(
                "FiscalIconThemeAnnatto",
                "Jalapão",
                ("#EE9A5E", "#D9653F"),
                ("#4C2316", "#2E140C"),
                {
                    "crest": Paint("#F9C79A", "#7A4A30", "#C8C8C8"),
                    "cliff": Paint("#8E2F23", "#471812", "#3A3A3A"),
                    "top": Paint("#C9603A", "#6E3220", "#6A6A6A"),
                    "shrub": Paint("#6E8A3A", "#36451D", "#4E4E4E"),
                    "palm": Paint("#3F8A3A", "#1F4A1D", "#555555"),
                    "sand": Paint("#FFF1D6", "#BFA98A", "#EEEEEE"),
                    "water": Paint("#2CC9D0", "#16707A", "#A8A8A8"),
                    "glint": Paint("#C8FAFA", "#7ACACE", "#F2F2F2"),
                },
                6,
            )
        ),
        pantanal(
            Scene(
                "FiscalIconThemeIndigo",
                "Pantanal",
                ("#3557A8", "#1E3A7A"),
                ("#0E1A38", "#060C1A"),
                {
                    "grass": Paint("#4A72B8", "#1C2E58", "#5A5A5A"),
                    "glow": Paint("#B9CCF5", "#4A5F8A", "#C8C8C8"),
                    "crown": Paint("#1F4A5A", "#0E2530", "#3A3A3A"),
                    "lit": Paint("#3F7A82", "#1C3E46", "#6A6A6A"),
                    "wing": Paint("#FFFFFF", "#DCE2EE", "#F4F4F4"),
                    "head": Paint("#1A1A1F", "#0A0A0E", "#2A2A2A"),
                    "collar": Paint("#E5484D", "#A8323A", "#8A8A8A"),
                },
                7,
            )
        ),
        ipes(
            Scene(
                "FiscalIconThemeIpe",
                "Ipês em flor",
                ("#FBE3EC", "#F2B8CF"),
                ("#3A1F2C", "#24121B"),
                {
                    "petal": Paint("#F08DBC", "#7A3A5A", "#BDBDBD"),
                    "grass": Paint("#8FB25A", "#3E5A26", "#8A8A8A"),
                    "shade": Paint("#9A2E66", "#12070D", "#4A4A4A"),
                    "crown": Paint("#D9418C", "#8E2A5C", "#6A6A6A"),
                    "lit": Paint("#F79AC6", "#B8487E", "#A8A8A8"),
                },
                8,
            )
        ),
        veadeiros(
            Scene(
                "FiscalIconThemeSavanna",
                "Chapada dos Veadeiros",
                ("#F0C060", "#D9933A"),
                ("#4C3314", "#2E1F0A"),
                {
                    "rock": Paint("#8A5226", "#4A2C12", "#4A4A4A"),
                    "river": Paint("#4FBFC4", "#1F6E72", "#B0B0B0"),
                    "pool": Paint("#1F7A84", "#0E3E44", "#6A6A6A"),
                    "foam": Paint("#FFFFFF", "#CFE6E6", "#F4F4F4"),
                    "tree": Paint("#6E7A2A", "#343A12", "#5A5A5A"),
                    "lit": Paint("#A9B048", "#5A6020", "#8A8A8A"),
                },
                9,
            )
        ),
        sugarloaf(
            Scene(
                "FiscalIconThemeGraphite",
                "Pão de Açúcar",
                ("#6F7E8E", "#4C5866"),
                ("#22272D", "#15181C"),
                {
                    "beach": Paint("#E8DCC0", "#77705E", "#E0E0E0"),
                    "land": Paint("#4E6E50", "#25352A", "#4A4A4A"),
                    "wake": Paint("#FFFFFF", "#AEB6C0", "#F4F4F4"),
                    "hull": Paint("#2A313A", "#0E1115", "#2E2E2E"),
                    "sail": Paint("#FFFFFF", "#D6DCE3", "#F4F4F4"),
                    "green": Paint("#3F6E46", "#1E3824", "#5A5A5A"),
                    "rock": Paint("#C9CFD6", "#6E747C", "#B4B4B4"),
                    "lit": Paint("#EEF1F4", "#959BA3", "#E0E0E0"),
                },
                10,
            )
        ),
    ]
    return {landscape.icon: landscape for landscape in scenes}


def validate(landscape):
    problems = []
    if not landscape.groups or len(landscape.groups) > 3:
        problems.append(f"needs 1 to 3 groups, has {len(landscape.groups)}")
    layers = [layer for group in landscape.groups for layer in group.layers]
    if not layers:
        problems.append("has no layer")
    if len(layers) > MAX_LAYERS:
        problems.append(f"has {len(layers)} layers, the limit is {MAX_LAYERS}")
    colors = [*landscape.light, *landscape.dark]
    for layer in layers:
        if not layer.paths:
            problems.append(f"layer {layer.name} has no shape")
        colors += [layer.paint.light, layer.paint.dark, layer.paint.tinted]
    problems += [f"color {c} is not #RRGGBB" for c in colors if not HEX.match(c)]
    if problems:
        raise LandscapeError(f"landscape {landscape.icon}: {problems[0]}")


def srgb(color):
    channels = [int(color[i : i + 2], 16) / 255 for i in (1, 3, 5)]
    return "srgb:" + ",".join(f"{c:.5f}" for c in [*channels, 1.0])


def svg(paths):
    body = "".join(f'<path d="{d}" fill="#FFFFFF"/>\n' for d in paths)
    return (
        f'<svg width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}" fill="none" '
        f'xmlns="http://www.w3.org/2000/svg">\n{body}</svg>\n'
    )


def layer_json(layer):
    return {
        "fill-specializations": [
            {"value": {"solid": srgb(layer.paint.light)}},
            {"appearance": "dark", "value": {"solid": srgb(layer.paint.dark)}},
            {"appearance": "tinted", "value": {"solid": srgb(layer.paint.tinted)}},
        ],
        "glass": False,
        "image-name": f"{layer.name}.svg",
        "name": layer.name,
        "opacity": layer.opacity,
        "position": {"scale": 1, "translation-in-points": [0, 0]},
    }


def group_json(group):
    return {
        "layers": [layer_json(layer) for layer in group.layers],
        "name": group.name,
        "shadow": {"kind": "neutral", "opacity": group.shadow},
        "specular": False,
        "translucency": {"enabled": False, "value": 0.5},
    }


def read_map():
    document = json.loads((MAP_SOURCE / "icon.json").read_text())
    group = next(g for g in document["groups"] if g["name"] == "Map")
    files = {name: (MAP_SOURCE / "Assets" / name).read_bytes() for name in MAP_FILES}
    return group, files


def write(landscape, map_group, map_files):
    package = ICONS / f"{landscape.icon}.icon"
    assets = package / "Assets"
    if assets.exists():
        shutil.rmtree(assets)
    assets.mkdir(parents=True)
    for name, data in map_files.items():
        (assets / name).write_bytes(data)
    for group in landscape.groups:
        for layer in group.layers:
            (assets / f"{layer.name}.svg").write_text(svg(layer.paths))
    document = {
        "fill-specializations": [
            {"value": {"linear-gradient": [srgb(c) for c in landscape.light]}},
            {"appearance": "dark", "value": {"linear-gradient": [srgb(c) for c in landscape.dark]}},
        ],
        "groups": [map_group, *[group_json(g) for g in landscape.groups]],
        "supported-platforms": {"circles": ["watchOS"], "squares": "shared"},
    }
    (package / "icon.json").write_text(json.dumps(document, indent=2, sort_keys=True) + "\n")


def main(argv):
    catalog = landscapes()
    names = argv or list(catalog)
    try:
        unknown = [n for n in names if n not in catalog]
        if unknown:
            raise LandscapeError(f"landscape {unknown[0]}: unknown icon")
        chosen = [catalog[n] for n in names]
        for landscape in chosen:
            validate(landscape)
    except LandscapeError as error:
        print(error, file=sys.stderr)
        return 1
    map_group, map_files = read_map()
    for landscape in chosen:
        write(landscape, map_group, map_files)
        print(f"{landscape.icon}: {landscape.place}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
