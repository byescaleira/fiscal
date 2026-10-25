import pathlib
import subprocess
import tempfile

from PIL import Image

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


def chrome(html: pathlib.Path, output: pathlib.Path, width: int, height: int, transparent=False):
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as profile:
        command = [
            CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--no-first-run",
            "--force-device-scale-factor=1", f"--user-data-dir={profile}",
            f"--window-size={width},{height}", "--virtual-time-budget=4000",
            f"--screenshot={output}",
        ]
        if transparent:
            command.append("--default-background-color=00000000")
        command.append(html.resolve().as_uri())
        subprocess.run(command, check=True, capture_output=True)
    image = Image.open(output)
    if image.size != (width, height):
        raise SystemExit(f"{output.name}: rendered {image.size}, expected {(width, height)}")
    if not transparent:
        image.convert("RGB").save(output, optimize=True)
    return output
