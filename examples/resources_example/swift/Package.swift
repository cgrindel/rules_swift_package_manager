// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "resources_example",
    dependencies: [
        .package(path: "../third_party/another_package_with_resources"),
        .package(path: "../third_party/app_lovin_sdk"),
        .package(path: "../third_party/package_with_resources"),
        .package(url: "https://github.com/Iterable/swift-sdk", from: "6.5.7"),
        .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI.git", from: "3.1.1"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "7.1.0"),
        .package(
            url: "https://github.com/GoogleCloudPlatform/recaptcha-enterprise-mobile-sdk",
            from: "18.6.0"
        ),
    ]
)
