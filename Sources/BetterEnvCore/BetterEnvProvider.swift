import Foundation

/// A protocol for environment variable providers that fetch values synchronously.
///
/// Providers are queried in the order they are added, and the first non-nil value wins.
/// Implement this protocol for local sources like file-based providers.
public protocol BetterEnvProvider: Sendable {
    /// Fetch a single environment variable by key.
    /// - Parameter key: The environment variable name
    /// - Returns: The value if found, nil otherwise
    func get(_ key: String) throws -> String?

    /// Fetch all available environment variables from this provider.
    /// - Returns: A dictionary of all key-value pairs
    func getAll() throws -> [String: String]
}

/// A protocol for environment variable providers that fetch values asynchronously.
///
/// Providers are queried in the order they are added, and the first non-nil value wins.
/// Implement this protocol for remote sources like secret managers (Infisical, Vault, etc.).
public protocol BetterEnvAsyncProvider: Sendable {
    /// Fetch a single environment variable by key.
    /// - Parameter key: The environment variable name
    /// - Returns: The value if found, nil otherwise
    func get(_ key: String) async throws -> String?

    /// Fetch all available environment variables from this provider.
    /// - Returns: A dictionary of all key-value pairs
    func getAll() async throws -> [String: String]
}
