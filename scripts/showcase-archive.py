#!/usr/bin/env python3
import argparse
import datetime
import json
import os
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "FiscalKit", "Sources", "FiscalResource", "Assets")
SUMMARY = [
    "id", "house", "date", "time", "proposition", "kind", "summary", "plainSummary", "themes",
    "result", "approved", "nominal", "yes", "no", "others",
]
OFFICES = {"federalDeputy", "senator", "governor", "viceGovernor", "stateDeputy"}
ACTIVITY = ["votes", "proposals", "speeches"]


def read(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def compact(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8")


def raw(path):
    return compact(read(path))


def pack(name, documents):
    index = {}
    blob = bytearray()
    for path in sorted(documents):
        data = documents[path]
        index[path] = [len(blob), len(data)]
        blob += data
    head = compact(index)
    body = len(head).to_bytes(4, "big") + head + bytes(blob)
    deflate = zlib.compressobj(9, zlib.DEFLATED, -15)
    packed = deflate.compress(body) + deflate.flush()
    path = os.path.join(ASSETS, f"showcase-{name}.deflate")
    with open(path, "wb") as fh:
        fh.write(packed)
    print(f"showcase-{name}.deflate: {len(documents):,} documents, {len(body):,} bytes raw, {len(packed):,} bytes packed")
    return len(packed)


def core(v1):
    docs = {}
    for name in ["meta.json", "today.json", "agenda/today.json", "money/overview.json"]:
        path = os.path.join(v1, name)
        if os.path.exists(path):
            docs[name] = raw(path)
    places = os.path.join(v1, "places")
    for name in sorted(os.listdir(places)):
        if name.endswith(".json"):
            docs[f"places/{name}"] = raw(os.path.join(places, name))
    return docs


def votes(v1, since, details):
    folder = os.path.join(v1, "votes")
    docs = {}
    summaries = []
    kept = set()
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".json") or name == "recent.json":
            continue
        detail = read(os.path.join(folder, name))
        day = detail["date"][:10]
        if day < details:
            continue
        docs[f"votes/{name}"] = compact(detail)
        kept.add(detail["id"])
        if day >= since:
            summaries.append({key: detail.get(key) for key in SUMMARY})
    summaries.sort(key=lambda s: (s["date"], s["time"] or "", s["id"]), reverse=True)
    docs["votes/recent.json"] = compact(summaries)
    houses = {}
    for s in summaries:
        houses[s["house"]] = houses.get(s["house"], 0) + 1
    print(f"recent votes since {since}: {len(summaries)} ({', '.join(f'{k} {v}' for k, v in sorted(houses.items()))}), details since {details}: {len(kept)}")
    return docs, kept


def people(v1, year, kept):
    docs = {}
    offices = {}
    for card in read(os.path.join(v1, "index", "people.json")):
        if card["office"] not in OFFICES:
            continue
        slug = card["slug"]
        base = os.path.join(v1, "people", slug)
        if not os.path.exists(base + ".json"):
            continue
        offices[card["office"]] = offices.get(card["office"], 0) + 1
        docs[f"people/{slug}.json"] = raw(base + ".json")
        if not os.path.isdir(base):
            continue
        for name in sorted(os.listdir(base)):
            if not name.endswith(".json"):
                continue
            kind, _, rest = name[:-5].partition("-")
            if kind in ACTIVITY and rest != str(year):
                continue
            value = read(os.path.join(base, name))
            if kind == "votes":
                value["items"] = [item for item in value["items"] if item["voteId"] in kept]
                value["total"] = len(value["items"])
            docs[f"people/{slug}/{name}"] = compact(value)
    print("people: " + ", ".join(f"{k} {v}" for k, v in sorted(offices.items())))
    return docs


def main():
    parser = argparse.ArgumentParser(description="Pack a server load into the showcase archives")
    parser.add_argument("v1", help="<PUBLIC_DIR>/v1 of a full load")
    parser.add_argument("--days", type=int, default=60, help="recent votes from the last N days of the load")
    parser.add_argument("--detail-days", type=int, default=0, help="vote details from the last N days (default: the whole year of the load)")
    args = parser.parse_args()
    meta = read(os.path.join(args.v1, "meta.json"))
    loaded = datetime.date.fromisoformat(meta["generatedAt"][:10])
    since = (loaded - datetime.timedelta(days=args.days)).isoformat()
    details = f"{loaded.year}-01-01"
    if args.detail_days:
        details = (loaded - datetime.timedelta(days=args.detail_days)).isoformat()
    vote_docs, kept = votes(args.v1, since, min(since, details))
    total = pack("core", core(args.v1))
    total += pack("votes", vote_docs)
    total += pack("people", people(args.v1, loaded.year, kept))
    print(f"total packed: {total:,} bytes")


if __name__ == "__main__":
    main()
