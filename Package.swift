// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "DiagnosticSDK",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "DiagnosticSDK",
            targets: ["DiagnosticSDK"]
        )
    ],
    dependencies: [],
    targets: [
            // 1. The Objective-C module
            .target(
                name: "DiagnosticSDKObjC",
                dependencies: [],
                publicHeadersPath: "include" // ⚠️ ESSENTIAL: exposes the .h files to Swift
            ),
            // 2. The Swift module
            .target(
                name: "DiagnosticSDK",
                dependencies: ["DiagnosticSDKObjC"] // ⚠️ THE MAGIC LINE: links the Swift target to the Obj-C target
            )
        ]
)