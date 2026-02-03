import Foundation

/// A protocol for environment variable providers that can fetch values asynchronously.
///
/// Providers are queried in the order they are added, and the first non-nil value wins.
/// Implement this protocol to add custom sources for environment variables,
/// such as remote secret managers (Infisical, Vault, AWS Secrets Manager, etc.).
public protocol BetterEnvProvider: Sendable {
    /// Fetch a single environment variable by key.
    /// - Parameter key: The environment variable name
    /// - Returns: The value if found, nil otherwise
    func get(_ key: String) async throws -> String?
    
    /// Fetch all available environment variables from this provider.
    /// - Returns: A dictionary of all key-value pairs
    func getAll() async throws -> [String: String]
}
