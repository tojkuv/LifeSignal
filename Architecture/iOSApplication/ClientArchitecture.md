# Client Architecture

> **Note:** As this is an MVP, the client architecture and types may evolve as the project matures.

## Client Types

LifeSignal uses two main types of clients:

1. **Core Infrastructure Clients** - Low-level clients for basic infrastructure operations
2. **Domain-Specific Clients** - Higher-level clients that use core clients for domain-specific operations

## Core Infrastructure Clients

These clients handle low-level infrastructure operations:

1. **StorageClient** - Document/collection operations
   - CRUD operations for documents and collections
   - Query operations with filtering, sorting, and pagination
   - Real-time updates via streams
   - Batch and transaction support
   - Field value operations (timestamps, increments, arrays)

2. **AuthClient** - Authentication operations
   - User authentication (email/password, phone, social)
   - User session management
   - User profile operations
   - Security rules and claims

3. **OfflineClient** - Offline persistence operations
   - Cache configuration
   - Offline data access
   - Synchronization policies
   - Conflict resolution

4. **AppClient** - Application lifecycle operations
   - App initialization
   - Configuration management
   - Environment detection
   - Feature flags

5. **NotificationClient** - Push notification operations
   - Token registration
   - Notification handling
   - Deep link processing
   - Notification permissions

6. **SessionClient** - Session management operations
   - Session creation and termination
   - Session state management
   - Session persistence
   - Multi-device session handling

7. **AnalyticsClient** - Analytics operations
   - Event tracking
   - User property tracking
   - Conversion tracking
   - Analytics configuration

8. **StorageMediaClient** - Media storage operations
   - File upload/download
   - Media metadata
   - Media processing
   - Access control

## Domain-Specific Clients

These clients use core clients to implement domain-specific operations:

1. **UserClient** - User management operations
   - User profile management
   - User preferences
   - User relationships
   - User search and discovery

2. **ContactsClient** - Contact management operations
   - Contact creation and management
   - Contact synchronization
   - Contact grouping and categorization
   - Contact permissions

3. **MessageClient** - Messaging operations
   - Message sending and receiving
   - Message status tracking
   - Message search and filtering
   - Message attachments

4. **LocationClient** - Location operations
   - Location tracking
   - Geofencing
   - Location sharing
   - Location history

5. **HealthClient** - Health data operations
   - Health metric tracking
   - Health data analysis
   - Health data sharing
   - Health notifications

6. **EmergencyClient** - Emergency operations
   - Emergency contact management
   - Emergency notifications
   - Emergency response coordination
   - Emergency history

## Client Implementation Guidelines

### Core Infrastructure Clients

- Use `@DependencyClient` macro for all client definitions
- Define methods with clear signatures and comprehensive documentation
- Handle errors consistently with domain-specific error types
- Provide proper test and preview implementations
- Use structured concurrency with async/await for all asynchronous operations
- Ensure all methods are marked as `@Sendable`
- Use cancellation tokens for long-running operations
- Implement proper resource cleanup with async sequences

### Domain-Specific Clients

- Use `@Dependency` to inject core clients
- Implement domain-specific business logic
- Convert between domain models and infrastructure formats
- Provide proper test and preview implementations
- Encapsulate complex operations in single methods
- Use domain-specific error types
- Implement retry logic for transient failures
- Use proper validation before storage operations

## Client Implementation Examples

### Core Infrastructure Client (StorageClient)

```swift
@DependencyClient
struct StorageClient: Sendable {
    /// Gets a document from storage
    var getDocument: @Sendable (_ path: StoragePath) async throws -> DocumentData = { _ in
        throw StorageError.notImplemented
    }
    
    /// Updates a document in storage
    var updateDocument: @Sendable (_ path: StoragePath, _ data: [String: Any]) async throws -> Void = { _, _ in
        throw StorageError.notImplemented
    }
    
    /// Deletes a document from storage
    var deleteDocument: @Sendable (_ path: StoragePath) async throws -> Void = { _ in
        throw StorageError.notImplemented
    }
    
    /// Observes changes to a document
    var observeDocument: @Sendable (_ path: StoragePath) -> AsyncStream<DocumentData> = { _ in
        AsyncStream { continuation in
            continuation.finish()
        }
    }
    
    /// Queries documents in a collection
    var queryDocuments: @Sendable (_ path: CollectionPath, _ query: Query) async throws -> [DocumentData] = { _, _ in
        throw StorageError.notImplemented
    }
    
    /// Observes changes to a query
    var observeQuery: @Sendable (_ path: CollectionPath, _ query: Query) -> AsyncStream<[DocumentData]> = { _, _ in
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}

// MARK: - Live Implementation

extension StorageClient: DependencyKey {
    static let liveValue = Self(
        getDocument: { path in
            @Dependency(\.storageAdapter) var adapter
            return try await adapter.getDocument(path)
        },
        
        updateDocument: { path, data in
            @Dependency(\.storageAdapter) var adapter
            try await adapter.updateDocument(path, data)
        },
        
        deleteDocument: { path in
            @Dependency(\.storageAdapter) var adapter
            try await adapter.deleteDocument(path)
        },
        
        observeDocument: { path in
            @Dependency(\.storageAdapter) var adapter
            return adapter.observeDocument(path)
        },
        
        queryDocuments: { path, query in
            @Dependency(\.storageAdapter) var adapter
            return try await adapter.queryDocuments(path, query)
        },
        
        observeQuery: { path, query in
            @Dependency(\.storageAdapter) var adapter
            return adapter.observeQuery(path, query)
        }
    )
}

// MARK: - Test Implementation

extension StorageClient: TestDependencyKey {
    static let testValue = Self(
        getDocument: unimplemented("StorageClient.getDocument"),
        updateDocument: unimplemented("StorageClient.updateDocument"),
        deleteDocument: unimplemented("StorageClient.deleteDocument"),
        observeDocument: unimplemented("StorageClient.observeDocument"),
        queryDocuments: unimplemented("StorageClient.queryDocuments"),
        observeQuery: unimplemented("StorageClient.observeQuery")
    )
}

// MARK: - Dependency Registration

extension DependencyValues {
    var storage: StorageClient {
        get { self[StorageClient.self] }
        set { self[StorageClient.self] = newValue }
    }
}
```

### Domain-Specific Client (UserClient)

```swift
@DependencyClient
struct UserClient: Sendable {
    /// Gets the current user
    var getCurrentUser: @Sendable () async throws -> User = {
        throw UserError.notAuthenticated
    }
    
    /// Updates the current user
    var updateUser: @Sendable (_ user: User) async throws -> Void = { _ in
        throw UserError.updateFailed
    }
    
    /// Observes changes to the current user
    var observeCurrentUser: @Sendable () -> AsyncStream<User> = {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
    
    /// Checks in the current user
    var checkIn: @Sendable () async throws -> Date = {
        throw UserError.checkInFailed
    }
    
    /// Updates the check-in interval for the current user
    var updateCheckInInterval: @Sendable (_ interval: TimeInterval) async throws -> Void = { _ in
        throw UserError.updateFailed
    }
}

// MARK: - Live Implementation

extension UserClient: DependencyKey {
    static let liveValue = Self(
        getCurrentUser: {
            @Dependency(\.storage) var storage
            @Dependency(\.auth) var auth
            
            // Get the current user ID
            let userId = try await auth.getCurrentUserId()
            
            // Get the user document
            let path = StoragePath(path: "users/\(userId)")
            let data = try await storage.getDocument(path)
            
            // Convert to User model
            guard let user = User.from(data: data, id: userId) else {
                throw UserError.invalidUserData
            }
            
            return user
        },
        
        updateUser: { user in
            @Dependency(\.storage) var storage
            
            let path = StoragePath(path: "users/\(user.id)")
            let data = user.toData()
            
            try await storage.updateDocument(path, data)
        },
        
        observeCurrentUser: {
            @Dependency(\.storage) var storage
            @Dependency(\.auth) var auth
            
            // Create an async stream of user updates
            AsyncStream { continuation in
                // Start a task to observe the user
                Task {
                    do {
                        // Get the current user ID
                        let userId = try await auth.getCurrentUserId()
                        
                        // Observe the user document
                        let path = StoragePath(path: "users/\(userId)")
                        let stream = storage.observeDocument(path)
                        
                        // Convert each update to a User model
                        for await data in stream {
                            if let user = User.from(data: data, id: userId) {
                                continuation.yield(user)
                            }
                        }
                        
                        // Stream ended
                        continuation.finish()
                    } catch {
                        // Handle errors
                        continuation.finish()
                    }
                }
            }
        },
        
        checkIn: {
            @Dependency(\.storage) var storage
            @Dependency(\.auth) var auth
            
            // Get the current user ID
            let userId = try await auth.getCurrentUserId()
            
            // Update the user document with the current time
            let path = StoragePath(path: "users/\(userId)")
            let now = Date()
            let data: [String: Any] = [
                "lastCheckedIn": now,
                "checkInExpiration": now.addingTimeInterval(3600) // Default 1 hour
            ]
            
            try await storage.updateDocument(path, data)
            
            return now
        },
        
        updateCheckInInterval: { interval in
            @Dependency(\.storage) var storage
            @Dependency(\.auth) var auth
            
            // Get the current user ID
            let userId = try await auth.getCurrentUserId()
            
            // Update the user document with the new interval
            let path = StoragePath(path: "users/\(userId)")
            let data: [String: Any] = [
                "checkInInterval": interval
            ]
            
            try await storage.updateDocument(path, data)
        }
    )
}

// MARK: - Test Implementation

extension UserClient: TestDependencyKey {
    static let testValue = Self(
        getCurrentUser: unimplemented("UserClient.getCurrentUser"),
        updateUser: unimplemented("UserClient.updateUser"),
        observeCurrentUser: unimplemented("UserClient.observeCurrentUser"),
        checkIn: unimplemented("UserClient.checkIn"),
        updateCheckInInterval: unimplemented("UserClient.updateCheckInInterval")
    )
}

// MARK: - Dependency Registration

extension DependencyValues {
    var user: UserClient {
        get { self[UserClient.self] }
        set { self[UserClient.self] = newValue }
    }
}
```
