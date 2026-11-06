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
    canoe = (blob(430, 856, 62, 15, math.radians(18), rng, 0.0, 12),)
    return Landscape(
        scene.icon,
        scene.place,
        scene.light,
        scene.dark,
        (
            Group(
                "Life",
                (Layer("5 Canoe", paints["canoe"], canoe), Layer("4 Pads", paints["pad"], pads)),
                0.35,
            ),
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
    for fx, fy, sx, a in [(30, -24, 1, -40), (-30, -24, -1, 220), (24, 30, 1, 40), (-24, 30, -1, 140)]:
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
