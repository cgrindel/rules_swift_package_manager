#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

# Thin wrapper that sources swift_package_lib.sh and delegates to
# spl_run_swift_package. The swift_worker_binary rule passes
# --swift_worker as the first flag-value pair; remaining flags come
# from the swift_package_tool_repo generated target.

# --- begin runfiles.bash initialization ---
# Copy-pasted from Bazel's Bash runfiles library.
if [[ ! -d ${RUNFILES_DIR:-/dev/null} && ! -f ${RUNFILES_MANIFEST_FILE:-/dev/null} ]]; then
  if [[ -f "$0.runfiles_manifest" ]]; then
    export RUNFILES_MANIFEST_FILE="$0.runfiles_manifest"
  elif [[ -f "$0.runfiles/MANIFEST" ]]; then
    export RUNFILES_MANIFEST_FILE="$0.runfiles/MANIFEST"
  elif [[ -f "$0.runfiles/bazel_tools/tools/bash/runfiles/runfiles.bash" ]]; then
    export RUNFILES_DIR="$0.runfiles"
  fi
fi
if [[ -f "${RUNFILES_DIR:-/dev/null}/bazel_tools/tools/bash/runfiles/runfiles.bash" ]]; then
  # shellcheck source=/dev/null
  source "${RUNFILES_DIR}/bazel_tools/tools/bash/runfiles/runfiles.bash"
elif [[ -f ${RUNFILES_MANIFEST_FILE:-/dev/null} ]]; then
  # shellcheck source=/dev/null
  source "$(grep -m1 "^bazel_tools/tools/bash/runfiles/runfiles.bash " \
    "$RUNFILES_MANIFEST_FILE" | cut -d ' ' -f 2-)"
else
  echo >&2 "ERROR: cannot find @bazel_tools//tools/bash/runfiles:runfiles.bash"
  exit 1
fi
# --- end runfiles.bash initialization ---

# Source the shared library via rlocation.
# Try external repo name first, then local workspace name.
lib_rel="swiftpkg/internal/swift_package_lib.sh"
lib_path="$(rlocation "rules_swift_package_manager/${lib_rel}" 2>/dev/null)" \
  || lib_path="$(rlocation "_main/${lib_rel}" 2>/dev/null)" \
  || {
    echo >&2 "ERROR: Could not find ${lib_rel}"
    exit 1
  }
# shellcheck source=swiftpkg/internal/swift_package_lib.sh
source "${lib_path}"

spl_run_swift_package "$@"
