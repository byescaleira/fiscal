import argparse
import base64
import math
import pathlib
import random
import tempfile
from io import BytesIO

from PIL import Image

from render import chrome

SOURCE = pathlib.Path(__file__).resolve().parent
MEDIA = SOURCE.parent
ICON = SOURCE / "raw" / "keyart" / "icon.png"
SCREENS = SOURCE / "raw" / "iphone"

PAPER = "#fbf5ea"
CREAM = "#f3e7cf"
MUSTARD = "#e3b04b"
OLIVE = "#8fa84e"
TEAL = "#4f9a90"
DENIM = "#5f86b3"
PLUM = "#9a5f82"
BACKGROUND = "radial-gradient(70% 80% at 50% 45%, #e0814a 0%, #c9642c 42%, #a8432a 100%)"
SHADOW = "rgba(70, 20, 5, 0.45)"
METAL = ("#33080f", "#8c3443", "#5c1a26")

SCALE = 1320 / 414
SCREEN_RATIO = 2868 / 1320

SHOWCASE = [
    ("home", 160, -4, (20, 200, 394, 420), 3),
    ("editor", -20, 0, (20, 200, 394, 420), 0),
    ("settings", 60, 4, (20, 200, 394, 420), -3),
]


def page(width, height, body, rays=None):
    burst = ""
    if rays:
        cx, cy, radius = rays
        stops = ",".join(
            f"rgba(251,245,234,{0.16 if i % 2 == 0 else 0}) {i * 10}deg {(i + 1) * 10}deg" for i in range(36)
        )
        burst = (
            f"<div style='position:absolute;left:{cx - radius}px;top:{cy - radius}px;width:{radius * 2}px;height:{radius * 2}px;"
            f"border-radius:50%;background:conic-gradient({stops});"
            f"-webkit-mask:radial-gradient(circle, #000 0%, #000 35%, transparent 70%);mask:radial-gradient(circle, #000 0%, #000 35%, transparent 70%)'></div>"
        )
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>
html, body {{ margin: 0; width: {width}px; height: {height}px; overflow: hidden; }}
body {{ position: relative; background: {BACKGROUND}; }}
.glow {{ position: absolute; inset: 0; background: radial-gradient(35% 45% at 50% 48%, rgba(255, 236, 200, 0.35), transparent 70%); }}
.abs {{ position: absolute; }}
.icon img {{ width: 100%; height: 100%; display: block; filter: drop-shadow(0 {height * 0.03:.0f}px {height * 0.05:.0f}px {SHADOW}); }}
svg {{ overflow: visible; }}
</style></head><body>{burst}<div class="glow"></div>{body}</body></html>"""


def icon(cx, cy, size):
    data = base64.b64encode(ICON.read_bytes()).decode()
    return (
        f"<div class='abs icon' style='left:{cx - size / 2}px;top:{cy - size / 2}px;width:{size}px;height:{size}px'>"
        f"<img src='data:image/png;base64,{data}'></div>"
    )


def shape(size, color, kind):
    if kind == "circle":
        return f"<svg width='{size}' height='{size}'><circle cx='{size / 2}' cy='{size / 2}' r='{size / 2}' fill='{color}'/></svg>", size, size
    if kind == "pill":
        return f"<svg width='{size}' height='{size * 0.4}'><rect width='{size}' height='{size * 0.4}' rx='{size * 0.2}' fill='{color}'/></svg>", size, size * 0.4
    return f"<svg width='{size}' height='{size}'><rect width='{size}' height='{size}' rx='{size * 0.2}' fill='{color}'/></svg>", size, size


def overlaps(box, boxes, margin):
    x, y, w, h = box
    for bx, by, bw, bh in boxes:
        if x < bx + bw + margin and x + w + margin > bx and y < by + bh + margin and y + h + margin > by:
            return True
    return False


def confetti(width, height, blocked, count, scale, seed, center=None, spread=None):
    rng = random.Random(seed)
    placed = list(blocked)
    out = ""
    colors = [MUSTARD, PAPER, OLIVE, TEAL, DENIM, PLUM, CREAM]
    attempts = 0
    while count > 0 and attempts < 8000:
        attempts += 1
        svg, w, h = shape(scale * rng.uniform(0.14, 0.32), rng.choice(colors), rng.choice(["circle", "pill", "square"]))
        if center:
            angle = rng.uniform(0, math.tau)
            radius = rng.uniform(spread[0], spread[1])
            x = center[0] + math.cos(angle) * radius * (width / height if width > height else 1) - w / 2
            y = center[1] + math.sin(angle) * radius - h / 2
        else:
            x, y = rng.uniform(-w * 0.3, width - w * 0.7), rng.uniform(-h * 0.3, height - h * 0.7)
        if x < -w * 0.4 or y < -h * 0.4 or x > width - w * 0.6 or y > height - h * 0.6:
            continue
        if overlaps((x, y, w, h), placed, scale * 0.12):
            continue
        placed.append((x, y, w, h))
        rotation = rng.uniform(-35, 35)
        out += f"<div class='abs' style='left:{x}px;top:{y}px;transform:rotate({rotation:.1f}deg)'>{svg}</div>"
        count -= 1
    return out


def header(width, height):
    u = height
    size = u * 0.62
    cx, cy = width / 2, u * 0.5
    blocked = [(cx - size * 0.56, cy - size * 0.56, size * 1.12, size * 1.12)]
    body = confetti(width, height, blocked, 110, u * 0.1, 7, center=(cx, cy), spread=(size * 0.6, u * 1.0))
    body += icon(cx, cy, size)
    return page(width, height, body, rays=(cx, cy, u * 1.2))


def crop_uri(screen, box):
    image = Image.open(SCREENS / f"{screen}.png").convert("RGB")
    crop = image.crop(tuple(round(v * SCALE) for v in box))
    buffer = BytesIO()
    crop.save(buffer, "PNG")
    return "data:image/png;base64," + base64.b64encode(buffer.getvalue()).decode(), crop.width / crop.height


def iphone(x, y, width, screen, rotation):
    uri, _ = crop_uri(screen, (0, 0, 414, 899))
    dark, light, mid = METAL
    metal = width * 0.016
    bezel = width * 0.022
    inner = width - 2 * (metal + bezel)
    height = inner * SCREEN_RATIO + 2 * (metal + bezel)
    radius = width * 0.18
    gradient = f"linear-gradient(90deg,{dark},{light} 3%,{mid} 9%,{mid} 91%,{light} 97%,{dark})"
    buttons = ""
    for side, top, length in (("left", 0.17, 0.045), ("left", 0.245, 0.08), ("left", 0.34, 0.08), ("right", 0.27, 0.12), ("right", 0.58, 0.07)):
        buttons += (
            f"<span class='abs' style='{side}:-{width * 0.011}px;top:{height * top}px;width:{width * 0.014}px;height:{height * length}px;"
            f"border-radius:{width * 0.006}px;background:linear-gradient(90deg,{dark},{light},{mid})'></span>"
        )
    return (
        f"<div class='abs' style='left:{x}px;top:{y}px;width:{width}px;height:{height}px;transform:rotate({rotation}deg);transform-origin:50% 0'>{buttons}"
        f"<div class='abs' style='inset:0;border-radius:{radius}px;padding:{metal}px;box-sizing:border-box;background:{gradient};"
        f"box-shadow:inset 0 0 0 {width * 0.002}px rgba(255,255,255,0.2), inset 0 {width * 0.003}px {width * 0.004}px rgba(255,255,255,0.25), "
        f"0 {width * 0.06}px {width * 0.16}px -{width * 0.04}px rgba(60,10,20,0.6)'>"
        f"<div style='height:100%;box-sizing:border-box;background:#050505;border-radius:{radius - metal}px;padding:{bezel}px;position:relative'>"
        f"<img src='{uri}' style='display:block;width:100%;border-radius:{radius - metal - bezel}px'>"
        f"<span class='abs' style='left:50%;top:{bezel + inner * 0.028}px;width:{inner * 0.27}px;height:{inner * 0.082}px;"
        f"transform:translateX(-50%);border-radius:999px;background:#000'></span></div></div></div>"
    ), metal + bezel, inner / 414


def lifted(x, y, width, screen, box, rotation):
    uri, ratio = crop_uri(screen, box)
    height = width / ratio
    return (
        f"<div class='abs' style='left:{x}px;top:{y}px;width:{width}px;height:{height}px;border-radius:{width * 0.055}px;overflow:hidden;"
        f"transform:rotate({rotation}deg);box-shadow:0 {width * 0.05}px {width * 0.14}px -{width * 0.03}px rgba(60,15,5,0.6), "
        f"0 0 0 {width * 0.003}px rgba(255,255,255,0.6)'><img src='{uri}' style='display:block;width:100%;height:100%'></div>"
    )


def search(width, height):
    k = width / 3840
    phone_w = 1100 * k
    gap = 150 * k
    left = (width - 3 * phone_w - 2 * gap) / 2
    body = confetti(width, height, [(left - 60 * k, 120 * k, 3 * phone_w + 2 * gap + 120 * k, height)], 24, 220 * k, 3)
    heroes = ""
    for index, (screen, top, rotation, box, tilt) in enumerate(SHOWCASE):
        x = left + index * (phone_w + gap)
        y = 480 * k + top * k
        html, inset, points = iphone(x, y, phone_w, screen, rotation)
        body += html
        hero_w = phone_w * 1.06
        center = x + phone_w / 2 + math.sin(math.radians(-rotation)) * (inset + box[1] * points)
        heroes += lifted(center - hero_w / 2, y + inset + box[1] * points - 30 * k, hero_w, screen, box, tilt)
    return page(width, height, body + heroes, rays=(width / 2, height * 0.5, 2600 * k))


TARGETS = {
    "header-3840x1646": (header, 3840, 1646),
    "header-5244x2950": (header, 5244, 2950),
    "search-3840x2560": (search, 3840, 2560),
    "search-1920x1280": (search, 1920, 1280),
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("targets", nargs="*", default=list(TARGETS), help=", ".join(TARGETS))
    args = parser.parse_args()
    unknown = set(args.targets) - set(TARGETS)
    if unknown:
        parser.error(f"unknown targets: {', '.join(sorted(unknown))}")
    with tempfile.TemporaryDirectory() as work:
        for name in args.targets:
            builder, width, height = TARGETS[name]
            path = pathlib.Path(work) / f"{name}.html"
            path.write_text(builder(width, height))
            folder = "header" if name.startswith("header") else "search"
            out = MEDIA / folder / f"{name}.png"
            chrome(path, out, width, height)
            print(out)


if __name__ == "__main__":
    main()
