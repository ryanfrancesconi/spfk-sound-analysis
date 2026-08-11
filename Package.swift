// swift-tools-version: 6.2
// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi

import PackageDescription

let package = Package(
    name: "spfk-sound-analysis",
    defaultLocalization: "en",
    platforms: [.macOS(.v13), .iOS(.v16),],
    products: [
        .library(
            name: "SPFKSoundAnalysis",
            targets: ["SPFKSoundAnalysis",]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ryanfrancesconi/spfk-base", from: "1.2.2"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-audio-base", from: "1.6.1"),
        .package(url: "https://github.com/ryanfrancesconi/spfk-testing", from: "1.1.0"),
    ],
    targets: [
        .target(
            name: "SPFKSoundAnalysis",
            dependencies: [
                .product(name: "SPFKBase", package: "spfk-base"),
            ]
        ),
        .testTarget(
            name: "SPFKSoundAnalysisTests",
            dependencies: [
                .targetItem(name: "SPFKSoundAnalysis", condition: nil),
                .product(name: "SPFKAudioBase", package: "spfk-audio-base"),
                .product(name: "SPFKTesting", package: "spfk-testing"),
            ]
        ),
    ]
)
