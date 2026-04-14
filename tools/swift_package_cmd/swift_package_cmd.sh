#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

# Thin wrapper that sources swift_package_lib.sh and delegates to
# spl_run_swift_package. The swift_worker_binary rule passes
# --swift_worker as the first flag-value pair; remaining flags come
# from the swift_package_tool_repo generated target.

# Locate swift_package_lib.sh relative to this script.
# In the runfiles tree, both this script and the library live under
# the same repository root:
#   <repo>/tools/swift_package_cmd/swift_package_cmd.sh
#   <repo>/swiftpkg/internal/swift_package_lib.sh
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="${script_dir}/../.."
lib_path="${repo_root}/swiftpkg/internal/swift_package_lib.sh"

if [[ ! -f ${lib_path} ]]; then
  echo >&2 "ERROR: Could not find swift_package_lib.sh at ${lib_path}"
  exit 1
fi

# shellcheck source=swiftpkg/internal/swift_package_lib.sh
source "${lib_path}"

spl_run_swift_package "$@"
