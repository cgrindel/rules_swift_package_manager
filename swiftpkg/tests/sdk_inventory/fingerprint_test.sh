#!/usr/bin/env bash
set -euo pipefail
/usr/bin/python3 - "$1" <<'PY'
import pathlib
import runpy
import sys
import tempfile

fingerprint = runpy.run_path(sys.argv[1])["fingerprint"]
with tempfile.TemporaryDirectory() as tmp:
    root = pathlib.Path(tmp)
    a, b = root / "A", root / "B"
    a.write_text("same")
    b.write_text("same")
    files = [str(a), str(b)]
    before = {"files": files, "layout": [["current", str(a), "file"]]}
    after = {"files": files, "layout": [["current", str(b), "file"]]}
    original = fingerprint(before)
    assert original == fingerprint(before), "unchanged inputs must be stable"
    assert original != fingerprint(after), "symlink destination must affect digest"
    a.write_text("changed")
    assert original != fingerprint(before), "file contents must affect digest"
PY
