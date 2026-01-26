// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BetterEnv",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        // The plugin that consumers apply to their targets
        .plugin(
            name: "BetterEnvPlugin",
            targets: ["BetterEnvPlugin"]
        )
    ],
    targets: [
        // Build tool plugin that generates the entire BetterEnv enum
        .plugin(
            name: "BetterEnvPlugin",
            capability: .buildTool(),
            dependencies: ["BetterEnvGenerator"]
        ),

        // Executable that reads .env files and generates Swift code
        .executableTarget(
            name: "BetterEnvGenerator"
        ),

        // Tests - applies the plugin to test the generated code
        .testTarget(
            name: "BetterEnvTests",
            plugins: [.plugin(name: "BetterEnvPlugin")]
        )
    ]
)
