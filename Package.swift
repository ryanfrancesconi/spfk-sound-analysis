// swift-tools-version: 6.2
// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi

import PackageDescription

let package = Package(
    name: "spfk-classification",
    defaultLocalization: "en",
    platforms: [.macOS(.v13), .iOS(.v16),],
    products: [
        .library(
            name: "SPFKClassification",
            targets: ["SPFKClassification",]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ryanfrancesconi/spfk-base", from: "1.2.3"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-video", from: "1.3.0"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-audio-base", from: "1.6.1"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-testing", from: "1.1.1"),
    ],
    targets: [
        .target(
            name: "SPFKClassification",
            dependencies: [
                .product(name: "SPFKBase", package: "spfk-base"),
                .product(name: "SPFKVideo", package: "spfk-video"),
            ]
        ),
        .testTarget(
            name: "SPFKClassificationTests",
            dependencies: [
                .targetItem(name: "SPFKClassification", condition: nil),
                .product(name: "SPFKAudioBase", package: "spfk-audio-base"),
                .product(name: "SPFKTesting", package: "spfk-testing"),
            ]
        ),
    ]
)
