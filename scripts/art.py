#!/usr/bin/env python3
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "scripts", "art-works.json")
RESOURCE = os.path.join(ROOT, "FiscalKit", "Sources", "FiscalResource")
CATALOG = os.path.join(RESOURCE, "Assets", "Art.xcassets")
MANIFEST = os.path.join(RESOURCE, "art-credits.json")
API = "https://commons.wikimedia.org/w/api.php"
AGENT = "FiscalArtFetch/1.0 (https://fiscal.byescaleira.com)"
PD_SHORT_NAMES = {"Public domain", "CC0"}
PD_LICENSES = {"pd", "cc0"}
MARK_URL = "https://creativecommons.org/publicdomain/mark/1.0/"
CC0_URL = "https://creativecommons.org/publicdomain/zero/1.0/"
TEMPLATE_URL = "https://commons.wikimedia.org/wiki/Template:"
CATALOG_INFO = {"info": {"author": "xcode", "version": 1}}
DISTINCT_COLOR = 28


def request(url, method="GET"):
    return urllib.request.Request(url, headers={"User-Agent": AGENT}, method=method)


def api(params):
    query = dict(params, format="json", formatversion="2")
    url = API + "?" + urllib.parse.urlencode(query)
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request(url), timeout=30) as response:
                return json.load(response)
        except OSError:
            time.sleep(2 + attempt * 3)
    raise SystemExit("Commons API unavailable: " + url)


def metadata(titles, width):
    found = {}
    for start in range(0, len(titles), 20):
        batch = titles[start:start + 20]
        data = api({
            "action": "query", "prop": "imageinfo", "iiprop": "url|extmetadata|size|mime",
            "iiurlwidth": str(width), "titles": "|".join(batch),
        })
        aliases = {item["to"]: item["from"] for item in data["query"].get("normalized", [])}
        for page in data["query"]["pages"]:
            title = aliases.get(page["title"], page["title"])
            found[title] = page.get("imageinfo", [None])[0]
    return found


def field(info, key):
    value = (info.get("extmetadata", {}).get(key) or {}).get("value") or ""
    return re.sub(r"<[^>]+>", "", value).strip()


def license_url(work, info):
    categories = field(info, "Categories").split("|")
    if "CC-PD-Mark" in categories:
        return MARK_URL
    if field(info, "License") == "cc0":
        return CC0_URL
    inner = re.search(r"\(([^)]+)\)", work["license"])
    return TEMPLATE_URL + (inner.group(1) if inner else work["license"])


def gate(work, artist, info, limit):
    if info is None:
        return ["arquivo não encontrado no Commons"]
    reasons = []
    if field(info, "LicenseShortName") not in PD_SHORT_NAMES:
        reasons.append("licença " + field(info, "LicenseShortName"))
    if field(info, "License") not in PD_LICENSES:
        reasons.append("código de licença " + field(info, "License"))
    if work["licenseCategory"] not in field(info, "Categories").split("|"):
        reasons.append("categoria " + work["licenseCategory"] + " ausente")
    if artist["died"] > limit:
        reasons.append("autor morto em " + str(artist["died"]))
    if not info.get("mime", "").startswith("image/"):
        reasons.append("tipo " + info.get("mime", "?"))
    if not info.get("thumburl"):
        reasons.append("sem miniatura")
    return reasons


def remote_size(url):
    try:
        with urllib.request.urlopen(request(url, "HEAD"), timeout=30) as response:
            return int(response.headers.get("Content-Length") or 0)
    except OSError:
        return 0


def run(arguments):
    return subprocess.run(arguments, check=True, capture_output=True, text=True).stdout


def download_once(url, path):
    result = subprocess.run(
        ["curl", "-fsSL", "--retry", "3", "--max-time", "180", "-A", AGENT, "-o", path, url],
        capture_output=True)
    return result.returncode == 0 and run(["file", "--mime-type", "-b", path]).startswith("image/")


def download(work, info, path):
    if download_once(info["thumburl"], path):
        return info["thumburl"]
    wider = metadata([work["file"]], 1920)[work["file"]]["thumburl"]
    if download_once(wider, path):
        return wider
    raise SystemExit("Download failed for " + work["file"])


def dimensions(path):
    output = run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", path])
    values = dict(re.findall(r"(pixelWidth|pixelHeight): (\d+)", output))
    return int(values["pixelWidth"]), int(values["pixelHeight"])


def convert(source, target, max_side, quality):
    width, height = dimensions(source)
    arguments = ["sips", "-s", "format", "jpeg", "-s", "formatOptions", str(quality)]
    if max(width, height) > max_side:
        arguments += ["-Z", str(max_side)]
    run(arguments + [source, "--out", target])


def bitmap(path):
    data = open(path, "rb").read()
    offset, = struct.unpack_from("<I", data, 10)
    width, height = struct.unpack_from("<ii", data, 18)
    bits, = struct.unpack_from("<H", data, 28)
    step = bits // 8
    stride = (width * step + 3) & ~3
    rows = []
    for row in range(abs(height)):
        line = offset + row * stride
        rows.append([tuple(data[line + x * step + 2 - c] for c in range(3)) for x in range(width)])
    return rows if height < 0 else rows[::-1]


def average(colors):
    return tuple(round(sum(color[i] for color in colors) / len(colors)) for i in range(3))


def distance(first, second):
    return sum((a - b) ** 2 for a, b in zip(first, second)) ** 0.5


def palette(path, scratch):
    grid_path = os.path.join(scratch, "palette.bmp")
    run(["sips", "-z", "3", "3", "-s", "format", "bmp", path, "--out", grid_path])
    grid = bitmap(grid_path)
    regions = [average(row) for row in grid] + [average([row[x] for row in grid]) for x in range(3)]
    chosen = [regions[1]]
    for color in regions:
        if len(chosen) < 3 and all(distance(color, other) > DISTINCT_COLOR for other in chosen):
            chosen.append(color)
    if len(chosen) < 2:
        chosen.append(max(regions, key=lambda color: distance(color, chosen[0])))
    return ["#%02X%02X%02X" % color for color in chosen]


def credit(work, artist):
    holder = work["holder"]
    origin = "Acervo " + holder if work["holderKind"] == "institution" else holder[0].upper() + holder[1:]
    return "%s, %s (%s). Domínio público. %s via Wikimedia Commons." % (
        artist["name"], work["title"], work["year"], origin)


def write_json(path, value):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(value, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


def check(source, found):
    accepted = True
    for work in source["works"]:
        artist = source["artists"][work["artist"]]
        info = found.get(work["file"])
        reasons = gate(work, artist, info, source["deathYearLimit"])
        accepted = accepted and not reasons
        size = remote_size(info["thumburl"]) if info and not reasons else 0
        status = "ok" if not reasons else "recusada: " + "; ".join(reasons)
        print("%-44s %-10s %5s KB  %s" % (work["id"], work["series"], size // 1024, status))
    return accepted


def fetch(source, found):
    scratch = tempfile.mkdtemp(prefix="fiscal-art-")
    staging = os.path.join(scratch, "Art.xcassets")
    os.makedirs(staging)
    write_json(os.path.join(staging, "Contents.json"), CATALOG_INFO)
    works, lead_palette, total = [], None, 0
    collection = source["collection"]
    for work in source["works"]:
        artist = source["artists"][work["artist"]]
        info = found[work["file"]]
        asset = "art-" + work["id"]
        original = os.path.join(scratch, work["id"] + ".download")
        fetched = download(work, info, original)
        imageset = os.path.join(staging, asset + ".imageset")
        os.makedirs(imageset)
        image = os.path.join(imageset, asset + ".jpg")
        convert(original, image, source["maxSide"], source["quality"])
        write_json(os.path.join(imageset, "Contents.json"), dict(
            images=[{"filename": asset + ".jpg", "idiom": "universal"}], **CATALOG_INFO))
        total += os.path.getsize(image)
        if work["id"] == collection["leadWork"]:
            lead_palette = palette(image, scratch)
        works.append({
            "id": work["id"], "asset": asset, "title": work["title"], "artist": artist["name"],
            "artistLife": "%d–%d" % (artist["born"], artist["died"]), "year": work["year"],
            "collection": collection["id"], "series": work["series"], "holder": work["holder"],
            "sourceUrl": info["descriptionurl"], "fileUrl": fetched.split("?")[0], "license": work["license"],
            "licenseUrl": license_url(work, info), "credit": credit(work, artist), "kind": "artwork",
        })
        print("%-44s %6d KB  %s" % (asset, os.path.getsize(image) // 1024, fetched))
    if total > source["maxTotalBytes"]:
        raise SystemExit("Collection is %d bytes, above the %d limit" % (total, source["maxTotalBytes"]))
    install(collection, lead_palette, source["series"], works, staging)
    shutil.rmtree(scratch)
    print("Total: %.1f MB in %d works" % (total / 1e6, len(works)))


def install(collection, lead_palette, series, works, staging):
    empty = {"collections": [], "works": []}
    manifest = json.load(open(MANIFEST, encoding="utf-8")) if os.path.exists(MANIFEST) else empty
    os.makedirs(CATALOG, exist_ok=True)
    write_json(os.path.join(CATALOG, "Contents.json"), CATALOG_INFO)
    for work in manifest["works"]:
        if work["collection"] == collection["id"]:
            shutil.rmtree(os.path.join(CATALOG, work["asset"] + ".imageset"), ignore_errors=True)
    for work in works:
        shutil.copytree(os.path.join(staging, work["asset"] + ".imageset"),
                        os.path.join(CATALOG, work["asset"] + ".imageset"))
    others = [item for item in manifest["collections"] if item["id"] != collection["id"]]
    kept = [work for work in manifest["works"] if work["collection"] != collection["id"]]
    write_json(MANIFEST, {"collections": others + [dict(collection, palette=lead_palette)], "series": series,
                          "works": kept + works})


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode not in ("check", "fetch"):
        raise SystemExit("Usage: python3 -I scripts/art.py check|fetch")
    source = json.load(open(SOURCE, encoding="utf-8"))
    found = metadata([work["file"] for work in source["works"]], source["maxSide"])
    accepted = check(source, found)
    if not accepted:
        raise SystemExit("Some works failed the license gate; nothing was downloaded.")
    if mode == "fetch":
        fetch(source, found)


if __name__ == "__main__":
    main()
