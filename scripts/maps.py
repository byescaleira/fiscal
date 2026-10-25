#!/usr/bin/env python3
import datetime
import gzip
import json
import math
import os
import time
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT = os.path.join(ROOT, "FiscalKit", "Sources", "FiscalResource", "Assets", "brazil-maps.json")
API = "https://servicodados.ibge.gov.br/api/v3/malhas/"
AGENT = "FiscalArtFetch/1.0 (https://fiscal.byescaleira.com)"
GEOJSON = "application/vnd.geo+json"
REFERENCE_LATITUDE = -15.0
COUNTRY_TOLERANCE = 0.0016
STATE_TOLERANCE = 0.0035
SMALLEST_ISLAND = 0.002
DIGITS = 4

STATES = {
    "11": "ro", "12": "ac", "13": "am", "14": "rr", "15": "pa", "16": "ap", "17": "to",
    "21": "ma", "22": "pi", "23": "ce", "24": "rn", "25": "pb", "26": "pe", "27": "al", "28": "se", "29": "ba",
    "31": "mg", "32": "es", "33": "rj", "35": "sp",
    "41": "pr", "42": "sc", "43": "rs",
    "50": "ms", "51": "mt", "52": "go", "53": "df",
}


def fetch(path, quality, extra=None):
    query = dict({"formato": GEOJSON, "qualidade": quality}, **(extra or {}))
    url = API + path + "?" + urllib.parse.urlencode(query)
    for attempt in range(4):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": AGENT})
            with urllib.request.urlopen(request, timeout=60) as response:
                body = response.read()
            return json.loads(gzip.decompress(body) if body[:2] == b"\x1f\x8b" else body)
        except OSError:
            time.sleep(2 + attempt * 3)
    raise SystemExit("IBGE API unavailable: " + url)


def project(point):
    longitude, latitude = point
    return (longitude * math.cos(math.radians(REFERENCE_LATITUDE)), -latitude)


def rings_of(geometry):
    polygons = geometry["coordinates"] if geometry["type"] == "MultiPolygon" else [geometry["coordinates"]]
    return [[project(point) for point in polygon[0]] for polygon in polygons]


def area(ring):
    return abs(sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(ring, ring[1:] + ring[:1]))) / 2


def distance(point, start, end):
    dx, dy = end[0] - start[0], end[1] - start[1]
    if dx == 0 and dy == 0:
        return math.hypot(point[0] - start[0], point[1] - start[1])
    t = max(0.0, min(1.0, ((point[0] - start[0]) * dx + (point[1] - start[1]) * dy) / (dx * dx + dy * dy)))
    return math.hypot(point[0] - start[0] - t * dx, point[1] - start[1] - t * dy)


def simplify(points, tolerance):
    if len(points) < 3:
        return points
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]
    while stack:
        first, last = stack.pop()
        index, farthest = None, tolerance
        for candidate in range(first + 1, last):
            gap = distance(points[candidate], points[first], points[last])
            if gap > farthest:
                index, farthest = candidate, gap
        if index is not None:
            keep[index] = True
            stack += [(first, index), (index, last)]
    return [point for point, kept in zip(points, keep) if kept]


def bounds(rings):
    xs = [x for ring in rings for x, _ in ring]
    ys = [y for ring in rings for _, y in ring]
    return min(xs), min(ys), max(xs), max(ys)


def normalize(rings, frame, tolerance):
    x0, y0, x1, y1 = frame
    side = max(x1 - x0, y1 - y0)
    result = []
    for ring in rings:
        scaled = [((x - x0) / side, (y - y0) / side) for x, y in ring]
        reduced = simplify(scaled, tolerance)
        if reduced[0] == reduced[-1]:
            reduced = reduced[:-1]
        if len(reduced) >= 3:
            result.append([[round(x, DIGITS), round(y, DIGITS)] for x, y in reduced])
    return result


def without_islands(rings):
    largest = max(area(ring) for ring in rings)
    return [ring for ring in rings if area(ring) >= largest * SMALLEST_ISLAND]


def outline(rings, frame, tolerance):
    x0, y0, x1, y1 = frame
    side = max(x1 - x0, y1 - y0)
    return {"width": round((x1 - x0) / side, DIGITS), "height": round((y1 - y0) / side, DIGITS),
            "rings": normalize(rings, frame, tolerance)}


def main():
    country = fetch("paises/BR", "minima", {"intrarregiao": "UF"})
    shapes = {STATES[feature["properties"]["codarea"]]: without_islands(rings_of(feature["geometry"]))
              for feature in country["features"]}
    frame = bounds([ring for rings in shapes.values() for ring in rings])
    country_states = {uf: outline(rings, frame, COUNTRY_TOLERANCE)["rings"] for uf, rings in sorted(shapes.items())}
    x0, y0, x1, y1 = frame
    side = max(x1 - x0, y1 - y0)
    states = {}
    for code, uf in sorted(STATES.items(), key=lambda item: item[1]):
        detail = fetch("estados/" + code, "intermediaria")
        rings = without_islands([ring for feature in detail["features"] for ring in rings_of(feature["geometry"])])
        states[uf] = outline(rings, bounds(rings), STATE_TOLERANCE)
        time.sleep(0.3)
    document = {
        "source": {
            "name": "IBGE, Malhas territoriais (API de malhas v3)",
            "url": "https://servicodados.ibge.gov.br/api/docs/malhas?versao=3",
            "fetchedAt": datetime.date.today().isoformat(),
            "note": "Formas simplificadas e normalizadas pelo Fiscal a partir da malha oficial; arte própria.",
        },
        "country": {"width": round((x1 - x0) / side, DIGITS), "height": round((y1 - y0) / side, DIGITS),
                    "states": country_states},
        "states": states,
    }
    with open(OUTPUT, "w", encoding="utf-8") as handle:
        json.dump(document, handle, ensure_ascii=False, separators=(",", ":"))
        handle.write("\n")
    points = sum(len(ring) for rings in country_states.values() for ring in rings)
    detail = sum(len(ring) for state in states.values() for ring in state["rings"])
    print("%d states, %d country points, %d state points, %d KB" % (
        len(states), points, detail, os.path.getsize(OUTPUT) // 1024))


if __name__ == "__main__":
    main()
