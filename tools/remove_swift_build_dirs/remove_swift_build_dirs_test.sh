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

remove_swift_build_dirs_sh_location=cgrindel_swift_bazel/tools/remove_swift_build_dirs/remove_swift_build_dirs.sh
remove_swift_build_dirs_sh="$(rlocation "${remove_swift_build_dirs_sh_location}")" || \
  (echo >&2 "Failed to locate ${remove_swift_build_dirs_sh_location}" && exit 1)

# MARK - Test

workspace_dir="${PWD}/workspace"
foo_dir="${workspace_dir}/examples/foo"
bar_dir="${workspace_dir}/bar"
# This is not under the workspace and should not be deleted
chicken_dir="${PWD}/chicken"

# Create .build directories in these directories. The .build directories should not be empty
dirs=("${foo_dir}" "${bar_dir}" "${chicken_dir}")
for dir in "${dirs[@]}" ; do
  build_dir="${dir}/.build"
  mkdir -p "${build_dir}" 
  touch "${build_dir}/hello"
done

# Remove the .build directories under the workspace
export BUILD_WORKSPACE_DIRECTORY="${workspace_dir}"
"${remove_swift_build_dirs_sh}"

# Confirm things that should be deleted are deleted and everything else still exists.
[[ -d "${workspace_dir}" ]] || fail "Expected workspace directory to exist."
[[ -d "${foo_dir}" ]] || fail "Expected foo directory to exist."
[[ -d "${bar_dir}" ]] || fail "Expected bar directory to exist."
[[ -d "${chicken_dir}" ]] || fail "Expected chicken directory to exist."
[[ -e "${chicken_dir}/.build/hello" ]] || fail "Expected chicken's build directory to exist."
[[ ! -e "${foo_dir}/.build" ]] || fail "Expected foo's build directory to not exist."
[[ ! -e "${bar_dir}/.build" ]] || fail "Expected bar's build directory to not exist."
