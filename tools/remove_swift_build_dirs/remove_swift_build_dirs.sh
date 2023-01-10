#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

if [[ -z "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
  echo >&2 "Expected BUILD_WORKSPACE_DIRECTORY to be defined."
  exit 1
fi

# Find and remove the Swift build directories
find "${BUILD_WORKSPACE_DIRECTORY}" -type d -name ".build" -prune -exec rm -rf "{}" \;
