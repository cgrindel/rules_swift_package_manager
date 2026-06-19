#!/usr/bin/env bash

# --- begin runfiles.bash initialization v2 ---
# Copy-pasted from the Bazel Bash runfiles library v2.
set -o nounset -o pipefail
f=bazel_tools/tools/bash/runfiles/runfiles.bash
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
f=
set -o errexit
# --- end runfiles.bash initialization v2 ---

# MARK - Locate Deps

assertions_sh_location=cgrindel_bazel_starlib/shlib/lib/assertions.sh
assertions_sh="$(rlocation "${assertions_sh_location}")" \
  || (echo >&2 "Failed to locate ${assertions_sh_location}" && exit 1)
# shellcheck disable=SC1090
source "${assertions_sh}"

lib_sh_location=rules_swift_package_manager/swiftpkg/internal/swift_package_lib.sh
lib_sh="$(rlocation "${lib_sh_location}")" \
  || (echo >&2 "Failed to locate ${lib_sh_location}" && exit 1)
# shellcheck disable=SC1090
source "${lib_sh}"

# MARK - Test Helpers

# Creates a unique temp dir under TEST_TMPDIR and prints the path.
new_tmp_dir() {
  mktemp -d "${TEST_TMPDIR:-/tmp}/spl_test.XXXXXX"
}

# MARK - spl_setup_registries

# An empty registries_json should NOT create the config dir or a symlink.
reg_empty_tmp_dir="$(new_tmp_dir)"
spl_setup_registries "" "${reg_empty_tmp_dir}/.config"
if [[ -e ${reg_empty_tmp_dir}/.config ]]; then
  fail "empty registries_json should not create config dir"
fi

# A valid registries_json should symlink into <config_path>/registries.json.
reg_tmp_dir="$(new_tmp_dir)"
registries_file="${reg_tmp_dir}/registries.json"
echo '{"registries":{}}' >"${registries_file}"
config_path="${reg_tmp_dir}/.config"
spl_setup_registries "${registries_file}" "${config_path}"

symlink="${config_path}/registries.json"
if [[ ! -L ${symlink} ]]; then
  fail "expected symlink at ${symlink}"
fi
if [[ ! -f ${symlink} ]]; then
  fail "symlink target at ${symlink} is not a readable file"
fi
symlink_target="$(readlink "${symlink}")"
expected_target="$(readlink -f "${registries_file}")"
assert_equal \
  "${expected_target}" "${symlink_target}" \
  "symlink should point to the registries.json realpath"

# MARK - spl_resolve_swift_executable

# Writes an executable bash script at $1 with body $2.
write_script() {
  local path="$1"
  local body="$2"
  printf '#!/usr/bin/env bash\n%s\n' "${body}" >"${path}"
  chmod +x "${path}"
}

# When xcrun is available (Apple), resolve swift via `xcrun --find swift`.
resolve_xcrun_dir="$(new_tmp_dir)"
fake_swift_xcrun="${resolve_xcrun_dir}/swift"
write_script "${fake_swift_xcrun}" 'echo xcrun-swift'
write_script "${resolve_xcrun_dir}/xcrun" \
  "[ \"\$1\" = '--find' ] && [ \"\$2\" = 'swift' ] && echo '${fake_swift_xcrun}'"
xcrun_output="$(PATH="${resolve_xcrun_dir}:${PATH}" \
  spl_resolve_swift_executable /unused/worker)"
assert_equal \
  "${fake_swift_xcrun}" "${xcrun_output}" \
  "xcrun --find swift should be used when xcrun is available"

# When xcrun is unavailable (e.g. Linux), fall back to `swift` on PATH.
resolve_path_dir="$(new_tmp_dir)"
fake_swift_path="${resolve_path_dir}/swift"
write_script "${fake_swift_path}" 'echo path-swift'
fallback_output="$(PATH="${resolve_path_dir}" \
  spl_resolve_swift_executable /unused/worker)"
assert_equal \
  "${fake_swift_path}" "${fallback_output}" \
  "swift on PATH should be used when xcrun is unavailable"

# MARK - spl_run_swift_package required-flag validation

# Missing required flags should return non-zero and name them in the
# error message, without invoking swift at all.
set +e
validation_err="$(spl_run_swift_package 2>&1 >/dev/null)"
validation_rc=$?
set -e
assert_equal \
  "1" "${validation_rc}" \
  "missing required flags should return exit code 1"
for flag in --cmd --build_path --cache_path \
  --config_path --security_path; do
  case "${validation_err}" in
    *"${flag}"*) ;;
    *) fail "validation error should mention ${flag}, got: ${validation_err}" ;;
  esac
done

# MARK - spl_run_swift_package (argv capture via fake swift)

# Stand up a fake swift that writes its argv (one arg per line) to
# ${SWIFT_ARGS_FILE}, plus a fake xcrun that resolves swift to it.
run_dir="$(new_tmp_dir)"
swift_args_file="${run_dir}/swift_args.txt"
fake_run_swift="${run_dir}/swift"
# Using printf '%s\n' in a heredoc-like block preserves the literal
# ${SWIFT_ARGS_FILE}/$@ so they evaluate at runtime, not now.
cat >"${fake_run_swift}" <<'FAKE_SWIFT'
#!/usr/bin/env bash
printf '%s\n' "$@" >"${SWIFT_ARGS_FILE}"
if [[ -n ${SWIFT_ENV_FILE:-} ]]; then
  # `env -0` separates entries with NUL so values containing newlines
  # cannot be confused with variable boundaries.
  env -0 >"${SWIFT_ENV_FILE}"
fi
FAKE_SWIFT
chmod +x "${fake_run_swift}"

fake_xcrun="${run_dir}/xcrun"
cat >"${fake_xcrun}" <<FAKE_XCRUN
#!/usr/bin/env bash
[ "\$1" = "--find" ] && [ "\$2" = "swift" ] && echo "${fake_run_swift}"
FAKE_XCRUN
chmod +x "${fake_xcrun}"

# BUILD_WORKSPACE_DIRECTORY must be set or the function exits.
workspace_dir="${run_dir}/ws"
mkdir -p "${workspace_dir}"

export SWIFT_ARGS_FILE="${swift_args_file}"
PATH="${run_dir}:${PATH}" BUILD_WORKSPACE_DIRECTORY="${workspace_dir}" \
  spl_run_swift_package \
  --cmd resolve \
  --package_path pkgsub \
  --build_path .build \
  --cache_path .cache \
  --config_path "${run_dir}/.config" \
  --security_path .security \
  --enable_build_manifest_caching true \
  --enable_dependency_cache false \
  --manifest_cache shared \
  --replace_scm_with_registry true \
  --use_registry_identity_for_scm false

# grep -xF matches one whole line at a time, which lines up with the
# fake_swift script writing one argv element per line.
assert_argv_has() {
  local line="$1"
  local msg="$2"
  grep -qxF -- "${line}" "${swift_args_file}" \
    || fail "${msg} (missing argv line: ${line})"
}

assert_argv_lacks() {
  local line="$1"
  local msg="$2"
  if grep -qxF -- "${line}" "${swift_args_file}"; then
    fail "${msg} (unexpected argv line: ${line})"
  fi
}

assert_argv_has "package" \
  "first swift arg should be 'package'"
assert_argv_has "--build-path" \
  "--build-path should appear"
assert_argv_has "${workspace_dir}/pkgsub" \
  "package-path should be BUILD_WORKSPACE_DIRECTORY/<package_path>"
assert_argv_has "resolve" \
  "cmd should appear as a positional arg"
assert_argv_has "--enable-build-manifest-caching" \
  "manifest-caching flag should be enabled"
assert_argv_has "--disable-dependency-cache" \
  "dependency-cache should be disabled"
assert_argv_has "--replace-scm-with-registry" \
  "replace-scm-with-registry flag should be present"
assert_argv_lacks "--use-registry-identity-for-scm" \
  "use-registry-identity-for-scm flag should be absent"

# MARK - spl_run_swift_package --netrc_file plumbing

# Reinvoke with --netrc_file pointing at a path containing a space; this
# guards against the word-split regression in the inline --netrc-file
# argv construction inside spl_run_swift_package.
netrc_space_dir="$(new_tmp_dir)/dir with spaces"
mkdir -p "${netrc_space_dir}"
netrc_space_file="${netrc_space_dir}/.netrc"
: >"${netrc_space_file}"
netrc_space_realpath="$(readlink -f "${netrc_space_file}")"

# Reset argv file so the next invocation is captured cleanly.
: >"${swift_args_file}"

PATH="${run_dir}:${PATH}" BUILD_WORKSPACE_DIRECTORY="${workspace_dir}" \
  spl_run_swift_package \
  --cmd resolve \
  --package_path pkgsub \
  --build_path .build \
  --cache_path .cache \
  --config_path "${run_dir}/.config" \
  --security_path .security \
  --enable_build_manifest_caching true \
  --enable_dependency_cache true \
  --manifest_cache shared \
  --replace_scm_with_registry false \
  --use_registry_identity_for_scm false \
  --netrc_file "${netrc_space_file}"

assert_argv_has "--netrc-file" \
  "--netrc-file flag should appear when --netrc_file is set"
assert_argv_has "${netrc_space_realpath}" \
  "netrc path with spaces should survive as one argv element"

# MARK - spl_run_swift_package --env plumbing

# Verify --env KEY=VAL pairs are exported into swift's environment, and
# that values containing spaces survive intact (regression for the
# word-split bug fixed in the --env handling).
swift_env_file="${run_dir}/swift_env.txt"
: >"${swift_args_file}"
: >"${swift_env_file}"
export SWIFT_ENV_FILE="${swift_env_file}"

PATH="${run_dir}:${PATH}" BUILD_WORKSPACE_DIRECTORY="${workspace_dir}" \
  spl_run_swift_package \
  --cmd resolve \
  --package_path pkgsub \
  --build_path .build \
  --cache_path .cache \
  --config_path "${run_dir}/.config" \
  --security_path .security \
  --enable_build_manifest_caching true \
  --enable_dependency_cache true \
  --manifest_cache shared \
  --replace_scm_with_registry false \
  --use_registry_identity_for_scm false \
  --env "SPL_TEST_FOO=bar" \
  --env "SPL_TEST_SPACED=value with spaces"

# `env -0` writes one KEY=VAL entry per NUL-delimited record. The
# `read -r -d ''` loop is portable to macOS bash 3.2 (no mapfile) and
# preserves entries verbatim, even when VAL contains spaces or other
# shell metacharacters.
env_entries=()
while IFS= read -r -d '' entry; do
  env_entries+=("${entry}")
done <"${swift_env_file}"

assert_env_has() {
  local entry="$1"
  local msg="$2"
  local found
  for found in "${env_entries[@]}"; do
    if [[ ${found} == "${entry}" ]]; then
      return 0
    fi
  done
  fail "${msg} (missing env entry: ${entry})"
}

assert_env_has "SPL_TEST_FOO=bar" \
  "simple --env KEY=VAL should reach swift's environment"
assert_env_has "SPL_TEST_SPACED=value with spaces" \
  "--env value containing spaces should survive as one entry"

unset SWIFT_ENV_FILE SPL_TEST_FOO SPL_TEST_SPACED

# MARK - spl_run_swift_package --manifest_swiftc_flags splitting

# Verify a single --manifest_swiftc_flags string with multiple
# space-separated flags splits into distinct argv elements when
# forwarded to `swift package`. The lib intentionally unquotes the
# variable to enable this splitting.
: >"${swift_args_file}"

PATH="${run_dir}:${PATH}" BUILD_WORKSPACE_DIRECTORY="${workspace_dir}" \
  spl_run_swift_package \
  --cmd resolve \
  --package_path pkgsub \
  --build_path .build \
  --cache_path .cache \
  --config_path "${run_dir}/.config" \
  --security_path .security \
  --enable_build_manifest_caching true \
  --enable_dependency_cache true \
  --manifest_cache shared \
  --replace_scm_with_registry false \
  --use_registry_identity_for_scm false \
  --manifest_swiftc_flags "-DSPL_TEST_FLAG_ONE -DSPL_TEST_FLAG_TWO"

assert_argv_has "-DSPL_TEST_FLAG_ONE" \
  "first manifest swiftc flag should appear as its own argv element"
assert_argv_has "-DSPL_TEST_FLAG_TWO" \
  "second manifest swiftc flag should appear as its own argv element"
assert_argv_lacks "-DSPL_TEST_FLAG_ONE -DSPL_TEST_FLAG_TWO" \
  "manifest swiftc flags should split, not pass through as one token"

# MARK - spl_run_swift_package --registries_json plumbing

# When --registries_json is supplied, spl_run_swift_package should
# materialize <config_path>/registries.json as a symlink to the input
# file's realpath. (The lower-level spl_setup_registries test verifies
# the helper directly; this test exercises the flag-parsing path.)
reg_plumb_dir="$(new_tmp_dir)"
reg_plumb_file="${reg_plumb_dir}/registries.json"
echo '{"registries":{"example":{"url":"https://example.invalid"}}}' \
  >"${reg_plumb_file}"
reg_plumb_config="${reg_plumb_dir}/.config"
: >"${swift_args_file}"

PATH="${run_dir}:${PATH}" BUILD_WORKSPACE_DIRECTORY="${workspace_dir}" \
  spl_run_swift_package \
  --cmd resolve \
  --package_path pkgsub \
  --build_path .build \
  --cache_path .cache \
  --config_path "${reg_plumb_config}" \
  --security_path .security \
  --enable_build_manifest_caching true \
  --enable_dependency_cache true \
  --manifest_cache shared \
  --replace_scm_with_registry false \
  --use_registry_identity_for_scm false \
  --registries_json "${reg_plumb_file}"

reg_plumb_symlink="${reg_plumb_config}/registries.json"
if [[ ! -L ${reg_plumb_symlink} ]]; then
  fail "expected registries symlink at ${reg_plumb_symlink}"
fi
reg_plumb_target="$(readlink "${reg_plumb_symlink}")"
reg_plumb_expected="$(readlink -f "${reg_plumb_file}")"
assert_equal \
  "${reg_plumb_expected}" "${reg_plumb_target}" \
  "--registries_json should symlink config_path/registries.json to realpath"

# MARK - spl_run_swift_package missing BUILD_WORKSPACE_DIRECTORY

# When all required flags are supplied but BUILD_WORKSPACE_DIRECTORY is
# unset (i.e. invoked via bazel test rather than bazel run), the
# function should return non-zero and mention the missing variable on
# stderr. The unset runs inside the $(...) subshell so the parent
# script's environment is undisturbed.
set +e
bwd_err="$(
  unset BUILD_WORKSPACE_DIRECTORY
  spl_run_swift_package \
    --cmd resolve \
    --package_path pkgsub \
    --build_path .build \
    --cache_path .cache \
    --config_path "${run_dir}/.config" \
    --security_path .security \
    2>&1 >/dev/null
)"
bwd_rc=$?
set -e

assert_equal \
  "1" "${bwd_rc}" \
  "unset BUILD_WORKSPACE_DIRECTORY should return exit code 1"
case "${bwd_err}" in
  *BUILD_WORKSPACE_DIRECTORY*) ;;
  *) fail "error should mention BUILD_WORKSPACE_DIRECTORY, got: ${bwd_err}" ;;
esac

echo >&2 "All tests passed."
