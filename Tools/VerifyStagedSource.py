"""Compare production sources, project settings, core sources, and assets with a build stage."""
import hashlib
import json
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
stage = Path(sys.argv[1]).resolve()
include = [root / "TuringMachine", root / "TuringCore/Sources", root / "TuringCore/Package.swift", root / "project.yml", root / "TuringMachine.xcodeproj/project.pbxproj", root / "Tests"]
paths = []
for target in include:
    paths.extend([target] if target.is_file() else [p for p in target.rglob("*") if p.is_file()])
errors = []
for path in paths:
    relative = path.relative_to(root)
    other = stage / relative
    if not other.is_file() or hashlib.sha256(path.read_bytes()).digest() != hashlib.sha256(other.read_bytes()).digest():
        errors.append(str(relative))
print(json.dumps({"compared": len(paths), "differences": errors}, indent=2))
sys.exit(bool(errors))
