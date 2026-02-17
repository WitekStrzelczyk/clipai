// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipAI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ClipAI", targets: ["ClipAI"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "ClipAI",
            dependencies: []
        ),
        .testTarget(
            name: "ClipAITests",
            dependencies: ["ClipAI"]
        )
    ]
)
