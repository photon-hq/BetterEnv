# BetterEnv

A Swift Package Manager build tool plugin that embeds environment variables at compile time, similar to Rust's `env!()` macro or `dotenv!()`.

## Features

- **Compile-time embedding**: Reads `.env` files during build and generates Swift code
- **Runtime fallback**: Falls back to compiled values if not found in runtime environment
- **Variable substitution**: Supports `${VAR}` syntax in `.env` files
- **Multiple env files**: Supports `.env`, `.env.local`, `.env.development`, `.env.production`
- **Type-safe access**: Use `BetterEnv["KEY"]` with subscript syntax
- **Provider support**: Fetch secrets at runtime from external sources (e.g., Infisical)

## Installation

Add BetterEnv to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/BetterEnv.git", from: "2.0.0")
]
```

Apply the plugin to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        // Required for providers (FileProvider, etc.)
        .product(name: "BetterEnvCore", package: "BetterEnv"),
        // Only if using Infisical:
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

# "export" prefix is also supported (for shell compatibility)
export SECRET_KEY=your_other_key
```

### Access environment variables

```swift
// Subscript access (Runtime → Compile, returns nil if not found)
let apiKey = BetterEnv["API_KEY"]                  // String?

// Compile-time values (from .env files)
let apiKey = BetterEnv.compile.API_KEY             // String (generated property)
let apiKey = BetterEnv.compile.get("API_KEY")      // String?
let all = BetterEnv.compile.getAll()               // [String: String]
let exists = BetterEnv.compile.has("API_KEY")      // Bool

// Runtime values (from ProcessInfo)
let path = BetterEnv.runtime.get("PATH")           // String?
let all = BetterEnv.runtime.getAll()               // [String: String]
let exists = BetterEnv.runtime.has("PATH")         // Bool

// Sync provider values (e.g., FileProvider)
let secret = try BetterEnv.provider(FileProvider.self).get("API_KEY")            // String?
let all = try BetterEnv.provider(FileProvider.self).getAll()                     // [String: String]

// Async provider values (e.g., InfisicalProvider)
let secret = try await BetterEnv.provider(InfisicalProvider.self).get("SECRET")  // String?
let all = try await BetterEnv.provider(InfisicalProvider.self).getAll()          // [String: String]

// Combined access (Providers → Runtime → Compile)
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
4. **Runtime**: `BetterEnv["KEY"]` first checks runtime environment, then falls back to compiled values

This means:
- Secrets from `.env` files are embedded in your binary at compile time
- You can override compiled values at runtime via system environment variables
- Missing keys return `nil` for safe handling

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

// Access (sync — no await needed)
let secret = try BetterEnv.provider(FileProvider.self).get("API_KEY")
```

### Infisical Provider

Fetch secrets from [Infisical](https://infisical.com) using Universal Auth.

```swift
import BetterEnvInfisical

// Register async provider at app startup
BetterEnv.addAsyncProvider(InfisicalProvider(
    url: "https://your-infisical-instance.com",
    clientId: clientId,
    clientSecret: clientSecret,
    project: "your-project-id",
    environment: "prod",
    secretPath: "/"  // optional, defaults to "/"
))

// Fetch from this specific provider
let dbPassword = try await BetterEnv.provider(InfisicalProvider.self).get("DB_PASSWORD")

// Fetch from all sources (Providers → Runtime → Compile)
let dbPassword = try await BetterEnv.get("DB_PASSWORD")
```

### Custom Providers

Implement `BetterEnvProvider` for sync sources or `BetterEnvAsyncProvider` for async sources:

```swift
import BetterEnvCore

// Sync provider (local sources)
public struct MyFileProvider: BetterEnvProvider {
    public func get(_ key: String) throws -> String? {
        // Fetch from local source
    }

    public func getAll() throws -> [String: String] {
        // Fetch all values
    }
}

BetterEnv.addProvider(MyFileProvider())
let value = try BetterEnv.provider(MyFileProvider.self).get("KEY")

// Async provider (remote sources)
public actor MyRemoteProvider: BetterEnvAsyncProvider {
    public func get(_ key: String) async throws -> String? {
        // Fetch from remote secret manager
    }

    public func getAll() async throws -> [String: String] {
        // Fetch all secrets
    }
}

BetterEnv.addAsyncProvider(MyRemoteProvider())
let value = try await BetterEnv.provider(MyRemoteProvider.self).get("KEY")
```

### API Summary

| Namespace | Methods | Async | Resolution |
|-----------|---------|-------|------------|
| `BetterEnv[key]` | subscript | No | Runtime → Compile |
| `BetterEnv.compile` | `KEY`, `get`, `getAll`, `has` | No | Compile only |
| `BetterEnv.runtime` | `get`, `getAll`, `has` | No | Runtime only |
| `BetterEnv.provider(T.self)` | `get`, `getAll` | Sync or Async | Provider only |
| `BetterEnv` | `get`, `getAll`, `has` | Yes | Providers → Runtime → Compile |
| `BetterEnv` | `addProvider`, `addAsyncProvider`, `removeAllProviders` | No | — |

## Security Note

Environment variables from `.env` files are embedded in your compiled binary. Make sure to:

- Add `.env.local` and sensitive `.env` files to `.gitignore`
- Never commit secrets to version control
- Use runtime environment variables or providers for production secrets

## License

MIT (Photon)
