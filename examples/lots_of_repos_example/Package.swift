// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "lots_of_repos_example",
    platforms: [
        .iOS(.v13),
        .macOS(.v13),
    ],
    dependencies: [
        .package(url: "https://github.com/a7ex/xcresultparser", .upToNextMajor(from: "1.5.2")),
        .package(url: "https://github.com/adyen/adyen-ios", exact: "4.13.0"),
        .package(url: "https://github.com/adyen/adyen-networking-ios", exact: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.3.1")),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.0.4"),
        .package(url: "https://github.com/apple/swift-collections", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/apple/swift-log", .upToNextMajor(from: "1.5.0")),
        .package(url: "https://github.com/AppsFlyerSDK/AppsFlyerFramework", .upToNextMinor(from: "6.11.2")),
        .package(url: "https://github.com/Bouke/Glob", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/CoreOffice/XMLCoder.git", .upToNextMajor(from: "0.17.0")),
        .package(url: "https://github.com/DataDog/dd-sdk-ios", .upToNextMinor(from: "2.13.0")),
        .package(url: "https://github.com/erikdoe/ocmock", .upToNextMajor(from: "3.8.1")),
        .package(url: "https://github.com/kean/Nuke", .upToNextMinor(from: "12.8.0")),
        .package(url: "https://github.com/mattgallagher/CwlCatchException", .upToNextMajor(from: "2.0.0")),
        .package(url: "https://github.com/mw99/DataCompression", .upToNextMajor(from: "3.8.0")),
        .package(url: "https://github.com/plaid/plaid-link-ios", .upToNextMinor(from: "4.3.1")),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.2.1"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-perception", from: "1.1.3"),
        .package(url: "https://github.com/pointfreeco/swift-url-routing", from: "0.6.0"),
        .package(url: "https://github.com/ReactiveX/RxSwift", exact: "6.6.0"),
        .package(url: "https://github.com/square/FetchRequests", exact: "6.1.0"),
        .package(url: "https://github.com/square/Listable", exact: "14.4.0"),
        .package(url: "https://github.com/square/Paralayout", .upToNextMinor(from: "1.0.0")),
        .package(url: "https://github.com/square/workflow-swift", from: "3.11.0"),
        .package(url: "https://github.com/stripe/stripe-ios", .upToNextMinor(from: "23.26.0")),
    ]
)
