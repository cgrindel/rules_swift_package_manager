// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "resources_example",
    dependencies: [
        .package(path: "third_party/another_package_with_resources"),
        .package(path: "third_party/app_lovin_sdk"),
        .package(path: "third_party/package_with_resources"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "7.0.0"),
        .package(url: "https://github.com/Datadog/dd-sdk-ios.git", exact: "2.5.0"),
    ]
)
