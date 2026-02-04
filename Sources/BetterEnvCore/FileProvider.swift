import Foundation

/// A provider that reads environment variables from a specific .env file at runtime.
public struct FileProvider: BetterEnvProvider, Sendable {
    private let path: String
    
    /// Create a file provider.
    /// - Parameter path: The path to the .env file
    public init(path: String) {
        self.path = path
    }
    
    /// Create a file provider with a path relative to the current directory.
    /// - Parameter relativePath: The relative path to the .env file
    public static func relative(_ relativePath: String) -> FileProvider {
        let currentDir = FileManager.default.currentDirectoryPath
        let fullPath = (currentDir as NSString).appendingPathComponent(relativePath)
        return FileProvider(path: fullPath)
    }
    
    public func get(_ key: String) async throws -> String? {
        let env = try parseEnvFile()
        return env[key]
    }
    
    public func getAll() async throws -> [String: String] {
        return try parseEnvFile()
    }
    
    // MARK: - Private
    
    private func parseEnvFile() throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: path) else {
            throw FileProviderError.fileNotFound(path: path)
        }
        
        let content = try String(contentsOfFile: path, encoding: .utf8)
        var result: [String: String] = [:]
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            
            // Parse KEY=VALUE
            guard let equalIndex = trimmed.firstIndex(of: "=") else {
                continue
            }
            
            let key = String(trimmed[..<equalIndex]).trimmingCharacters(in: .whitespaces)
            var value = String(trimmed[trimmed.index(after: equalIndex)...]).trimmingCharacters(in: .whitespaces)
            
            // Remove surrounding quotes if present
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            
            // Handle variable substitution ${VAR}
            value = substituteVariables(in: value, environment: result)
            
            guard !key.isEmpty else {
                continue
            }
            
            result[key] = value
        }
        
        return result
    }
    
    private func substituteVariables(in value: String, environment: [String: String]) -> String {
        var result = value
        let pattern = "\\$\\{([^}]+)\\}"
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return value
        }
        
        let matches = regex.matches(in: value, range: NSRange(value.startIndex..., in: value))
        
        for match in matches.reversed() {
            guard let varRange = Range(match.range(at: 1), in: value),
                  let fullRange = Range(match.range, in: value) else {
                continue
            }
            
            let varName = String(value[varRange])
            let replacement = environment[varName]
                ?? ProcessInfo.processInfo.environment[varName]
                ?? ""
            
            result = result.replacingCharacters(in: fullRange, with: replacement)
        }
        
        return result
    }
}

// MARK: - Errors

public enum FileProviderError: Error, LocalizedError {
    case fileNotFound(path: String)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Environment file not found: \(path)"
        }
    }
}
