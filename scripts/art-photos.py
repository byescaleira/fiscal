#!/usr/bin/env python3
import json
import os
import re
import urllib.parse
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import art

SOURCE = os.path.join(art.ROOT, "scripts", "art-photos.json")
PREFIX = "art-"
ALLOWED_CODES = {"cc-by-sa-4.0", "cc-by-4.0", "cc0"}
BLOCKING_CATEGORIES = ("Personality rights", "Trademarked", "Logos", "Flags", "People", "Politic", "Election")
REVIEW_SIDE = 640


def metadata(titles, width):
    found = {}
    for start in range(0, len(titles), 20):
        batch = titles[start:start + 20]
        data = art.api({
            "action": "query", "prop": "imageinfo", "iiprop": "url|extmetadata|size|mime|user",
            "iiurlwidth": str(width), "titles": "|".join(batch),
        })
        aliases = {item["to"]: item["from"] for item in data["query"].get("normalized", [])}
        for page in data["query"]["pages"]:
            title = aliases.get(page["title"], page["title"])
            found[title] = page.get("imageinfo", [None])[0]
    return found


def gate(photo, info, licenses):
    if info is None:
        return ["arquivo não encontrado no Commons"]
    reasons = []
    short = art.field(info, "LicenseShortName")
    if short not in licenses:
        reasons.append("licença " + short)
    if art.field(info, "License") not in ALLOWED_CODES:
        reasons.append("código de licença " + art.field(info, "License"))
    categories = art.field(info, "Categories").split("|")
    event = "Images from Wiki Loves Earth %s in Brazil" % photo["event"]
    if not any(category.startswith(event) for category in categories):
        reasons.append("fora do " + event)
    blocked = [c for c in categories if any(word.lower() in c.lower() for word in BLOCKING_CATEGORIES)]
    if blocked:
        reasons.append("categoria " + blocked[0])
    if art.field(info, "Restrictions"):
        reasons.append("restrição " + art.field(info, "Restrictions"))
    if not art.field(info, "Artist") or not username(info):
        reasons.append("sem autor")
    if info.get("mime") != "image/jpeg" or not info.get("thumburl"):
        reasons.append("tipo " + info.get("mime", "?"))
    return reasons


def credit(photo, info, title):
    author, user = art.field(info, "Artist"), username(info)
    name = author if author == user else "%s (%s)" % (author, user)
    return "Foto: %s, “%s”. %s (%s). %s. Wiki Loves Earth %s · Brasil, via Wikimedia Commons." % (
        name, title, photo["place"], photo["uf"].upper(), art.field(info, "LicenseShortName"), photo["event"])


def username(info):
    raw = (info.get("extmetadata", {}).get("Artist") or {}).get("value") or ""
    linked = re.search(r"User:([^\"&?#]+)", raw)
    if linked:
        return urllib.parse.unquote(linked.group(1)).replace("_", " ")
    return info.get("user", "")


def taken_year(info, photo):
    taken = art.field(info, "DateTimeOriginal")[:4]
    return taken if taken.isdigit() and "1990" <= taken <= photo["event"] else photo["event"]


def title_of(photo):
    return os.path.splitext(photo["file"].split(":", 1)[1])[0]


def check(source, found):
    accepted = True
    for photo in source["photos"]:
        reasons = gate(photo, found.get(photo["file"]), source["licenses"])
        accepted = accepted and not reasons
        print("%-34s %s  %s" % (photo["id"], photo["uf"], "ok" if not reasons else "recusada: " + "; ".join(reasons)))
    return accepted


def stage(source, found, folder):
    os.makedirs(folder, exist_ok=True)
    works, total = [], 0
    for photo in source["photos"]:
        info = found[photo["file"]]
        asset = PREFIX + photo["id"]
        original = os.path.join(folder, photo["id"] + ".download")
        fetched = art.download({"file": photo["file"]}, info, original)
        image = os.path.join(folder, asset + ".jpg")
        art.convert(original, image, source["maxSide"], source["quality"])
        os.remove(original)
        art.run(["sips", "-Z", str(REVIEW_SIDE), "-s", "format", "png", image,
                 "--out", os.path.join(folder, "review-" + photo["id"] + ".png")])
        total += os.path.getsize(image)
        title = title_of(photo)
        works.append({
            "id": photo["id"], "asset": asset, "title": title, "artist": art.field(info, "Artist"),
            "artistLife": "", "year": taken_year(info, photo), "collection": source["collection"]["id"],
            "holder": "Wiki Loves Earth %s · Brasil" % photo["event"],
            "sourceUrl": info["descriptionurl"], "fileUrl": fetched.split("?")[0],
            "license": art.field(info, "LicenseShortName"),
            "licenseUrl": source["licenses"][art.field(info, "LicenseShortName")],
            "credit": credit(photo, info, title), "kind": "photo", "author": username(info),
            "event": "Wiki Loves Earth " + photo["event"], "uf": photo["uf"], "place": photo["place"],
        })
        print("%-34s %6d KB" % (asset, os.path.getsize(image) // 1024))
    art.write_json(os.path.join(folder, "works.json"), works)
    print("Staged %.1f MB in %d photos at %s" % (total / 1e6, len(works), folder))


def catalog_bytes(names):
    total = 0
    for name in names:
        path = os.path.join(art.CATALOG, name + ".imageset", name + ".jpg")
        total += os.path.getsize(path) if os.path.exists(path) else 0
    return total


def install(source, folder):
    works = json.load(open(os.path.join(folder, "works.json"), encoding="utf-8"))
    collection_id = source["collection"]["id"]
    manifest = json.load(open(art.MANIFEST, encoding="utf-8"))
    for work in manifest["works"]:
        if work["collection"] == collection_id:
            shutil.rmtree(os.path.join(art.CATALOG, work["asset"] + ".imageset"), ignore_errors=True)
    for work in works:
        imageset = os.path.join(art.CATALOG, work["asset"] + ".imageset")
        os.makedirs(imageset, exist_ok=True)
        shutil.copy(os.path.join(folder, work["asset"] + ".jpg"), os.path.join(imageset, work["asset"] + ".jpg"))
        art.write_json(os.path.join(imageset, "Contents.json"), dict(
            images=[{"filename": work["asset"] + ".jpg", "idiom": "universal"}], **art.CATALOG_INFO))
    lead = next(work for work in works if work["id"] == source["collection"]["leadWork"])
    scratch = tempfile.mkdtemp(prefix="fiscal-photos-")
    palette = art.palette(os.path.join(folder, lead["asset"] + ".jpg"), scratch)
    shutil.rmtree(scratch)
    others = [work for work in manifest["works"] if work["collection"] != collection_id]
    collections = [dict(source["collection"], palette=palette)]
    collections += [item for item in manifest["collections"] if item["id"] != collection_id]
    manifest = {"collections": collections, "series": manifest.get("series", []), "works": works + others}
    total = catalog_bytes(work["asset"] for work in manifest["works"])
    if total > source["maxTotalBytes"]:
        raise SystemExit("Art catalog is %d bytes, above the %d limit" % (total, source["maxTotalBytes"]))
    art.write_json(art.MANIFEST, manifest)
    print("Installed %d photos; catalog total %.1f MB" % (len(works), total / 1e6))


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode not in ("check", "stage", "install", "fetch"):
        raise SystemExit("Usage: python3 -I scripts/art-photos.py check | stage <dir> | install <dir> | fetch")
    source = json.load(open(SOURCE, encoding="utf-8"))
    if mode == "install":
        install(source, sys.argv[2])
        return
    found = metadata([photo["file"] for photo in source["photos"]], source["maxSide"])
    if not check(source, found):
        raise SystemExit("Some photos failed the license gate; nothing was downloaded.")
    if mode == "stage":
        stage(source, found, sys.argv[2])
    elif mode == "fetch":
        folder = tempfile.mkdtemp(prefix="fiscal-photos-")
        stage(source, found, folder)
        install(source, folder)
        shutil.rmtree(folder)


if __name__ == "__main__":
    main()
