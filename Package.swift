// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "langSwitch",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "LangSwitcher",
            path: "Sources/LangSwitcher",
            exclude: ["Info.plist"],
            resources: [
                .process("Assets.xcassets"),
                .copy("AppIcon.icon")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/LangSwitcher/Info.plist"
                ])
            ]
        ),
        .testTarget(
            name: "LangSwitcherTests",
            dependencies: ["LangSwitcher"]
        ),
    ]
)
