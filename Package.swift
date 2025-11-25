// swift-tools-version: 6.2.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

// Swift target
private let name: String = "SPFKSoundAnalysis"
private let dependencyNames: [String] = ["SPFKBase", "SPFKAudioBase", "SPFKTesting"]
private let dependencyBranch = "main"
private let useLocalDependencies: Bool = true
private let platforms: [PackageDescription.SupportedPlatform]? = [
    .macOS(.v12),
    .iOS(.v15),
]


// MARK: - Reusable Code for single package

private let nameTests: String = "\(name)Tests" // Test target
private let githubBase = "https://github.com/ryanfrancesconi"

private let products: [PackageDescription.Product] = [
    .library(
        name: name,
        targets: [name]
    )
]

private var packageDependencies: [PackageDescription.Package.Dependency] {
     let local: [PackageDescription.Package.Dependency] =
        dependencyNames.map {
            .package(name: "\($0)", path: "../\($0)")
        }

        
     let remote: [PackageDescription.Package.Dependency] =
        dependencyNames.map {
            .package(url: "\(githubBase)/\($0)", branch: dependencyBranch)
        }
    
    return useLocalDependencies ? local : remote
}

// is there a Sources/[NAME]/Resources folder?
private var swiftTargetResources: [PackageDescription.Resource]? {
    // package folder
    let root = URL(fileURLWithPath: #file).deletingLastPathComponent()
    
    let dir = root.appending(component: "Sources")
        .appending(component: name)
        .appending(component: "Resources")
    
    let exists = FileManager.default.fileExists(atPath: dir.path)
    
    return exists ? [.process("Resources")] : nil
}

private var swiftTargetDependencies: [PackageDescription.Target.Dependency] {
    let names = dependencyNames.filter { $0 != "SPFKTesting" }
    
    return names.map {
        .byNameItem(name: "\($0)", condition: nil)
    }
}

private let swiftTarget: PackageDescription.Target = .target(
    name: name,
    dependencies: swiftTargetDependencies,
    resources: swiftTargetResources
)

private var testTargetDependencies: [PackageDescription.Target.Dependency] {
    var array: [PackageDescription.Target.Dependency] = [
        .byNameItem(name: name, condition: nil),
    ]

    if dependencyNames.contains("SPFKTesting") {
        array.append(.byNameItem(name: "SPFKTesting", condition: nil))
    }
    
    return array
}

private let testTarget: PackageDescription.Target = .testTarget(
    name: nameTests,
    dependencies: testTargetDependencies
)

private let targets: [PackageDescription.Target] = [
    swiftTarget, testTarget
]

let package = Package(
    name: name,
    defaultLocalization: "en",
    platforms: platforms,
    products: products,
    dependencies: packageDependencies,
    targets: targets,
    cxxLanguageStandard: .cxx20
)

