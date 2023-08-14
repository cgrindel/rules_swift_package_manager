#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

if [[ -z "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
  echo >&2 "Expected BUILD_WORKSPACE_DIRECTORY to be defined."
  exit 1
fi
cd "${BUILD_WORKSPACE_DIRECTORY}"
