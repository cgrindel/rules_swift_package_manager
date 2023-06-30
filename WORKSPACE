workspace(name = "rules_swift_package_manager")

load("//:deps.bzl", "swift_bazel_dependencies")

swift_bazel_dependencies()

# MARK: - Starlark

load("@cgrindel_bazel_starlib//:deps.bzl", "bazel_starlib_dependencies")

bazel_starlib_dependencies()

load("@buildifier_prebuilt//:deps.bzl", "buildifier_prebuilt_deps")

buildifier_prebuilt_deps()

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()

load("@buildifier_prebuilt//:defs.bzl", "buildifier_prebuilt_register_toolchains")

buildifier_prebuilt_register_toolchains()

# MARK: - Golang

load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies")
load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")

# gazelle:repo bazel_gazelle

load("//:go_deps.bzl", "swift_bazel_go_dependencies")

# Workaround for missing strict deps error as described here:
# https://github.com/bazelbuild/bazel-gazelle/issues/1217#issuecomment-1152236735
# gazelle:repository go_repository name=in_gopkg_alecthomas_kingpin_v2 importpath=gopkg.in/alecthomas/kingpin.v2

# gazelle:repository_macro go_deps.bzl%swift_bazel_go_dependencies
swift_bazel_go_dependencies()

# MARK: - Skylib Gazelle Extension

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "bazel_skylib_gazelle_plugin",
    sha256 = "3327005dbc9e49cc39602fb46572525984f7119a9c6ffe5ed69fbe23db7c1560",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.4.2/bazel-skylib-gazelle-plugin-1.4.2.tar.gz",
        "https://github.com/bazelbuild/bazel-skylib/releases/download/1.4.2/bazel-skylib-gazelle-plugin-1.4.2.tar.gz",
    ],
)

load("@bazel_skylib_gazelle_plugin//:workspace.bzl", "bazel_skylib_gazelle_plugin_workspace")

bazel_skylib_gazelle_plugin_workspace()

go_rules_dependencies()

go_register_toolchains(version = "1.19.5")

gazelle_dependencies()

# MARK: - Bazel Integration Test

http_archive(
    name = "rules_bazel_integration_test",
    sha256 = "bfba659b9e29fc4cbeb2410e20f0270c54da3886bbe69aa8b0378701dca06a8d",
    urls = [
        "https://github.com/bazel-contrib/rules_bazel_integration_test/releases/download/v0.14.1/rules_bazel_integration_test.v0.14.1.tar.gz",
    ],
)

load("@rules_bazel_integration_test//bazel_integration_test:deps.bzl", "bazel_integration_test_rules_dependencies")

bazel_integration_test_rules_dependencies()

load("@rules_bazel_integration_test//bazel_integration_test:defs.bzl", "bazel_binaries")

bazel_binaries(versions = ["//:.bazelversion"])

# Go Deps for bazel-starlib

load("@cgrindel_bazel_starlib//:go_deps.bzl", "bazel_starlib_go_dependencies")

bazel_starlib_go_dependencies()

# MARK: - Swift Toolchain

http_archive(
    name = "build_bazel_rules_swift",
    sha256 = "7929b4fd6d9f7c44ed5734a15004bfc2046146ba5ea269f0568d9efe2f405ef3",
    url = "https://github.com/bazelbuild/rules_swift/releases/download/1.9.0/rules_swift.1.9.0.tar.gz",
)

load(
    "@build_bazel_rules_swift//swift:repositories.bzl",
    "swift_rules_dependencies",
)

swift_rules_dependencies()

load(
    "@build_bazel_rules_swift//swift:extras.bzl",
    "swift_rules_extra_dependencies",
)

swift_rules_extra_dependencies()
