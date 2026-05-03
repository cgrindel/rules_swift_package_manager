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

# Lexically normalize a path, mirroring Python's `os.path.normpath`:
# collapses `//`, drops `.` segments, and resolves `..` segments
# against the preceding component (without touching the filesystem).
# Empty input yields ".".
_crj_normpath() {
  local path="$1"
  local is_abs=0
  [[ ${path:0:1} == / ]] && is_abs=1
  local -a out=()
  local component
  local IFS=/
  for component in $path; do
    [[ -z ${component} || ${component} == "." ]] && continue
    if [[ ${component} == ".." ]]; then
      local n=${#out[@]}
      if ((n > 0)) && [[ ${out[n - 1]} != ".." ]]; then
        unset 'out[n-1]'
        out=("${out[@]}")
        continue
      fi
      ((is_abs)) && continue
    fi
    out+=("${component}")
  done
  if ((is_abs)); then
    if ((${#out[@]} == 0)); then
      printf '%s' "/"
    else
      printf '/%s' "${out[*]}"
    fi
  else
    if ((${#out[@]} == 0)); then
      printf '%s' "."
    else
      printf '%s' "${out[*]}"
    fi
  fi
}

# Compute a relative path from `base` to `target`, mirroring Python's
# `os.path.relpath`. Both inputs are normalized first.
_crj_relpath() {
  local target base
  target="$(_crj_normpath "$1")"
  base="$(_crj_normpath "$2")"
  local -a tparts=() bparts=()
  local component
  local IFS=/
  for component in $target; do
    [[ -n ${component} ]] && tparts+=("${component}")
  done
  for component in $base; do
    [[ -n ${component} ]] && bparts+=("${component}")
  done
  local common=0
  while ((common < ${#tparts[@]})) \
    && ((common < ${#bparts[@]})) \
    && [[ ${tparts[common]} == "${bparts[common]}" ]]; do
    ((common++))
  done
  local -a out=()
  local i
  for ((i = common; i < ${#bparts[@]}; i++)); do
    out+=("..")
  done
  for ((i = common; i < ${#tparts[@]}; i++)); do
    out+=("${tparts[i]}")
  done
  if ((${#out[@]} == 0)); then
    printf '%s' "."
  else
    printf '%s' "${out[*]}"
  fi
}

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
# supplied parent_pkg_dir before being emitted. Sibling-package paths
# stored as `{{WORKSPACE_ROOT}}/<rel>` tokens are expanded against the
# optional workspace_root argument.
crj_describe_local_deps() {
  local desc_json="$1"
  local parent_pkg_dir="$2"
  local workspace_root="${3:-}"
  workspace_root="${workspace_root%/}"

  # Awk pulls (identity, path) for fileSystem deps from the
  # `dependencies` array of desc.json. SPM emits well-formed,
  # alphabetically-sorted, two-space-indented JSON, so a state machine
  # tracking brace depth and splitting on `"` is reliable here without
  # taking on a JSON-parser dependency.
  awk '
    BEGIN { in_deps = 0; depth = 0; identity = ""; type = ""; path = "" }
    !in_deps && /"dependencies"[ \t]*:[ \t]*\[/ { in_deps = 1; next }
    in_deps {
      if (depth == 0 && $0 ~ /^[ \t]*\][ \t]*,?[ \t]*$/) {
        in_deps = 0
        next
      }
      n = length($0)
      for (i = 1; i <= n; i++) {
        c = substr($0, i, 1)
        if (c == "{") depth++
        else if (c == "}") {
          depth--
          if (depth == 0) {
            if (type == "fileSystem" && identity != "" && path != "") {
              print identity "\t" path
            }
            identity = ""; type = ""; path = ""
          }
        }
      }
      # Only capture top-level fields (depth == 1 after counting).
      if (depth == 1) {
        m = split($0, parts, "\"")
        if (m >= 4) {
          k = parts[2]
          v = parts[4]
          if (k == "identity") identity = v
          else if (k == "type") type = v
          else if (k == "path") path = v
        }
      }
    }
  ' "${desc_json}" | while IFS=$'\t' read -r identity path; do
    [[ -z ${identity} ]] && continue
    if [[ -n ${workspace_root} && ${path} == *"{{WORKSPACE_ROOT}}"* ]]; then
      path="${path//\{\{WORKSPACE_ROOT\}\}/${workspace_root}}"
    fi
    if [[ ${path:0:1} != "/" ]]; then
      path="$(_crj_normpath "${parent_pkg_dir}/${path}")"
    fi
    printf '%s\t%s\n' "${identity}" "${path}"
  done
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
  checkouts_dir="${checkouts_dir%/}"

  # Same pattern as crj_describe_local_deps: walk the `pins` array,
  # capture top-level fields (identity, kind, location) and post-
  # process in shell.
  awk '
    BEGIN { in_pins = 0; depth = 0; identity = ""; kind = ""; location = "" }
    !in_pins && /"pins"[ \t]*:[ \t]*\[/ { in_pins = 1; next }
    in_pins {
      if (depth == 0 && $0 ~ /^[ \t]*\][ \t]*,?[ \t]*$/) {
        in_pins = 0
        next
      }
      n = length($0)
      for (i = 1; i <= n; i++) {
        c = substr($0, i, 1)
        if (c == "{") depth++
        else if (c == "}") {
          depth--
          if (depth == 0) {
            if (identity != "" && kind != "") {
              print identity "\t" kind "\t" location
            }
            identity = ""; kind = ""; location = ""
          }
        }
      }
      if (depth == 1) {
        m = split($0, parts, "\"")
        if (m >= 4) {
          k = parts[2]
          v = parts[4]
          if (k == "identity") identity = v
          else if (k == "kind") kind = v
          else if (k == "location") location = v
        }
      }
    }
  ' "${resolved_path}" | while IFS=$'\t' read -r identity kind location; do
    local checkout=""
    case "${kind}" in
      remoteSourceControl | localSourceControl)
        local basename="${location%/}"
        basename="${basename##*/}"
        basename="${basename%.git}"
        checkout="${checkouts_dir}/${basename}"
        ;;
      registry)
        checkout="${checkouts_dir}/${identity}"
        ;;
      *)
        continue
        ;;
    esac
    [[ -z ${identity} || -z ${checkout} ]] && continue
    printf '%s\t%s\n' "${identity}" "${checkout}"
  done
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
#   $7 - workspace root (BUILD_WORKSPACE_DIRECTORY) for sibling-path
#        portability. Empty disables the workspace-relative rewrite.
crj_dump_describe() {
  local swift_executable="$1"
  local pkg_dir="$2"
  local out_dir="$3"
  local cfg_path="$4"
  local replace_scm="$5"
  local manifest_flags="$6"
  local workspace_root="${7:-}"

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
  # any `<pkg_dir>/` prefix becomes `./`, paths under workspace_root but
  # outside pkg_dir become `{{WORKSPACE_ROOT}}/<rel>`, and the consumer
  # expands both back at fetch time.
  "${swift_executable}" "${base_args[@]}" dump-package \
    | crj_relativize_paths "${pkg_dir}" "${workspace_root}" \
      >"${out_dir}/dump.json"
  "${swift_executable}" "${base_args[@]}" describe --type json \
    | crj_relativize_paths "${pkg_dir}" "${workspace_root}" \
      >"${out_dir}/desc.json"
  crj_write_dep_build_file "${out_dir}"
}

# Pipe stdin through, replacing every "${pkg_dir}/" occurrence with
# "./" and a bare "${pkg_dir}" (e.g. the top-level "path" field whose
# value equals the package root with no trailing component) with "."
# so cache files store paths relative to the package root. After that,
# paths still rooted at "${workspace_root}" (typically sibling local
# packages) are rewritten to a "{{WORKSPACE_ROOT}}/<rel>" token so the
# cache stays portable across machines; the consumer expands the token
# back to the on-disk workspace path. Plain string substitution is
# enough; the JSON content does not contain any metacharacters that
# would interact with this transformation.
crj_relativize_paths() {
  local pkg_root="${1%/}"
  local ws_root="${2:-}"
  ws_root="${ws_root%/}"
  # Awk does literal substring replacement (index/substr) so paths
  # containing regex metacharacters (`.`, `*`, `[`, etc.) are safe.
  awk -v pkg="${pkg_root}" -v ws="${ws_root}" '
    function replace(s, target, repl,    pos, len, out) {
      if (target == "") return s
      len = length(target)
      out = ""
      pos = index(s, target)
      while (pos > 0) {
        out = out substr(s, 1, pos - 1) repl
        s = substr(s, pos + len)
        pos = index(s, target)
      }
      return out s
    }
    {
      # Replace child-path occurrences first so the bare-root
      # replacement does not chew into longer matches.
      line = replace($0, pkg "/", "./")
      line = replace(line, "\"" pkg "\"", "\".\"")
      if (ws != "") {
        line = replace(line, ws "/", "{{WORKSPACE_ROOT}}/")
        line = replace(line, "\"" ws "\"", "\"{{WORKSPACE_ROOT}}\"")
      }
      print line
    }
  '
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
  local workspace_root="${9:-}"

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
    "${manifest_flags}" \
    "${workspace_root}"

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
      "${visited}" \
      "${workspace_root}"
  done < <(crj_describe_local_deps "${dep_out}/desc.json" "${path}" "${workspace_root}")
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
#
# A single committed cache can only match one (OS, toolchain)
# combination, so the generator stamps the test with a
# target_compatible_with constraint matching the host OS that produced
# the cache. Cross-platform CI then automatically skips the test on
# other platforms instead of failing.
#
# Arguments:
#   $1 - output directory
#   $2 - host OS slug ("macos" or "linux")
crj_write_root_build_file() {
  local out_root="$1"
  local host_os="$2"
  cat >"${out_root}/BUILD.bazel" <<EOF
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
    target_compatible_with = ["@platforms//os:${host_os}"],
)
EOF
}

# Map "uname -s" to the @platforms//os slug used in the auto-generated
# swift_info_test target_compatible_with constraint.
crj_host_os_slug() {
  local uname_s
  uname_s="$(uname -s)"
  case "${uname_s}" in
    Darwin) echo "macos" ;;
    Linux) echo "linux" ;;
    *)
      echo >&2 "ERROR: unsupported host OS for cache generation: ${uname_s}"
      return 1
      ;;
  esac
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
  # macOS realpath lacks --relative-to, so do the relpath ourselves.
  local module_bazel_rel
  module_bazel_rel="$(_crj_relpath "${module_bazel}" "${BUILD_WORKSPACE_DIRECTORY}")"
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
    output_dir_rel="$(_crj_relpath "${output_dir}" "${BUILD_WORKSPACE_DIRECTORY}")"
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
  # --package_path can arrive as "" (empty) or "/" depending on whether
  # the Package.swift label has an empty package component. Strip the
  # leading "/" so concatenation doesn't discard the workspace prefix,
  # then normalize the result.
  local relative_pkg_path="${package_path#/}"
  local root_pkg_dir
  root_pkg_dir="$(_crj_normpath "${BUILD_WORKSPACE_DIRECTORY}/${relative_pkg_path}")"
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
    "${manifest_swiftc_flags}" \
    "${BUILD_WORKSPACE_DIRECTORY}"

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
      "${visited}" \
      "${BUILD_WORKSPACE_DIRECTORY}"
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
      "${visited}" \
      "${BUILD_WORKSPACE_DIRECTORY}"
  done < <(crj_describe_local_deps \
    "${output_dir}/_main/desc.json" \
    "${root_pkg_dir}" \
    "${BUILD_WORKSPACE_DIRECTORY}")

  # Drop any per-dep cache directories that no longer correspond to a
  # discovered dependency.
  crj_prune_stale "${output_dir}" "${visited}"

  # Write the root BUILD.bazel after pruning so the swift_info_test
  # target is always (re)written. The per-dep BUILD.bazel files are
  # written inline by crj_dump_describe.
  local host_os
  host_os="$(crj_host_os_slug)"
  crj_write_root_build_file "${output_dir}" "${host_os}"

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
