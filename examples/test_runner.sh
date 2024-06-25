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

create_scratch_dir_sh_location=rules_bazel_integration_test/tools/create_scratch_dir.sh
create_scratch_dir_sh="$(rlocation "${create_scratch_dir_sh_location}")" || \
  (echo >&2 "Failed to locate ${create_scratch_dir_sh_location}" && exit 1)

# MARK - Process Arguments

legacy_mode=false
while (("$#")); do
  case "${1}" in
    "--legacy")
      legacy_mode=true
      shift 1
      ;;
    "--nolegacy")
      legacy_mode=false
      shift 1
      ;;
    *)
      args+=("${1}")
      shift 1
      ;;
  esac
done

bazel="${BIT_BAZEL_BINARY:-}"
workspace_dir="${BIT_WORKSPACE_DIR:-}"

[[ -n "${bazel:-}" ]] || exit_with_msg "Must specify the location of the Bazel binary."
[[ -n "${workspace_dir:-}" ]] || exit_with_msg "Must specify the location of the workspace directory."

# MARK - Create Scratch Directory

scratch_dir="$("${create_scratch_dir_sh}" --workspace "${workspace_dir}")"
cd "${scratch_dir}"

if [[ "${legacy_mode}" == "true" ]]; then
  echo "build --config=legacy" >> .bazelrc
fi

# Dump Bazel info
echo "=== Output Bazel info ==="
"${bazel}" info

# MARK - Test As Is

echo "=== Do Test ==="
do_test

# MARK - Clean Test

if [[ -f set_up_clean_test ]]; then
  echo "=== Set Up Clean Test ==="
  ./set_up_clean_test
  echo "=== Do Clean Test ==="
  do_test
fi
