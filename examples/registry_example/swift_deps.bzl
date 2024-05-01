load("@rules_swift_package_manager//swiftpkg:defs.bzl", "swift_registry_package")

def swift_dependencies():
    swift_registry_package(
        name = "swiftpkg_apple.swift_collections",
        dependencies_index = "@//:swift_packages_index.json",
        id = "apple.swift-collections",
        version = "1.1.0",
    )
