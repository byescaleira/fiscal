#!/usr/bin/env python3
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESOURCE = os.path.join(ROOT, "FiscalKit", "Sources", "FiscalResource")
OFFICES = {"mayor": 0, "viceMayor": 1, "cityCouncilor": 2}
SOURCE = "Carga do servidor do Fiscal (TSE, Câmara, Senado e IBGE), dados de teste do showcase"


def read(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def write(name, value):
    path = os.path.join(RESOURCE, name)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(value, fh, ensure_ascii=False, separators=(",", ":"))
        fh.write("\n")
    print(f"{name}: {os.path.getsize(path):,} bytes")


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: python3 -I scripts/showcase-roster.py <PUBLIC_DIR>/v1")
    v1 = sys.argv[1]
    meta = read(os.path.join(v1, "meta.json"))
    people = [
        [p["slug"], p["name"], p["office"], p["uf"], p["party"], p["photo"], p["status"]]
        for p in read(os.path.join(v1, "index", "people.json"))
    ]
    write("showcase-people.json", {"source": SOURCE, "generatedAt": meta["generatedAt"], "people": people})
    cities = []
    missing = []
    for place in read(os.path.join(v1, "index", "places.json")):
        if place["code"] == place["uf"]:
            continue
        path = os.path.join(v1, "places", "city", place["code"] + ".json")
        if not os.path.exists(path):
            missing.append(place["code"])
            continue
        city = read(path)
        officials = [
            [OFFICES[p["office"]], p["name"], p["party"]]
            for group in city["groups"]
            for p in group["people"]
        ]
        cities.append([city["code"], city["name"], city["uf"], city["note"], officials])
    if missing:
        sys.exit(f"{len(missing)} municipalities without a city file, e.g. {missing[:5]}")
    write("showcase-cities.json", {"source": SOURCE, "generatedAt": meta["generatedAt"], "cities": cities})


if __name__ == "__main__":
    main()
