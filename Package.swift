// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VidForge",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "vidforge", targets: ["vidforge"]),
        .executable(name: "vidforge-ui-server", targets: ["vidforge-ui-server"])
    ],
    targets: [
        .executableTarget(
            name: "vidforge",
            path: "CLI",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "vidforge-ui-server",
            path: "UIServer"
        )
    ]
)
