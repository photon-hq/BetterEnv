import Foundation

/// Runtime provider management for BetterEnv.
///
/// Thread-safe storage for providers with async access for fetching values.
public final class BetterEnvRuntime: @unchecked Sendable {
    /// Shared singleton instance
    public static let shared = BetterEnvRuntime()
    
    private var providers: [any BetterEnvProvider] = []
    private let lock = NSLock()
    
    private init() {}
    
    /// Add a provider to the runtime.
    /// Providers are queried in order: first added = highest priority.
    /// - Parameter provider: The provider to add
    public func addProvider(_ provider: any BetterEnvProvider) {
        lock.lock()
        defer { lock.unlock() }
        providers.append(provider)
    }
    
    /// Remove all providers.
    public func removeAllProviders() {
        lock.lock()
        defer { lock.unlock() }
        providers.removeAll()
    }
    
    /// Get a provider by type.
    /// - Parameter type: The provider type to find
    /// - Returns: The provider if found, nil otherwise
    public func getProvider<T: BetterEnvProvider>(_ type: T.Type) -> T? {
        lock.withLock {
            providers.first { $0 is T } as? T
        }
    }
    
    /// Get a value from providers only.
    /// - Parameter key: The environment variable name
    /// - Returns: The value if found in any provider, nil otherwise
    public func getFromProviders(_ key: String) async throws -> String? {
        let currentProviders = lock.withLock { providers }
        for provider in currentProviders {
            if let value = try await provider.get(key) {
                return value
            }
        }
        return nil
    }
    
    /// Get all values from all providers, merged.
    /// Earlier providers take precedence over later ones.
    /// - Returns: Merged dictionary of all provider values
    public func getAllFromProviders() async throws -> [String: String] {
        let currentProviders = lock.withLock { providers }
        var result: [String: String] = [:]
        
        // Iterate in reverse so earlier providers override later ones
        for provider in currentProviders.reversed() {
            let values = try await provider.getAll()
            for (key, value) in values {
                result[key] = value
            }
        }
        
        return result
    }
    
    /// Check if any providers are registered.
    public var hasProviders: Bool {
        lock.withLock { !providers.isEmpty }
    }
}
