// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Logdeck",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "LogdeckCore", targets: ["LogdeckCore"]),
        .executable(name: "Logdeck", targets: ["Logdeck"])
    ],
    targets: [
        .target(name: "LogdeckCore"),
        .executableTarget(
            name: "Logdeck",
            dependencies: [
                "LogdeckCore"
            ]
        ),
        .testTarget(
            name: "LogdeckCoreTests",
            dependencies: ["LogdeckCore"]
        )
    ]
)
