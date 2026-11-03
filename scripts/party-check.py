#!/usr/bin/env python3
import argparse
import json
import sys
import unicodedata
import urllib.request

PUBLISHED = "https://dados.fiscal.byescaleira.com/v2/"
AGENT = "fiscal-party-check"
UFS = (
    "ac al am ap ba ce df es go ma mg ms mt pa pb pe pi pr rj rn ro rr rs sc se sp to"
).split()


def key(party):
    decomposed = unicodedata.normalize("NFD", party.casefold())
    return "".join(c for c in decomposed if unicodedata.category(c) != "Mn" and not c.isspace())


def fetch(path):
    request = urllib.request.Request(PUBLISHED + path, headers={"User-Agent": AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def collect(node, found):
    if isinstance(node, dict):
        if isinstance(node.get("slug"), str) and isinstance(node.get("party"), str):
            found.append(node)
        for value in node.values():
            collect(value, found)
    elif isinstance(node, list):
        for value in node:
            collect(value, found)


def divergent(index, places):
    parties = {}
    for card in index + places:
        parties.setdefault(card["slug"], {})[key(card["party"])] = card["party"]
    return {slug: sorted(names.values()) for slug, names in parties.items() if len(names) > 1}


def main():
    parser = argparse.ArgumentParser(description="List who has more than one party in the published files")
    parser.parse_args()
    index, places = [], []
    collect(fetch("index/people.json"), index)
    for uf in UFS:
        collect(fetch(f"places/{uf}.json"), places)
    found = divergent(index, places)
    print(f"party-check: {len({card['slug'] for card in index + places})} people, {len(found)} with more than one party")
    for slug, parties in sorted(found.items()):
        print(f"  {slug}: {', '.join(parties)}", file=sys.stderr)
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
