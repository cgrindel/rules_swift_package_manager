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

# MARK - spl_setup_netrc

# An empty netrc path should produce no output and not error.
netrc_empty_output="$(spl_setup_netrc "")"
assert_equal "" "${netrc_empty_output}" "empty netrc should produce no output"

# A valid netrc path should produce `--netrc-file <realpath>`.
netrc_tmp_dir="$(new_tmp_dir)"
netrc_file="${netrc_tmp_dir}/.netrc"
: >"${netrc_file}"
netrc_output="$(spl_setup_netrc "${netrc_file}")"
netrc_expected="--netrc-file $(readlink -f "${netrc_file}")"
assert_equal \
  "${netrc_expected}" "${netrc_output}" \
  "valid netrc should produce --netrc-file <realpath>"

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

# When the swift_worker --find returns a path, use it.
resolve_ok_dir="$(new_tmp_dir)"
worker_ok="${resolve_ok_dir}/worker"
write_script "${worker_ok}" 'echo "/fake/resolved/swift"'
resolve_output="$(spl_resolve_swift_executable "${worker_ok}")"
assert_equal \
  "/fake/resolved/swift" "${resolve_output}" \
  "swift_worker --find output should be used when it succeeds"

# When swift_worker fails, fall back to `which swift` on PATH.
resolve_fallback_dir="$(new_tmp_dir)"
worker_fail="${resolve_fallback_dir}/worker"
write_script "${worker_fail}" 'exit 1'
fake_swift="${resolve_fallback_dir}/swift"
write_script "${fake_swift}" 'echo fake-swift-called'
fallback_output="$(PATH="${resolve_fallback_dir}:${PATH}" \
  spl_resolve_swift_executable "${worker_fail}")"
assert_equal \
  "${fake_swift}" "${fallback_output}" \
  "which swift should be used when swift_worker fails"

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
for flag in --swift_worker --cmd --build_path --cache_path \
  --config_path --security_path; do
  case "${validation_err}" in
    *"${flag}"*) ;;
    *) fail "validation error should mention ${flag}, got: ${validation_err}" ;;
  esac
done

# MARK - spl_run_swift_package (argv capture via fake swift)

# Stand up a fake swift that writes its argv (one arg per line) to
# ${SWIFT_ARGS_FILE}, plus a swift_worker that resolves to it.
run_dir="$(new_tmp_dir)"
swift_args_file="${run_dir}/swift_args.txt"
fake_run_swift="${run_dir}/swift"
# Using printf '%s\n' in a heredoc-like block preserves the literal
# ${SWIFT_ARGS_FILE}/$@ so they evaluate at runtime, not now.
cat >"${fake_run_swift}" <<'FAKE_SWIFT'
#!/usr/bin/env bash
printf '%s\n' "$@" >"${SWIFT_ARGS_FILE}"
FAKE_SWIFT
chmod +x "${fake_run_swift}"

fake_run_worker="${run_dir}/worker"
cat >"${fake_run_worker}" <<FAKE_WORKER
#!/usr/bin/env bash
echo "${fake_run_swift}"
FAKE_WORKER
chmod +x "${fake_run_worker}"

# BUILD_WORKSPACE_DIRECTORY must be set or the function exits.
workspace_dir="${run_dir}/ws"
mkdir -p "${workspace_dir}"

export SWIFT_ARGS_FILE="${swift_args_file}"
BUILD_WORKSPACE_DIRECTORY="${workspace_dir}" \
  spl_run_swift_package \
  --swift_worker "${fake_run_worker}" \
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

echo "All tests passed."
