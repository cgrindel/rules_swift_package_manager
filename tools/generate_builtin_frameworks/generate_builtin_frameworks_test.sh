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

generate_builtin_frameworks_sh_location=rules_swift_package_manager/tools/generate_builtin_frameworks/generate_builtin_frameworks.sh
generate_builtin_frameworks_sh="$(rlocation "${generate_builtin_frameworks_sh_location}")" || \
  (echo >&2 "Failed to locate ${generate_builtin_frameworks_sh_location}" && exit 1)

# MARK - Test

# Generate usage message
output="$("${generate_builtin_frameworks_sh}" --help)"
assert_match "Usage:" "${output}"

output_dir="${PWD}/output"
foo_output_dir="${output_dir}/foo"
rm -rf "${output_dir}"
mkdir -p "${output_dir}" "${foo_output_dir}"

# Write Go file to an absolute path and change the package
bzl_abs_path="${output_dir}/absolute.bzl"
"${generate_builtin_frameworks_sh}" \
  --bzl_output "${bzl_abs_path}"
[[ -e "${bzl_abs_path}" ]] || \
  fail "Expected the output file for the Starlark absolute path to exist."

bzl_output="$(< "${bzl_abs_path}")"
assert_match "_macos_frameworks = " "${bzl_output}" "Starlark absolute path"
assert_match "_macos_swift_modules = " "${bzl_output}" "Starlark absolute path"
assert_match "_ios_frameworks = " "${bzl_output}" "Starlark absolute path"
assert_match "_ios_swift_modules = " "${bzl_output}" "Starlark absolute path"
assert_match "_tvos_frameworks = " "${bzl_output}" "Starlark absolute path"
assert_match "_tvos_swift_modules = " "${bzl_output}" "Starlark absolute path"
assert_match "_watchos_frameworks = " "${bzl_output}" "Starlark absolute path"

# Write Go file to a relative path
export BUILD_WORKSPACE_DIRECTORY="${output_dir}"
bzl_rel_path="foo/relative.bzl"
exp_bzl_output_path="${BUILD_WORKSPACE_DIRECTORY}/${bzl_rel_path}"
"${generate_builtin_frameworks_sh}" \
  --bzl_output "${bzl_rel_path}"
[[ -e "${exp_bzl_output_path}" ]] || \
  fail "Expected the Starlark output file for the relative path to exist."

bzl_output="$(< "${exp_bzl_output_path}")"
assert_match "_macos_frameworks = " "${bzl_output}" "Starlark relative path"
assert_match "_macos_swift_modules = " "${bzl_output}" "Starlark relative path"
assert_match "_ios_frameworks = " "${bzl_output}" "Starlark relative path"
assert_match "_ios_swift_modules = " "${bzl_output}" "Starlark relative path"
assert_match "_tvos_frameworks = " "${bzl_output}" "Starlark relative path"
assert_match "_tvos_swift_modules = " "${bzl_output}" "Starlark relative path"
assert_match "_watchos_frameworks = " "${bzl_output}" "Starlark relative path"
assert_match "_watchos_swift_modules = " "${bzl_output}" "Starlark relative path"
