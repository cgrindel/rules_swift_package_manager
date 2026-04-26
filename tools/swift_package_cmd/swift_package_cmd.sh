#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

# --- begin runfiles.bash initialization v3 ---
# Copy-pasted from the Bazel Bash runfiles library v3.
set -uo pipefail
set +e
f=bazel_tools/tools/bash/runfiles/runfiles.bash
# shellcheck disable=SC1090
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null \
  || source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null \
  || source "$0.runfiles/$f" 2>/dev/null \
  || source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null \
  || source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null \
  || {
    echo >&2 "ERROR: cannot find $f"
    exit 1
  }
f=
set -e
# --- end runfiles.bash initialization v3 ---

# Thin wrapper that sources swift_package_lib.sh and delegates to
# spl_run_swift_package. The swift_worker_binary rule passes
# --swift_worker as the first flag-value pair; remaining flags come
# from the swift_package_tool_repo generated target.

lib_location=rules_swift_package_manager/swiftpkg/internal/swift_package_lib.sh
lib_path="$(rlocation "${lib_location}")" \
  || {
    echo >&2 "ERROR: Could not locate ${lib_location}"
    exit 1
  }

# shellcheck source=../../swiftpkg/internal/swift_package_lib.sh
source "${lib_path}"

spl_run_swift_package "$@"
