#!/usr/bin/env python3
import argparse
import json
import os
import sys
import unicodedata
import urllib.request

ROOT = os.path.dirname(os.path.abspath(__file__))
TRAITS = os.path.join(ROOT, "avatar-traits.json")
FIXTURE = os.path.join(ROOT, "..", "FiscalKit", "Sources", "FiscalResource", "showcase-people.json")
PUBLISHED = "https://dados.fiscal.byescaleira.com/v2/"
AGENT = "fiscal-portrait-check"
UFS = (
    "ac al am ap ba ce df es go ma mg ms mt pa pb pe pi pr rj rn ro rr rs sc se sp to"
).split()


def normalized(name):
    decomposed = unicodedata.normalize("NFD", name.casefold())
    return " ".join("".join(c for c in decomposed if unicodedata.category(c) != "Mn").split())


def traits():
    with open(TRAITS, encoding="utf-8") as handle:
        return {person["slug"]: person["name"] for person in json.load(handle)["people"]}


def fixture():
    with open(FIXTURE, encoding="utf-8") as handle:
        return {row[0]: row[1] for row in json.load(handle)["people"]}


def fetch(path):
    request = urllib.request.Request(PUBLISHED + path, headers={"User-Agent": AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def collect(node, people):
    if isinstance(node, dict):
        if isinstance(node.get("slug"), str) and isinstance(node.get("name"), str):
            people.setdefault(node["slug"], node["name"])
        for value in node.values():
            collect(value, people)
    elif isinstance(node, list):
        for value in node:
            collect(value, people)


def published():
    people = {}
    collect(fetch("index/people.json"), people)
    for uf in UFS:
        collect(fetch(f"places/{uf}.json"), people)
    return people


def main():
    parser = argparse.ArgumentParser(description="Check that each slug has the same name in the portrait traits")
    parser.add_argument("--published", action="store_true", help="read the published files instead of the fixture")
    args = parser.parse_args()
    described = traits()
    people = published() if args.published else fixture()
    problems = []
    missing = 0
    for slug, name in sorted(people.items()):
        if slug not in described:
            missing += 1
            if args.published:
                problems.append(f"{slug}: no traits for {name}")
        elif normalized(described[slug]) != normalized(name):
            problems.append(f"{slug}: {name} in the data, {described[slug]} in the traits")
    source = "published" if args.published else "fixture"
    print(f"portrait-check: {len(people)} people in the {source}, {missing} without traits, {len(problems)} problems")
    for problem in problems:
        print(f"  {problem}", file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
