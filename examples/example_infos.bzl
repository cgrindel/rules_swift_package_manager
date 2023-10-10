"""Module exposing information about the example integration tests."""

load("@bazel_binaries//:defs.bzl", "bazel_binaries")
load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@cgrindel_bazel_starlib//bzllib:defs.bzl", "lists")
load(
    "@rules_bazel_integration_test//bazel_integration_test:defs.bzl",
    "bazel_integration_tests",
    "integration_test_utils",
)
load(
    "//ci:defs.bzl",
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

def _test_name_prefix(name, enable_bzlmod = True):
    suffix = "_test" if enable_bzlmod else "_legacy_test"
    return name + suffix

def _test_name(example_name, enable_bzlmod, version):
    return integration_test_utils.bazel_integration_test_name(
        _test_name_prefix(example_name, enable_bzlmod = enable_bzlmod),
        version,
    )

def _bazel_integration_test(ei):
    target_compatible_with = select(dicts.add(
        {
            "@platforms//os:{}".format(os): []
            for os in ei.oss
        },
        {"//conditions:default": ["@platforms//:incompatible"]},
    ))
    timeout = _timeouts.get(ei.name, _default_timeout)
    workspace_files = integration_test_utils.glob_workspace_files(ei.name) + [
        "//:runtime_files",
    ]
    workspace_path = ei.name
    for enable_bzlmod in ei.enable_bzlmods:
        test_runner = ":test_runner" if enable_bzlmod else ":legacy_test_runner"
        bazel_integration_tests(
            name = _test_name_prefix(ei.name, enable_bzlmod = enable_bzlmod),
            bazel_binaries = bazel_binaries,
            bazel_versions = ei.versions,
            timeout = timeout,
            target_compatible_with = target_compatible_with,
            test_runner = test_runner,
            workspace_files = workspace_files,
            workspace_path = workspace_path,
        )
        for version in ei.versions:
            _ci_integration_test_params(ei, enable_bzlmod, version)

def _test_params_name(name, enable_bzlmod, version):
    test_name = _test_name(name, enable_bzlmod, version)
    return _test_params_name_from_test_name(test_name)

def _test_params_name_from_test_name(test_name):
    return "{}_params".format(test_name)

def _ci_integration_test_params(ei, enable_bzlmod, version):
    test_name = _test_name(ei.name, enable_bzlmod, version)
    ci_integration_test_params(
        name = _test_params_name_from_test_name(test_name),
        oss = ei.oss,
        test_names = [test_name],
        visibility = ["//:__subpackages__"],
    )

def _ci_test_params_suite(name, example_infos):
    ci_test_params_suite(
        name = name,
        test_params = lists.flatten([
            [
                [
                    _test_params_name(ei.name, eb, v)
                    for eb in ei.enable_bzlmods
                ]
                for v in ei.versions
            ]
            for ei in example_infos
        ]),
        visibility = ["//:__subpackages__"],
    )

# Switched the default to eternal as CI is failing intermittently.
_default_timeout = "eternal"

_timeouts = {
    "firebase_example": "eternal",
    "soto_example": "eternal",
    "vapor_example": "eternal",
    "xcmetrics_example": "eternal",
}

_default_enable_bzlmods = [True]

_enable_bzlmods = {
    # GH411: Enable bzlmod for http_archive_ext_deps.
    "http_archive_ext_deps": [False],
    "vapor_example": [True, False],
}

_all_os_all_bazel_versions_test_examples = [
    "http_archive_ext_deps",
    "pkg_manifest_minimal",
]

_all_os_single_bazel_version_test_examples = [
    "soto_example",
    "vapor_example",
    "grpc_example",
]

_macos_single_bazel_version_test_examples = [
    "firebase_example",
    "interesting_deps",
    "ios_sim",
    "lottie_ios_example",
    "messagekit_example",
    "nimble_example",
    "objc_code",
    "phone_number_kit",
    "resources_example",
    "shake_ios_example",
    "snapkit_example",
    "stripe_example",
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
    test_name_prefix = _test_name_prefix,
    test_name = _test_name,
)
