// swift-tools-version: 5.9
// iOS + macOS shared implementation of the xue_hua_audio plugin.
// xue_hua_audio 插件的 iOS 与 macOS 共享实现。

import PackageDescription

let package = Package(
    name: "xue_hua_audio_darwin",
    platforms: [
        .iOS("13.0"),
        .macOS("10.15"),
    ],
    products: [
        .library(name: "xue-hua-audio-darwin", targets: ["xue_hua_audio_darwin"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "xue_hua_audio_darwin",
            dependencies: [],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
