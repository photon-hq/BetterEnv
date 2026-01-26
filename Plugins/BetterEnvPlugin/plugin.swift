import PackagePlugin
import Foundation

@main
struct BetterEnvPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        // Get the generator tool
        let generator = try context.tool(named: "BetterEnvGenerator")

        // Output path for generated Swift file
        let outputDir = context.pluginWorkDirectory
        let outputPath = outputDir.appending(subpath: "BetterEnv.swift")

        // Find .env files in the package root (where Package.swift is)
        let packageDir = context.package.directory

        // Define the env file patterns to look for
        let envPatterns = [
            ".env",
            ".env.local",
            ".env.development",
            ".env.production"
        ]

        // Build input file list for dependency tracking
        var inputFiles: [Path] = []
        for pattern in envPatterns {
            let envPath = packageDir.appending(subpath: pattern)
            if FileManager.default.fileExists(atPath: envPath.string) {
                inputFiles.append(envPath)
            }
        }

        // Build arguments
        var arguments = [
            packageDir.string,
            outputPath.string
        ]
        arguments.append(contentsOf: envPatterns)

        return [
            .buildCommand(
                displayName: "Generate BetterEnv from .env files",
                executable: generator.path,
                arguments: arguments,
                inputFiles: inputFiles,
                outputFiles: [outputPath]
            )
        ]
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension BetterEnvPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        // Get the generator tool
        let generator = try context.tool(named: "BetterEnvGenerator")

        // Output path for generated Swift file
        let outputDir = context.pluginWorkDirectory
        let outputPath = outputDir.appending(subpath: "BetterEnv.swift")

        // For Xcode projects, look for .env files in the project directory
        let projectDir = context.xcodeProject.directory

        // Define the env file patterns to look for
        let envPatterns = [
            ".env",
            ".env.local",
            ".env.development",
            ".env.production"
        ]

        // Build input file list for dependency tracking
        var inputFiles: [Path] = []
        for pattern in envPatterns {
            let envPath = projectDir.appending(subpath: pattern)
            if FileManager.default.fileExists(atPath: envPath.string) {
                inputFiles.append(envPath)
            }
        }

        // Build arguments
        var arguments = [
            projectDir.string,
            outputPath.string
        ]
        arguments.append(contentsOf: envPatterns)

        return [
            .buildCommand(
                displayName: "Generate BetterEnv from .env files",
                executable: generator.path,
                arguments: arguments,
                inputFiles: inputFiles,
                outputFiles: [outputPath]
            )
        ]
    }
}
#endif
