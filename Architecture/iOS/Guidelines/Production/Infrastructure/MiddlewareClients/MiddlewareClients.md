# Middleware Clients

**Navigation:** [Back to General Architecture](../../../../General/README.md) | [Modular Features](../../ModularFeatures/ModularFeatures.md)

---

## Overview

Middleware clients are backend agnostic anti-corruption clients that decouple application logic from specific infrastructure implementations. This approach ensures that the core application can work with different backend technologies, databases, authentication systems, and other infrastructure components without significant changes to the application code.

In our architecture, features use middleware clients, and middleware clients use adapters of platform backend clients (such as Firebase and Supabase). This layered approach creates a clean separation of concerns and makes the application more flexible, testable, and maintainable.

## Core Principles

### 1. Dependency Inversion

We follow the Dependency Inversion Principle:

- High-level modules (features) should not depend on low-level modules (infrastructure)
- Both should depend on abstractions
- Abstractions should not depend on details
- Details should depend on abstractions

### 2. Interface-Based Design

We define infrastructure capabilities through interfaces:

- Infrastructure-agnostic interfaces define what operations are available
- Concrete implementations provide the how for specific technologies
- Features depend only on the interfaces, not the implementations

### 3. Adapter Pattern

We use the Adapter Pattern to integrate with specific infrastructure:

- Adapters implement infrastructure-agnostic interfaces
- Adapters translate between domain models and infrastructure DTOs
- Adapters handle infrastructure-specific error mapping
- Adapters encapsulate infrastructure-specific authentication and authorization

### 4. Dependency Injection

We use Dependency Injection to provide infrastructure implementations:

- Features receive infrastructure dependencies through constructor injection or property injection
- Dependencies are registered in a central location
- Different environments (production, testing, preview) can use different implementations

## Implementation in LifeSignal

### Layered Architecture

The LifeSignal application follows a layered architecture that enforces backend agnosticism through middleware clients:

```
Feature Layer → Middleware Clients → Adapters → Platform Backend Clients → Backend
(UserFeature)    (UserClient)       (FirebaseUserAdapter)  (FirebaseClient)     (Firebase/Supabase)
```

### Middleware Client Interfaces

We define middleware client interfaces for all backend operations:

```swift
// Core infrastructure client interface
protocol StorageClient {
    func getDocument(path: String) async throws -> Document
    func setDocument(path: String, data: [String: Any]) async throws -> Void
    func updateDocument(path: String, data: [String: Any]) async throws -> Void
    func deleteDocument(path: String) async throws -> Void
    func queryDocuments(collection: String, query: Query) async throws -> [Document]
    func listenToDocument(path: String) -> AsyncStream<Document>
    func listenToCollection(path: String, query: Query?) -> AsyncStream<[Document]>
}
```

### Domain-Specific Middleware Clients

We build domain-specific middleware clients that act as anti-corruption layers between our features and the backend:

```swift
// Domain-specific client
struct UserClient {
    private let storageClient: StorageClient

    init(storageClient: StorageClient) {
        self.storageClient = storageClient
    }

    func getCurrentUser() async throws -> User {
        let document = try await storageClient.getDocument(path: "users/current")
        return User.fromDocument(document)
    }

    func updateProfile(user: User) async throws {
        try await storageClient.updateDocument(
            path: "users/\(user.id)",
            data: user.toDictionary()
        )
    }

    // Other user-related operations
}
```

### Platform-Specific Adapters

We implement adapters for specific platform backend technologies:

```swift
// Firebase adapter for StorageClient
struct FirebaseStorageAdapter: StorageClient {
    func getDocument(path: String) async throws -> Document {
        let snapshot = try await Firestore.firestore().document(path).getDocument()
        guard let data = snapshot.data() else {
            throw StorageError.documentNotFound
        }
        return Document(id: snapshot.documentID, data: data)
    }

    // Other StorageClient methods implemented using Firebase
}
```

### Dependency Registration

We register dependencies using TCA's dependency system:

```swift
// Register infrastructure dependencies
extension StorageClient: DependencyKey {
    static let liveValue: StorageClient = FirebaseStorageAdapter()
    static let testValue: StorageClient = MockStorageClient()
    static let previewValue: StorageClient = PreviewStorageClient()
}

extension DependencyValues {
    var storageClient: StorageClient {
        get { self[StorageClient.self] }
        set { self[StorageClient.self] = newValue }
    }
}
```

## Benefits of Middleware Clients

### 1. Flexibility

- The application can switch to different backend technologies with minimal changes
- New infrastructure technologies can be adopted incrementally
- Legacy systems can be integrated through adapters

### 2. Testability

- Infrastructure can be mocked for testing
- Tests can run without real infrastructure dependencies
- Tests are faster and more reliable

### 3. Maintainability

- Infrastructure changes don't affect application logic
- Infrastructure upgrades can be performed independently
- Technical debt in infrastructure can be addressed without affecting features

### 4. Portability

- The application can run in different environments
- The application can support multiple deployment models
- The application can be migrated to different cloud providers

## Challenges and Mitigations

### 1. Interface Design

**Challenge:** Designing interfaces that are both infrastructure-agnostic and expressive enough.

**Mitigation:**
- Focus on domain operations rather than infrastructure capabilities
- Evolve interfaces based on actual usage patterns
- Accept some infrastructure leakage when necessary for performance or functionality

### 2. Performance Overhead

**Challenge:** Abstraction layers can introduce performance overhead.

**Mitigation:**
- Use efficient mapping between domain models and infrastructure DTOs
- Optimize critical paths
- Profile and benchmark to identify bottlenecks

### 3. Feature Parity

**Challenge:** Different infrastructure technologies may have different capabilities.

**Mitigation:**
- Design interfaces around common capabilities
- Implement feature detection and graceful degradation
- Document infrastructure-specific limitations

## Conclusion

Middleware clients provide a powerful approach for building applications that are resilient to changes in backend technologies. By implementing backend agnostic anti-corruption clients, we create a clean separation between our application features and the underlying platform implementations. Features use middleware clients, and middleware clients use adapters of platform backend clients, creating a flexible, testable, and maintainable architecture that can evolve over time with minimal disruption to the application code.
