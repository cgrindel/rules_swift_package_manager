#!/usr/bin/env bash

# TODO(chuck): Add some doc

# script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null && pwd)"

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
  find "${dir}" -name "*.framework" -depth 1 -not -name "_*" -exec basename -s .framework {} \;
}

format_as_go_args() {
  sed -E -e 's/^(.*)/\t"\1",/g'
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
${utility} [OPTION]... [<output_path>]

Options:
  --go_package <go_pkg>  The name of the Go package. (Default: ${go_package})
  <output_path>          The path where to write the Go source.
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
    -*)
      usage_error "Unrecognized option. ${1}"
      ;;
    *)
      if [[ -z "${output_path:-}" ]]; then
        output_path="${1}"
        shift 1
      else
        usage_error "Unexpected argument. ${1}"
      fi
      ;;
  esac
done


is_installed xcrun || usage_error "This utility requires that xcrun is available on the PATH."

sdk_path="$(xcrun --show-sdk-path)"
macos_frameworks_dir="${sdk_path}/System/Library/Frameworks"
ios_frameworks_dir="${sdk_path}/System/iOSSupport/System/Library/Frameworks"

macos_frameworks="$(list_frameworks "${macos_frameworks_dir}")"
ios_frameworks="$(list_frameworks "${ios_frameworks_dir}")"

go_src="$(cat <<-EOF
package "${go_package}"

import mapset "github.com/deckarep/golang-set/v2"

var macosFrameworks = mapset.NewSet[string](
$(echo "${macos_frameworks}" | format_as_go_args)
)

var iosFrameworks = mapset.NewSet[string](
$(echo "${ios_frameworks}" | format_as_go_args)
)
EOF
)"

# Ouptut the Go source
output_cmd=( echo "${go_src}" )
if [[ -n "${output_path:-}" ]]; then
  "${output_cmd[@]}" > "${output_path}"
else
  "${output_cmd[@]}"
fi
