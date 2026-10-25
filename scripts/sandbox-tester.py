#!/usr/bin/env python3
import argparse
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

API = "https://api.appstoreconnect.apple.com"
RATES = {
    "1h": "MONTHLY_RENEWAL_EVERY_ONE_HOUR",
    "30m": "MONTHLY_RENEWAL_EVERY_THIRTY_MINUTES",
    "15m": "MONTHLY_RENEWAL_EVERY_FIFTEEN_MINUTES",
    "5m": "MONTHLY_RENEWAL_EVERY_FIVE_MINUTES",
    "3m": "MONTHLY_RENEWAL_EVERY_THREE_MINUTES",
}
FIELDS = "acAccountName,firstName,lastName,territory,interruptPurchases,subscriptionRenewalRate"


def b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(der):
    def integer(at):
        assert der[at] == 0x02
        size = der[at + 1]
        value = der[at + 2 : at + 2 + size].lstrip(b"\x00")
        return value.rjust(32, b"\x00"), at + 2 + size

    assert der[0] == 0x30
    start = 3 if der[1] & 0x80 else 2
    r, at = integer(start)
    s, _ = integer(at)
    return r + s


def token():
    missing = [name for name in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_PATH") if not os.environ.get(name)]
    if missing:
        sys.exit(f"Missing environment variables: {', '.join(missing)}")
    header = {"alg": "ES256", "kid": os.environ["ASC_KEY_ID"], "typ": "JWT"}
    now = int(time.time())
    claims = {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"}
    signing = f"{b64(json.dumps(header).encode())}.{b64(json.dumps(claims).encode())}"
    der = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", os.path.expanduser(os.environ["ASC_KEY_PATH"])],
        input=signing.encode(), capture_output=True, check=True).stdout
    return f"{signing}.{b64(der_to_raw(der))}"


class Client:
    def __init__(self, dry_run):
        self.dry_run = dry_run
        self.bearer = None if dry_run else token()

    def call(self, method, path, body=None):
        url = API + path
        payload = json.dumps(body, indent=2) if body is not None else None
        if self.dry_run:
            print(f"{method} {url}")
            if payload:
                print(payload)
            return None
        request = urllib.request.Request(url, method=method, data=payload.encode() if payload else None)
        request.add_header("Authorization", f"Bearer {self.bearer}")
        request.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(request) as response:
                raw = response.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as error:
            sys.exit(f"{method} {path} failed with {error.code}: {error.read().decode()}")

    def testers(self):
        found, path = [], f"/v2/sandboxTesters?limit=200&fields[sandboxTesters]={FIELDS}"
        while path:
            page = self.call("GET", path)
            if page is None:
                return []
            found += page.get("data", [])
            following = page.get("links", {}).get("next")
            path = following[len(API):] if following else None
        return found

    def resolve(self, who):
        if "@" not in who:
            return who
        if self.dry_run:
            self.testers()
            return f"<id of {who}>"
        for tester in self.testers():
            if tester["attributes"].get("acAccountName", "").lower() == who.lower():
                return tester["id"]
        sys.exit(f"No sandbox tester with account {who}")

    def update(self, who, attributes):
        tester = self.resolve(who)
        body = {"data": {"type": "sandboxTesters", "id": tester, "attributes": attributes}}
        return self.call("PATCH", f"/v2/sandboxTesters/{tester}", body)


def list_testers(client, _):
    testers = client.testers()
    for tester in testers:
        values = tester["attributes"]
        print(
            f"{tester['id']}  {values.get('acAccountName', '')}  {values.get('territory', '')}  "
            f"renewal={values.get('subscriptionRenewalRate', '')}  "
            f"interrupt={values.get('interruptPurchases', '')}")


def clear(client, args):
    ids = [client.resolve(who) for who in args.testers]
    body = {
        "data": {
            "type": "sandboxTestersClearPurchaseHistoryRequest",
            "relationships": {"sandboxTesters": {"data": [{"type": "sandboxTesters", "id": id} for id in ids]}},
        }
    }
    client.call("POST", "/v2/sandboxTestersClearPurchaseHistoryRequest", body)
    if not client.dry_run:
        print(f"Purchase history cleared for {len(ids)} tester(s)")


def renewal(client, args):
    client.update(args.tester, {"subscriptionRenewalRate": RATES.get(args.rate, args.rate)})
    if not client.dry_run:
        print(f"Renewal rate set to {RATES.get(args.rate, args.rate)}")


def interrupt(client, args):
    client.update(args.tester, {"interruptPurchases": args.state == "on"})
    if not client.dry_run:
        print(f"Interrupted purchases {args.state}")


def main():
    parser = argparse.ArgumentParser(description="Manage App Store Connect sandbox testers.")
    parser.add_argument("--dry-run", action="store_true", help="print the requests without sending them")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("list", help="list sandbox testers").set_defaults(run=list_testers)
    clearing = commands.add_parser("clear", help="clear the purchase history of testers")
    clearing.add_argument("testers", nargs="+", help="tester id or account email")
    clearing.set_defaults(run=clear)
    renewing = commands.add_parser("renewal", help="set the subscription renewal rate")
    renewing.add_argument("tester", help="tester id or account email")
    renewing.add_argument("rate", choices=[*RATES, *RATES.values()])
    renewing.set_defaults(run=renewal)
    interrupting = commands.add_parser("interrupt", help="turn interrupted purchases on or off")
    interrupting.add_argument("tester", help="tester id or account email")
    interrupting.add_argument("state", choices=["on", "off"])
    interrupting.set_defaults(run=interrupt)
    args = parser.parse_args()
    args.run(Client(args.dry_run), args)


if __name__ == "__main__":
    main()
