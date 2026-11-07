#!/usr/bin/env bash
set -euo pipefail
python3 - "$1" <<'PY'
import json
import sys

with open(sys.argv[1]) as source:
    report = json.load(source)
greeter = report["targets"]["Greeter"]
assert any(setting["values"] == ["Security"] for setting in greeter["linked_frameworks"])
for sdk, expected, absent in [("MacOSX", "AppKit", "UIKit"), ("iPhoneSimulator", "UIKit", "AppKit")]:
    records = [record for record in greeter["scans"] if record["sdk"] == sdk]
    assert {record["configuration"] for record in records} == {"debug", "release", "fastbuild"}, records
    for record in records:
        imports = set(record["imports"])
        assert {expected, "Foundation", "ObjCGreeter", "Compression"} <= imports, record
        assert any(w["module"] == "ObjCGreeter" for w in record["warnings"]), record
        assert absent not in imports, record
for record in report["targets"]["DeveloperProbe"]["scans"]:
    assert {"XCTest", "Testing"} <= set(record["imports"]), record
print("Compiler inference report: SDK fallbacks, package import, manifest framework and all configurations verified.")
PY
