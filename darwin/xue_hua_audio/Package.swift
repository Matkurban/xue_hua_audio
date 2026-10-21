// swift-tools-version: 5.9
// iOS + macOS shared implementation of the xue_hua_audio plugin.
// xue_hua_audio 插件的 iOS 与 macOS 共享实现。

import PackageDescription

let package = Package(
    name: "xue_hua_audio",
    platforms: [
        .iOS("13.0"),
        .macOS("10.15"),
    ],
    products: [
        .library(name: "xue-hua-audio", targets: ["xue_hua_audio"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "xue_hua_audio",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
