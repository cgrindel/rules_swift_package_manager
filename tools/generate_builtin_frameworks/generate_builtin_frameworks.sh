#!/usr/bin/env bash

# Generates a Go source file with the set of macOS and iOS framework names.

# --- begin runfiles.bash initialization v2 ---
# Copy-pasted from the Bazel Bash runfiles library v2.
set -o nounset -o pipefail; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -o errexit
# --- end runfiles.bash initialization v2 ---

# MARK - Locate Deps

fail_sh_location=cgrindel_bazel_starlib/shlib/lib/fail.sh
fail_sh="$(rlocation "${fail_sh_location}")" || \
  (echo >&2 "Failed to locate ${fail_sh_location}" && exit 1)
source "${fail_sh}"

env_sh_location=cgrindel_bazel_starlib/shlib/lib/env.sh
env_sh="$(rlocation "${env_sh_location}")" || \
  (echo >&2 "Failed to locate ${env_sh_location}" && exit 1)
source "${env_sh}"


# MARK - Functions

list_frameworks() {
  local dir="${1}"
  find "${dir}" -name "*.framework" -depth 1 -not -name "_*" -exec basename -s .framework {} \; \
    | sort
}

format_as_go_list_item() {
  sed -E -e 's/^(.*)/\t"\1",/g'
}

format_as_bzl_list_item() {
  sed -E -e 's/^(.*)/    "\1",/g'
}


show_usage() {
  get_usage
  exit 0
}

# MARK - Process Args

go_package="swift"

get_usage() {
  local utility
  utility="$(basename "${BASH_SOURCE[0]}")"
  cat <<-EOF
Generates a Go source file with the current list of macOS and iOS frameworks.

Usage:
${utility} [OPTION]... [<go_output>]

Options:
  --go_package <go_pkg>    The name of the Go package. (Default: ${go_package})
  --go_output <go_output>  The path where to write the Go source. If it is a 
                           relative path, it is evaluated relative to the 
                           workspace root.
EOF
}

# Process args
while (("$#")); do
  case "${1}" in
    "--help")
      show_usage
      ;;
    "--go_package")
      go_package="${2}"
      shift 2
      ;;
    "--go_output")
      go_output="${2}"
      shift 2
      ;;
    "--bzl_output")
      bzl_output="${2}"
      shift 2
      ;;
    -*)
      usage_error "Unrecognized option. ${1}"
      ;;
    *)
      usage_error "Unexpected argument. ${1}"
      ;;
  esac
done


is_installed xcrun || usage_error "This utility requires that xcrun is available on the PATH."

[[ -n "${go_output:-}" ]] || usage_error "Must specify an output path for the Go source file."
[[ -n "${bzl_output:-}" ]] || \
  usage_error "Must specify an output path for the Bazel Starlark source file."

sdk_path="$(xcrun --show-sdk-path)"
macos_frameworks_dir="${sdk_path}/System/Library/Frameworks"
ios_frameworks_dir="${sdk_path}/System/iOSSupport/System/Library/Frameworks"

sdk_version="$(xcrun --show-sdk-version)"
sdk_build_version="$(xcrun --show-sdk-build-version)"

macos_frameworks="$(list_frameworks "${macos_frameworks_dir}")"
ios_frameworks="$(list_frameworks "${ios_frameworks_dir}")"

# Go Source

go_src="$(cat <<-EOF
package ${go_package}

import mapset "github.com/deckarep/golang-set/v2"

// NOTE: This file is generated by running the following:
// bazel run //tools/generate_builtin_frameworks
// 
// SDK Version: ${sdk_version}
// SDK Build Version: ${sdk_build_version}

var macosFrameworks = mapset.NewSet[string](
$(echo "${macos_frameworks}" | format_as_go_list_item)
)

var iosFrameworks = mapset.NewSet[string](
$(echo "${ios_frameworks}" | format_as_go_list_item)
)
EOF
)"

# Ouptut the Go source
go_output_cmd=( echo "${go_src}" )
if [[ ! "${go_output}" = /* ]]; then
  go_output="${BUILD_WORKSPACE_DIRECTORY}/${go_output}"
fi
"${go_output_cmd[@]}" > "${go_output}"

# Starlark Source

bzl_src="$(cat <<-EOF
"""Module listing built-in Frameworks."""

load("@bazel_skylib//lib:sets.bzl", "sets")

# NOTE: This file is generated by running the following:
# bazel run //tools/generate_builtin_frameworks
#
# SDK Version: ${sdk_version}
# SDK Build Version: ${sdk_build_version}

_macos = sets.make([
$(echo "${macos_frameworks}" | format_as_bzl_list_item)
])

_ios = sets.make([
$(echo "${ios_frameworks}" | format_as_bzl_list_item)
])

_all = sets.union(_macos, _ios)

apple_builtin_frameworks = struct(
    all = _all,
    ios = _ios,
    macos = _macos,
)
EOF
)"

# Ouptut the Starlark source
bzl_output_cmd=( echo "${bzl_src}" )
if [[ ! "${bzl_output}" = /* ]]; then
  bzl_output="${BUILD_WORKSPACE_DIRECTORY}/${bzl_output}"
fi
"${bzl_output_cmd[@]}" > "${bzl_output}"
