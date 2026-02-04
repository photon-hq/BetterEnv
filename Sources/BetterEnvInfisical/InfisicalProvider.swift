import Foundation
import BetterEnvCore

/// A provider that fetches secrets from Infisical using Universal Auth.
public actor InfisicalProvider: BetterEnvProvider {
    private let url: String
    private let clientId: String
    private let clientSecret: String
    private let project: String
    private let environment: String
    private let secretPath: String
    
    private var accessToken: String?
    private var tokenExpiry: Date?
    
    /// Cache for secrets
    private var cache: [String: String]?
    private var cacheExpiry: Date?
    
    /// How long to cache secrets (default: 5 minutes)
    public var cacheTTL: TimeInterval = 300
    
    /// Create an Infisical provider.
    /// - Parameters:
    ///   - url: The Infisical API URL (e.g., "https://app.infisical.com" or your self-hosted URL)
    ///   - clientId: The Universal Auth client ID
    ///   - clientSecret: The Universal Auth client secret
    ///   - project: The project ID to fetch secrets from
    ///   - environment: The environment slug (e.g., "dev", "staging", "prod")
    ///   - secretPath: The secret path (default: "/")
    public init(
        url: String,
        clientId: String,
        clientSecret: String,
        project: String,
        environment: String,
        secretPath: String = "/"
    ) {
        self.url = url.hasSuffix("/") ? String(url.dropLast()) : url
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.project = project
        self.environment = environment
        self.secretPath = secretPath
    }
    
    /// Fetch a single secret by key.
    public func get(_ key: String) async throws -> String? {
        let secrets = try await fetchSecretsIfNeeded()
        return secrets[key]
    }
    
    /// Fetch all secrets.
    public func getAll() async throws -> [String: String] {
        return try await fetchSecretsIfNeeded()
    }
    
    /// Clear the cache, forcing a refresh on next access.
    public func clearCache() {
        cache = nil
        cacheExpiry = nil
    }
    
    /// Force refresh the token.
    public func refreshToken() async throws {
        accessToken = nil
        tokenExpiry = nil
        _ = try await getAccessToken()
    }
    
    // MARK: - Private
    
    private func fetchSecretsIfNeeded() async throws -> [String: String] {
        // Return cached if valid
        if let cache = cache, let expiry = cacheExpiry, Date() < expiry {
            return cache
        }
        
        // Fetch fresh
        let secrets = try await fetchSecrets()
        self.cache = secrets
        self.cacheExpiry = Date().addingTimeInterval(cacheTTL)
        return secrets
    }
    
    private func getAccessToken() async throws -> String {
        // Return cached token if valid
        if let token = accessToken, let expiry = tokenExpiry, Date() < expiry {
            return token
        }
        
        // Authenticate
        let token = try await authenticate()
        return token
    }
    
    private func authenticate() async throws -> String {
        let loginURL = URL(string: "\(url)/api/v1/auth/universal-auth/login")!
        
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "clientId=\(urlEncode(clientId))&clientSecret=\(urlEncode(clientSecret))"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw InfisicalError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw InfisicalError.authenticationFailed(statusCode: httpResponse.statusCode, message: message)
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        
        self.accessToken = authResponse.accessToken
        // Set expiry a bit early to avoid edge cases
        self.tokenExpiry = Date().addingTimeInterval(TimeInterval(authResponse.expiresIn - 60))
        
        return authResponse.accessToken
    }
    
    private func fetchSecrets() async throws -> [String: String] {
        let token = try await getAccessToken()
        
        // Use v3 API for broader compatibility with self-hosted instances
        var components = URLComponents(string: "\(url)/api/v3/secrets/raw")!
        components.queryItems = [
            URLQueryItem(name: "workspaceId", value: project),
            URLQueryItem(name: "environment", value: environment),
            URLQueryItem(name: "secretPath", value: secretPath)
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw InfisicalError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw InfisicalError.fetchFailed(statusCode: httpResponse.statusCode, message: message)
        }
        
        let secretsResponse = try JSONDecoder().decode(SecretsResponse.self, from: data)
        
        var result: [String: String] = [:]
        for secret in secretsResponse.secrets {
            result[secret.secretKey] = secret.secretValue
        }
        
        return result
    }
    
    private func urlEncode(_ string: String) -> String {
        return string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }
}

// MARK: - Response Types

private struct AuthResponse: Decodable {
    let accessToken: String
    let expiresIn: Int
    let tokenType: String
}

private struct SecretsResponse: Decodable {
    let secrets: [Secret]
}

private struct Secret: Decodable {
    let secretKey: String
    let secretValue: String
}

// MARK: - Errors

public enum InfisicalError: Error, LocalizedError {
    case invalidResponse
    case authenticationFailed(statusCode: Int, message: String)
    case fetchFailed(statusCode: Int, message: String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Infisical API"
        case .authenticationFailed(let code, let message):
            return "Infisical authentication failed (\(code)): \(message)"
        case .fetchFailed(let code, let message):
            return "Failed to fetch secrets from Infisical (\(code)): \(message)"
        }
    }
}
