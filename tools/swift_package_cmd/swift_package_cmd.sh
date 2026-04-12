#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

# Thin wrapper that sources swift_package_lib.sh and delegates to
# spl_run_swift_package. The swift_worker_binary rule passes
# --swift_worker as the first flag-value pair; remaining flags come
# from the swift_package_tool_repo generated target.

# Locate swift_package_lib.sh in the runfiles tree.
# RUNFILES_DIR is set by Bazel when invoked via `bazel run`.
lib_rel="swiftpkg/internal/swift_package_lib.sh"
lib_path=""
for prefix in \
  "${RUNFILES_DIR:-}/_main" \
  "${RUNFILES_DIR:-}/rules_swift_package_manager"; do
  if [[ -f "${prefix}/${lib_rel}" ]]; then
    lib_path="${prefix}/${lib_rel}"
    break
  fi
done

if [[ -z ${lib_path} ]]; then
  echo >&2 "ERROR: Could not find ${lib_rel} in runfiles"
  exit 1
fi

# shellcheck source=swiftpkg/internal/swift_package_lib.sh
source "${lib_path}"

spl_run_swift_package "$@"
