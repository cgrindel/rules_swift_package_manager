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

generate_builtin_frameworks_sh_location=cgrindel_swift_bazel/tools/generate_builtin_frameworks/generate_builtin_frameworks.sh
generate_builtin_frameworks_sh="$(rlocation "${generate_builtin_frameworks_sh_location}")" || \
  (echo >&2 "Failed to locate ${generate_builtin_frameworks_sh_location}" && exit 1)

# MARK - Test

# Generate usage message
output="$("${generate_builtin_frameworks_sh}" --help)"
assert_match "Usage:" "${output}"

# Default output
output="$("${generate_builtin_frameworks_sh}")"
assert_match "package swift" "${output}"
assert_match "var macosFrameworks =" "${output}"
assert_match "AppKit" "${output}"
assert_match "var iosFrameworks =" "${output}"
assert_match "UIKit" "${output}"

# Change the package
output="$("${generate_builtin_frameworks_sh}" --go_package foobar)"
assert_match "package foobar" "${output}"

output_dir="${PWD}/output"
rm -rf "${output_dir}"
mkdir -p "${output_dir}"

# Write to an absolute path
absolute_path="${output_dir}/absolute.go"
"${generate_builtin_frameworks_sh}" "${absolute_path}"
[[ -e "${absolute_path}" ]] || fail "Expected the output file for the absolute path to exist."
output="$(< "${absolute_path}")"
assert_match "package swift" "${output}"
assert_match "var macosFrameworks =" "${output}"
assert_match "var iosFrameworks =" "${output}"

# Write to a relative path
export BUILD_WORKSPACE_DIRECTORY="${output_dir}"
relative_path="foo/relative.go"
expected_output_path="${BUILD_WORKSPACE_DIRECTORY}/${relative_path}"
mkdir -p "$(dirname "${expected_output_path}")"
"${generate_builtin_frameworks_sh}" "${relative_path}"
[[ -e "${expected_output_path}" ]] || fail "Expected the output file for the relative path to exist."
assert_match "package swift" "${output}"
assert_match "var macosFrameworks =" "${output}"
assert_match "var iosFrameworks =" "${output}"
