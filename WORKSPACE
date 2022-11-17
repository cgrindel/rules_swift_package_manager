workspace(name = "cgrindel_swift_bazel")

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

# gazelle:repository_macro go_deps.bzl%swift_bazel_go_dependencies
swift_bazel_go_dependencies()

go_rules_dependencies()

go_register_toolchains(version = "1.19.1")

gazelle_dependencies()

bazel_skylib_workspace()

# MARK: - Bazel Integration Test

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "contrib_rules_bazel_integration_test",
    sha256 = "dc104db22f2845aed0aa5dfcdd8af35de15ce0985502859db48c902977ca0dda",
    strip_prefix = "rules_bazel_integration_test-a9b2a411712e75851a1c21222df4fc317ed98fee",
    urls = [
        "http://github.com/bazel-contrib/rules_bazel_integration_test/archive/a9b2a411712e75851a1c21222df4fc317ed98fee.tar.gz",
    ],
)

load("@contrib_rules_bazel_integration_test//bazel_integration_test:deps.bzl", "bazel_integration_test_rules_dependencies")

bazel_integration_test_rules_dependencies()

load("@contrib_rules_bazel_integration_test//bazel_integration_test:defs.bzl", "bazel_binaries")
load("//:bazel_versions.bzl", "SUPPORTED_BAZEL_VERSIONS")

bazel_binaries(versions = SUPPORTED_BAZEL_VERSIONS)
