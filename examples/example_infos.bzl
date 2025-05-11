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

def _test_name_prefix(name):
    return name + "_test"

def _test_name(example_name, version):
    return integration_test_utils.bazel_integration_test_name(
        _test_name_prefix(example_name),
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
        if not enable_bzlmod:
            fail("The {name} example still has legacy test enabled.".format(name = ei.name))
        test_runner = ":test_runner"
        bazel_integration_tests(
            name = _test_name_prefix(ei.name),
            bazel_binaries = bazel_binaries,
            bazel_versions = ei.versions,
            tags = integration_test_utils.DEFAULT_INTEGRATION_TEST_TAGS + [
                # Avoid file permssion error when using disk and repository cache after
                # 7.0.0rc2 upgrade.
                # https://github.com/bazelbuild/bazel/issues/19908
                "no-sandbox",
            ],
            timeout = timeout,
            target_compatible_with = target_compatible_with,
            test_runner = test_runner,
            workspace_files = workspace_files,
            workspace_path = workspace_path,
        )
        for version in ei.versions:
            _ci_integration_test_params(ei, version)

def _test_params_name(name, version):
    test_name = _test_name(name, version)
    return _test_params_name_from_test_name(test_name)

def _test_params_name_from_test_name(test_name):
    return "{}_params".format(test_name)

def _ci_integration_test_params(ei, version):
    test_name = _test_name(ei.name, version)
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
                _test_params_name(ei.name, v)
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

_enable_bzlmods = {}

_all_os_all_bazel_versions_test_examples = [
    "pkg_manifest_minimal",
]

_all_os_single_bazel_version_test_examples = [
    "vapor_example",
    "grpc_example",
]

_macos_single_bazel_version_test_examples = [
    "firebase_example",
    "google_maps_example",
    "interesting_deps",
    "ios_sim",
    "kscrash_example",
    "lottie_ios_example",
    "messagekit_example",
    "nimble_example",
    "objc_code",
    "phone_number_kit",
    "soto_example",  # Soto supports Linux and MacOS. However, the resolved package is different.
    "resources_example",
    "shake_ios_example",
    "skip_local_transitive_dependencies_example",
    "snapkit_example",
    "stripe_example",
    "xcmetrics_example",
    "tca_example",
    "symlink_example",
    "swift_package_registry_example",
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
