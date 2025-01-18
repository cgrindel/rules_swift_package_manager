// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "stripe_example",
    dependencies: [
        .package(
            url: "https://github.com/stripe/stripe-ios",
            from: "24.4.0"
        ),
    ]
)
