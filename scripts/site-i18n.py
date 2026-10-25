import json
import re
import sys
from html.parser import HTMLParser
from pathlib import Path

VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr", "path", "rect", "circle"}
PAGES = ["index.html", "privacy.html", "terms.html", "support.html"]
LANGS = ["en", "pt-BR", "es", "de", "fr", "it", "ja", "ko", "zh-Hans", "ru"]


class Node:
    def __init__(self, tag, attrs, parent):
        self.tag = tag
        self.attrs = dict(attrs)
        self.parent = parent
        self.children = []


class Builder(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = Node("#root", [], None)
        self.current = self.root

    def handle_starttag(self, tag, attrs):
        node = Node(tag, attrs, self.current)
        self.current.children.append(node)
        if tag not in VOID:
            self.current = node

    def handle_startendtag(self, tag, attrs):
        self.current.children.append(Node(tag, attrs, self.current))

    def handle_endtag(self, tag):
        if tag in VOID:
            return
        node = self.current
        while node is not None and node.tag != tag:
            node = node.parent
        if node is not None and node.parent is not None:
            self.current = node.parent

    def handle_data(self, data):
        self.current.children.append(data)


def walk(node):
    for child in node.children:
        if isinstance(child, Node):
            yield child
            yield from walk(child)


def text_value(node):
    parts = []
    for child in node.children:
        if isinstance(child, str):
            parts.append(child)
        elif "data-slot" in child.attrs:
            parts.append("{" + child.attrs["data-slot"] + "}")
    return re.sub(r"\s+", " ", "".join(parts)).strip()


def extract(site):
    strings = {}

    def put(key, value, where):
        if key in strings and strings[key] != value:
            sys.exit(f"conflict for {key} in {where}: {strings[key]!r} vs {value!r}")
        strings[key] = value

    for page in PAGES:
        source = (site / page).read_text()
        builder = Builder()
        builder.feed(source)
        for node in walk(builder.root):
            if "data-i18n" in node.attrs:
                put(node.attrs["data-i18n"], text_value(node), page)
            for attr in ("content", "aria-label", "alt"):
                key = node.attrs.get("data-i18n-" + attr)
                if key:
                    put(key, node.attrs[attr], page)
        for match in re.finditer(r'<(\w+)[^>]*\sdata-i18n-html="([^"]+)"[^>]*>(.*?)</\1>', source, re.S):
            put(match.group(2), match.group(3).strip(), page)
    return dict(sorted(strings.items()))


def tags(value):
    return sorted(re.findall(r"<(/?\w+)", value))


def check(site):
    en = json.loads((site / "i18n" / "en.json").read_text())
    extracted = extract(site)
    problems = 0
    if extracted != en:
        missing = set(extracted) - set(en)
        extra = set(en) - set(extracted)
        changed = [k for k in extracted if k in en and extracted[k] != en[k]]
        print("en.json out of date with HTML", missing, extra, changed)
        problems += 1
    for lang in LANGS[1:]:
        data = json.loads((site / "i18n" / f"{lang}.json").read_text())
        missing = sorted(set(en) - set(data))
        extra = sorted(set(data) - set(en))
        if missing or extra:
            print(lang, "missing:", missing, "extra:", extra)
            problems += 1
        same = []
        for key, value in en.items():
            if key not in data:
                continue
            other = data[key]
            if not other.strip():
                print(lang, key, "empty")
                problems += 1
            if sorted(re.findall(r"\{\w+\}", value)) != sorted(re.findall(r"\{\w+\}", other)):
                print(lang, key, "placeholders differ:", other)
                problems += 1
            if tags(value) != tags(other):
                print(lang, key, "markup differs:", other)
                problems += 1
            if other == value:
                same.append(key)
        print(lang, len(data), "keys, identical to English:", same)
    print("problems:", problems)
    return problems


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else "check"
    site = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(__file__).resolve().parent.parent / "site"
    if command == "extract":
        (site / "i18n").mkdir(exist_ok=True)
        (site / "i18n" / "en.json").write_text(json.dumps(extract(site), ensure_ascii=False, indent=2) + "\n")
        print(len(extract(site)), "keys")
    elif command == "check":
        sys.exit(1 if check(site) else 0)
