// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Smock",
    platforms: [.macOS(.v14), .iOS(.v16), .tvOS(.v13), .watchOS(.v4), .macCatalyst(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Smock",
            targets: ["Smock"]
        ),
        .library(
            name: "SmockTestSupport",
            targets: ["SmockTestSupport"]
        ),
//        .executable(
//            name: "SmockClient",
//            targets: ["SmockClient"]
//        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.0-latest"),
        // Backport of Synchronization.Mutex from Swift 6+
        .package(url: "https://github.com/swhitty/swift-mutex.git", .upToNextMajor(from: "0.0.5"))
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        // Macro implementation that performs the source transformation of a macro.
        .macro(
            name: "SmockMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),

        // Library that exposes a macro as part of its API, which is used in client programs.
        .target(
            name: "Smock",
            dependencies: [
                "SmockMacros",
                .productItem(name: "Mutex", package: "swift-mutex", moduleAliases: nil, condition: nil)
            ]
        ),

        .target(name: "SmockTestSupport", dependencies: ["Smock"]),

        // A client of the library, which is able to use the macro in its own code.
        .executableTarget(name: "SmockClient", dependencies: ["Smock"]),

        // A test target used to develop the macro implementation.
        .testTarget(
            name: "SmockMacroTests",
            dependencies: [
                "SmockMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),

        .testTarget(
            name: "SmockTests",
            dependencies: ["Smock", "SmockTestSupport"]
        ),
    ],
//    swiftLanguageModes: [.v6] // swift-tools-version 6+
)
