#!/usr/bin/env bash

# Shared shell library for tools that invoke `swift package` commands.
#
# Provides reusable functions for Swift executable resolution, netrc
# handling, registry setup, and running `swift package` with the full
# set of SPM flags.
#
# Usage: source this file and call the functions you need.

# Resolves the `swift` executable path from the swift_worker binary.
# Falls back to `which swift` if --find is not supported (e.g. Linux).
#
# Arguments:
#   $1 - path to the swift_worker executable
#
# Outputs:
#   Prints the resolved swift executable path to stdout.
spl_resolve_swift_executable() {
  local swift_worker="$1"
  local swift_executable
  swift_executable="$(
    "${swift_worker}" --find swift \
      || which swift \
      || (
        echo >&2 "Could not find the swift executable."
        exit 1
      )
  )"
  echo "${swift_executable}"
}

# Resolves the real path of a .netrc file and outputs the appropriate
# --netrc-file flag.
#
# Arguments:
#   $1 - path to the .netrc file (may be empty)
#
# Outputs:
#   Prints "--netrc-file <realpath>" to stdout if the file is non-empty.
spl_setup_netrc() {
  local netrc_file="$1"
  if [[ -n ${netrc_file} ]]; then
    echo "--netrc-file" "$(readlink -f "${netrc_file}")"
  fi
}

# Creates the config directory and symlinks registries.json into it so
# SPM can find registry configuration.
#
# Arguments:
#   $1 - path to the registries.json file (may be empty)
#   $2 - config_path directory
spl_setup_registries() {
  local registries_json="$1"
  local config_path="$2"
  if [[ -n ${registries_json} ]]; then
    mkdir -p "${config_path}"
    ln -sf "$(readlink -f "${registries_json}")" \
      "${config_path}/registries.json"
  fi
}

# Orchestrates swift executable resolution, netrc/registry setup, and
# executes a `swift package` command with the full set of SPM flags.
#
# Arguments (passed as flag-value pairs):
#   --swift_worker <path>
#   --cmd <update|resolve>
#   --package_path <path>
#   --build_path <path>
#   --cache_path <path>
#   --config_path <path>
#   --security_path <path>
#   --enable_build_manifest_caching <true|false>
#   --enable_dependency_cache <true|false>
#   --manifest_cache <shared|local|none>
#   --netrc_file <path>           (optional, may be empty)
#   --registries_json <path>      (optional, may be empty)
#   --replace_scm_with_registry <true|false>
#   --use_registry_identity_for_scm <true|false>
#   --env <KEY=VAL ...>           (optional, space-separated)
#   --manifest_swiftc_flags <flags>  (optional, space-separated)
#
# Any remaining arguments after -- are appended to the swift package
# command.
spl_run_swift_package() {
  local swift_worker=""
  local cmd=""
  local package_path=""
  local build_path=""
  local cache_path=""
  local config_path=""
  local security_path=""
  local enable_build_manifest_caching="true"
  local enable_dependency_cache="true"
  local manifest_cache="shared"
  local netrc_file=""
  local registries_json=""
  local replace_scm_with_registry="false"
  local use_registry_identity_for_scm="false"
  local env=""
  local manifest_swiftc_flags=""
  local extra_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --swift_worker)
        swift_worker="$2"
        shift 2
        ;;
      --cmd)
        cmd="$2"
        shift 2
        ;;
      --package_path)
        package_path="$2"
        shift 2
        ;;
      --build_path)
        build_path="$2"
        shift 2
        ;;
      --cache_path)
        cache_path="$2"
        shift 2
        ;;
      --config_path)
        config_path="$2"
        shift 2
        ;;
      --security_path)
        security_path="$2"
        shift 2
        ;;
      --enable_build_manifest_caching)
        enable_build_manifest_caching="$2"
        shift 2
        ;;
      --enable_dependency_cache)
        enable_dependency_cache="$2"
        shift 2
        ;;
      --manifest_cache)
        manifest_cache="$2"
        shift 2
        ;;
      --netrc_file)
        netrc_file="$2"
        shift 2
        ;;
      --registries_json)
        registries_json="$2"
        shift 2
        ;;
      --replace_scm_with_registry)
        replace_scm_with_registry="$2"
        shift 2
        ;;
      --use_registry_identity_for_scm)
        use_registry_identity_for_scm="$2"
        shift 2
        ;;
      --env)
        env="$2"
        shift 2
        ;;
      --manifest_swiftc_flags)
        manifest_swiftc_flags="$2"
        shift 2
        ;;
      --)
        shift
        extra_args+=("$@")
        break
        ;;
      *)
        extra_args+=("$1")
        shift
        ;;
    esac
  done

  if [[ -z ${BUILD_WORKSPACE_DIRECTORY:-} ]]; then
    echo "BUILD_WORKSPACE_DIRECTORY is not set, this target" \
      'may only be `bazel run`'
    exit 1
  fi

  # Resolve package_path relative to workspace.
  package_path="${BUILD_WORKSPACE_DIRECTORY}/${package_path}"

  # Resolve swift executable.
  local swift_executable
  swift_executable="$(spl_resolve_swift_executable "${swift_worker}")"

  # Construct dynamic arguments.
  local args=()

  if [[ ${enable_build_manifest_caching} == "true" ]]; then
    args+=("--enable-build-manifest-caching")
  else
    args+=("--disable-build-manifest-caching")
  fi

  if [[ ${enable_dependency_cache} == "true" ]]; then
    args+=("--enable-dependency-cache")
  else
    args+=("--disable-dependency-cache")
  fi

  if [[ ${replace_scm_with_registry} == "true" ]]; then
    args+=("--replace-scm-with-registry")
  fi

  if [[ ${use_registry_identity_for_scm} == "true" ]]; then
    args+=("--use-registry-identity-for-scm")
  fi

  args+=("--manifest-cache=${manifest_cache}")

  # Set up netrc.
  local netrc_args
  netrc_args=($(spl_setup_netrc "${netrc_file}"))
  if [[ ${#netrc_args[@]} -gt 0 ]]; then
    args+=("${netrc_args[@]}")
  fi

  # Set up registries.
  spl_setup_registries "${registries_json}" "${config_path}"

  # Export environment variables.
  if [[ -n ${env} ]]; then
    for env_var in ${env}; do
      export "${env_var?}"
    done
  fi

  # Run the command.
  # shellcheck disable=SC2086
  "${swift_executable}" package \
    ${manifest_swiftc_flags} \
    --build-path "${build_path}" \
    --cache-path "${cache_path}" \
    --config-path "${config_path}" \
    --package-path "${package_path}" \
    --security-path "${security_path}" \
    "${cmd}" \
    "${args[@]}" \
    "${extra_args[@]}"
}
