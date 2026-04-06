// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "DiagnosticSDK",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Le produit final livré aux développeurs
        .library(
            name: "DiagnosticSDK",
            targets: ["DiagnosticSDK", "DiagnosticSDKObjC"]),
    ],
    dependencies: [],
    targets: [
        // Target Objective-C (Pour le Swizzling bas niveau)
        .target(
            name: "DiagnosticSDKObjC",
            dependencies: [],
            path: "Sources/DiagnosticSDKObjC",
            publicHeadersPath: "include"
        ),
        // Target Swift Principale
        .target(
            name: "DiagnosticSDK",
            dependencies: ["DiagnosticSDKObjC"],
            path: "Sources/DiagnosticSDK"
        ),
        // Target de Tests
        .testTarget(
            name: "DiagnosticSDKTests",
            dependencies: ["DiagnosticSDK"],
            path: "Tests/DiagnosticSDKTests"
        )
    ]
)