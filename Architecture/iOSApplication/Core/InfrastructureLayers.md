# Infrastructure Layers

> **Note:** As this is an MVP, the infrastructure layers and their organization may evolve as the project matures.

## Architecture Layers

```
Feature Layer → Domain-Specific Clients → Core Infrastructure Clients → Adapters → Backend
(UserFeature)    (UserClient)            (StorageClient)              (StorageAdapter)  (Firebase)
```

This layered architecture ensures:

1. **Type Safety**: All interfaces between layers use strongly-typed Swift types
2. **Concurrency Safety**: All async operations are properly handled with structured concurrency
3. **Infrastructure Agnosticism**: No backend-specific types leak into the application code
4. **Testability**: Each layer can be tested independently with appropriate mocks
5. **Maintainability**: Changes to one layer don't affect other layers

## Layer Descriptions

### 1. Domain Models

Pure business entities independent of any infrastructure:

- Located in `Core/Domain/Models`
- Fully `Sendable` and `Equatable`
- No infrastructure dependencies
- Example: `User`, `Contact`, `Session`

### 2. Data Transfer Objects (DTOs)

Infrastructure-agnostic data structures for storage/retrieval:

- Located in `Core/Infrastructure/DTOs`
- Generic value types for different data types
- Helper methods for safe type conversion
- Example: `DocumentData`, `StorageValue`

### 3. Mapping Layer

Converts between domain models and DTOs:

- Located in `Core/Infrastructure/Mapping`
- Protocols for mapping operations
- Backend-specific implementations
- Example: `UserMapping`, `ContactMapping`

### 4. Core Infrastructure Clients

Low-level clients for basic infrastructure operations:

- Located in `Core/Infrastructure/Clients`
- Use `@DependencyClient` macro
- Connect to adapter interfaces
- Fully type-safe and concurrency-safe
- Example: `StorageClient`, `AuthClient`, `OfflineClient`

### 5. Domain-Specific Clients

Higher-level clients that use core infrastructure clients:

- Located in `Core/Infrastructure/Clients`
- Use core clients for infrastructure operations
- Implement domain-specific business logic
- No direct adapter dependencies
- Example: `UserClient`, `ContactsClient`

### 6. Dependency Clients

Infrastructure-agnostic clients using TCA's dependency system:

- Located in `Core/Infrastructure/Clients`
- Define operations using domain models and DTOs
- Use `@DependencyClient` macro for client definitions
- Provide default values for non-throwing closures
- No backend-specific types
- Example: `StorageClient`, `AuthClient`

```swift
@DependencyClient
struct AuthClient: Sendable {
    var currentUser: @Sendable () async -> User? = { nil }
    var signIn: @Sendable (String, String) async throws -> User = { _, _ in
        throw AuthError.invalidCredentials
    }
    var signOut: @Sendable () async throws -> Void = { }
    var authStateStream: @Sendable () -> AsyncStream<User?> = {
        AsyncStream { continuation in continuation.finish() }
    }
}

extension AuthClient: DependencyKey {
    static let liveValue: Self = unimplemented("Register a live implementation")
    static let testValue = Self(
        currentUser: { User.mock },
        signIn: { _, _ in User.mock },
        signOut: { },
        authStateStream: {
            AsyncStream { continuation in
                continuation.yield(User.mock)
                continuation.finish()
            }
        }
    )
}

extension DependencyValues {
    var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}
```

### 7. Backend Implementations

Concrete implementations for specific backends:

- Located in `Infrastructure/[Backend]/Adapters`
- Implement adapter interfaces
- Use mappers for type conversion
- Handle backend-specific details
- Example: `FirebaseStorageAdapter`, `FirebaseAuthAdapter`

### 8. Dependency Registration System

A way to register backend implementations as dependency values:

- Located in `Infrastructure/[Backend]/[Backend]Adapter.swift`
- Uses TCA's dependency system to register implementations
- Provides live, test, and preview values for each dependency
- Makes it easy to switch backends or mock dependencies for testing
- Example: `FirebaseAdapter.registerLiveValues()`

```swift
struct FirebaseAdapter {
    static func registerLiveValues() {
        // Register Firebase implementations as live values
        DependencyValues._current[FirebaseAppClient.self] = FirebaseAppClient.liveValue
        DependencyValues._current[FirebaseAuthClient.self] = FirebaseAuthClient.liveValue
        DependencyValues._current[FirestoreClient.self] = FirestoreClient.liveValue
        // Other Firebase clients...
    }

    static func registerTestValues() {
        // Register test implementations
        DependencyValues._current[FirebaseAppClient.self] = FirebaseAppClient.testValue
        DependencyValues._current[FirebaseAuthClient.self] = FirebaseAuthClient.testValue
        DependencyValues._current[FirestoreClient.self] = FirestoreClient.testValue
        // Other Firebase clients...
    }
}
```

## Implementation Examples

### Domain Model (User)

```swift
struct User: Equatable, Sendable, Identifiable {
    let id: String
    var name: String
    var email: String?
    var phoneNumber: String
    var lastCheckedIn: Date?
    var checkInInterval: TimeInterval
    var checkInExpiration: Date
    var profileImageURL: URL?
    var isOnboarded: Bool
    var createdAt: Date
    var updatedAt: Date
}
```

### Data Transfer Object (DocumentData)

```swift
struct DocumentData: Equatable, Sendable {
    var fields: [String: StorageValue]

    subscript(key: String) -> StorageValue? {
        get { fields[key] }
        set { fields[key] = newValue }
    }
}

enum StorageValue: Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case date(Date)
    case map(DocumentData)
    case array([StorageValue])
    case null
}
```

### Core Infrastructure Client (StorageClient)

```swift
@DependencyClient
public struct StorageClient: Sendable {
    public var getDocument: @Sendable (StoragePath) async throws -> DocumentSnapshot = { _ in
        throw InfrastructureError.unimplemented("StorageClient.getDocument")
    }

    public var updateDocument: @Sendable (StoragePath, [String: Any]) async throws -> Void = { _, _ in
        throw InfrastructureError.unimplemented("StorageClient.updateDocument")
    }

    // Other methods...
}
```

### Domain-Specific Client (UserClient)

```swift
@DependencyClient
struct UserClient: Sendable {
    var getCurrentUser: @Sendable () async throws -> User = {
        throw UserError.notAuthenticated
    }

    var updateUser: @Sendable (User) async throws -> Void = { _ in
        throw UserError.updateFailed
    }

    var observeCurrentUser: @Sendable () -> AsyncStream<User> = {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    // Other methods...
}
```

### Adapter Interface (StorageAdapter)

```swift
public protocol StorageAdapter: Sendable {
    func getDocument(_ path: StoragePath) async throws -> DocumentSnapshot
    func updateDocument(_ path: StoragePath, _ data: [String: Any]) async throws
    // Other methods...
}
```

### Backend Adapter (FirebaseStorageAdapter)

```swift
struct FirebaseStorageAdapter: StorageAdapter {
    func getDocument(_ path: StoragePath) async throws -> DocumentSnapshot {
        let firestore = Firestore.firestore()
        let docRef = firestore.document(path.stringPath)

        do {
            let snapshot = try await docRef.getDocument()
            return FirebaseDocumentSnapshot(snapshot: snapshot)
        } catch {
            throw StorageError.from(error)
        }
    }

    func updateDocument(_ path: StoragePath, _ data: [String: Any]) async throws {
        let firestore = Firestore.firestore()
        let docRef = firestore.document(path.stringPath)

        do {
            try await docRef.updateData(data)
        } catch {
            throw StorageError.from(error)
        }
    }

    // Other methods...
}
```

### Registration System

```swift
struct FirebaseAdapter {
    static func registerLiveValues() {
        // Register Firebase adapters as live values
        DependencyValues.register(\.storageAdapter, value: FirebaseStorageAdapter())
        DependencyValues.register(\.authAdapter, value: FirebaseAuthAdapter())
        DependencyValues.register(\.offlineAdapter, value: FirebaseOfflineAdapter())
        // Other adapters...
    }
}
```
