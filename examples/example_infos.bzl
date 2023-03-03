"""Module exposing information about the example integration tests."""

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load(
    "@contrib_rules_bazel_integration_test//bazel_integration_test:defs.bzl",
    "bazel_integration_test",
    "bazel_integration_tests",
    "integration_test_utils",
)
load("//:bazel_versions.bzl", "CURRENT_BAZEL_VERSION", "SUPPORTED_BAZEL_VERSIONS")

def _new(name, oss, versions):
    # Remove the Bazel label prefix if it exists.
    # Replace periods (.) with underscore (_), after the first character
    clean_versions = [
        v.removeprefix("//:")
        for v in versions
    ]
    clean_versions = [
        v[0] + v[1:].replace(".", "_")
        for v in clean_versions
    ]
    return struct(
        name = name,
        oss = oss,
        versions = versions,
        clean_versions = clean_versions,
    )

def _test_name(example_name, version):
    return integration_test_utils.bazel_integration_test_name(
        example_name + "_test",
        version,
    )

def _bazel_integration_test(ei):
    versions_len = len(ei.versions)
    target_compatible_with = select(dicts.add(
        {
            "@platforms//os:{}".format(os): []
            for os in ei.oss
        },
        {"//conditions:default": ["@platforms//:incompatible"]},
    ))
    timeout = _timeouts.get(ei.name, _default_timeout)
    test_runner = ":test_runner"
    workspace_files = integration_test_utils.glob_workspace_files(ei.name) + [
        "//:local_repository_files",
    ]
    workspace_path = ei.name
    if versions_len == 1:
        version = ei.versions[0]
        bazel_integration_test(
            name = example_infos.test_name(
                ei.name,
                version,
            ),
            bazel_version = version,
            timeout = timeout,
            target_compatible_with = target_compatible_with,
            test_runner = test_runner,
            workspace_files = workspace_files,
            workspace_path = workspace_path,
        )
    elif versions_len > 1:
        bazel_integration_tests(
            name = ei.name + "_test",
            bazel_versions = ei.versions,
            timeout = timeout,
            target_compatible_with = target_compatible_with,
            test_runner = test_runner,
            workspace_files = workspace_files,
            workspace_path = workspace_path,
        )

def _write_json_impl(ctx):
    json_str = json.encode_indent(_all)
    out_filename = ctx.attr.out
    if out_filename == "":
        out_filename = "{}.json".format(ctx.label.name)
    out = ctx.actions.declare_file(out_filename)
    ctx.actions.write(out, json_str)
    return [DefaultInfo(files = depset([out]))]

_write_json = rule(
    implementation = _write_json_impl,
    attrs = {
        "out": attr.string(
            doc = """\
The name of the output file. If not specified, the label name is used.\
""",
        ),
    },
    doc = """\
Write the information about the example integration tests to a JSON file.\
""",
)

# The default timeout is "long".
_default_timeout = "long"

_timeouts = {
    "firebase_example": "eternal",
    "soto_example": "eternal",
    "vapor_example": "eternal",
    "xcmetrics_example": "eternal",
}

_all_os_all_bazel_versions_test_examples = [
    "http_archive_ext_deps",
    "pkg_manifest_minimal",
]

_all_os_single_bazel_version_test_examples = [
    "soto_example",
    "vapor_example",
]

_macos_single_bazel_version_test_examples = [
    "firebase_example",
    "interesting_deps",
    "ios_sim",
    "objc_code",
    "phone_number_kit",
    "xcmetrics_example",
]

_linux_single_bazel_version_test_examples = []

_all = [
    _new(
        name = name,
        oss = ["macos", "linux"],
        versions = SUPPORTED_BAZEL_VERSIONS,
    )
    for name in _all_os_all_bazel_versions_test_examples
] + [
    _new(
        name = name,
        oss = ["macos", "linux"],
        versions = [CURRENT_BAZEL_VERSION],
    )
    for name in _all_os_single_bazel_version_test_examples
] + [
    _new(
        name = name,
        oss = ["macos"],
        versions = [CURRENT_BAZEL_VERSION],
    )
    for name in _macos_single_bazel_version_test_examples
] + [
    _new(
        name = name,
        oss = ["linux"],
        versions = [CURRENT_BAZEL_VERSION],
    )
    for name in _linux_single_bazel_version_test_examples
]

example_infos = struct(
    all = _all,
    bazel_integration_test = _bazel_integration_test,
    new = _new,
    test_name = _test_name,
    write_json = _write_json,
)
