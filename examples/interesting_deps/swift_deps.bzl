load("@cgrindel_swift_bazel//swiftpkg:defs.bzl", "swift_package")

def swift_dependencies():
    # version: 1.2.4
    swift_package(
        name = "swiftpkg_libwebp_xcode",
        commit = "4f52fc9b29600a03de6e05af16df0d694cb44301",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/SDWebImage/libwebp-Xcode.git",
    )

    # version: 1.5.1
    swift_package(
        name = "swiftpkg_swift_log",
        commit = "3e3ef75109d6801b2c44504e73f55f0dce6662c9",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/apple/swift-log",
    )
