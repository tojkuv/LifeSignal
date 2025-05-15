# Firebase Client Design

**Navigation:** [Back to iOS Architecture](../../README.md) | [Firebase Integration](./FirebaseIntegration.md) | [Firebase Adapters](./FirebaseAdapters.md) | [Firebase Streaming](./FirebaseStreaming.md)

---

> **Note:** As this is an MVP, the Firebase client design may evolve as the project matures.

## Client Design Principles

Firebase clients in LifeSignal follow these core principles:

1. **Infrastructure Agnosticism**: Clients define interfaces that are independent of Firebase
2. **Type Safety**: All data is strongly typed using domain models
3. **Concurrency Safety**: All asynchronous operations use structured concurrency (async/await)
4. **Error Handling**: Firebase errors are mapped to domain-specific errors
5. **Dependency Injection**: Clients are provided via TCA's dependency system

## Client Types

LifeSignal uses two types of clients:

### 1. Core Infrastructure Clients

Low-level clients that provide basic infrastructure operations:

- **StorageClient**: Document storage operations
- **AuthClient**: Authentication operations
- **OfflineClient**: Offline capabilities
- **MessagingClient**: Push notification operations

### 2. Domain-Specific Clients

Higher-level clients that use core infrastructure clients:

- **UserClient**: User management operations
- **ContactsClient**: Contact management operations
- **CheckInClient**: Check-in operations
- **AlertClient**: Alert operations

## Client Implementation

Clients are implemented using TCA's `@DependencyClient` macro:

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

## Firebase Auth Client

The Firebase Auth Client provides authentication operations:

```swift
struct FirebaseAuthClient: Sendable {
    var currentUser: @Sendable () async -> User?
    var signIn: @Sendable (String, String) async throws -> User
    var signOut: @Sendable () async throws -> Void
    var authStateStream: @Sendable () -> AsyncStream<User?>
    var createUser: @Sendable (String, String) async throws -> User
    var sendPasswordReset: @Sendable (String) async throws -> Void
}
```

## Firebase Firestore Client

The Firebase Firestore Client provides document storage operations:

```swift
struct FirestoreClient: Sendable {
    var getDocument: @Sendable (StoragePath) async throws -> DocumentSnapshot
    var setDocument: @Sendable (StoragePath, DocumentData) async throws -> Void
    var updateDocument: @Sendable (StoragePath, [String: Any]) async throws -> Void
    var deleteDocument: @Sendable (StoragePath) async throws -> Void
    var addDocument: @Sendable (StoragePath, DocumentData) async throws -> String
    var getCollection: @Sendable (StoragePath) async throws -> [DocumentSnapshot]
    var observeDocument: @Sendable (StoragePath) -> AsyncStream<DocumentSnapshot>
    var observeCollection: @Sendable (StoragePath) -> AsyncStream<[DocumentSnapshot]>
}
```

## Firebase Storage Client

The Firebase Storage Client provides file storage operations:

```swift
struct StorageClient: Sendable {
    var uploadFile: @Sendable (StoragePath, Data) async throws -> URL
    var downloadFile: @Sendable (StoragePath) async throws -> Data
    var deleteFile: @Sendable (StoragePath) async throws -> Void
    var getDownloadURL: @Sendable (StoragePath) async throws -> URL
}
```

## Firebase Messaging Client

The Firebase Messaging Client provides push notification operations:

```swift
struct MessagingClient: Sendable {
    var getToken: @Sendable () async throws -> String
    var subscribe: @Sendable (String) async throws -> Void
    var unsubscribe: @Sendable (String) async throws -> Void
    var messageStream: @Sendable () -> AsyncStream<RemoteMessage>
}
```

## Domain-Specific Client Example

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
    
    var updateLastCheckedIn: @Sendable (Date) async throws -> Void = { _ in
        throw UserError.updateFailed
    }
    
    var updateCheckInInterval: @Sendable (TimeInterval) async throws -> Void = { _ in
        throw UserError.updateFailed
    }
}
```

## Error Handling

Firebase errors are mapped to domain-specific errors:

```swift
enum AuthError: Error, Equatable {
    case invalidCredentials
    case emailAlreadyInUse
    case weakPassword
    case userNotFound
    case networkError
    case unknown(String)
    
    static func from(_ error: Error) -> AuthError {
        // Map Firebase Auth errors to AuthError
    }
}

enum StorageError: Error, Equatable {
    case documentNotFound
    case permissionDenied
    case networkError
    case serializationError
    case unknown(String)
    
    static func from(_ error: Error) -> StorageError {
        // Map Firebase Firestore errors to StorageError
    }
}
```

## Client Registration

Clients are registered with TCA's dependency system:

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

## Best Practices

1. **Keep Clients Focused**: Each client should have a single responsibility
2. **Use Structured Concurrency**: Use async/await for all asynchronous operations
3. **Provide Default Values**: Provide default values for non-throwing closures
4. **Map Errors**: Map Firebase errors to domain-specific errors
5. **Use Strong Types**: Use strongly typed domain models instead of dictionaries
6. **Stream at Top Level**: Stream Firebase data at the top level of the application
7. **Handle Offline Mode**: Properly handle offline capabilities
8. **Use Atomic Operations**: Use atomic operations when appropriate
9. **Test Thoroughly**: Provide comprehensive test implementations
