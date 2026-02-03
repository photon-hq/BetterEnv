import Foundation

/// Runtime provider management for BetterEnv.
///
/// This actor manages async providers and provides thread-safe access to environment variables
/// from multiple sources (providers, compiled values, and runtime environment).
public actor BetterEnvRuntime {
    /// Shared singleton instance
    public static let shared = BetterEnvRuntime()
    
    private var providers: [BetterEnvProvider] = []
    
    private init() {}
    
    /// Add a provider to the runtime.
    /// Providers are queried in order: first added = highest priority.
    /// - Parameter provider: The provider to add
    public func addProvider(_ provider: BetterEnvProvider) {
        providers.append(provider)
    }
    
    /// Remove all providers.
    public func removeAllProviders() {
        providers.removeAll()
    }
    
    /// Get a value from providers only.
    /// - Parameter key: The environment variable name
    /// - Returns: The value if found in any provider, nil otherwise
    public func getFromProviders(_ key: String) async throws -> String? {
        for provider in providers {
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
        var result: [String: String] = [:]
        
        // Iterate in reverse so earlier providers override later ones
        for provider in providers.reversed() {
            let values = try await provider.getAll()
            for (key, value) in values {
                result[key] = value
            }
        }
        
        return result
    }
    
    /// Check if any providers are registered.
    public var hasProviders: Bool {
        !providers.isEmpty
    }
}
