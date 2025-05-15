# Client Architecture

**Navigation:** [Back to iOS Architecture](../README.md) | [Infrastructure Layers](./InfrastructureLayers.md) | [Dependency Management](./DependencyManagement.md) | [Firebase Integration](./Firebase/FirebaseIntegration.md)

---

> **Note:** As this is an MVP, the client architecture may evolve as the project matures.

## Client Design Principles

Clients in LifeSignal follow these core principles:

1. **Infrastructure Agnosticism**: Clients define interfaces that are independent of specific backends
2. **Type Safety**: All data is strongly typed using domain models
3. **Concurrency Safety**: All asynchronous operations use structured concurrency (async/await)
4. **Error Handling**: Errors are mapped to domain-specific errors
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

## Core Infrastructure Client Examples

### Storage Client

```swift
@DependencyClient
public struct StorageClient: Sendable {
    public var getDocument: @Sendable (StoragePath) async throws -> DocumentSnapshot = { _ in
        throw InfrastructureError.unimplemented("StorageClient.getDocument")
    }

    public var updateDocument: @Sendable (StoragePath, [String: Any]) async throws -> Void = { _, _ in
        throw InfrastructureError.unimplemented("StorageClient.updateDocument")
    }
    
    public var setDocument: @Sendable (StoragePath, DocumentData) async throws -> Void = { _, _ in
        throw InfrastructureError.unimplemented("StorageClient.setDocument")
    }
    
    public var deleteDocument: @Sendable (StoragePath) async throws -> Void = { _ in
        throw InfrastructureError.unimplemented("StorageClient.deleteDocument")
    }
    
    public var addDocument: @Sendable (StoragePath, DocumentData) async throws -> String = { _, _ in
        throw InfrastructureError.unimplemented("StorageClient.addDocument")
    }
    
    public var getCollection: @Sendable (StoragePath) async throws -> [DocumentSnapshot] = { _ in
        throw InfrastructureError.unimplemented("StorageClient.getCollection")
    }
    
    public var observeDocument: @Sendable (StoragePath) -> AsyncStream<DocumentSnapshot> = { _ in
        AsyncStream { continuation in
            continuation.finish()
        }
    }
    
    public var observeCollection: @Sendable (StoragePath) -> AsyncStream<[DocumentSnapshot]> = { _ in
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
```

### Auth Client

```swift
@DependencyClient
public struct AuthClient: Sendable {
    public var currentUser: @Sendable () async -> User? = { nil }
    
    public var signIn: @Sendable (String, String) async throws -> User = { _, _ in
        throw AuthError.invalidCredentials
    }
    
    public var signOut: @Sendable () async throws -> Void = { }
    
    public var createUser: @Sendable (String, String) async throws -> User = { _, _ in
        throw AuthError.invalidCredentials
    }
    
    public var sendPasswordReset: @Sendable (String) async throws -> Void = { _ in
        throw AuthError.invalidCredentials
    }
    
    public var authStateStream: @Sendable () -> AsyncStream<User?> = {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
```

### File Storage Client

```swift
@DependencyClient
public struct FileStorageClient: Sendable {
    public var uploadFile: @Sendable (StoragePath, Data) async throws -> URL = { _, _ in
        throw StorageError.uploadFailed
    }
    
    public var downloadFile: @Sendable (StoragePath) async throws -> Data = { _ in
        throw StorageError.downloadFailed
    }
    
    public var deleteFile: @Sendable (StoragePath) async throws -> Void = { _ in
        throw StorageError.deleteFailed
    }
    
    public var getDownloadURL: @Sendable (StoragePath) async throws -> URL = { _ in
        throw StorageError.urlFailed
    }
}
```

### Messaging Client

```swift
@DependencyClient
public struct MessagingClient: Sendable {
    public var getToken: @Sendable () async throws -> String = {
        throw MessagingError.tokenFailed
    }
    
    public var subscribe: @Sendable (String) async throws -> Void = { _ in
        throw MessagingError.subscribeFailed
    }
    
    public var unsubscribe: @Sendable (String) async throws -> Void = { _ in
        throw MessagingError.unsubscribeFailed
    }
    
    public var messageStream: @Sendable () -> AsyncStream<RemoteMessage> = {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
```

## Domain-Specific Client Examples

### User Client

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

### Contacts Client

```swift
@DependencyClient
struct ContactsClient: Sendable {
    var getContacts: @Sendable () async throws -> [Contact] = {
        throw ContactsError.loadFailed
    }
    
    var addContact: @Sendable (Contact) async throws -> Void = { _ in
        throw ContactsError.addFailed
    }
    
    var updateContact: @Sendable (Contact) async throws -> Void = { _ in
        throw ContactsError.updateFailed
    }
    
    var deleteContact: @Sendable (String) async throws -> Void = { _ in
        throw ContactsError.deleteFailed
    }
    
    var observeContacts: @Sendable () -> AsyncStream<[Contact]> = {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
```

### Check-In Client

```swift
@DependencyClient
struct CheckInClient: Sendable {
    var checkIn: @Sendable () async throws -> Void = {
        throw CheckInError.checkInFailed
    }
    
    var getLastCheckIn: @Sendable () async throws -> Date? = {
        throw CheckInError.loadFailed
    }
    
    var getCheckInInterval: @Sendable () async throws -> TimeInterval = {
        throw CheckInError.loadFailed
    }
    
    var updateCheckInInterval: @Sendable (TimeInterval) async throws -> Void = { _ in
        throw CheckInError.updateFailed
    }
}
```

### Alert Client

```swift
@DependencyClient
struct AlertClient: Sendable {
    var sendAlert: @Sendable (AlertType) async throws -> Void = { _ in
        throw AlertError.sendFailed
    }
    
    var cancelAlert: @Sendable (String) async throws -> Void = { _ in
        throw AlertError.cancelFailed
    }
    
    var getActiveAlerts: @Sendable () async throws -> [Alert] = {
        throw AlertError.loadFailed
    }
    
    var observeAlerts: @Sendable () -> AsyncStream<[Alert]> = {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
```

## Error Handling

Clients define domain-specific error types:

```swift
enum AuthError: Error, Equatable {
    case invalidCredentials
    case emailAlreadyInUse
    case weakPassword
    case userNotFound
    case networkError
    case unknown(String)
}

enum StorageError: Error, Equatable {
    case documentNotFound
    case permissionDenied
    case networkError
    case serializationError
    case unknown(String)
}

enum UserError: Error, Equatable {
    case notAuthenticated
    case updateFailed
    case loadFailed
    case networkError
    case unknown(String)
}
```

## Client Registration

Clients are registered with TCA's dependency system:

```swift
extension AuthClient: DependencyKey {
    static let liveValue = Self(
        currentUser: { /* Live implementation */ },
        signIn: { /* Live implementation */ },
        signOut: { /* Live implementation */ },
        authStateStream: { /* Live implementation */ }
    )
    
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

## Client Usage in Features

Clients are used in features via the `@Dependency` property wrapper:

```swift
@Reducer
struct Feature {
    @Dependency(\.userClient) var userClient
    @Dependency(\.contactsClient) var contactsClient
    
    // State, Action, etc.
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadUserButtonTapped:
                return .run { send in
                    do {
                        let user = try await userClient.getCurrentUser()
                        await send(.userResponse(user))
                    } catch {
                        await send(.userFailed(error))
                    }
                }
                
            // Other cases...
            }
        }
    }
}
```

## Best Practices

1. **Keep Clients Focused**: Each client should have a single responsibility
2. **Use @DependencyClient**: Use the `@DependencyClient` macro for client definitions
3. **Provide Default Values**: Provide default values for non-throwing closures
4. **Remove Argument Labels**: Remove argument labels in function types for cleaner syntax
5. **Use Structured Concurrency**: Use async/await for all asynchronous operations
6. **Map Errors**: Define domain-specific error types
7. **Use Strong Types**: Use strongly typed domain models instead of dictionaries
8. **Test Thoroughly**: Provide comprehensive test implementations
9. **Document Clients**: Document the purpose of each client method
10. **Handle Edge Cases**: Properly handle edge cases like offline mode
