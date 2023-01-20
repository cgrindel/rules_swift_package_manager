load("@cgrindel_swift_bazel//swiftpkg:defs.bzl", "swift_package")

def swift_dependencies():
    # version: 1.2.4
    swift_package(
        name = "swiftpkg_libwebp_xcode",
        commit = "4f52fc9b29600a03de6e05af16df0d694cb44301",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/SDWebImage/libwebp-Xcode.git",
        init_submodules = True,
    )

    # version: 1.4.4
    swift_package(
        name = "swiftpkg_swift_log",
        commit = "6fe203dc33195667ce1759bf0182975e4653ba1c",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/apple/swift-log",
    )
