load("@cgrindel_swift_bazel//swiftpkg:defs.bzl", "local_swift_package", "swift_package")

def swift_dependencies():
    local_swift_package(
        name = "swiftpkg_add_5_5_manifest",
        module_index = "@//:module_index.json",
        path = "../../../../libwebp-Xcode/cg/add_5_5_manifest",
    )

    # # version: 1.2.4
    # swift_package(
    #     name = "swiftpkg_libwebp_xcode",
    #     commit = "4f52fc9b29600a03de6e05af16df0d694cb44301",
    #     module_index = "@//:module_index.json",
    #     remote = "https://github.com/SDWebImage/libwebp-Xcode.git",
    #     # This repository uses submodules to gather its code.
    #     init_submodules = True,
    # )

    # version: 1.4.4
    swift_package(
        name = "swiftpkg_swift_log",
        commit = "6fe203dc33195667ce1759bf0182975e4653ba1c",
        module_index = "@//:module_index.json",
        remote = "https://github.com/apple/swift-log",
    )
