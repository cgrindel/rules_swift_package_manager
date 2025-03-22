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

sdk_dirs() {
  local platform_path="${1}"
  local sdks_path="${platform_path}/Developer/SDKs"
  find "${sdks_path}" -name "*.sdk" -depth 1 -type d -print0
}

sdk_paths_for_platform() {
  local platform_path="${1}"

  # Find the SDK paths for the platform
  local sdk_paths=()
  while IFS=  read -r -d $'\0'; do
      sdk_paths+=("$REPLY")
  done < <(sdk_dirs "${platform_path}")

  echo "${sdk_paths[@]}"
}

list_frameworks_for_sdk() {
  local sdk_path="${1}"
  local frameworks_dir="${sdk_path}/System/Library/Frameworks"
  local lib_swift_dir="${sdk_path}/usr/lib/swift"

  # Find all ``.framework` directories within the expected SDK library path.
  # This includes things like `UIKit.framework`, etc.
  find "${frameworks_dir}" -name "*.framework" -depth 1 -not -name "_*" -exec basename -s .framework {} \;
}

list_frameworks_for_platform() {
  local platform_path="${1}"
  local sdk_paths=("$(sdk_paths_for_platform "${platform_path}")")

  local frameworks=""
  for sdk_path in "${sdk_paths[@]}" ; do
    frameworks+="$(list_frameworks_for_sdk "${sdk_path}")"
  done

  echo "${frameworks}" | sort --unique
}

list_swift_modules_for_sdk() {
  local sdk_path="${1}"
  local lib_swift_dir="${sdk_path}/usr/lib/swift"

  # Find all `.swiftmodule` directories within the expected SDK library path.
  # This includes things like `os` and `Darwin` which do not have `.framework` equivalents.
  find "${lib_swift_dir}" -name "*.swiftmodule" -depth 1 -not -name "_*" -exec basename -s .swiftmodule {} \;
}

list_swift_modules_for_platform() {
  local platform_path="${1}"
  local frameworks="${2}"
  local sdk_paths=("$(sdk_paths_for_platform "${platform_path}")")

  local swift_modules=()
  for sdk_path in "${sdk_paths[@]}" ; do
    local sdk_swift_modules="$(list_swift_modules_for_sdk "${sdk_path}")"

    # Filter out any swift modules that are also frameworks
    for module in ${sdk_swift_modules} ; do
      is_framework=false
      for framework in ${frameworks} ; do
        if [[ "${module}" == "${framework}" ]]; then
          is_framework=true
          break
        fi
      done

      if [[ "${is_framework}" == false ]]; then
        swift_modules+=("${module}")
      fi
    done

  done

  (IFS=$'\n'; echo "${swift_modules[*]}" | sort --unique)
}

format_as_bzl_list_item() {
  sed -E -e 's/^(.*)/    "\1",/g'
}


show_usage() {
  get_usage
  exit 0
}

# MARK - Process Args

get_usage() {
  local utility
  utility="$(basename "${BASH_SOURCE[0]}")"
  cat <<-EOF
Generates a Go source file with the current list of macOS and iOS frameworks.

Usage:
${utility} [OPTION]... 

Options:
  --bzl_output             The path where to write the Starlark source. 
                           Relative paths are evaluated from the workspace 
                           root.
EOF
}

# Process args
while (("$#")); do
  case "${1}" in
    "--help")
      show_usage
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

if [[ -z "${bzl_output:-}" ]]; then
  usage_error "Must specify an output path for the Bazel Starlark source file."
fi



# sdk_path="$(xcrun --show-sdk-path)"
# macos_frameworks_dir="${sdk_path}/System/Library/Frameworks"

sdk_version="$(xcrun --show-sdk-version)"
sdk_build_version="$(xcrun --show-sdk-build-version)"

platforms_path="$(dirname "$(xcrun --show-sdk-platform-path)")"

macos_frameworks="$(list_frameworks_for_platform "${platforms_path}/MacOSX.platform")"
ios_frameworks="$(list_frameworks_for_platform "${platforms_path}/iPhoneOS.platform")"
tvos_frameworks="$(list_frameworks_for_platform "${platforms_path}/AppleTVOS.platform")"
watchos_frameworks="$(list_frameworks_for_platform "${platforms_path}/WatchOS.platform")"

macos_swift_modules="$(list_swift_modules_for_platform "${platforms_path}/MacOSX.platform" "${macos_frameworks}")"
ios_swift_modules="$(list_swift_modules_for_platform "${platforms_path}/iPhoneOS.platform" "${ios_frameworks}")"
tvos_swift_modules="$(list_swift_modules_for_platform "${platforms_path}/AppleTVOS.platform" "${tvos_frameworks}")"
watchos_swift_modules="$(list_swift_modules_for_platform "${platforms_path}/WatchOS.platform" "${watchos_frameworks}")"

# Starlark Source

bzl_src="$(cat <<-EOF
"""Module listing built-in Frameworks."""

load("@bazel_skylib//lib:sets.bzl", "sets")

# NOTE: This file is generated by running the following:
# bazel run //tools/generate_builtin_frameworks
#
# SDK Version: ${sdk_version}
# SDK Build Version: ${sdk_build_version}

_macos_frameworks = sets.make([
$(echo "${macos_frameworks}" | format_as_bzl_list_item)
])

_macos_swift_modules = sets.make([
$(echo "${macos_swift_modules}" | format_as_bzl_list_item)
])

_ios_frameworks = sets.make([
$(echo "${ios_frameworks}" | format_as_bzl_list_item)
])

_ios_swift_modules = sets.make([
$(echo "${ios_swift_modules}" | format_as_bzl_list_item)
])

_tvos_frameworks = sets.make([
$(echo "${tvos_frameworks}" | format_as_bzl_list_item)
])

_tvos_swift_modules = sets.make([
$(echo "${tvos_swift_modules}" | format_as_bzl_list_item)
])

_watchos_frameworks = sets.make([
$(echo "${watchos_frameworks}" | format_as_bzl_list_item)
])

_watchos_swift_modules = sets.make([
$(echo "${watchos_swift_modules}" | format_as_bzl_list_item)
])

_all_frameworks = sets.union(
    _macos_frameworks,
    _ios_frameworks,
    _tvos_frameworks,
    _watchos_frameworks,
)

_all_swift_modules = sets.union(
    _macos_swift_modules,
    _ios_swift_modules,
    _tvos_swift_modules,
    _watchos_swift_modules,
)

apple_builtin_frameworks = struct(
    all = _all_frameworks,
    ios = _ios_frameworks,
    macos = _macos_frameworks,
    tvos = _tvos_frameworks,
    watchos = _watchos_frameworks,
)

apple_builtin_swift_modules = struct(
    all = _all_swift_modules,
    ios = _ios_swift_modules,
    macos = _macos_swift_modules,
    tvos = _tvos_swift_modules,
    watchos = _watchos_swift_modules,
)

apple_builtin = struct(
    frameworks = apple_builtin_frameworks,
    swift_modules = apple_builtin_swift_modules,
)
EOF
)"

# Ouptut the Starlark source
bzl_output_cmd=( echo "${bzl_src}" )
if [[ ! "${bzl_output}" = /* ]]; then
  bzl_output="${BUILD_WORKSPACE_DIRECTORY}/${bzl_output}"
fi
"${bzl_output_cmd[@]}" > "${bzl_output}"
