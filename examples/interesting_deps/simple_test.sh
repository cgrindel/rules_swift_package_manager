#!/usr/bin/env bash

# --- begin runfiles.bash initialization v2 ---
# Copy-pasted from the Bazel Bash runfiles library v2.
set -uo pipefail; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v2 ---

err_msg() {
  local msg="$1"
  echo >&2 "${msg}"
  exit 1
}

print_location=interesting_deps_example/print
binary="$(rlocation "${print_location}")" || \
  (echo >&2 "Failed to locate ${print_location}" && exit 1)

output="$( "${binary}" )"

expected="Hello World"
echo "${output}" | grep "${expected}" || err_msg "Failed to find expected output. ${expected}"

expected="WebP version:"
echo "${output}" | grep "${expected}" || err_msg "Failed to find expected output. ${expected}"
