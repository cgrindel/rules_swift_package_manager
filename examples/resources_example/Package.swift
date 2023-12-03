// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "resources_example",
    dependencies: [
        .package(path: "third_party/package_with_resources"),
        .package(path: "third_party/another_package_with_resources"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "7.0.0"),
        // .package(url: "https://github.com/AppLovin/AppLovin-MAX-Swift-Package.git", from: "12.0.0"),
        // .package(path: "/Users/chuck/code/cgrindel/AppLovin-MAX-Swift-Package/fix_init_return"),
        .package(path: "third_party/app_lovin_sdk"),
    ]
)
