# Platform-Agnostic Clients Architecture

**Navigation:** [Back to Infrastructure Layer](README.md) | [Data Persistence and Streaming](DataPersistenceStreaming.md)

---

## Overview

This document outlines the architecture for platform-agnostic clients in the LifeSignal iOS application. Platform-agnostic clients provide a consistent interface for the application to interact with backend services, regardless of the specific backend technology being used. This approach allows the application to switch between different backend technologies (such as Firebase and Supabase) without affecting the rest of the application.

## Architecture Components

### 1. Infrastructure Provider

The infrastructure provider is an enumeration that defines the available backend technologies:

```swift
/// The infrastructure provider to use
public enum InfrastructureProvider {
    /// Use Firebase as the infrastructure provider
    case firebase
    
    /// Use Supabase as the infrastructure provider
    case supabase
    
    /// Use mock implementations for testing
    case mock
}
```

### 2. Client Interfaces

Client interfaces define the contract between the application and the infrastructure layer. They are protocol-based and infrastructure-agnostic:

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

### 3. Platform-Agnostic Clients

Platform-agnostic clients implement the client interfaces and use platform-specific clients to interact with backend services:

```swift
/// User client implementation
public struct UserClient: UserClientProtocol {
    private let platformClient: any UserClientProtocol
    
    /// Initialize with a specific infrastructure provider
    public init(provider: InfrastructureProvider = Current.infrastructureProvider()) {
        self.platformClient = InfrastructureFactory.createUserClient(provider: provider)
    }
    
    /// Get user document once
    public func getUserDocument(_ userId: String) async throws -> UserModel {
        return try await platformClient.getUserDocument(userId)
    }
    
    /// Stream user document updates
    public func streamUser(_ userId: String) -> AsyncStream<UserModel> {
        return platformClient.streamUser(userId)
    }
    
    // Other method implementations...
}

/// Contacts client implementation
public struct ContactsClient: ContactsClientProtocol {
    private let platformClient: any ContactsClientProtocol
    
    /// Initialize with a specific infrastructure provider
    public init(provider: InfrastructureProvider = Current.infrastructureProvider()) {
        self.platformClient = InfrastructureFactory.createContactsClient(provider: provider)
    }
    
    /// Stream contacts collection updates
    public func streamContacts(_ userId: String) -> AsyncStream<[ContactModel]> {
        return platformClient.streamContacts(userId)
    }
    
    // Other method implementations...
}
```

### 4. Infrastructure Factory

The infrastructure factory is responsible for creating platform-specific clients based on the infrastructure provider:

```swift
/// A factory for creating infrastructure clients
public enum InfrastructureFactory {
    /// Create a user client based on the current infrastructure provider
    /// - Parameter provider: The infrastructure provider to use
    /// - Returns: A user client
    public static func createUserClient(provider: InfrastructureProvider) -> any UserClientProtocol {
        switch provider {
        case .firebase:
            return FirebaseUserClient()
        case .supabase:
            // TODO: Implement Supabase adapter
            fatalError("Supabase user client not implemented")
        case .mock:
            return MockUserClient()
        }
    }
    
    /// Create a contacts client based on the current infrastructure provider
    /// - Parameter provider: The infrastructure provider to use
    /// - Returns: A contacts client
    public static func createContactsClient(provider: InfrastructureProvider) -> any ContactsClientProtocol {
        switch provider {
        case .firebase:
            return FirebaseContactsClient()
        case .supabase:
            // TODO: Implement Supabase adapter
            fatalError("Supabase contacts client not implemented")
        case .mock:
            return MockContactsClient()
        }
    }
    
    // Other factory methods...
}
```

### 5. Platform-Specific Clients

Platform-specific clients implement the client interfaces for specific backend technologies:

```swift
/// Firebase user client implementation
struct FirebaseUserClient: UserClientProtocol {
    @Dependency(\.typedFirestore) private var typedFirestore
    
    func getUserDocument(_ userId: String) async throws -> UserModel {
        let path = FirestorePath(path: "users/\(userId)")
        let snapshot = try await typedFirestore.getDocument(
            path,
            UserModelFirestoreConvertible.self,
            .default,
            .server
        )
        return snapshot.data
    }
    
    // Other method implementations...
}

/// Firebase contacts client implementation
struct FirebaseContactsClient: ContactsClientProtocol {
    @Dependency(\.typedFirestore) private var typedFirestore
    
    func streamContacts(_ userId: String) -> AsyncStream<[ContactModel]> {
        AsyncStream { continuation in
            let path = FirestorePath(path: "users/\(userId)/contacts")
            let listener = typedFirestore.addSnapshotListener(
                path,
                ContactModelFirestoreConvertible.self,
                .default
            ) { result in
                switch result {
                case .success(let snapshot):
                    let contacts = snapshot.documents.map { $0.data }
                    continuation.yield(contacts)
                case .failure:
                    continuation.finish()
                }
            }
            
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }
    
    // Other method implementations...
}
```

### 6. Mock Clients

Mock clients implement the client interfaces for testing and development:

```swift
/// Mock user client implementation
struct MockUserClient: UserClientProtocol {
    private let userDefaults = UserDefaults.standard
    private let userKey = "mockUser"
    
    func getUserDocument(_ userId: String) async throws -> UserModel {
        if let userData = userDefaults.data(forKey: userKey),
           let user = try? JSONDecoder().decode(UserModel.self, from: userData) {
            return user
        }
        
        // Return default user if none exists
        return UserModel(id: userId, name: "Mock User")
    }
    
    // Other method implementations...
}

/// Mock contacts client implementation
struct MockContactsClient: ContactsClientProtocol {
    private let userDefaults = UserDefaults.standard
    private let contactsKey = "mockContacts"
    
    func streamContacts(_ userId: String) -> AsyncStream<[ContactModel]> {
        AsyncStream { continuation in
            // Initial value
            Task {
                let contacts = try await getContacts(userId)
                continuation.yield(contacts)
            }
            
            // Set up notification observer for changes
            let observer = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("ContactsUpdated"),
                object: nil,
                queue: .main
            ) { _ in
                Task {
                    let contacts = try await getContacts(userId)
                    continuation.yield(contacts)
                }
            }
            
            continuation.onTermination = { _ in
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    // Other method implementations...
}
```

### 7. Dependency Registration

Client interfaces are registered as dependencies in TCA:

```swift
/// Register infrastructure dependencies
public func registerInfrastructureDependencies() {
    // Register the infrastructure provider
    DependencyValues.registerDependency(
        \.infrastructureProvider,
        default: .firebase
    )
    
    // Register the user client
    DependencyValues.registerDependency(
        \.userClient,
        factory: { @Sendable () -> any UserClientProtocol in
            UserClient(provider: Current.infrastructureProvider())
        }
    )
    
    // Register the contacts client
    DependencyValues.registerDependency(
        \.contactsClient,
        factory: { @Sendable () -> any ContactsClientProtocol in
            ContactsClient(provider: Current.infrastructureProvider())
        }
    )
    
    // Other dependency registrations...
}
```

## Mixed Backend Implementation

In the future, the LifeSignal application will use a mixed backend implementation, with some functionality provided by Firebase and some by Supabase. The platform-agnostic client architecture makes this possible by allowing each client to use the appropriate platform-specific client based on the current requirements.

For example, the `AuthClient` might use Firebase for authentication, while the `StorageClient` might use Supabase for data storage:

```swift
/// Auth client implementation
public struct AuthClient: AuthClientProtocol {
    private let platformClient: any AuthClientProtocol
    
    /// Initialize with a specific infrastructure provider
    public init(provider: InfrastructureProvider = .firebase) {
        self.platformClient = InfrastructureFactory.createAuthClient(provider: provider)
    }
    
    // Method implementations...
}

/// Storage client implementation
public struct StorageClient: StorageClientProtocol {
    private let platformClient: any StorageClientProtocol
    
    /// Initialize with a specific infrastructure provider
    public init(provider: InfrastructureProvider = .supabase) {
        self.platformClient = InfrastructureFactory.createStorageClient(provider: provider)
    }
    
    // Method implementations...
}
```

## Benefits

The platform-agnostic client architecture provides several benefits:

1. **Flexibility**: The application can switch between different backend technologies without affecting the rest of the application.
2. **Testability**: The application can use mock implementations for testing without changing the client interfaces.
3. **Maintainability**: The application can evolve its backend implementation without affecting the client interfaces.
4. **Mixed Backend Support**: The application can use different backend technologies for different functionality.
5. **Future-Proofing**: The application can adopt new backend technologies as they become available.

## Best Practices

When implementing platform-agnostic clients, follow these best practices:

1. **Keep client interfaces focused**: Each client interface should have a single responsibility.
2. **Use dependency injection**: Clients should be created using dependency injection to allow for easy testing.
3. **Handle errors consistently**: Platform-specific clients should map backend-specific errors to domain-specific errors.
4. **Document client behavior**: Clients should be well-documented, including information on error handling and expected behavior.
5. **Provide comprehensive tests**: Each client should have comprehensive tests to ensure correct behavior.
6. **Use async/await for asynchronous operations**: Clients should use async/await for asynchronous operations to provide a consistent and easy-to-use API.
7. **Use AsyncStream for streaming data**: Clients should use AsyncStream for streaming data to provide a consistent and easy-to-use API.

## Conclusion

The platform-agnostic client architecture provides a flexible and maintainable approach to interacting with backend services in the LifeSignal iOS application. By using platform-agnostic clients that delegate to platform-specific clients, the application can switch between different backend technologies without affecting the rest of the application. This approach also enables the application to use a mixed backend implementation, with some functionality provided by Firebase and some by Supabase.
