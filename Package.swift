// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VidForge",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "vidforge", targets: ["vidforge"]),
        .executable(name: "vidforge-ui-server", targets: ["vidforge-ui-server"]),
        .library(name: "VidForgeCore", targets: ["VidForgeCore"])
    ],
    targets: [
        .target(
            name: "VidForgeCore",
            path: "Shared"
        ),
        .executableTarget(
            name: "vidforge",
            dependencies: ["VidForgeCore"],
            path: "CLI",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "vidforge-ui-server",
            dependencies: ["VidForgeCore"],
            path: "UIServer"
        )
    ]
)
