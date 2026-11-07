#!/usr/bin/env python3
import argparse
import hashlib
import pathlib
import sys
import time
import urllib.error
import urllib.request

from asc import call, every, token

BUNDLE = "com.byescaleira.fiscal"
MEDIA = pathlib.Path(__file__).resolve().parent.parent / "docs" / "app-store" / "media"
FOLDERS = {
    "APP_IPHONE_67": "iphone",
    "APP_IPHONE_61": "iphone-6.3",
    "APP_IPAD_PRO_3GEN_129": "ipad",
}


class Store:
    def __init__(self):
        self.issued = 0
        self.current = None

    @property
    def bearer(self):
        if time.time() - self.issued > 600:
            self.current = token()
            self.issued = time.time()
        return self.current

    def call(self, method, path, body=None):
        return call(self.bearer, method, path, body)

    def every(self, path):
        return every(self.bearer, path)

    def localization(self, locale):
        apps = self.every(f"/v1/apps?filter[bundleId]={BUNDLE}")
        if not apps:
            sys.exit(f"No app with bundle id {BUNDLE}")
        versions = self.every(
            f"/v1/apps/{apps[0]['id']}/appStoreVersions"
            "?filter[platform]=IOS&filter[appStoreState]=PREPARE_FOR_SUBMISSION")
        if not versions:
            sys.exit("No iOS version in Prepare for Submission")
        version = versions[0]
        localizations = self.every(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")
        for localization in localizations:
            if localization["attributes"]["locale"] == locale:
                return version["attributes"]["versionString"], localization["id"]
        sys.exit(f"No {locale} localization on version {version['attributes']['versionString']}")

    def sets(self, localization):
        return self.every(f"/v1/appStoreVersionLocalizations/{localization}/appScreenshotSets")

    def screenshots(self, screenshot_set):
        return self.every(f"/v1/appScreenshotSets/{screenshot_set}/appScreenshots")

    def existing_set(self, localization, display_type):
        for screenshot_set in self.sets(localization):
            if screenshot_set["attributes"]["screenshotDisplayType"] == display_type:
                return screenshot_set["id"]
        return None

    def set_for(self, localization, display_type):
        found = self.existing_set(localization, display_type)
        if found:
            return found
        body = {
            "data": {
                "type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": display_type},
                "relationships": {
                    "appStoreVersionLocalization": {
                        "data": {"type": "appStoreVersionLocalizations", "id": localization}
                    }
                },
            }
        }
        return self.call("POST", "/v1/appScreenshotSets", body)["data"]["id"]

    def upload(self, screenshot_set, path):
        data = path.read_bytes()
        body = {
            "data": {
                "type": "appScreenshots",
                "attributes": {"fileName": path.name, "fileSize": len(data)},
                "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": screenshot_set}}},
            }
        }
        reserved = self.call("POST", "/v1/appScreenshots", body)["data"]
        for operation in reserved["attributes"]["uploadOperations"]:
            chunk = data[operation["offset"] : operation["offset"] + operation["length"]]
            request = urllib.request.Request(operation["url"], method=operation["method"], data=chunk)
            for header in operation.get("requestHeaders", []):
                request.add_header(header["name"], header["value"])
            send(request)
        commit = {
            "data": {
                "type": "appScreenshots",
                "id": reserved["id"],
                "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()},
            }
        }
        self.call("PATCH", f"/v1/appScreenshots/{reserved['id']}", commit)
        return reserved["id"]

    def order(self, screenshot_set, names):
        shots = {shot["attributes"].get("fileName"): shot["id"] for shot in self.screenshots(screenshot_set)}
        data = [{"type": "appScreenshots", "id": shots[name]} for name in names if name in shots]
        self.call("PATCH", f"/v1/appScreenshotSets/{screenshot_set}/relationships/appScreenshots", {"data": data})

    def wait(self, screenshot):
        for _ in range(300):
            state = self.call("GET", f"/v1/appScreenshots/{screenshot}")["data"]["attributes"]
            delivery = (state.get("assetDeliveryState") or {}).get("state")
            if delivery == "COMPLETE":
                return
            if delivery == "FAILED":
                sys.exit(f"{state.get('fileName')} failed: {state['assetDeliveryState'].get('errors')}")
            time.sleep(2)
        sys.exit(f"{screenshot} is still processing")


def send(request, attempts=4):
    for attempt in range(attempts):
        try:
            return urllib.request.urlopen(request).read()
        except urllib.error.URLError:
            if attempt == attempts - 1:
                raise
            time.sleep(2 ** attempt)


def files(display_type):
    return sorted((MEDIA / FOLDERS[display_type]).glob("*.png"))


def show(store, args):
    version, localization = store.localization(args.locale)
    print(f"Version {version}, {args.locale}")
    for screenshot_set in store.sets(localization):
        shots = store.screenshots(screenshot_set["id"])
        print(f"{screenshot_set['attributes']['screenshotDisplayType']}: {len(shots)}")
        for shot in shots:
            asset = shot["attributes"].get("imageAsset") or {}
            print(f"  {shot['attributes'].get('fileName')} {asset.get('width')}x{asset.get('height')}")


def replace(store, args):
    unknown = set(args.types) - set(FOLDERS)
    if unknown:
        sys.exit(f"Unknown display types: {', '.join(sorted(unknown))}")
    version, localization = store.localization(args.locale)
    print(f"Version {version}, {args.locale}")
    for display_type in args.types or list(FOLDERS):
        paths = files(display_type)
        if not paths:
            sys.exit(f"No PNG in {MEDIA / FOLDERS[display_type]}")
        if args.dry_run:
            found = store.existing_set(localization, display_type)
            old = store.screenshots(found) if found else []
            print(f"{display_type}: replace {len(old)} with {', '.join(path.name for path in paths)}")
            continue
        screenshot_set = store.set_for(localization, display_type)
        for shot in store.screenshots(screenshot_set):
            store.call("DELETE", f"/v1/appScreenshots/{shot['id']}")
        uploaded = [(path, store.upload(screenshot_set, path)) for path in paths]
        for path, screenshot in uploaded:
            store.wait(screenshot)
            print(f"{display_type}: {path.name}")


def repair(store, args):
    version, localization = store.localization(args.locale)
    print(f"Version {version}, {args.locale}")
    for display_type in args.types or list(FOLDERS):
        screenshot_set = store.existing_set(localization, display_type)
        if not screenshot_set:
            continue
        paths = {path.name: path for path in files(display_type)}
        stuck = [
            shot
            for shot in store.screenshots(screenshot_set)
            if (shot["attributes"].get("assetDeliveryState") or {}).get("state") != "COMPLETE"
        ]
        for shot in stuck:
            name = shot["attributes"].get("fileName")
            store.call("DELETE", f"/v1/appScreenshots/{shot['id']}")
            store.wait(store.upload(screenshot_set, paths[name]))
            print(f"{display_type}: {name} sent again")
        store.order(screenshot_set, list(paths))


def main():
    parser = argparse.ArgumentParser(description="Upload the store screenshots to App Store Connect.")
    parser.add_argument("--locale", default="pt-BR")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("list", help="list the screenshot sets of the version in preparation").set_defaults(run=show)
    replacing = commands.add_parser("replace", help="replace the screenshots of each display type")
    replacing.add_argument("types", nargs="*", help=", ".join(FOLDERS))
    replacing.add_argument("--dry-run", action="store_true", help="show the plan without changing anything")
    replacing.set_defaults(run=replace)
    repairing = commands.add_parser("repair", help="send again the screenshots stuck in processing")
    repairing.add_argument("types", nargs="*", help=", ".join(FOLDERS))
    repairing.set_defaults(run=repair)
    args = parser.parse_args()
    args.run(Store(), args)


if __name__ == "__main__":
    main()
