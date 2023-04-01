#!/usr/bin/env bash

# --- begin runfiles.bash initialization v2 ---
# Copy-pasted from the Bazel Bash runfiles library v2.
set -o nounset -o pipefail; f=bazel_tools/tools/bash/runfiles/runfiles.bash
# shellcheck disable=SC1090
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -o errexit
# --- end runfiles.bash initialization v2 ---

# MARK - Locate Deps

assertions_sh_location=cgrindel_bazel_starlib/shlib/lib/assertions.sh
assertions_sh="$(rlocation "${assertions_sh_location}")" || \
  (echo >&2 "Failed to locate ${assertions_sh_location}" && exit 1)
source "${assertions_sh}"

PrintVersion_location=rules_swift_package_manager/swiftpkg/tests/generate_modulemap_tests/Sources/PrintVersion/PrintVersion
PrintVersion="$(rlocation "${PrintVersion_location}")" || \
  (echo >&2 "Failed to locate ${PrintVersion_location}" && exit 1)

PrintVersionObjc_location=rules_swift_package_manager/swiftpkg/tests/generate_modulemap_tests/PrintVersionObjc/PrintVersionObjc
PrintVersionObjc="$(rlocation "${PrintVersionObjc_location}")" || \
  (echo >&2 "Failed to locate ${PrintVersionObjc_location}" && exit 1)

# MARK - Test

expected="1.2.3"

output="$("${PrintVersion}")"
assert_equal "${expected}" "${output}" "version check"

objc_output="$("${PrintVersionObjc}")"
assert_equal "${expected}" "${output}" "version check"
