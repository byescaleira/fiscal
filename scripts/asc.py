import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

API = "https://api.appstoreconnect.apple.com"


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


def call(bearer, method, path, body=None, attempts=4):
    url = path if path.startswith("https://") else API + path
    payload = json.dumps(body).encode() if body is not None else None
    for attempt in range(attempts):
        request = urllib.request.Request(url, method=method, data=payload)
        request.add_header("Authorization", f"Bearer {bearer}")
        request.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(request) as response:
                raw = response.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as error:
            if error.code < 500 or attempt == attempts - 1:
                sys.exit(f"{method} {path} failed with {error.code}: {error.read().decode()}")
        except urllib.error.URLError:
            if attempt == attempts - 1:
                raise
        time.sleep(2 ** attempt)


def every(bearer, path):
    found = []
    while path:
        page = call(bearer, "GET", path)
        found += page.get("data", [])
        path = page.get("links", {}).get("next")
    return found
