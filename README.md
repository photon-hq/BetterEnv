# BetterEnv

A Swift Package Manager build tool plugin that embeds environment variables at compile time, similar to Rust's `env!()` macro or `dotenv!()`.

## Features

- **Compile-time embedding**: Reads `.env` files during build and generates Swift code
- **Runtime fallback**: Falls back to `ProcessInfo.processInfo.environment` if not found at compile time
- **Variable substitution**: Supports `${VAR}` syntax in `.env` files
- **Multiple env files**: Supports `.env`, `.env.local`, `.env.development`, `.env.production`
- **Type-safe access**: Use `BetterEnv["KEY"]` with subscript syntax
- **Provider support**: Fetch secrets at runtime from external sources (e.g., Infisical)

## Installation

Add BetterEnv to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/BetterEnv.git", from: "1.0.0")
]
```

Apply the plugin to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "BetterEnvCore", package: "BetterEnv"),
        // Add if using Infisical:
        .product(name: "BetterEnvInfisical", package: "BetterEnv"),
    ],
    plugins: [.plugin(name: "BetterEnvPlugin", package: "BetterEnv")]
)
```

## Usage

### Create a `.env` file

Create a `.env` file in your package root (same directory as `Package.swift`):

```env
API_KEY=your_secret_key
API_URL=https://api.example.com
DEBUG=true
```

### Access environment variables

```swift
// Subscript access (Compile → Runtime, fatalError if not found)
let apiKey = BetterEnv["API_KEY"]                  // String

// Compile-time values (from .env files)
let apiKey = BetterEnv.compile.get("API_KEY")      // String?
let all = BetterEnv.compile.getAll()               // [String: String]
let exists = BetterEnv.compile.has("API_KEY")      // Bool

// Runtime values (from ProcessInfo)
let path = BetterEnv.runtime.get("PATH")           // String?
let all = BetterEnv.runtime.getAll()               // [String: String]
let exists = BetterEnv.runtime.has("PATH")         // Bool

// Provider values (type-specific)
let secret = try await BetterEnv.provider(InfisicalProvider.self).get("DB_PASSWORD")  // String?
let all = try await BetterEnv.provider(InfisicalProvider.self).getAll()               // [String: String]

// Combined access (All Providers → Compile → Runtime)
let value = try await BetterEnv.get("KEY")         // String?
let all = try await BetterEnv.getAll()             // [String: String]
let exists = try await BetterEnv.has("KEY")        // Bool
```

### Variable Substitution

You can reference other variables using `${VAR}` syntax:

```env
BASE_URL=https://api.example.com
FULL_URL=${BASE_URL}/v1/users

# Reference system environment variables
HOME_PATH=${HOME}
```

### Multiple Environment Files

BetterEnv reads these files in order (later files override earlier ones):

1. `.env` - Base configuration
2. `.env.local` - Local overrides (add to .gitignore)
3. `.env.development` - Development environment
4. `.env.production` - Production environment

## How It Works

1. **Build Time**: The `BetterEnvPlugin` runs during the build process
2. **Generation**: It reads your `.env` files and generates a `BetterEnv.swift` file with all values embedded
3. **Compilation**: The generated code is compiled into your module
4. **Runtime**: `BetterEnv["KEY"]` first checks the compiled values, then falls back to runtime environment

This means:
- Secrets from `.env` files are embedded in your binary at compile time
- You can override values at runtime via system environment variables
- Missing keys cause a `fatalError` with a helpful message

## IDE / Linting Support

Since the `BetterEnv` enum is generated at build time, your IDE may show errors until the first build completes. After running `swift build` once, the generated file exists and IDE features will work.

## Providers

Providers allow you to fetch secrets at runtime from external sources. This is useful when credentials are only available at runtime.

### File Provider

Read environment variables from a specific `.env` file at runtime.

```swift
import BetterEnvCore

// Absolute path
BetterEnv.addProvider(FileProvider(path: "/path/to/.env.production"))

// Relative to current directory
BetterEnv.addProvider(FileProvider.relative(".env.secrets"))

// Access
let secret = try await BetterEnv.provider(FileProvider.self).get("API_KEY")
```

### Infisical Provider

Fetch secrets from [Infisical](https://infisical.com) using Universal Auth.

```swift
import BetterEnvInfisical

// Register provider at app startup
BetterEnv.addProvider(InfisicalProvider(
    url: "https://your-infisical-instance.com",
    clientId: clientId,
    clientSecret: clientSecret,
    project: "your-project-id",
    environment: "prod",
    secretPath: "/"  // optional, defaults to "/"
))

// Fetch from this specific provider
let dbPassword = try await BetterEnv.provider(InfisicalProvider.self).get("DB_PASSWORD")

// Fetch from all sources (All Providers → Compile → Runtime)
let dbPassword = try await BetterEnv.get("DB_PASSWORD")
```

### Custom Providers

Implement the `BetterEnvProvider` protocol to add your own secret sources:

```swift
import BetterEnvCore

public struct MyProvider: BetterEnvProvider {
    public func get(_ key: String) async throws -> String? {
        // Fetch from your secret manager
    }
    
    public func getAll() async throws -> [String: String] {
        // Fetch all secrets
    }
}

// Register
BetterEnv.addProvider(MyProvider())

// Access
let value = try await BetterEnv.provider(MyProvider.self).get("KEY")
```

### API Summary

| Namespace | Methods | Async |
|-----------|---------|-------|
| `BetterEnv[key]` | subscript | No (Compile → Runtime) |
| `BetterEnv.compile` | `get`, `getAll`, `has` | No |
| `BetterEnv.runtime` | `get`, `getAll`, `has` | No |
| `BetterEnv.provider(T.self)` | `get`, `getAll` | Yes |
| `BetterEnv` | `get`, `getAll`, `has`, `addProvider`, `removeAllProviders` | Yes (get/getAll/has) |

## Security Note

Environment variables from `.env` files are embedded in your compiled binary. Make sure to:

- Add `.env.local` and sensitive `.env` files to `.gitignore`
- Never commit secrets to version control
- Use runtime environment variables or providers for production secrets

## License

MIT (Photon)
