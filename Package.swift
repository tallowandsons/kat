// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Kat",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Kat",
            path: "Sources/Kat"
        ),
        .testTarget(
            name: "KatTests",
            dependencies: ["Kat"],
            path: "Tests/KatTests"
        )
    ]
)
