load("@cgrindel_swift_bazel//swiftpkg:defs.bzl", "swift_package")

def swift_dependencies():
    # version: 1.2.0
    swift_package(
        name = "apple_swift_argument_parser",
        commit = "fddd1c00396eed152c45a46bea9f47b98e59301d",
        remote = "https://github.com/apple/swift-argument-parser",
    )
