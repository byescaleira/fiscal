import argparse
import pathlib
import tempfile

from PIL import Image

from render import chrome

SOURCE = pathlib.Path(__file__).resolve().parent
MEDIA = SOURCE.parent
RAW = SOURCE / "raw"

SIZES = {
    "iphone": (1320, 2868),
    "iphone-6.3": (1206, 2622),
    "ipad": (2064, 2752),
}


def uri(path: pathlib.Path) -> str:
    return path.resolve().as_uri()


def raw(name: str) -> pathlib.Path:
    return RAW / name


def copy(title, subtitle, left, top, width, size, align="center"):
    sub = f"<p style='font-size:{size * 0.42:.0f}px'>{subtitle}</p>" if subtitle else ""
    return (
        f"<div class='copy' style='left:{left}px;top:{top}px;width:{width}px;text-align:{align}'>"
        f"<h1 style='font-size:{size}px'>{title}</h1>{sub}</div>"
    )


def iphone(shot, left, top, width):
    return (
        f"<div class='iphone' style='--d:{width}px;left:{left}px;top:{top}px'>"
        "<span class='button action'></span><span class='button up'></span>"
        "<span class='button down'></span><span class='button power'></span>"
        f"<div class='bezel'><div class='screen'><img class='shot' src='{uri(raw(shot))}'><span class='island'></span></div></div></div>"
    )


def ipad(shot, left, top, width):
    image = Image.open(raw(shot))
    ratio = image.height / image.width
    return (
        f"<div class='ipad' style='--d:{width}px;--ratio:{ratio};left:{left}px;top:{top}px'>"
        f"<div class='screen'><img class='shot' src='{uri(raw(shot))}'></div></div>"
    )


def card(shot, crop, scale, left, top, radius=66):
    x, y, w, h = crop
    image = Image.open(raw(shot))
    return (
        f"<div class='card' style='--s:{scale};left:{left}px;top:{top}px;width:{w * scale:.1f}px;"
        f"height:{h * scale:.1f}px;border-radius:{radius * scale:.1f}px;"
        f"background-image:url({uri(raw(shot))});background-size:{image.width * scale:.1f}px auto;"
        f"background-position:{-x * scale:.1f}px {-y * scale:.1f}px'></div>"
    )


def page(size, background, body, light=False):
    width, height = size
    style = uri(SOURCE / "style.css")
    return (
        "<!doctype html><html><head><meta charset='utf-8'>"
        f"<link rel='stylesheet' href='{style}'>"
        f"<style>:root{{--w:{width}px;--h:{height}px;--bg:{background}}}</style></head>"
        f"<body class='{'light' if light else ''}'>{body}</body></html>"
    )


IPHONE = [
    ("01-home", "var(--orange)", False, "Everything in one place",
     "Open Fiscal and what matters is already on the first screen.",
     "home.png", []),
    ("02-editor", "var(--teal)", False, "Add in seconds",
     "A focused editor with only the fields you need.",
     "editor.png", []),
    ("03-sync", "var(--denim)", False, "On all your devices",
     "Synced with your own iCloud. No account, no ads, no tracking.",
     "settings.png", []),
    ("04-appearance", "var(--mustard)", True, "Make it yours",
     "Light or dark, with the accent color you like best.",
     "appearance.png", []),
]

IPAD = [
    ("01-home", "var(--orange)", False, "Everything in one place",
     "Open Fiscal and what matters is already on the first screen.",
     "ipad/home.png"),
    ("02-editor", "var(--teal)", False, "Details beside the list",
     "Edit any item next to the list, with room to spare.",
     "ipad/editor.png"),
]


def iphone_slide(spec):
    name, background, light, title, subtitle, shot, cards = spec
    width = 900
    body = copy(title, subtitle, 110, 170, 1100, 120)
    body += iphone(shot, (1320 - width * 1.078) / 2, 720, width)
    body += "".join(card(*item) for item in cards)
    return name, page(SIZES["iphone"], background, body, light)


def ipad_slide(spec):
    name, background, light, title, subtitle, shot = spec
    width = 1600
    body = copy(title, subtitle, 132, 170, 1800, 132)
    body += ipad(shot, (2064 - width * 1.068) / 2, 720, width)
    return name, page(SIZES["ipad"], background, body, light)


def medium(path: pathlib.Path):
    out = MEDIA / "iphone-6.3" / path.name
    out.parent.mkdir(parents=True, exist_ok=True)
    Image.open(path).convert("RGB").resize(SIZES["iphone-6.3"], Image.LANCZOS).save(out, optimize=True)
    print(out)


def build(device, slides, folder, builder):
    out = MEDIA / folder
    with tempfile.TemporaryDirectory() as work:
        for spec in slides:
            name, html = builder(spec)
            path = pathlib.Path(work) / f"{name}.html"
            path.write_text(html)
            size = SIZES[device]
            chrome(path, out / f"{name}.png", *size)
            print(out / f"{name}.png")
            if device == "iphone":
                medium(out / f"{name}.png")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("targets", nargs="*", default=["iphone", "ipad"], help="iphone, ipad or both")
    args = parser.parse_args()
    unknown = set(args.targets) - {"iphone", "ipad"}
    if unknown:
        parser.error(f"unknown targets: {', '.join(sorted(unknown))}")
    if "iphone" in args.targets:
        build("iphone", [(*s[:5], "iphone/" + s[5], [("iphone/" + c[0], *c[1:]) for c in s[6]]) for s in IPHONE], "iphone", iphone_slide)
    if "ipad" in args.targets:
        build("ipad", IPAD, "ipad", ipad_slide)


if __name__ == "__main__":
    main()
