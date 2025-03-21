#!/usr/bin/env bash

# --- begin runfiles.bash initialization v3 ---
# Copy-pasted from the Bazel Bash runfiles library v3.
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---

# MARK - Locate Dependencies

fail_sh_location=cgrindel_bazel_starlib/shlib/lib/fail.sh
fail_sh="$(rlocation "${fail_sh_location}")" || \
  (echo >&2 "Failed to locate ${fail_sh_location}" && exit 1)
source "${fail_sh}"

do_test_location=rules_swift_package_manager/tools/create_example/template_files/do_test
do_test="$(rlocation "${do_test_location}")" || \
  (echo >&2 "Failed to locate ${do_test_location}" && exit 1)

MODULE_bazel_location=rules_swift_package_manager/tools/create_example/template_files/MODULE.bazel
MODULE_bazel="$(rlocation "${MODULE_bazel_location}")" || \
  (echo >&2 "Failed to locate ${MODULE_bazel_location}" && exit 1)

set_up_clean_test_location=rules_swift_package_manager/tools/create_example/template_files/set_up_clean_test
set_up_clean_test="$(rlocation "${set_up_clean_test_location}")" || \
  (echo >&2 "Failed to locate ${set_up_clean_test_location}" && exit 1)

bazelrc_location=rules_swift_package_manager/tools/create_example/template_files/.bazelrc
bazelrc="$(rlocation "${bazelrc_location}")" || \
  (echo >&2 "Failed to locate ${bazelrc_location}" && exit 1)

# MARK - Functions

get_usage() {
  local utility
  utility="$(basename "${BASH_SOURCE[0]}")"
  cat <<-EOF
Create an example workspace.

Usage:
${utility} <example>

Options:
  --force            Replace any existing files. Default: false
  <example>          The name of the example without the '_example' suffix.
EOF
}

copy_template_file() {
  local force="${1}"
  local example_dir="${2}"
  local template_file="${3}"
  local basename
  basename="$(basename "${template_file}")"
  local output_path
  output_path="${example_dir}/${basename}"
  if [[ -e "${output_path}" ]] && [[ "${force}" == "false" ]]; then
    warn "File exists, skipping. ${output_path}"
    return 0
  fi
  cp -f "${template_file}" "${output_path}"
}

write_file() {
  local force="${1}"
  local output_path="${2}"
  local contents="${3:-}"
  if [[ -e "${output_path}" ]] && [[ "${force}" == "false" ]]; then
    warn "File exists, skipping. ${output_path}"
    return 0
  fi
  if [[ "${force}" == "true" ]]; then
    rm -f "${output_path}"
  fi
  if [[ -n "${contents:-}" ]]; then
    echo "${contents}" > "${output_path}"
  fi
  cat > "${output_path}"
}

# MARK - Process Args

force="false"
example=""
while (("$#")); do
  case "${1}" in
    "--help")
      show_usage
      exit 0
      ;;
    "--force")
      force="true"
      shift 1
      ;;
    "--noforce")
      force="false"
      shift 1
      ;;
    *)
      if [[ -z "${example:-}" ]]; then
        example="${1}"
      else
        usage_error "Unexpected argument. ${1}"
      fi
      shift 1
      ;;
  esac
done

[[ -n "${example:-}" ]] || usage_error "Missing value for 'example'."
if [[ "${example}" =~ _example$ ]]; then
  example_dirname="${example}"
else
  example_dirname="${example}_example"
fi
example_dir="${BUILD_WORKSPACE_DIRECTORY}/examples/${example_dirname}"

# MARK - Create example direcotry and write files

if [[ ! -d "${example_dir}" ]]; then
  echo "Creating directory: ${example_dir}"
  mkdir -p "${example_dir}"
else
  warn "Directory exists: ${example_dir} already exists."
fi

write_file "${force}" "${example_dir}/WORKSPACE" <<-EOF
# Intentionally blank: Using bzlmod
EOF

write_file "${force}" "${example_dir}/WORKSPACE.bzlmod" <<-EOF
# Intentionally blank: Force bzlmod to strict mode
EOF

write_file "${force}" "${example_dir}/BUILD.bazel" <<-EOF
load("@bazel_gazelle//:def.bzl", "gazelle", "gazelle_binary")
load("@cgrindel_bazel_starlib//bzltidy:defs.bzl", "tidy")

tidy(
    name = "tidy",
    targets = [
        ":update_build_files",
    ],
)

# MARK: - Gazelle

# Ignore the Swift build folder
# gazelle:exclude .build

gazelle_binary(
    name = "gazelle_bin",
    languages = [
        "@bazel_skylib_gazelle_plugin//bzl",
        "@swift_gazelle_plugin//gazelle",
    ],
)

gazelle(
    name = "update_build_files",
    gazelle = ":gazelle_bin",
)
EOF

write_file "${force}" "${example_dir}/README.md" <<-EOF
# ${example} Example
EOF

write_file "${force}" "${example_dir}/Package.swift" <<-EOF
// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "${example_dirname}",
    dependencies: [
        // TODO: Replace this dependency with your dependencies.
        .package(url: "https://github.com/apple/swift-log", from: "1.5.2"),
    ]
)
EOF

write_file "${force}" "${example_dir}/main.swift" <<-EOF
import Logging

let logger = Logger(label: "com.example.main")
logger.info("Hello World!")
EOF

copy_template_file "${force}" "${example_dir}" "${do_test}"
copy_template_file "${force}" "${example_dir}" "${MODULE_bazel}"
copy_template_file "${force}" "${example_dir}" "${set_up_clean_test}"
copy_template_file "${force}" "${example_dir}" "${bazelrc}"

# MARK - Initialize the repo

cd "${example_dir}"

echo "Running tidy..."
bazelisk run //:tidy

echo "Building..."
bazelisk build //...

echo "Running simple Swift binary..."
bazelisk run "//:${example_dirname}"

cat <<-EOF
All appears to be working!

Be sure to add the new example to one of the following lists in 'examples/example_infos.bzl',
as is appropriate for the requirements of the example. In preferred order, the lists are

1. _all_os_single_bazel_version_test_examples
2. _macos_single_bazel_version_test_examples
3. _all_os_all_bazel_versions_test_examples

You will need to run the following from the parent workspace once you have made the changes to
'examples/example_infos.bzl':

$ bazel run //:tidy
EOF
