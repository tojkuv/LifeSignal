# Middleware Clients Architecture

**Navigation:** [Back to Infrastructure Layer](README.md) | [Data Persistence and Streaming](DataPersistenceStreaming.md)

---

## Overview

This document outlines the architecture for middleware clients in the LifeSignal iOS application. Middleware clients are backend agnostic anti-corruption clients that provide a consistent interface for the application to interact with backend services, regardless of the specific backend technology being used. This approach allows the application to switch between different backend technologies (such as Firebase and Supabase) without affecting the rest of the application.

In our architecture, features use middleware clients, and middleware clients use adapters of platform backend clients. This layered approach creates a clean separation of concerns and makes the application more flexible, testable, and maintainable.

## Architecture Components

### 1. Feature Layer

Features use middleware clients to interact with backend services:

```swift
@Reducer
struct ProfileFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var user: User?
        var isLoading = false
        var error: String?
    }
    
    enum Action: Equatable, Sendable {
        case viewDidAppear
        case userResponse(TaskResult<User>)
        case updateProfile(firstName: String, lastName: String)
        case updateProfileResponse(TaskResult<Void>)
    }
    
    @Dependency(\.userClient) var userClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .viewDidAppear:
                state.isLoading = true
                return .run { send in
                    await send(.userResponse(TaskResult {
                        try await userClient.getCurrentUser()
                    }))
                }
                
            case let .userResponse(.success(user)):
                state.isLoading = false
                state.user = user
                return .none
                
            case let .userResponse(.failure(error)):
                state.isLoading = false
                state.error = error.localizedDescription
                return .none
                
            case let .updateProfile(firstName, lastName):
                guard var user = state.user else { return .none }
                user.firstName = firstName
                user.lastName = lastName
                state.isLoading = true
                return .run { send in
                    await send(.updateProfileResponse(TaskResult {
                        try await userClient.updateProfile(user)
                    }))
                }
                
            case .updateProfileResponse(.success):
                state.isLoading = false
                return .none
                
            case let .updateProfileResponse(.failure(error)):
                state.isLoading = false
                state.error = error.localizedDescription
                return .none
            }
        }
    }
}
```

### 2. Middleware Client Interfaces

Middleware client interfaces define the contract between the application and the backend services:

```swift
/// Protocol for user client operations
public protocol UserClientProtocol: Sendable {
    /// Get user document once
    func getUserDocument(_ userId: String) async throws -> UserModel
    
    /// Stream user document updates
    func streamUser(_ userId: String) -> AsyncStream<UserModel>
    
    /// Update user document
    func updateUserDocument(_ userId: String, _ data: [String: Any]) async throws -> Bool
    
    // Other methods...
}

/// Protocol for contacts client operations
public protocol ContactsClientProtocol: Sendable {
    /// Stream contacts collection updates
    func streamContacts(_ userId: String) -> AsyncStream<[ContactModel]>
    
    /// Get contacts collection once
    func getContacts(_ userId: String) async throws -> [ContactModel]
    
    // Other methods...
}
```

### 3. Middleware Clients

Middleware clients implement the client interfaces and use adapters to interact with platform backend clients:

```swift
/// User client implementation
public struct UserClient: UserClientProtocol {
    private let adapter: any UserClientAdapter
    
    /// Initialize with a specific adapter
    public init(adapter: any UserClientAdapter = AdapterFactory.createUserClientAdapter()) {
        self.adapter = adapter
    }
    
    /// Get user document once
    public func getUserDocument(_ userId: String) async throws -> UserModel {
        return try await adapter.getUserDocument(userId)
    }
    
    /// Stream user document updates
    public func streamUser(_ userId: String) -> AsyncStream<UserModel> {
        return adapter.streamUser(userId)
    }
    
    // Other method implementations...
}

/// Contacts client implementation
public struct ContactsClient: ContactsClientProtocol {
    private let adapter: any ContactsClientAdapter
    
    /// Initialize with a specific adapter
    public init(adapter: any ContactsClientAdapter = AdapterFactory.createContactsClientAdapter()) {
        self.adapter = adapter
    }
    
    /// Stream contacts collection updates
    public func streamContacts(_ userId: String) -> AsyncStream<[ContactModel]> {
        return adapter.streamContacts(userId)
    }
    
    // Other method implementations...
}
```

### 4. Adapter Interfaces

Adapter interfaces define the contract between middleware clients and platform-specific adapters:

```swift
/// Protocol for user client adapters
public protocol UserClientAdapter: UserClientProtocol {
    // Inherits all methods from UserClientProtocol
}

/// Protocol for contacts client adapters
public protocol ContactsClientAdapter: ContactsClientProtocol {
    // Inherits all methods from ContactsClientProtocol
}
```

### 5. Platform-Specific Adapters

Platform-specific adapters implement the adapter interfaces for specific backend technologies:

```swift
/// Firebase user client adapter
struct FirebaseUserClientAdapter: UserClientAdapter {
    private let firebaseClient: FirebaseClient
    
    init(firebaseClient: FirebaseClient = .shared) {
        self.firebaseClient = firebaseClient
    }
    
    func getUserDocument(_ userId: String) async throws -> UserModel {
        let path = "users/\(userId)"
        let snapshot = try await firebaseClient.getDocument(path)
        guard let data = snapshot.data() else {
            throw StorageError.documentNotFound
        }
        return UserModel.fromFirestore(data, id: snapshot.documentID)
    }
    
    // Other method implementations...
}

/// Supabase user client adapter
struct SupabaseUserClientAdapter: UserClientAdapter {
    private let supabaseClient: SupabaseClient
    
    init(supabaseClient: SupabaseClient = .shared) {
        self.supabaseClient = supabaseClient
    }
    
    func getUserDocument(_ userId: String) async throws -> UserModel {
        let response = try await supabaseClient.from("users").select().eq("id", value: userId).single().execute()
        guard let data = response.data else {
            throw StorageError.documentNotFound
        }
        return UserModel.fromSupabase(data)
    }
    
    // Other method implementations...
}
```

## Mixed Backend Implementation

In the future, the LifeSignal application will use a mixed backend implementation, with some functionality provided by Firebase and some by Supabase. The middleware client architecture makes this possible by allowing each client to use the appropriate adapter based on the current requirements.

For example, the `AuthClient` might use Firebase for authentication, while the `StorageClient` might use Supabase for data storage:

```swift
/// Auth client implementation
public struct AuthClient: AuthClientProtocol {
    private let adapter: any AuthClientAdapter
    
    /// Initialize with a specific adapter
    public init(adapter: any AuthClientAdapter = AdapterFactory.createAuthClientAdapter(provider: .firebase)) {
        self.adapter = adapter
    }
    
    // Method implementations...
}

/// Storage client implementation
public struct StorageClient: StorageClientProtocol {
    private let adapter: any StorageClientAdapter
    
    /// Initialize with a specific adapter
    public init(adapter: any StorageClientAdapter = AdapterFactory.createStorageClientAdapter(provider: .supabase)) {
        self.adapter = adapter
    }
    
    // Method implementations...
}
```

## Benefits

The middleware client architecture provides several benefits:

1. **Flexibility**: The application can switch between different backend technologies without affecting the rest of the application.
2. **Testability**: The application can use mock adapters for testing without changing the client interfaces.
3. **Maintainability**: The application can evolve its backend implementation without affecting the client interfaces.
4. **Mixed Backend Support**: The application can use different backend technologies for different functionality.
5. **Future-Proofing**: The application can adopt new backend technologies as they become available.

## Best Practices

When implementing middleware clients, follow these best practices:

1. **Keep client interfaces focused**: Each client interface should have a single responsibility.
2. **Use dependency injection**: Clients should be created using dependency injection to allow for easy testing.
3. **Handle errors consistently**: Platform-specific adapters should map backend-specific errors to domain-specific errors.
4. **Document client behavior**: Clients should be well-documented, including information on error handling and expected behavior.
5. **Provide comprehensive tests**: Each client should have comprehensive tests to ensure correct behavior.
6. **Use async/await for asynchronous operations**: Clients should use async/await for asynchronous operations to provide a consistent and easy-to-use API.
7. **Use AsyncStream for streaming data**: Clients should use AsyncStream for streaming data to provide a consistent and easy-to-use API.

## Conclusion

The middleware client architecture provides a flexible and maintainable approach to interacting with backend services in the LifeSignal iOS application. By using middleware clients that delegate to platform-specific adapters, the application can switch between different backend technologies without affecting the rest of the application. This approach also enables the application to use a mixed backend implementation, with some functionality provided by Firebase and some by Supabase.
