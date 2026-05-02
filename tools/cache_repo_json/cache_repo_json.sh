#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

# Resolve the swift_package_lib helper and the buildozer binary from
# this script's runfiles. Extracted into a function so unit tests can
# source this file to exercise the pure helpers without bringing in
# the runfiles bootstrap.
_crj_setup_runfiles() {
  # --- begin runfiles.bash initialization v3 ---
  # Copy-pasted from the Bazel Bash runfiles library v3.
  set -uo pipefail
  set +e
  local f=bazel_tools/tools/bash/runfiles/runfiles.bash
  # shellcheck disable=SC1090
  source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null \
    || source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null \
    || source "$0.runfiles/$f" 2>/dev/null \
    || source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null \
    || source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null \
    || {
      echo >&2 "ERROR: cannot find $f"
      exit 1
    }
  set -e
  # --- end runfiles.bash initialization v3 ---

  local lib_location=rules_swift_package_manager/swiftpkg/internal/swift_package_lib.sh
  local lib_path
  lib_path="$(rlocation "${lib_location}")" \
    || {
      echo >&2 "ERROR: Could not locate ${lib_location}"
      exit 1
    }
  # shellcheck source=../../swiftpkg/internal/swift_package_lib.sh
  source "${lib_path}"

  # Locate the runfiles-bundled buildozer binary. Used to update
  # MODULE.bazel with dump_manifests / desc_manifests label maps.
  local buildozer_location=buildifier_prebuilt/buildozer/buildozer
  buildozer_path="$(rlocation "${buildozer_location}")" \
    || {
      echo >&2 "ERROR: Could not locate ${buildozer_location}"
      exit 1
    }
}

# Generates dump.json and desc.json caches for the root Package.swift
# and every transitive dependency, using the Bazel-resolved Swift
# toolchain (so the inspection toolchain matches the compilation
# toolchain). See //tools/cache_repo_json:BUILD.bazel and the design
# at the top of //swiftpkg/internal:swift_package_lib.sh.

# Print first line of `swift --version`. The exact format differs
# between Apple and open-source Swift, but is stable per toolchain
# and serves as our cache key. Examples:
#   "Apple Swift version 6.2 (swiftlang-6.2.0.19.9 clang-1700.3.19.1)"
#   "Swift version 5.10.1 (swift-5.10.1-RELEASE)"
crj_swift_version() {
  local swift_executable="$1"
  "${swift_executable}" --version | head -n 1
}

# Read swift_version from a swift_info.json file. Uses a small jq-free
# parser so we don't take on a jq dependency for one field.
crj_read_swift_info_version() {
  local swift_info_path="$1"
  # Match the first "swift_version": "<value>" pair. The sed expression
  # captures everything between the quotes after the colon.
  sed -nE 's/.*"swift_version"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' \
    "${swift_info_path}" | head -n 1
}

# Write swift_info.json with the current Swift version.
crj_write_swift_info() {
  local swift_info_path="$1"
  local swift_version="$2"
  cat >"${swift_info_path}" <<EOF
{
  "swift_version": "${swift_version}"
}
EOF
}

# Run swift package resolve or update via the shared library, forwarding
# every SPM flag we received from swift_package_tool_repo.
#
# Arguments:
#   $1 - subcommand ("resolve" or "update")
#   remaining - the captured SPM flags array
crj_run_spm_subcommand() {
  local cmd="$1"
  shift
  spl_run_swift_package "$@" --cmd "${cmd}"
}

# Print "<identity>\t<absolute_path>" lines for every fileSystem
# dependency listed in the supplied desc.json. SCM/registry deps are
# emitted separately via crj_resolved_pins because describe leaves their
# path null when only the source-control state is known.
#
# The cached desc.json stores paths relative to the parent package's
# root for portability, so dependency paths are absolutized against the
# supplied parent_pkg_dir before being emitted.
crj_describe_local_deps() {
  local desc_json="$1"
  local parent_pkg_dir="$2"
  python3 - "${desc_json}" "${parent_pkg_dir}" <<'PY'
import json, os.path, sys
desc_path, parent_dir = sys.argv[1], sys.argv[2]
with open(desc_path) as f:
    desc = json.load(f)
for dep in desc.get("dependencies", []):
    if dep.get("type") != "fileSystem":
        continue
    identity = dep.get("identity") or ""
    path = dep.get("path") or ""
    if not identity or not path:
        continue
    if not os.path.isabs(path):
        path = os.path.normpath(os.path.join(parent_dir, path))
    print(f"{identity}\t{path}")
PY
}

# Print "<identity>\t<checkout_dir>" lines for every SCM/registry pin
# in Package.resolved. SPM stores SCM checkouts in
# `<checkouts_dir>/<repo-basename-without-.git>` (case preserved); the
# package's SPM identity may differ (e.g. SwiftFormat -> swiftformat).
# Registry pins use the identity as the directory name.
crj_resolved_pins() {
  local resolved_path="$1"
  local checkouts_dir="$2"
  if [[ ! -f ${resolved_path} ]]; then
    return 0
  fi
  python3 - "${resolved_path}" "${checkouts_dir}" <<'PY'
import json, os.path, sys
resolved_path, checkouts_dir = sys.argv[1], sys.argv[2]
with open(resolved_path) as f:
    data = json.load(f)
for pin in data.get("pins", []):
    identity = pin.get("identity") or ""
    kind = pin.get("kind") or ""
    location = pin.get("location") or ""
    if kind in ("remoteSourceControl", "localSourceControl"):
        basename = location.rstrip("/").rsplit("/", 1)[-1]
        if basename.endswith(".git"):
            basename = basename[:-4]
        checkout = os.path.join(checkouts_dir, basename)
    elif kind == "registry":
        checkout = os.path.join(checkouts_dir, identity)
    else:
        continue
    if identity and checkout:
        print(f"{identity}\t{checkout}")
PY
}

# Run `swift package dump-package` and `swift package describe` on a
# specific package directory, writing dump.json and desc.json into the
# given output subdirectory. Reuses the SPM flags forwarded to this
# script so that --config-path (registries) and --replace-scm-with-registry
# are honored consistently with the resolve/update pass.
#
# Arguments:
#   $1 - swift_executable
#   $2 - target package directory (the package containing Package.swift)
#   $3 - output subdirectory (where dump.json and desc.json are written)
#   $4 - registries config dir or empty
#   $5 - replace_scm_with_registry ("true" / "false")
#   $6 - manifest_swiftc_flags (space-separated)
crj_dump_describe() {
  local swift_executable="$1"
  local pkg_dir="$2"
  local out_dir="$3"
  local cfg_path="$4"
  local replace_scm="$5"
  local manifest_flags="$6"

  mkdir -p "${out_dir}"

  local -a base_args=(package)
  if [[ -n ${manifest_flags} ]]; then
    # shellcheck disable=SC2206 # intentional word splitting
    base_args+=(${manifest_flags})
  fi
  if [[ -n ${cfg_path} ]]; then
    base_args+=(--config-path "${cfg_path}")
  fi
  if [[ ${replace_scm} == "true" ]]; then
    base_args+=(--replace-scm-with-registry)
  fi
  base_args+=(--package-path "${pkg_dir}")

  # Pipe through path relativization so the cache is portable across
  # checkouts and machines. Mirrors repository_utils._replace_working_directory:
  # any `<pkg_dir>/` prefix becomes `./`, and the read path absolutizes
  # back against the on-disk location at fetch time.
  "${swift_executable}" "${base_args[@]}" dump-package \
    | crj_relativize_paths "${pkg_dir}" \
      >"${out_dir}/dump.json"
  "${swift_executable}" "${base_args[@]}" describe --type json \
    | crj_relativize_paths "${pkg_dir}" \
      >"${out_dir}/desc.json"
  crj_write_dep_build_file "${out_dir}"
}

# Pipe stdin through, replacing every "${pkg_dir}/" occurrence with
# "./" and a bare "${pkg_dir}" (e.g. the top-level "path" field whose
# value equals the package root with no trailing component) with "."
# so cache files store paths relative to the package root. Plain
# string substitution is enough; the JSON content does not contain any
# metacharacters that would interact with this transformation.
crj_relativize_paths() {
  local pkg_dir="$1"
  python3 -c '
import sys
root = sys.argv[1].rstrip("/")
data = sys.stdin.read()
# Replace child-path occurrences first so the bare-root replacement
# does not chew into longer matches.
data = data.replace(root + "/", "./")
data = data.replace("\"" + root + "\"", "\".\"")
sys.stdout.write(data)
' "${pkg_dir}"
}

# Process one (identity, path) pair: skip if already visited, otherwise
# generate dump/desc for it and recurse into its filesystem deps.
# Recursion only follows local deps because SCM/registry deps are
# enumerated up front from Package.resolved.
crj_process_dep() {
  local swift_executable="$1"
  local identity="$2"
  local path="$3"
  local out_root="$4"
  local cfg_path="$5"
  local replace_scm="$6"
  local manifest_flags="$7"
  local visited="$8"

  if grep -qxF "${identity}" "${visited}" 2>/dev/null; then
    return 0
  fi
  echo "${identity}" >>"${visited}"

  local dep_out="${out_root}/${identity}"
  crj_dump_describe \
    "${swift_executable}" \
    "${path}" \
    "${dep_out}" \
    "${cfg_path}" \
    "${replace_scm}" \
    "${manifest_flags}"

  # Recurse into transitive filesystem deps (Package.resolved already
  # covers transitive SCM/registry deps).
  while IFS=$'\t' read -r child_identity child_path; do
    [[ -z ${child_identity} ]] && continue
    crj_process_dep \
      "${swift_executable}" \
      "${child_identity}" \
      "${child_path}" \
      "${out_root}" \
      "${cfg_path}" \
      "${replace_scm}" \
      "${manifest_flags}" \
      "${visited}"
  done < <(crj_describe_local_deps "${dep_out}/desc.json" "${path}")
}

# Write a BUILD.bazel for a per-dep cache directory that exports
# dump.json and desc.json. Repo rules consume them via cached_dump_manifest
# and cached_desc_manifest label attributes.
crj_write_dep_build_file() {
  local dep_dir="$1"
  cat >"${dep_dir}/BUILD.bazel" <<'EOF'
exports_files(
    [
        "desc.json",
        "dump.json",
    ],
    visibility = ["//visibility:public"],
)
EOF
}

# Write the root BUILD.bazel for the cache directory: declare the
# swift_info_test target so `bazel test //...` validates the cached
# Swift version against the current toolchain, and export
# swift_info.json for any downstream consumer.
crj_write_root_build_file() {
  local out_root="$1"
  cat >"${out_root}/BUILD.bazel" <<'EOF'
load(
    "@rules_swift_package_manager//swiftpkg:defs.bzl",
    "swift_info_test",
)

exports_files(
    ["swift_info.json"],
    visibility = ["//visibility:public"],
)

swift_info_test(
    name = "swift_info_test",
    swift_info = "swift_info.json",
)
EOF
}

# Drive buildozer to set the dump_manifests and desc_manifests dict
# attributes on the swift_deps.from_package tag in MODULE.bazel.
#
# Buildozer addresses module-extension tags with a `%` prefix; the
# trailing target is the file label `//MODULE.bazel:%swift_deps.from_package`,
# which matches every from_package invocation in the file. For
# single-tag setups (the common case) that is exactly right; multi-tag
# setups would require a more selective expression.
#
# `dict_set` takes `key:value` pairs. Colons inside the label value
# must be escaped as `\:` so buildozer's parser doesn't split on them.
#
# Arguments:
#   $1 - module_bazel path (workspace-absolute)
#   $2 - workspace-relative output_dir (e.g. "swift_deps_cache")
#   $3 - visited file (newline-separated identity list)
crj_update_module_bazel() {
  local module_bazel="$1"
  local output_dir_rel="$2"
  local visited="$3"

  if [[ ! -f ${module_bazel} ]]; then
    echo >&2 "WARNING: ${module_bazel} not found; skipping MODULE.bazel update."
    return 0
  fi

  local -a ops=()
  local identity
  while IFS= read -r identity; do
    [[ -z ${identity} ]] && continue
    local pkg="//${output_dir_rel}/${identity}"
    ops+=("dict_set dump_manifests ${identity}:${pkg}\\:dump.json")
    ops+=("dict_set desc_manifests ${identity}:${pkg}\\:desc.json")
  done <"${visited}"

  if [[ ${#ops[@]} -eq 0 ]]; then
    return 0
  fi

  # buildozer takes one command per positional arg; the final arg is
  # the target. The path arg must be relative to the workspace root.
  # macOS realpath lacks --relative-to, so use python (already a dep).
  local module_bazel_rel
  module_bazel_rel="$(python3 -c \
    'import os.path,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' \
    "${module_bazel}" "${BUILD_WORKSPACE_DIRECTORY}")"
  local target="//${module_bazel_rel}:%swift_deps.from_package"

  "${buildozer_path}" "${ops[@]}" "${target}"
}

# Remove any stale per-dep cache directories under ${output_dir} that are
# not present in the visited identity set. _main and swift_info.json are
# always preserved. This prevents obsolete dependency caches from sticking
# around after a Package.swift change drops a dep.
crj_prune_stale() {
  local out_root="$1"
  local visited="$2"

  shopt -s nullglob
  local entry
  for entry in "${out_root}"/*/; do
    local name
    name="$(basename "${entry}")"
    if [[ ${name} == "_main" ]]; then
      continue
    fi
    if ! grep -qxF "${name}" "${visited}" 2>/dev/null; then
      echo "Removing stale cache entry: ${name}"
      rm -rf "${entry}"
    fi
  done
  shopt -u nullglob
}

main() {
  _crj_setup_runfiles

  local swift_worker=""
  local output_dir=""
  local mode="resolve"
  local module_bazel=""

  # Cache-utility-specific flags are stripped here; everything else is
  # forwarded to spl_run_swift_package. spm_flags collects the SPM
  # passthrough flags so we can replay them for resolve/update and for
  # the per-package dump/describe runs.
  local -a spm_flags=()

  # We also peel off a few SPM flag values for direct use in the
  # dump/describe step. They stay in spm_flags so the resolve/update
  # passthrough still sees them.
  local package_path=""
  local config_path=""
  local replace_scm_with_registry="false"
  local manifest_swiftc_flags=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --output_dir)
        output_dir="$2"
        shift 2
        ;;
      --mode)
        mode="$2"
        shift 2
        ;;
      --module_bazel)
        module_bazel="$2"
        shift 2
        ;;
      --swift_worker)
        swift_worker="$2"
        spm_flags+=("$1" "$2")
        shift 2
        ;;
      --package_path)
        package_path="$2"
        spm_flags+=("$1" "$2")
        shift 2
        ;;
      --config_path)
        config_path="$2"
        spm_flags+=("$1" "$2")
        shift 2
        ;;
      --replace_scm_with_registry)
        replace_scm_with_registry="$2"
        spm_flags+=("$1" "$2")
        shift 2
        ;;
      --manifest_swiftc_flags)
        manifest_swiftc_flags="$2"
        spm_flags+=("$1" "$2")
        shift 2
        ;;
      --build_path | --cache_path | --security_path | \
        --enable_build_manifest_caching | --enable_dependency_cache | \
        --manifest_cache | --netrc_file | --registries_json | \
        --use_registry_identity_for_scm | --env)
        spm_flags+=("$1" "$2")
        shift 2
        ;;
      --)
        shift
        spm_flags+=("$@")
        break
        ;;
      *)
        echo >&2 "ERROR: unknown flag: $1"
        return 1
        ;;
    esac
  done

  if [[ -z ${swift_worker} ]]; then
    echo >&2 "ERROR: --swift_worker is required"
    return 1
  fi
  if [[ -z ${output_dir} ]]; then
    echo >&2 "ERROR: --output_dir is required"
    return 1
  fi
  case "${mode}" in
    resolve | update) ;;
    *)
      echo >&2 "ERROR: --mode must be 'resolve' or 'update' (got: ${mode})"
      return 1
      ;;
  esac

  if [[ -z ${BUILD_WORKSPACE_DIRECTORY:-} ]]; then
    echo >&2 "ERROR: BUILD_WORKSPACE_DIRECTORY is not set;" \
      'this target may only be `bazel run`.'
    return 1
  fi

  # Resolve the output_dir relative to the workspace. Keep the
  # original (workspace-relative) form for label generation; use the
  # absolute form for filesystem operations.
  local output_dir_rel="${output_dir}"
  if [[ ${output_dir} == /* ]]; then
    output_dir_rel="$(python3 -c \
      'import os.path,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' \
      "${output_dir}" "${BUILD_WORKSPACE_DIRECTORY}")"
  else
    output_dir="${BUILD_WORKSPACE_DIRECTORY}/${output_dir}"
  fi
  mkdir -p "${output_dir}"

  # Default --module_bazel to the workspace MODULE.bazel.
  if [[ -z ${module_bazel} ]]; then
    module_bazel="${BUILD_WORKSPACE_DIRECTORY}/MODULE.bazel"
  fi

  # Resolve the swift executable so we can read the toolchain version.
  local swift_executable
  swift_executable="$(spl_resolve_swift_executable "${swift_worker}")"

  local current_version
  current_version="$(crj_swift_version "${swift_executable}")"

  local swift_info_path="${output_dir}/swift_info.json"

  # Resolve mode: validate the cached version against the current
  # toolchain. If no cache yet, silently fall back to update mode so
  # first-time setup works without two commands.
  if [[ ${mode} == "resolve" ]]; then
    if [[ ! -f ${swift_info_path} ]]; then
      echo "No ${swift_info_path}; switching to update mode."
      mode="update"
    else
      local cached_version
      cached_version="$(crj_read_swift_info_version "${swift_info_path}")"
      if [[ ${cached_version} != "${current_version}" ]]; then
        echo >&2 "ERROR: Swift version mismatch in ${swift_info_path}."
        echo >&2 "  Cached:  ${cached_version}"
        echo >&2 "  Current: ${current_version}"
        echo >&2 "Re-run with --mode update to refresh the cache."
        return 1
      fi
    fi
  fi

  # Compute root_pkg_dir early so we can pin --build_path to an absolute
  # location. SPM treats --build-path as cwd-relative; under `bazel run`
  # cwd is the runfiles sandbox and would lose .build/checkouts.
  #
  # Normalize via os.path: --package_path can arrive as "" (empty) or
  # "/" depending on whether the Package.swift label has an empty
  # package component. os.path.join treats a leading "/" as absolute and
  # would discard the workspace prefix entirely, so strip it first.
  local relative_pkg_path="${package_path#/}"
  local root_pkg_dir
  root_pkg_dir="$(python3 -c '
import os.path, sys
print(os.path.normpath(os.path.join(sys.argv[1], sys.argv[2])))
' "${BUILD_WORKSPACE_DIRECTORY}" "${relative_pkg_path}")"
  spm_flags+=("--build_path" "${root_pkg_dir}/.build")

  # Run swift package resolve|update with the forwarded SPM flags.
  crj_run_spm_subcommand "${mode}" "${spm_flags[@]}"

  # Update mode writes the version stamp after a successful update.
  if [[ ${mode} == "update" ]]; then
    crj_write_swift_info "${swift_info_path}" "${current_version}"
  fi

  # ${root_pkg_dir} was set earlier (alongside the build_path override).
  # The matching checkouts directory holds SCM/registry working copies.
  local checkouts_dir="${root_pkg_dir}/.build/checkouts"

  # Generate root dump.json/desc.json under <output_dir>/_main.
  crj_dump_describe \
    "${swift_executable}" \
    "${root_pkg_dir}" \
    "${output_dir}/_main" \
    "${config_path}" \
    "${replace_scm_with_registry}" \
    "${manifest_swiftc_flags}"

  # Visited set seeds with "_main" so it never gets pruned. Cleaned up
  # inline at the end of main() (no EXIT trap so nounset stays sane).
  local visited
  visited="$(mktemp)"
  echo "_main" >"${visited}"

  # SCM and registry deps (including transitive) come from Package.resolved.
  while IFS=$'\t' read -r identity path; do
    [[ -z ${identity} ]] && continue
    if [[ ! -d ${path} ]]; then
      echo >&2 "WARNING: checkout missing for ${identity} at ${path}"
      continue
    fi
    crj_process_dep \
      "${swift_executable}" \
      "${identity}" \
      "${path}" \
      "${output_dir}" \
      "${config_path}" \
      "${replace_scm_with_registry}" \
      "${manifest_swiftc_flags}" \
      "${visited}"
  done < <(crj_resolved_pins \
    "${root_pkg_dir}/Package.resolved" \
    "${checkouts_dir}")

  # Filesystem deps come from the root describe output (recurse to
  # discover transitive local-dep chains).
  while IFS=$'\t' read -r identity path; do
    [[ -z ${identity} ]] && continue
    crj_process_dep \
      "${swift_executable}" \
      "${identity}" \
      "${path}" \
      "${output_dir}" \
      "${config_path}" \
      "${replace_scm_with_registry}" \
      "${manifest_swiftc_flags}" \
      "${visited}"
  done < <(crj_describe_local_deps "${output_dir}/_main/desc.json" "${root_pkg_dir}")

  # Drop any per-dep cache directories that no longer correspond to a
  # discovered dependency.
  crj_prune_stale "${output_dir}" "${visited}"

  # Write the root BUILD.bazel after pruning so the swift_info_test
  # target is always (re)written. The per-dep BUILD.bazel files are
  # written inline by crj_dump_describe.
  crj_write_root_build_file "${output_dir}"

  # Update MODULE.bazel with dump_manifests / desc_manifests entries
  # pointing at the freshly generated per-dep cache directories.
  crj_update_module_bazel \
    "${module_bazel}" \
    "${output_dir_rel}" \
    "${visited}"

  rm -f "${visited}"

  echo "cache_repo_json: cache regenerated under ${output_dir}"
  echo "  module_bazel:  ${module_bazel}"
  echo "  swift_version: ${current_version}"
}

# Only invoke main when this file is executed directly. Sourcing the
# script (e.g. from unit tests) registers the helper functions without
# triggering main or the runfiles bootstrap.
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  main "$@"
fi
