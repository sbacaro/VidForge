// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VidForge",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "VidForge", targets: ["VidForge"])
    ],
    targets: [
        .executableTarget(
            name: "VidForge",
            path: "Sources/VidForge"
        )
    ]
)
