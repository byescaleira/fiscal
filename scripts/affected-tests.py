import json
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
package = root / "FiscalKit"


def git(*args):
    return subprocess.run(["git", *args], cwd=root, capture_output=True, text=True).stdout.split()


def base_ref():
    if len(sys.argv) > 1:
        return sys.argv[1]
    for ref in ("development", "main"):
        if subprocess.run(["git", "rev-parse", "--verify", "-q", ref], cwd=root, capture_output=True).returncode == 0:
            return ref
    return "HEAD"


def changed_files(base):
    files = set(git("diff", "--name-only", f"{base}...HEAD"))
    files |= set(git("diff", "--name-only", "HEAD"))
    files |= set(git("ls-files", "--others", "--exclude-standard"))
    return files


description = json.loads(subprocess.run(
    ["swift", "package", "describe", "--type", "json"], cwd=package, capture_output=True, text=True,
    check=True).stdout)
targets = {t["name"]: t for t in description["targets"]}
tests = sorted(name for name, t in targets.items() if t["type"] == "test")

changed_modules, changed_tests, everything = set(), set(), False
for path in changed_files(base_ref()):
    parts = Path(path).parts
    if path.startswith("FiscalKit/Package."):
        everything = True
    elif parts[:2] == ("FiscalKit", "Sources") and len(parts) > 2 and parts[2] in targets:
        changed_modules.add(parts[2])
    elif parts[:2] == ("FiscalKit", "Tests") and len(parts) > 2 and parts[2] in targets:
        changed_tests.add(parts[2])

if everything:
    print("\n".join(tests))
    sys.exit()

dependents = {name: set() for name in targets}
for name, target in targets.items():
    for dependency in target.get("target_dependencies", []):
        dependents.setdefault(dependency, set()).add(name)

affected, queue = set(changed_modules), list(changed_modules)
while queue:
    for dependent in dependents.get(queue.pop(), ()):
        if dependent not in affected:
            affected.add(dependent)
            queue.append(dependent)

selected = {name for name in tests if name in affected or name in changed_tests}
print("\n".join(sorted(selected)))
