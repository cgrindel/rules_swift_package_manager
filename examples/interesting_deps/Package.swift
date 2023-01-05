// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "MySwiftPackage",
    dependencies: [
        .package(url: "https://github.com/apple/swift-log", from: "1.4.4"),
        // .package(url: "https://github.com/SDWebImage/libwebp-Xcode.git", from: "1.2.1"),
        .package(path: "/Users/chuck/code/cgrindel/libwebp-Xcode/cg/add_5_5_manifest"),
    ]
)
