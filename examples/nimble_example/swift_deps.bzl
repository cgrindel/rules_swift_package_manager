load("@rules_swift_package_manager//swiftpkg:defs.bzl", "swift_package")

def swift_dependencies():
    # version: 2.1.1
    swift_package(
        name = "swiftpkg_cwlcatchexception",
        commit = "35f9e770f54ce62dd8526470f14c6e137cef3eea",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/mattgallagher/CwlCatchException.git",
    )

    # version: 2.1.0
    swift_package(
        name = "swiftpkg_cwlpreconditiontesting",
        commit = "c21f7bab5ca8eee0a9998bbd17ca1d0eb45d4688",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/mattgallagher/CwlPreconditionTesting.git",
    )

    # version: 10.0.0
    swift_package(
        name = "swiftpkg_nimble",
        commit = "f552a16f434eef1f18b62985172489f41d37a18e",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/Quick/Nimble",
    )

    # version: 5.0.1
    swift_package(
        name = "swiftpkg_quick",
        commit = "9913828ef3554e6cc1a57797c9f8dfd136c6c9d6",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/Quick/Quick",
    )
