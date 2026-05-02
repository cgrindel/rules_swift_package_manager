#!/usr/bin/env bash

# --- begin runfiles.bash initialization v3 ---
# Copy-pasted from the Bazel Bash runfiles library v3.
set -uo pipefail
set +e
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
set -e
# --- end runfiles.bash initialization v3 ---

set -o errexit -o nounset -o pipefail

# MARK - Locate Deps

assertions_sh_location=cgrindel_bazel_starlib/shlib/lib/assertions.sh
assertions_sh="$(rlocation "${assertions_sh_location}")" \
  || (echo >&2 "Failed to locate ${assertions_sh_location}" && exit 1)
# shellcheck disable=SC1090
source "${assertions_sh}"

crj_sh_location=rules_swift_package_manager/tools/cache_repo_json/cache_repo_json.sh
crj_sh="$(rlocation "${crj_sh_location}")" \
  || (echo >&2 "Failed to locate ${crj_sh_location}" && exit 1)
# shellcheck disable=SC1090
source "${crj_sh}"

# MARK - Test Helpers

new_tmp_dir() {
  mktemp -d "${TEST_TMPDIR:-/tmp}/crj_test.XXXXXX"
}

# MARK - crj_write_swift_info / crj_read_swift_info_version

write_read_dir="$(new_tmp_dir)"
swift_info_path="${write_read_dir}/swift_info.json"
crj_write_swift_info "${swift_info_path}" \
  "Apple Swift version 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)"
[[ -f ${swift_info_path} ]] || fail "expected swift_info.json to be written"

# Read it back via the helper.
read_back="$(crj_read_swift_info_version "${swift_info_path}")"
assert_equal \
  "Apple Swift version 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)" \
  "${read_back}" \
  "swift_info round-trip should preserve the recorded version"

# Embedded special characters (parentheses) must survive intact.
crj_write_swift_info "${swift_info_path}" "Swift version 5.10.1"
read_back="$(crj_read_swift_info_version "${swift_info_path}")"
assert_equal "Swift version 5.10.1" "${read_back}" \
  "swift_info should be rewritable in place"

# MARK - crj_relativize_paths

relativize_dir="$(new_tmp_dir)"
pkg_dir="${relativize_dir}/pkg"
mkdir -p "${pkg_dir}/Sources/Foo"

# Subpath replacement.
input='{"path": "'"${pkg_dir}"'/Sources/Foo"}'
output="$(printf '%s' "${input}" | crj_relativize_paths "${pkg_dir}")"
assert_equal '{"path": "./Sources/Foo"}' "${output}" \
  "should rewrite descendants of pkg_dir to ./<rel>"

# Bare-root replacement (top-level path field).
input='{"path": "'"${pkg_dir}"'", "name": "pkg"}'
output="$(printf '%s' "${input}" | crj_relativize_paths "${pkg_dir}")"
assert_equal '{"path": ".", "name": "pkg"}' "${output}" \
  "should rewrite a bare pkg_dir value to '.'"

# Trailing slash on input pkg_dir should not produce a double-slash.
input='{"path": "'"${pkg_dir}"'/Sources/Foo"}'
output="$(printf '%s' "${input}" | crj_relativize_paths "${pkg_dir}/")"
assert_equal '{"path": "./Sources/Foo"}' "${output}" \
  "should normalize a trailing-slash pkg_dir input"

# Cross-package paths (outside pkg_dir) stay absolute when no
# workspace_root is supplied.
sibling='/Users/test/somewhere_else/Sibling'
input='{"path": "'"${sibling}"'"}'
output="$(printf '%s' "${input}" | crj_relativize_paths "${pkg_dir}")"
assert_equal "${input}" "${output}" \
  "should leave paths outside pkg_dir unchanged when ws_root is unset"

# When workspace_root is supplied, sibling paths under it get rewritten
# to the {{WORKSPACE_ROOT}}/<rel> token so the cache is portable across
# checkouts. The consumer expands the token at fetch time.
ws_root="${relativize_dir}"
ws_sibling="${ws_root}/sibling_pkg/Sources/Bar"
input='{"path": "'"${ws_sibling}"'"}'
output="$(printf '%s' "${input}" | crj_relativize_paths "${pkg_dir}" "${ws_root}")"
assert_equal '{"path": "{{WORKSPACE_ROOT}}/sibling_pkg/Sources/Bar"}' "${output}" \
  "should rewrite workspace-internal sibling paths to {{WORKSPACE_ROOT}}/<rel>"

# A bare workspace_root value also gets tokenized.
input='{"path": "'"${ws_root}"'"}'
output="$(printf '%s' "${input}" | crj_relativize_paths "${pkg_dir}" "${ws_root}")"
assert_equal '{"path": "{{WORKSPACE_ROOT}}"}' "${output}" \
  "should rewrite a bare workspace_root value to '{{WORKSPACE_ROOT}}'"

# pkg_dir paths still take precedence (they get './' form, not the ws token)
# when pkg_dir lives under workspace_root.
nested_ws="$(new_tmp_dir)"
nested_pkg="${nested_ws}/pkg"
mkdir -p "${nested_pkg}"
input='{"path": "'"${nested_pkg}"'/Sources/Foo"}'
output="$(printf '%s' "${input}" | crj_relativize_paths "${nested_pkg}" "${nested_ws}")"
assert_equal '{"path": "./Sources/Foo"}' "${output}" \
  "should prefer pkg-relative form for paths under pkg_dir"

# Paths outside the workspace stay absolute even when ws_root is set.
input='{"path": "/usr/lib/external"}'
output="$(printf '%s' "${input}" | crj_relativize_paths "${pkg_dir}" "${ws_root}")"
assert_equal "${input}" "${output}" \
  "should leave paths outside both pkg_dir and workspace_root unchanged"

# MARK - crj_describe_local_deps

describe_dir="$(new_tmp_dir)"
desc_path="${describe_dir}/desc.json"
parent_dir="${describe_dir}/parent"
mkdir -p "${parent_dir}"

# A relative-path local dep should be absolutized against parent_dir.
# A non-fileSystem dep must be skipped. A null-path entry must be
# skipped. The output is "<identity>\t<path>" lines.
cat >"${desc_path}" <<JSON
{
  "dependencies": [
    {
      "type": "fileSystem",
      "identity": "rel_dep",
      "path": "./sub/rel_dep"
    },
    {
      "type": "fileSystem",
      "identity": "abs_dep",
      "path": "/some/abs/path/abs_dep"
    },
    {
      "type": "sourceControl",
      "identity": "scm_dep",
      "path": null
    },
    {
      "type": "fileSystem",
      "identity": "no_path",
      "path": null
    }
  ]
}
JSON

actual="$(crj_describe_local_deps "${desc_path}" "${parent_dir}")"
expected_rel="rel_dep	${parent_dir}/sub/rel_dep"
expected_abs='abs_dep	/some/abs/path/abs_dep'
assert_match "${expected_rel}" "${actual}" \
  "should absolutize relative fileSystem dep paths"
assert_match "${expected_abs}" "${actual}" \
  "should preserve absolute fileSystem dep paths"
if [[ ${actual} == *scm_dep* ]]; then
  fail "should skip non-fileSystem deps; got: ${actual}"
fi
if [[ ${actual} == *no_path* ]]; then
  fail "should skip fileSystem deps without a path; got: ${actual}"
fi

# MARK - crj_resolved_pins

resolved_dir="$(new_tmp_dir)"
resolved_path="${resolved_dir}/Package.resolved"
checkouts_dir="${resolved_dir}/.build/checkouts"

cat >"${resolved_path}" <<'JSON'
{
  "pins": [
    {
      "identity": "swift-argument-parser",
      "kind": "remoteSourceControl",
      "location": "https://github.com/apple/swift-argument-parser.git"
    },
    {
      "identity": "swiftformat",
      "kind": "remoteSourceControl",
      "location": "https://github.com/nicklockwood/SwiftFormat"
    },
    {
      "identity": "some-registry-pkg",
      "kind": "registry",
      "location": "registry://some-registry-pkg"
    },
    {
      "identity": "ignored",
      "kind": "unknown",
      "location": "ignored"
    }
  ]
}
JSON

actual="$(crj_resolved_pins "${resolved_path}" "${checkouts_dir}")"
expected_arg_parser="swift-argument-parser	${checkouts_dir}/swift-argument-parser"
expected_swiftformat="swiftformat	${checkouts_dir}/SwiftFormat"
expected_registry="some-registry-pkg	${checkouts_dir}/some-registry-pkg"
assert_match "${expected_arg_parser}" "${actual}" \
  "should strip .git suffix and use repo basename"
assert_match "${expected_swiftformat}" "${actual}" \
  "should preserve case of repo basename"
assert_match "${expected_registry}" "${actual}" \
  "should use identity as checkout dir for registry kind"
if [[ ${actual} == *ignored* ]]; then
  fail "should skip unknown pin kinds; got: ${actual}"
fi

# Missing Package.resolved must be a silent no-op.
missing_actual="$(crj_resolved_pins "/nonexistent/Package.resolved" "${checkouts_dir}")"
assert_equal "" "${missing_actual}" \
  "should treat a missing Package.resolved as empty"

# MARK - crj_write_dep_build_file

build_file_dir="$(new_tmp_dir)"
crj_write_dep_build_file "${build_file_dir}"
build_file_path="${build_file_dir}/BUILD.bazel"
[[ -f ${build_file_path} ]] || fail "expected per-dep BUILD.bazel to be written"
content="$(cat "${build_file_path}")"
assert_match 'exports_files' "${content}" \
  "per-dep BUILD.bazel should export desc/dump.json"
assert_match '"desc.json"' "${content}" \
  "per-dep BUILD.bazel should reference desc.json"
assert_match '"dump.json"' "${content}" \
  "per-dep BUILD.bazel should reference dump.json"

# MARK - crj_write_root_build_file

root_build_dir="$(new_tmp_dir)"
crj_write_root_build_file "${root_build_dir}"
root_build_path="${root_build_dir}/BUILD.bazel"
[[ -f ${root_build_path} ]] || fail "expected root BUILD.bazel to be written"
content="$(cat "${root_build_path}")"
assert_match 'swift_info_test' "${content}" \
  "root BUILD.bazel should declare swift_info_test"
assert_match 'swift_info.json' "${content}" \
  "root BUILD.bazel should reference swift_info.json"
