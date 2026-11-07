import json
import re
import sys
from html.parser import HTMLParser
from pathlib import Path

PAGES = ["index.html", "privacy.html", "terms.html", "support.html"]
LANGUAGE = "pt-BR"
APP_STORE_ID = "6826982117"
SKIPPED = {"script", "style", "svg"}
LEFTOVERS = [
    "Fiscal Pro",
    "assinatura mensal",
    "free trial",
    "First idea",
    "Weekend plan",
    "Reading list",
    "Fiscal on the Web",
    "Fiscal na Web",
    "Download on the App Store",
]


class Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.lang = None
        self.attributes = []
        self.links = []
        self.texts = []
        self.skipping = 0

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "html":
            self.lang = attrs.get("lang")
        if tag in SKIPPED:
            self.skipping += 1
        self.attributes.extend(name for name in attrs if name.startswith("data-i18n") or name == "data-locale")
        for name in ("href", "src"):
            if attrs.get(name):
                self.links.append(attrs[name])
        for name in ("alt", "aria-label", "title"):
            value = (attrs.get(name) or "").strip()
            if value:
                self.texts.append(value)
        described = attrs.get("name") == "description" or attrs.get("property") in ("og:title", "og:description")
        if tag == "meta" and described and attrs.get("content"):
            self.texts.append(attrs["content"].strip())

    def handle_endtag(self, tag):
        if tag in SKIPPED and self.skipping:
            self.skipping -= 1

    def handle_data(self, data):
        text = re.sub(r"\s+", " ", data).strip()
        if text and not self.skipping:
            self.texts.append(text)


def read(site, page):
    parser = Page()
    parser.feed((site / page).read_text())
    return parser


def extract(site):
    return {page: read(site, page).texts for page in PAGES}


def problems_in(site, page, parsed):
    problems = []
    if parsed.lang != LANGUAGE:
        problems.append(f"{page}: <html lang> is {parsed.lang!r}, expected {LANGUAGE!r}")
    for name in sorted(set(parsed.attributes)):
        problems.append(f"{page}: translation attribute {name} left over")
    for link in parsed.links:
        if "locale=" in link or link.endswith("i18n.js") or "/i18n/" in link:
            problems.append(f"{page}: language link {link}")
        if link == "/app" or link.startswith("/app#") or link.startswith("/app?"):
            problems.append(f"{page}: links to Fiscal na Web, which waits until after 1.0")
        match = re.match(r"https://apps\.apple\.com/app/id(\d+)", link)
        if match and match.group(1) != APP_STORE_ID:
            problems.append(f"{page}: App Store link id{match.group(1)}, expected id{APP_STORE_ID}")
        if link.startswith("/") and not link.startswith("//"):
            path = link.split("#")[0].split("?")[0]
            if path not in ("", "/") and not any((site / candidate).exists() for candidate in (path.lstrip("/"), path.lstrip("/") + ".html")):
                problems.append(f"{page}: broken local link {link}")
    text = " ".join(parsed.texts)
    for word in LEFTOVERS:
        if word.lower() in text.lower():
            problems.append(f"{page}: template or postponed text {word!r}")
    return problems


def check(site):
    problems = []
    if (site / "i18n").exists():
        problems.append("site/i18n/ exists; the site is pt-BR only (ADR 0003)")
    if (site / "i18n.js").exists():
        problems.append("site/i18n.js exists; the site is pt-BR only (ADR 0003)")
    for page in PAGES:
        problems.extend(problems_in(site, page, read(site, page)))
    llms = (site / "llms.txt").read_text()
    for found in re.findall(r"apps\.apple\.com/app/id(\d+)", llms):
        if found != APP_STORE_ID:
            problems.append(f"llms.txt: App Store link id{found}, expected id{APP_STORE_ID}")
    for word in LEFTOVERS:
        if word.lower() in llms.lower():
            problems.append(f"llms.txt: template or postponed text {word!r}")
    for problem in problems:
        print(problem)
    print(f"{len(PAGES)} pages in {LANGUAGE}, problems: {len(problems)}")
    return len(problems)


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else "check"
    site = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(__file__).resolve().parent.parent / "site"
    if command == "extract":
        print(json.dumps(extract(site), ensure_ascii=False, indent=2))
    elif command == "check":
        sys.exit(1 if check(site) else 0)
    else:
        sys.exit(f"unknown command {command!r}: use extract or check")
