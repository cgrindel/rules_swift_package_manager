#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

# Maintainer-only: migrates one example workspace under `examples/` from the
# v1 `from_package` tag to v2 slices. Run it from the repository root:
#
#   bazel run //tools/migrate_example_to_slices -- <example_name>
#
# It refuses to run on an example that already has a slice, so a failed run is
# undone with `git checkout` and `git clean` on the example directory.

usage() {
  cat >&2 <<USAGE
Usage: bazel run //tools/migrate_example_to_slices -- \\
  [--slices any|apple,linux] [--skip-cache] <example_name>

  --slices      The slices to create. Default: from examples/example_infos.bzl,
                two slices (apple, linux) for an _all_os_ example and one
                (any) otherwise.
  --skip-cache  Do not run @swift_package//:cache after the migration.
USAGE
  exit 1
}

die() {
  echo >&2 "ERROR: ${*}"
  exit 1
}

warn() {
  echo >&2 "WARNING: ${*}"
}

bazel="${BAZEL:-bazel}"

slices_arg=""
skip_cache=false
example=""
while [[ ${#} -gt 0 ]]; do
  case "${1}" in
    --slices)
      [[ ${#} -ge 2 ]] || usage
      slices_arg="${2}"
      shift 2
      ;;
    --skip-cache)
      skip_cache=true
      shift 1
      ;;
    -h | --help)
      usage
      ;;
    -*)
      echo >&2 "Unknown option: ${1}"
      usage
      ;;
    *)
      [[ -z ${example} ]] || die "Unexpected argument: ${1}"
      example="${1}"
      shift 1
      ;;
  esac
done
[[ -n ${example} ]] || usage

root="${BUILD_WORKSPACE_DIRECTORY:-}"
[[ -n ${root} ]] \
  || die "BUILD_WORKSPACE_DIRECTORY is not set; run this with bazel run."
example_rel="examples/${example}"
example_dir="${root}/${example_rel}"
[[ -f "${example_dir}/MODULE.bazel" ]] \
  || die "No MODULE.bazel in ${example_dir}."

# MARK: - Preflight

if [[ -d "${example_dir}/swift_deps" ]] \
  || grep -qF 'include("//swift_deps/' "${example_dir}/MODULE.bazel"; then
  die "${example_rel} already has slices; refusing to migrate it twice."
fi
grep -qF 'swift_deps.from_package(' "${example_dir}/MODULE.bazel" \
  || die "${example_rel}/MODULE.bazel has no v1 swift_deps.from_package tag."
if [[ -n "$(git -C "${root}" status --porcelain -- "${example_rel}")" ]]; then
  warn "${example_rel} has uncommitted changes; undoing a failed run with" \
    "git will also discard them."
fi

if [[ -f "${example_dir}/Package.swift" ]]; then
  swift_rel="Package.swift"
elif [[ -f "${example_dir}/swift/Package.swift" ]]; then
  swift_rel="swift/Package.swift"
else
  die "No Package.swift at the root or under swift/ in ${example_rel}."
fi
resolved_rel="$(dirname "${swift_rel}")/Package.resolved"
resolved_rel="${resolved_rel#./}"

# Prints the name of the `examples/example_infos.bzl` list that holds the
# example, such as `_macos_single_bazel_version_test_examples`.
example_list() {
  awk -v name="\"${example}\"" '
    /^_[a-z_]+_test_examples = \[/ { list = $1; next }
    list != "" && /^\]/ { list = ""; next }
    list != "" && index($0, name) > 0 { print list }
  ' "${root}/examples/example_infos.bzl"
}

if [[ -n ${slices_arg} ]]; then
  IFS=, read -ra slices <<<"${slices_arg}"
else
  list="$(example_list)"
  case "${list}" in
    _all_os_*) slices=(apple linux) ;;
    _macos_* | _linux_*) slices=(any) ;;
    "")
      die "${example} is in no list in examples/example_infos.bzl; pass" \
        "--slices."
      ;;
    *) die "Unexpected example_infos.bzl list for ${example}: ${list}" ;;
  esac
fi
for slice in "${slices[@]}"; do
  case "${slice}" in
    any | apple | linux) ;;
    *) die "Unknown slice: ${slice}. Expected any, apple or linux." ;;
  esac
done
if [[ ${#slices[@]} -gt 1 ]]; then
  for slice in "${slices[@]}"; do
    [[ ${slice} != any ]] \
      || die "The any slice overlaps every other slice; use it alone."
  done
fi

# The slice that `@swift_package//:cache` regenerates on this host.
host_slice=""
if [[ ${#slices[@]} -eq 1 && ${slices[0]} == any ]]; then
  host_slice=any
else
  case "$(uname)" in
    Darwin) host_os_slice=apple ;;
    *) host_os_slice=linux ;;
  esac
  for slice in "${slices[@]}"; do
    [[ ${slice} != "${host_os_slice}" ]] || host_slice="${slice}"
  done
fi

echo "Migrating ${example_rel}: Package.swift at ${swift_rel}, slices:" \
  "${slices[*]}."

# MARK: - Rewrites

# Rewrites one file in place. The first argument picks the edit; see the
# Python below. The rest are passed through.
rewrite() {
  python3 -I - "${@}" <<'PY'
import re
import sys

GAZELLE_DEPS = {"gazelle", "swift_gazelle_plugin", "bazel_skylib_gazelle_plugin"}

# v1 `from_package` attributes that the migration cannot carry into a slice.
_BY_HAND = "Carry it into each slice's inc.MODULE.bazel by hand."
UNCARRIED_TAG_ATTRS = {
    "declare_swift_package": (
        "v2 always declares @swift_package, so drop it by hand and check that "
        "nothing else declares a repository with that name."
    ),
    "make_files_read_only": _BY_HAND,
    "netrc": _BY_HAND,
    "registries": _BY_HAND + " v2 does not support registries until #2699.",
}

GIT_OVERRIDE = """\
# TODO(#2641): remove once a rules_swift release includes swift_toolchain_tool.
# The root module's override in rules_swift_package_manager does not reach
# this workspace.
git_override(
    module_name = "rules_swift",
    commit = "dd629b0cbb25c017e30fff3c40d0f0fddf653613",
    remote = "https://github.com/cgrindel/rules_swift.git",
)
"""

TIDY = """\
tidy(
    name = "tidy",
    targets = [
        ":update_all",
    ],
)
"""

UPDATE_ALL_LOAD = (
    'load("@cgrindel_bazel_starlib//updatesrc:defs.bzl", "updatesrc_update_all")'
)


def log(msg):
    print("  " + msg)


def call_end(text, open_idx):
    """Returns the index after the `)` matching the `(` at open_idx."""
    depth = 0
    i = open_idx
    quote = None
    while i < len(text):
        c = text[i]
        if quote:
            if c == "\\":
                i += 2
                continue
            if text.startswith(quote, i):
                i += len(quote)
                quote = None
                continue
        elif c == "#":
            i = text.find("\n", i)
            if i < 0:
                break
            continue
        elif c in "\"'":
            quote = text[i : i + 3] if text[i : i + 3] in ('"""', "'''") else c
            i += len(quote)
            continue
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    raise SystemExit("ERROR: unbalanced call at offset {}".format(open_idx))


def find_calls(text, name):
    """Yields (start, end) of top-level `name(...)` calls, whole lines."""
    spans = []
    for m in re.finditer(r"^" + re.escape(name) + r"\(", text, re.M):
        end = call_end(text, m.end() - 1)
        nl = text.find("\n", end)
        end = len(text) if nl < 0 else nl + 1
        spans.append((m.start(), end))
    return spans


def with_attached_comments(text, start):
    """Moves start back over the comment lines directly above it."""
    lines_before = text[:start].split("\n")
    # The last element is the empty string before `start`.
    idx = len(lines_before) - 1
    while idx > 0 and lines_before[idx - 1].lstrip().startswith("#"):
        idx -= 1
    return len("\n".join(lines_before[:idx])) + (1 if idx > 0 else 0)


def remove_spans(text, spans):
    for start, end in sorted(spans, reverse=True):
        log("removed:\n" + indent(text[start:end]))
        text = text[:start] + text[end:]
    return text


def indent(s):
    return "".join("    | " + line + "\n" for line in s.rstrip("\n").split("\n"))


def tidy_blank_lines(text):
    text = re.sub(r"[ \t]+\n", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip("\n") + "\n"


def call_name_attr(span_text):
    m = re.search(r'\bname\s*=\s*"([^"]+)"', span_text)
    return m.group(1) if m else None


# MARK: - MODULE.bazel


def module(path):
    text = open(path).read()

    # Refuse to drop a v1 tag attribute that `init` does not write into
    # the slice's inc.MODULE.bazel.
    for s, e in find_calls(text, "swift_deps.from_package"):
        for attr in sorted(UNCARRIED_TAG_ATTRS):
            if re.search(r"\b" + attr + r"\s*=", text[s:e]):
                raise SystemExit(
                    "ERROR: the v1 from_package tag in {} sets `{}`. {}".format(
                        path, attr, UNCARRIED_TAG_ATTRS[attr]
                    )
                )

    # Gazelle deps.
    spans = [
        (with_attached_comments(text, s), e)
        for s, e in find_calls(text, "bazel_dep")
        if call_name_attr(text[s:e]) in GAZELLE_DEPS
    ]
    text = remove_spans(text, spans)

    # The v1 tag.
    spans = [
        (with_attached_comments(text, s), e)
        for s, e in find_calls(text, "swift_deps.from_package")
    ]
    text = remove_spans(text, spans)

    # swift_deps_info from the swift_deps use_repo.
    for s, e in find_calls(text, "use_repo"):
        span = text[s:e]
        if not re.match(r"use_repo\(\s*swift_deps\s*,", span):
            continue
        new = re.sub(r'\n[ \t]*"swift_deps_info",[^\n]*', "", span)
        new = re.sub(r',\s*"swift_deps_info"', "", new)
        if '"swift_package"' not in new:
            new = re.sub(
                r"use_repo\(\s*swift_deps\s*,",
                'use_repo(\n    swift_deps,\n    "swift_package",',
                new,
                count=1,
            )
            log('added "swift_package" to the swift_deps use_repo')
        if new != span:
            log('dropped "swift_deps_info" from the swift_deps use_repo')
            text = text[:s] + new + text[e:]
        break
    else:
        raise SystemExit("ERROR: no use_repo(swift_deps, ...) in " + path)

    # The rules_swift git_override.
    if re.search(r'git_override\(\s*module_name\s*=\s*"rules_swift"', text):
        log("rules_swift git_override already present")
    else:
        anchor = None
        for s, e in find_calls(text, "bazel_dep"):
            if call_name_attr(text[s:e]) == "rules_swift":
                anchor = e
        if anchor is None:
            for s, e in find_calls(text, "local_path_override"):
                anchor = e
                break
        if anchor is None:
            raise SystemExit("ERROR: no place for the git_override in " + path)
        text = text[:anchor] + "\n" + GIT_OVERRIDE + "\n" + text[anchor:]
        log("added the rules_swift git_override")

    for attr in ("build_path", "env =", "env_inherit", "cached_json_directory"):
        if attr in text:
            log("NOTE: MODULE.bazel still mentions `{}`; v2 drops it".format(attr))

    open(path, "w").write(tidy_blank_lines(text))


def module_includes(path, *slices):
    text = open(path).read()
    if len(slices) == 1:
        comment = (
            "# The slice's `from_package` tag. Include it after the root "
            "`use_extension` so\n# that `bazel mod tidy` writes `use_repo` "
            "here rather than into the slice file.\n"
        )
    else:
        comment = (
            "# One `from_package` tag per slice. Include them after the root\n"
            "# `use_extension` so that `bazel mod tidy` writes `use_repo` "
            "here rather than\n# into a slice file.\n"
        )
    lines = "".join(
        'include("//swift_deps/{}:inc.MODULE.bazel")\n'.format(s) for s in slices
    )
    open(path, "w").write(tidy_blank_lines(text) + "\n" + comment + lines)
    log("appended " + ", ".join(slices) + " include() lines")


# MARK: - BUILD.bazel


def build(path):
    text = open(path).read()

    # Calls to drop.
    spans = []
    for name in ("gazelle_binary", "gazelle", "swift_package_tool"):
        spans += [(with_attached_comments(text, s), e) for s, e in find_calls(text, name)]
    # An alias of a v1 `swift_package_tool` in another package.
    spans += [
        (with_attached_comments(text, s), e)
        for s, e in find_calls(text, "alias")
        if "update_swift_packages" in text[s:e]
    ]
    text = remove_spans(text, spans)

    # Gazelle directives and headings, a paragraph at a time.
    paragraphs = text.split("\n\n")
    kept = []
    for para in paragraphs:
        lines = para.split("\n")
        comment_only = all(l.lstrip().startswith("#") or not l.strip() for l in lines)
        if comment_only and (
            any(l.lstrip().startswith("# gazelle:") for l in lines)
            or para.strip() == "# MARK: - Gazelle"
        ):
            log("removed:\n" + indent(para))
            continue
        new_lines = [l for l in lines if not l.lstrip().startswith("# gazelle:")]
        kept.append("\n".join(new_lines))
    text = "\n\n".join(kept)

    # Loads: drop Gazelle and swift_package_tool.
    def fix_load(m):
        stmt = m.group(0)
        if "@bazel_gazelle//" in stmt:
            log("removed: " + stmt)
            return ""
        if '"swift_package_tool"' in stmt:
            new = re.sub(r',\s*"swift_package_tool"', "", stmt)
            if not re.search(r'",\s*"', new):
                log("removed: " + stmt)
                return ""
            log("removed swift_package_tool from: " + stmt)
            return new
        return stmt

    text = re.sub(r"^load\([^)]*\)\n?", fix_load, text, flags=re.M)

    # tidy runs :update_all only. An example without a tidy keeps none: its
    # MODULE.bazel may not depend on cgrindel_bazel_starlib.
    tidy_spans = find_calls(text, "tidy")
    if len(tidy_spans) > 1:
        raise SystemExit("ERROR: more than one tidy() in " + path)
    if tidy_spans:
        s, e = tidy_spans[0]
        text = text[:s] + TIDY + text[e:]
        log("tidy now runs :update_all only")
        if not find_calls(text, "updatesrc_update_all"):
            text = (
                text[:s]
                + 'updatesrc_update_all(name = "update_all")\n\n'
                + text[s:]
            )
            if UPDATE_ALL_LOAD not in text:
                text = UPDATE_ALL_LOAD + "\n" + text
            log("added updatesrc_update_all")
    else:
        log("no tidy() to rewrite; left the BUILD.bazel without one")

    # Keep the single-line loads at the top sorted.
    lines = text.lstrip("\n").split("\n")
    n = 0
    while n < len(lines) and lines[n].startswith("load(") and lines[n].endswith(")"):
        n += 1
    text = "\n".join(sorted(lines[:n]) + lines[n:])

    for word in ("swift_deps_info", "swift_deps_index", "update_build_files"):
        if word in text:
            log("NOTE: BUILD.bazel still mentions `{}`".format(word))

    # The root package must stay. Do not leave an empty file behind.
    code = [l for l in text.split("\n") if l.strip() and not l.lstrip().startswith("#")]
    if not code:
        log("only comments were left; replaced them with a note")
        text = (
            "# The root package of the example. Update the Swift packages with\n"
            "# `bazel run @swift_package//:update`.\n"
        )

    open(path, "w").write(tidy_blank_lines(text))


# MARK: - do_test


def do_test(path, slice_dir_note):
    text = open(path).read()

    new = re.sub(r"//:update_swift_packages\b", "@swift_package//:update", text)
    if new != text:
        log("replaced //:update_swift_packages with @swift_package//:update")
        text = new

    paragraphs = text.split("\n\n")
    kept = []
    for para in paragraphs:
        if "update_build_files" in para:
            log("removed:\n" + indent(para))
            continue
        kept.append(para)
    text = "\n\n".join(kept)

    if re.search(r"^\s*trap ", text, re.M):
        log("NOTE: do_test already sets a trap; the inserted block replaces it")

    block = """\
# The checked-in slice for this host must regenerate byte-for-byte on this
# host, and `bazel mod tidy` must find the root use_repo current. An `any`
# slice is cached on macOS, so only macOS checks it.{note}
if [[ -d swift_deps/apple && "$(uname)" == "Darwin" ]]; then
  host_slice="apple"
elif [[ -d swift_deps/linux && "$(uname)" == "Linux" ]]; then
  host_slice="linux"
elif [[ -d swift_deps/any && "$(uname)" == "Darwin" ]]; then
  host_slice="any"
else
  host_slice=""
fi
if [[ -z "${{host_slice}}" ]]; then
  echo "No checked-in slice for $(uname); skipped the cache-and-diff check."
else
  slice_tmp="$(mktemp -d)"
  trap 'rm -rf "${{slice_tmp}}"' EXIT
  cp -R swift_deps "${{slice_tmp}}/swift_deps"
  cp MODULE.bazel "${{slice_tmp}}/MODULE.bazel"

  "${{bazel}}" run @swift_package//:cache
  diff -r --exclude=.build \\
    "${{slice_tmp}}/swift_deps/${{host_slice}}" "swift_deps/${{host_slice}}" \\
    || (echo >&2 "The cache step changed the checked-in ${{host_slice}} slice." \\
      && exit 1)

  "${{bazel}}" mod tidy
  diff "${{slice_tmp}}/MODULE.bazel" MODULE.bazel \\
    || (echo >&2 "bazel mod tidy changed MODULE.bazel." && exit 1)
  diff -r --exclude=.build "${{slice_tmp}}/swift_deps" swift_deps \\
    || (echo >&2 "bazel mod tidy changed a slice." && exit 1)
fi
""".format(note=slice_dir_note)
    # Only blank lines are normalized; other lines stay byte for byte.
    text = re.sub(r"\n{3,}", "\n\n", text).rstrip("\n") + "\n"

    # Snapshot the committed slice, not the one `update` rewrites: insert the
    # block before the first `@swift_package//:update` line and the comment
    # lines right above it.
    lines = text.split("\n")
    at = next(
        (
            i
            for i, l in enumerate(lines)
            if not l.lstrip().startswith("#") and "@swift_package//:update" in l
        ),
        None,
    )
    if at is None:
        open(path, "w").write(text + "\n" + block)
        log("appended the cache-and-diff block")
        return
    while at > 0 and lines[at - 1].lstrip().startswith("#"):
        at -= 1
    before = "\n".join(lines[:at])
    after = "\n".join(lines[at:])
    open(path, "w").write(before + "\n" + block + "\n" + after)
    log("inserted the cache-and-diff block before @swift_package//:update")


# MARK: - swift/BUILD.bazel


def swift_build(path):
    """Drops the v1 `swift_package_tool` from the package of `Package.swift`.

    The package stays, since `//swift:Package.swift` must remain a label.
    """
    text = open(path).read()
    spans = [
        (with_attached_comments(text, s), e)
        for s, e in find_calls(text, "swift_package_tool")
    ]
    text = remove_spans(text, spans)
    text = re.sub(
        r'^load\("@rules_swift_package_manager//swiftpkg:defs.bzl", "swift_package_tool"\)\n',
        "",
        text,
        flags=re.M,
    )
    code = [l for l in text.split("\n") if l.strip() and not l.lstrip().startswith("#")]
    if not code:
        log("only comments were left; replaced them with a note")
        text = (
            "# The package exists so that `//swift:Package.swift` is a valid "
            "label. Update\n# the Swift packages with "
            "`bazel run @swift_package//:update`.\n"
        )
    open(path, "w").write(tidy_blank_lines(text))


cmds = {
    "module": module,
    "module_includes": module_includes,
    "build": build,
    "do_test": do_test,
    "swift_build": swift_build,
}
cmds[sys.argv[1]](*sys.argv[2:])
PY
}

linux_note=""
for slice in "${slices[@]}"; do
  if [[ ${slice} == linux ]]; then
    linux_note=$'\n'"# The linux slice comes from the generate_linux_slices workflow."
  fi
done

echo "MODULE.bazel:"
rewrite module "${example_dir}/MODULE.bazel"
echo "BUILD.bazel:"
rewrite build "${example_dir}/BUILD.bazel"
swift_dir="$(dirname "${swift_rel}")"
if [[ ${swift_dir} != . && -f "${example_dir}/${swift_dir}/BUILD.bazel" ]]; then
  echo "${swift_dir}/BUILD.bazel:"
  rewrite swift_build "${example_dir}/${swift_dir}/BUILD.bazel"
fi
if [[ -f "${example_dir}/do_test" ]]; then
  echo "do_test:"
  rewrite do_test "${example_dir}/do_test" "${linux_note}"
else
  warn "No do_test in ${example_rel}."
fi

# MARK: - Slices

# `init` must run before the include() lines exist; it refuses to overwrite a
# slice, which makes a second migration fail early.
cd "${example_dir}"
seed_args=()
if [[ -f "${example_dir}/${resolved_rel}" ]]; then
  seed_args=(--seed "${resolved_rel}")
else
  echo "No ${resolved_rel}; the slices start without a seed."
fi
for slice in "${slices[@]}"; do
  echo "Creating slice swift_deps/${slice}..."
  "${bazel}" run @rules_swift_package_manager//tools:init -- \
    --swift "${swift_rel}" \
    --dir "swift_deps/${slice}" \
    --config "@rules_swift_package_manager//config:${slice}" \
    "${seed_args[@]+"${seed_args[@]}"}" >/dev/null
done
if [[ -f "${example_dir}/${resolved_rel}" ]]; then
  rm "${example_dir}/${resolved_rel}"
  echo "Deleted the v1 ${resolved_rel}."
fi

echo "MODULE.bazel:"
rewrite module_includes "${example_dir}/MODULE.bazel" "${slices[@]}"

# The rspm root ignores every slice's SwiftPM scratch dir.
for slice in "${slices[@]}"; do
  line="${example_rel}/swift_deps/${slice}/.build"
  if ! grep -qxF -- "${line}" "${root}/.bazelignore"; then
    echo "${line}" >>"${root}/.bazelignore"
    echo "Added ${line} to the root .bazelignore."
  fi
done

if command -v buildifier >/dev/null; then
  buildifier -mode=fix "${example_dir}/MODULE.bazel" "${example_dir}/BUILD.bazel"
else
  warn "buildifier is not on PATH; MODULE.bazel and BUILD.bazel are unformatted."
fi

# MARK: - Cache

if [[ ${skip_cache} == true ]]; then
  echo "Skipped the cache step (--skip-cache)."
elif [[ -z ${host_slice} ]]; then
  warn "This host caches no slice of ${example_rel}; skipped the cache step."
else
  echo "Caching the ${host_slice} slice..."
  # The v1 use_repo names local packages that a stale slice cannot declare
  # yet, which fails the cache run. Prune use_repo first; the second
  # `bazel mod tidy` adds them back.
  "${bazel}" mod tidy
  "${bazel}" run @swift_package//:cache
  "${bazel}" mod tidy
  rm -rf "${example_dir}"/swift_deps/*/.build
fi

# MARK: - Summary

cat <<SUMMARY

Migrated ${example_rel} to slices: ${slices[*]}.

Remaining manual steps:
  - Review the diff (git diff -- ${example_rel}), including the README.
  - Run \`bazel run //:tidy\` at the repository root so that .bazelrc
    deleted_packages and ci.yml pick up the slice packages.
  - Run the example's integration test.
SUMMARY
for slice in "${slices[@]}"; do
  if [[ ${slice} != "${host_slice}" ]]; then
    cat <<SUMMARY
  - The ${slice} slice is an empty skeleton. Generate it on a ${slice} host;
    for linux, use the generate_linux_slices workflow
    (.github/workflows/generate_linux_slices.yml) and commit the artifact.
SUMMARY
  fi
done
