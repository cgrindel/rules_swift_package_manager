// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "google_maps_example",
    dependencies: [
        .package(url: "https://github.com/googlemaps/ios-maps-sdk", from: "10.4.0"),
    ]
)
