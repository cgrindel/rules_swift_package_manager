"""Module exposing information about the example integration tests."""

load("@bazel_binaries//:defs.bzl", "bazel_binaries")
load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "lists")
load(
    "@rules_bazel_integration_test//bazel_integration_test:defs.bzl",
    "bazel_integration_test",
    "bazel_integration_tests",
    "integration_test_utils",
)
load(
    "//ci:defs.bzl",
    "bzlmod_modes",
    "ci_integration_test_params",
    "ci_test_params_suite",
)

def _new(name, oss, versions, enable_bzlmods):
    # Remove the Bazel label prefix if it exists.
    # Depending upon the whether bzmlod is enabled, the prefix could be `@@//:`
    # Replace periods (.) with underscore (_), after the first character
    clean_versions = [
        v.removeprefix("//:").removeprefix("@@//:")
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
        enable_bzlmods = enable_bzlmods,
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
        "//:runtime_files",
    ]
    workspace_path = ei.name
    if versions_len == 1:
        version = ei.versions[0]
        test_name = example_infos.test_name(ei.name, version)
        bazel_integration_test(
            name = test_name,
            bazel_binaries = bazel_binaries,
            bazel_version = version,
            timeout = timeout,
            target_compatible_with = target_compatible_with,
            test_runner = test_runner,
            workspace_files = workspace_files,
            workspace_path = workspace_path,
        )
        _ci_integration_test_params(ei, version)
    elif versions_len > 1:
        bazel_integration_tests(
            name = ei.name + "_test",
            bazel_binaries = bazel_binaries,
            bazel_versions = ei.versions,
            timeout = timeout,
            target_compatible_with = target_compatible_with,
            test_runner = test_runner,
            workspace_files = workspace_files,
            workspace_path = workspace_path,
        )
        for version in ei.versions:
            _ci_integration_test_params(ei, version)

def _test_params_name(ei, version):
    test_name = example_infos.test_name(ei.name, version)
    return _test_params_name_from_test_name(test_name)

def _test_params_name_from_test_name(test_name):
    return "{}_params".format(test_name)

def _ci_integration_test_params(ei, version):
    test_name = example_infos.test_name(ei.name, version)
    ci_integration_test_params(
        name = _test_params_name_from_test_name(test_name),
        bzlmod_modes = [
            bzlmod_modes.from_bool(enable_bzlmod)
            for enable_bzlmod in ei.enable_bzlmods
        ],
        oss = ei.oss,
        test_names = [test_name],
        visibility = ["//:__subpackages__"],
    )

def _ci_test_params_suite(name, example_infos):
    ci_test_params_suite(
        name = name,
        test_params = lists.flatten([
            [
                _test_params_name(ei, v)
                for v in ei.versions
            ]
            for ei in example_infos
        ]),
        visibility = ["//:__subpackages__"],
    )

# The default timeout is "long".
_default_timeout = "long"

_timeouts = {
    "firebase_example": "eternal",
    "soto_example": "eternal",
    "vapor_example": "eternal",
    "xcmetrics_example": "eternal",
}

_default_enable_bzlmods = [True]

_enable_bzlmods = {
    "http_archive_ext_deps": [True, False],
    "vapor_example": [True, False],
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
    "resources_example",
    "xcmetrics_example",
]

_linux_single_bazel_version_test_examples = []

_all = [
    _new(
        name = name,
        oss = ["macos", "linux"],
        versions = bazel_binaries.versions.all,
        enable_bzlmods = _enable_bzlmods.get(name, _default_enable_bzlmods),
    )
    for name in _all_os_all_bazel_versions_test_examples
] + [
    _new(
        name = name,
        oss = ["macos", "linux"],
        versions = [bazel_binaries.versions.current],
        enable_bzlmods = _enable_bzlmods.get(name, _default_enable_bzlmods),
    )
    for name in _all_os_single_bazel_version_test_examples
] + [
    _new(
        name = name,
        oss = ["macos"],
        versions = [bazel_binaries.versions.current],
        enable_bzlmods = _enable_bzlmods.get(name, _default_enable_bzlmods),
    )
    for name in _macos_single_bazel_version_test_examples
] + [
    _new(
        name = name,
        oss = ["linux"],
        versions = [bazel_binaries.versions.current],
        enable_bzlmods = _enable_bzlmods.get(name, _default_enable_bzlmods),
    )
    for name in _linux_single_bazel_version_test_examples
]

example_infos = struct(
    all = _all,
    bazel_integration_test = _bazel_integration_test,
    ci_test_params_suite = _ci_test_params_suite,
    new = _new,
    test_name = _test_name,
)
