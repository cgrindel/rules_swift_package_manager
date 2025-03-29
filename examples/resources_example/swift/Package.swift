// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "resources_example",
    dependencies: [
        .package(path: "../third_party/another_package_with_resources"),
        .package(path: "../third_party/app_lovin_sdk"),
        .package(path: "../third_party/package_with_resources"),
        .package(path: "../third_party/package_with_resources_swift_6"),
        .package(url: "https://github.com/Iterable/swift-sdk", from: "6.5.11"),
        .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI.git", from: "3.1.3"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "8.0.0"),
        .package(
            url: "https://github.com/GoogleCloudPlatform/recaptcha-enterprise-mobile-sdk",
            from: "18.7.0"
        ),
    ]
)
