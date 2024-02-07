// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "firebase_example",
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", .upToNextMajor(from: "10.21.0")),
        // Used by crashlytics example
        .package(url: "https://github.com/ashleymills/Reachability.swift.git", .upToNextMajor(from: "5.2.0")),
    ]
)
