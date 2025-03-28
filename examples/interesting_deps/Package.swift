// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "MySwiftPackage",
    dependencies: [
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", from: "3.8.5"),
        .package(url: "https://github.com/GEOSwift/GEOSwift", from: "11.2.0"),
        .package(url: "https://github.com/OpenCombine/OpenCombine", from: "0.14.0"),
        .package(url: "https://github.com/SDWebImage/libwebp-Xcode.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.6.3"),
        .package(url: "https://github.com/erikdoe/ocmock", from: "3.9.4"),
        .package(url: "https://github.com/getyoti/yoti-doc-scan-ios.git", from: "6.0.0"),
        .package(url: "https://github.com/luispadron/swift-package-defines-example", from: "2.0.0"),
    ]
)
