// swift-tools-version: 6.2.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// Swift target
private let name: String = "SPFKSoundAnalysis"

private let platforms: [PackageDescription.SupportedPlatform]? = [
    .macOS(.v12),
    .iOS(.v15)
]

private let products: [PackageDescription.Product] = [
    .library(
        name: name,
        targets: [name]
    )
]

private let spmRelease = false

private let local_dependencies: [PackageDescription.Package.Dependency] = [
    .package(name: "SPFKBase", path: "../SPFKBase"),
    .package(name: "SPFKAudioBase", path: "../SPFKAudioBase"),
    .package(name: "SPFKTesting", path: "../SPFKTesting"),
]

private let remote_dependencies: [PackageDescription.Package.Dependency] = [
     .package(url: "https://github.com/ryanfrancesconi/SPFKBase", branch: "main"),
     .package(url: "https://github.com/ryanfrancesconi/SPFKAudioBase", branch: "main"),
     .package(url: "https://github.com/ryanfrancesconi/SPFKTesting", branch: "main"),
]

private var dependencies: [PackageDescription.Package.Dependency] {
    spmRelease ?
        remote_dependencies :
        local_dependencies
}

private let targets: [PackageDescription.Target] = [
    // Swift
    .target(
        name: name,
        dependencies: [
            .byNameItem(name: "SPFKBase", condition: nil),
            .byNameItem(name: "SPFKAudioBase", condition: nil)
        ]
    ),
    
    .testTarget(
        name: "\(name)Tests",
        dependencies: [
            .byNameItem(name: name, condition: nil),
            .byNameItem(name: "SPFKTesting", condition: nil)
        ],
        resources: [
            .process("Resources")
        ]
    )
]

let package = Package(
    name: name,
    defaultLocalization: "en",
    platforms: platforms,
    products: products,
    dependencies: dependencies,
    targets: targets,
    cxxLanguageStandard: .cxx20
)
