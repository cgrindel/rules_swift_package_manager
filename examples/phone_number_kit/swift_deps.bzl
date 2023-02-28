load("@cgrindel_swift_bazel//swiftpkg:defs.bzl", "swift_package")

def swift_dependencies():
    # version: 3.5.7
    swift_package(
        name = "swiftpkg_phonenumberkit",
        commit = "434a7432cceca19829bc6e34bdcfc0b0ee4c6801",
        dependencies_index = "@//:swift_deps_index.json",
        remote = "https://github.com/marmelroy/PhoneNumberKit",
    )
