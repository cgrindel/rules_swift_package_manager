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

output_dir="${PWD}/output"
rm -rf "${output_dir}"
mkdir -p "${output_dir}"

# Write Go file to an absolute path and change the package
absolute_path="${output_dir}/absolute.go"
"${generate_builtin_frameworks_sh}" --go_output "${absolute_path}" --go_package foobar
[[ -e "${absolute_path}" ]] || fail "Expected the output file for the absolute path to exist."
output="$(< "${absolute_path}")"
assert_match "package foobar" "${output}" "absolute path"
assert_match "var macosFrameworks =" "${output}" "absolute path"
assert_match "var iosFrameworks =" "${output}" "absolute path"

# Write Go file to a relative path
export BUILD_WORKSPACE_DIRECTORY="${output_dir}"
relative_path="foo/relative.go"
expected_output_path="${BUILD_WORKSPACE_DIRECTORY}/${relative_path}"
mkdir -p "$(dirname "${expected_output_path}")"
"${generate_builtin_frameworks_sh}" --go_output "${relative_path}"
[[ -e "${expected_output_path}" ]] || fail "Expected the output file for the relative path to exist."
output="$(< "${expected_output_path}")"
assert_match "package swift" "${output}" "relative path"
assert_match "var macosFrameworks =" "${output}" "relative path"
assert_match "var iosFrameworks =" "${output}" "relative path"
