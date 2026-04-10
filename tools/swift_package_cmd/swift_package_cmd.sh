#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

# Thin wrapper that sources swift_package_lib.sh and delegates to
# spl_run_swift_package. The swift_worker_binary rule passes
# --swift_worker as the first flag-value pair; remaining flags come
# from the swift_package_tool_repo generated target.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The library is made available via runfiles / data dependency.
# shellcheck source=swiftpkg/internal/swift_package_lib.sh
source "${script_dir}/../swiftpkg/internal/swift_package_lib.sh" \
  2>/dev/null \
  || source "${script_dir}/swift_package_lib.sh" \
    2>/dev/null \
  || {
    echo >&2 "ERROR: Could not find swift_package_lib.sh"
    exit 1
  }

spl_run_swift_package "$@"
