#!/usr/bin/env bash

# The backticks in the messages are literal.
# shellcheck disable=SC2016

# Fails when the Swift toolchain's major.minor version differs from the one
# that produced a slice's `swift_deps_cache`. Run by `swift_version_check`.
#
# Usage: swift_version_check.sh <swift> <version_file> <slice_dir> <marker>

set -o errexit -o nounset -o pipefail

swift="${1}"
version_file="${2}"
slice_dir="${3}"
marker="${4}"

want="$(head -n 1 "${version_file}" | tr -d '[:space:]' | cut -d. -f1,2)"
if ! version_output="$("${swift}" --version 2>&1)"; then
  printf 'swift_version_check: `swift --version` failed:\n%s\n' \
    "${version_output}" >&2
  exit 1
fi
have="$(
  printf '%s\n' "${version_output}" \
    | sed -nE 's/.*Swift version ([0-9]+\.[0-9]+).*/\1/p' \
    | head -n 1
)"
if [[ -z ${have} ]]; then
  printf 'swift_version_check: could not parse `swift --version`:\n%s\n' \
    "${version_output}" >&2
  exit 1
fi
if [[ ${have} != "${want}" ]]; then
  msg="\`swift_deps_cache\` for slice \`${slice_dir}\` was produced by"
  msg+=" Swift ${want} but this build uses Swift ${have}; run"
  msg+=" \`bazel run @swift_package//:cache\`"
  printf '%s\n' "${msg}" >&2
  exit 1
fi
touch "${marker}"
