"""Module exposing information about the example integration tests."""

load(
    "@contrib_rules_bazel_integration_test//bazel_integration_test:defs.bzl",
    "bazel_integration_test",
    "bazel_integration_tests",
    "integration_test_utils",
)
load("//:bazel_versions.bzl", "CURRENT_BAZEL_VERSION", "SUPPORTED_BAZEL_VERSIONS")

def _new(name, oss, versions):
    return struct(
        name = name,
        oss = oss,
        versions = versions,
    )

def _test_name(example_name, version):
    return integration_test_utils.bazel_integration_test_name(
        example_name + "_test",
        version,
    )

def _bazel_integration_test(ei):
    versions_len = len(ei.versions)
    if versions_len == 1:
        version = ei.versions[0]
        bazel_integration_test(
            name = example_infos.test_name(
                ei.name,
                version,
            ),
            timeout = _timeouts.get(
                ei.name,
                _default_timeout,
            ),
            bazel_version = version,
            target_compatible_with = [
                "@platforms//os:{}".format(os)
                for os in ei.oss
            ],
            test_runner = ":test_runner",
            workspace_files = integration_test_utils.glob_workspace_files(ei.name) + [
                "//:local_repository_files",
            ],
            workspace_path = ei.name,
        )
    elif versions_len > 1:
        bazel_integration_tests(
            name = ei.name + "_test",
            timeout = _timeouts.get(ei.name, _default_timeout),
            bazel_versions = ei.versions,
            test_runner = ":test_runner",
            workspace_files = integration_test_utils.glob_workspace_files(ei.name) + [
                "//:local_repository_files",
            ],
            workspace_path = ei.name,
        )

# The default timeout is "long".
_default_timeout = "long"

_timeouts = {
    "firebase_example": "eternal",
    "xcmetrics_example": "eternal",
}

_all_os_all_bazel_versions_test_examples = [
    "http_archive_ext_deps",
    "pkg_manifest_minimal",
]

_all_os_single_bazel_version_test_examples = [
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
)
