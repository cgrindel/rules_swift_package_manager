#!/usr/bin/env bash

# --- begin runfiles.bash initialization v2 ---
# Copy-pasted from the Bazel Bash runfiles library v2.
set -o nounset -o pipefail
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
set -o errexit
# --- end runfiles.bash initialization v2 ---

# MARK - Locate Deps

assertions_sh_location=cgrindel_bazel_starlib/shlib/lib/assertions.sh
assertions_sh="$(rlocation "${assertions_sh_location}")" \
  || (echo >&2 "Failed to locate ${assertions_sh_location}" && exit 1)
# shellcheck disable=SC1090
source "${assertions_sh}"

lib_sh_location=rules_swift_package_manager/swiftpkg/internal/swift_package_lib.sh
lib_sh="$(rlocation "${lib_sh_location}")" \
  || (echo >&2 "Failed to locate ${lib_sh_location}" && exit 1)
# shellcheck disable=SC1090
source "${lib_sh}"

# MARK - Test Helpers

# Creates a unique temp dir under TEST_TMPDIR and prints the path.
new_tmp_dir() {
  mktemp -d "${TEST_TMPDIR:-/tmp}/spl_test.XXXXXX"
}

# MARK - spl_setup_netrc

# An empty netrc path should produce no output and not error.
netrc_empty_output="$(spl_setup_netrc "")"
assert_equal "" "${netrc_empty_output}" "empty netrc should produce no output"

# A valid netrc path should produce `--netrc-file <realpath>`.
netrc_tmp_dir="$(new_tmp_dir)"
netrc_file="${netrc_tmp_dir}/.netrc"
: >"${netrc_file}"
netrc_output="$(spl_setup_netrc "${netrc_file}")"
netrc_expected="--netrc-file $(readlink -f "${netrc_file}")"
assert_equal \
  "${netrc_expected}" "${netrc_output}" \
  "valid netrc should produce --netrc-file <realpath>"

# MARK - spl_setup_registries

# An empty registries_json should NOT create the config dir or a symlink.
reg_empty_tmp_dir="$(new_tmp_dir)"
spl_setup_registries "" "${reg_empty_tmp_dir}/.config"
if [[ -e ${reg_empty_tmp_dir}/.config ]]; then
  fail "empty registries_json should not create config dir"
fi

# A valid registries_json should symlink into <config_path>/registries.json.
reg_tmp_dir="$(new_tmp_dir)"
registries_file="${reg_tmp_dir}/registries.json"
echo '{"registries":{}}' >"${registries_file}"
config_path="${reg_tmp_dir}/.config"
spl_setup_registries "${registries_file}" "${config_path}"

symlink="${config_path}/registries.json"
if [[ ! -L ${symlink} ]]; then
  fail "expected symlink at ${symlink}"
fi
if [[ ! -f ${symlink} ]]; then
  fail "symlink target at ${symlink} is not a readable file"
fi
symlink_target="$(readlink "${symlink}")"
expected_target="$(readlink -f "${registries_file}")"
assert_equal \
  "${expected_target}" "${symlink_target}" \
  "symlink should point to the registries.json realpath"

echo "All tests passed."
