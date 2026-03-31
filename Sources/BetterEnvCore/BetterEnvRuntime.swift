import Foundation

/// Runtime provider management for BetterEnv.
///
/// Thread-safe storage for providers with sync and async access for fetching values.
public final class BetterEnvRuntime: @unchecked Sendable {
    /// Shared singleton instance
    public static let shared = BetterEnvRuntime()

    private var syncProviders: [any BetterEnvProvider] = []
    private var asyncProviders: [any BetterEnvAsyncProvider] = []
    private let lock = NSLock()

    private init() {}

    // MARK: - Sync Providers

    /// Add a sync provider to the runtime.
    /// Providers are queried in order: first added = highest priority.
    /// - Parameter provider: The provider to add
    public func addProvider(_ provider: any BetterEnvProvider) {
        lock.lock()
        defer { lock.unlock() }
        syncProviders.append(provider)
    }

    /// Get a sync provider by type.
    /// - Parameter type: The provider type to find
    /// - Returns: The provider if found, nil otherwise
    public func getProvider<T: BetterEnvProvider>(_ type: T.Type) -> T? {
        lock.withLock {
            syncProviders.first { $0 is T } as? T
        }
    }

    /// Get a value from sync providers only.
    /// - Parameter key: The environment variable name
    /// - Returns: The value if found in any provider, nil otherwise
    public func getFromProviders(_ key: String) throws -> String? {
        let current = lock.withLock { syncProviders }
        for provider in current {
            if let value = try provider.get(key) {
                return value
            }
        }
        return nil
    }

    /// Get all values from all sync providers, merged.
    /// Earlier providers take precedence over later ones.
    /// - Returns: Merged dictionary of all provider values
    public func getAllFromProviders() throws -> [String: String] {
        let current = lock.withLock { syncProviders }
        var result: [String: String] = [:]
        for provider in current.reversed() {
            let values = try provider.getAll()
            for (key, value) in values {
                result[key] = value
            }
        }
        return result
    }

    // MARK: - Async Providers

    /// Add an async provider to the runtime.
    /// Providers are queried in order: first added = highest priority.
    /// - Parameter provider: The provider to add
    public func addAsyncProvider(_ provider: any BetterEnvAsyncProvider) {
        lock.lock()
        defer { lock.unlock() }
        asyncProviders.append(provider)
    }

    /// Get an async provider by type.
    /// - Parameter type: The provider type to find
    /// - Returns: The provider if found, nil otherwise
    public func getAsyncProvider<T: BetterEnvAsyncProvider>(_ type: T.Type) -> T? {
        lock.withLock {
            asyncProviders.first { $0 is T } as? T
        }
    }

    /// Get a value from async providers only.
    /// - Parameter key: The environment variable name
    /// - Returns: The value if found in any provider, nil otherwise
    public func getFromAsyncProviders(_ key: String) async throws -> String? {
        let current = lock.withLock { asyncProviders }
        for provider in current {
            if let value = try await provider.get(key) {
                return value
            }
        }
        return nil
    }

    /// Get all values from all async providers, merged.
    /// Earlier providers take precedence over later ones.
    /// - Returns: Merged dictionary of all provider values
    public func getAllFromAsyncProviders() async throws -> [String: String] {
        let current = lock.withLock { asyncProviders }
        var result: [String: String] = [:]
        for provider in current.reversed() {
            let values = try await provider.getAll()
            for (key, value) in values {
                result[key] = value
            }
        }
        return result
    }

    // MARK: - Combined

    /// Get a value from all providers (sync first, then async).
    /// - Parameter key: The environment variable name
    /// - Returns: The value if found in any provider, nil otherwise
    public func getFromAllProviders(_ key: String) async throws -> String? {
        if let value = try getFromProviders(key) {
            return value
        }
        return try await getFromAsyncProviders(key)
    }

    /// Get all values from all providers (sync and async), merged.
    /// Sync providers take precedence over async providers.
    /// - Returns: Merged dictionary of all provider values
    public func getAllFromAllProviders() async throws -> [String: String] {
        var result = try await getAllFromAsyncProviders()
        for (key, value) in try getAllFromProviders() {
            result[key] = value
        }
        return result
    }

    // MARK: - Management

    /// Remove all registered providers (both sync and async).
    public func removeAllProviders() {
        lock.lock()
        defer { lock.unlock() }
        syncProviders.removeAll()
        asyncProviders.removeAll()
    }

    /// Check if any providers are registered.
    public var hasProviders: Bool {
        lock.withLock { !syncProviders.isEmpty || !asyncProviders.isEmpty }
    }
}
