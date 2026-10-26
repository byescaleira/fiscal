#!/usr/bin/env python3
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT = os.path.join(ROOT, "FiscalKit", "Sources", "FiscalResource", "showcase-indicators.json")
ORDER = [
    "gasolina", "etanol", "diesel-s10", "glp",
    "ipca", "ipca-alimentacao-domicilio", "ipca-energia-eletrica", "ipca-aluguel", "ipca-gasolina",
]


def month_index(date):
    return int(date[:4]) * 12 + int(date[5:7]) - 1


def compact(series):
    if not series:
        return None
    first = month_index(series[0]["date"])
    last = month_index(series[-1]["date"])
    values = [None] * (last - first + 1)
    for point in series:
        values[month_index(point["date"]) - first] = point["value"]
    return series[0]["date"][:7], values


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: showcase-indicators.py <PUBLIC_DIR/v1/indicators>")
    folder = sys.argv[1]
    with open(os.path.join(folder, "index.json"), encoding="utf-8") as handle:
        index = json.load(handle)
    sources = [
        {"id": s["id"], "name": s["name"], "url": s["url"], "updatedAt": s["updatedAt"]}
        for s in index["sources"]
    ]
    ids = [item["id"] for item in index["items"]]
    ids.sort(key=lambda i: ORDER.index(i) if i in ORDER else len(ORDER))
    indicators = []
    for ident in ids:
        with open(os.path.join(folder, ident + ".json"), encoding="utf-8") as handle:
            data = json.load(handle)
        areas = []
        for area in data["areas"]:
            packed = compact(area["series"])
            if packed:
                areas.append([area["scope"], area["name"], packed[0], packed[1]])
        indicators.append({
            "id": data["id"], "name": data["name"], "unit": data["unit"], "kind": data["kind"],
            "sources": [s["id"] for s in data["sources"]], "areas": areas,
        })
    with open(OUTPUT, "w", encoding="utf-8") as handle:
        json.dump({"sources": sources, "indicators": indicators}, handle, ensure_ascii=False, separators=(",", ":"))
        handle.write("\n")
    print(f"{OUTPUT}: {os.path.getsize(OUTPUT)} bytes, {len(indicators)} indicators")


if __name__ == "__main__":
    main()
