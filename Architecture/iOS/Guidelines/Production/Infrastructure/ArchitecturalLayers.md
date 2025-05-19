# Architectural Layers

**Navigation:** [Back to Production Guidelines](../README.md) | [Backend Integration](BackendIntegration.md) | [Infrastructure Specification](../../../Specification/Infrastructure/README.md) | [Supabase Overview](SupabaseAdapters/Overview.md) | [Firebase Overview](FirebaseAdapters/Overview.md)

---

## Overview

This document outlines the architectural layers in the LifeSignal iOS application and their responsibilities. The application follows a clean, layered architecture that separates concerns and ensures that each component has a single responsibility. This approach makes the codebase more maintainable, testable, and adaptable to changes.

## Architectural Layers

The LifeSignal application is structured into the following layers, from highest to lowest level:

1. **UI Layer** - SwiftUI views and view modifiers
2. **Reducer Layer** - Business logic and state management
3. **Middleware Client Layer** - Domain-specific client interfaces
4. **Infrastructure Adapter Layer** - Platform-specific implementations
5. **Backend Layer** - External services (Firebase and Supabase)

```
┌─────────────────┐
│                 │
│  UI Layer       │  SwiftUI views and view modifiers
│                 │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│                 │
│  Reducer Layer  │  Business logic and state management
│                 │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│                 │
│  Middleware     │  Domain-specific client interfaces
│  Client Layer   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│                 │
│  Infrastructure │  Platform-specific implementations
│  Adapter Layer  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│                 │
│  Backend Layer  │  External services (Firebase and Supabase)
│                 │
└─────────────────┘
```

## Layer Responsibilities

### 1. UI Layer

The UI Layer is responsible for:

- Presenting the user interface using SwiftUI
- Binding to store state for reactive updates
- Dispatching user actions to the store
- Handling UI-specific logic (animations, transitions, etc.)

```swift
struct ContactsView: View {
    @Bindable var store: StoreOf<ContactsFeature>

    var body: some View {
        List {
            ForEach(store.contacts) { contact in
                ContactRow(contact: contact)
                    .onTapGesture {
                        store.send(.contactSelected(contact.id))
                    }
            }
        }
        .navigationTitle("Contacts")
        .toolbar {
            Button("Add") {
                store.send(.addButtonTapped)
            }
        }
    }
}
```

### 2. Reducer Layer

The Reducer Layer is responsible for all business logic in the application:

- Handling user actions and updating application state
- Orchestrating complex workflows and business rules
- Interacting with backend services exclusively through middleware clients
- Managing side effects using TCA's effect system

**Key Principle**: Reducers should only use middleware clients for backend operations, never directly accessing infrastructure adapters or backend SDKs.

```swift
@Reducer
struct ContactsFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var contacts: [Contact] = []
        var isLoading = false
        var error: Error?
    }

    enum Action: Equatable, Sendable {
        case viewAppeared
        case contactsResponse(TaskResult<[Contact]>)
        case contactSelected(UUID)
        case addButtonTapped
        // Other actions...
    }

    @Dependency(\.contactsClient) var contactsClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .viewAppeared:
                state.isLoading = true
                return .run { send in
                    await send(.contactsResponse(TaskResult {
                        try await contactsClient.fetchContacts()
                    }))
                }

            case let .contactsResponse(.success(contacts)):
                state.isLoading = false
                state.contacts = contacts
                return .none

            case let .contactsResponse(.failure(error)):
                state.isLoading = false
                state.error = error
                return .none

            // Other action handlers...
            }
        }
    }
}
```

### 3. Middleware Client Layer

The Middleware Client Layer provides domain-specific client interfaces that abstract away infrastructure details:

- Providing platform-agnostic interfaces for backend operations
- Abstracting away infrastructure details from reducers
- Using infrastructure adapters to communicate with specific backends
- Handling domain-specific operations and transformations

**Key Principle**: Middleware clients are the only clients that reducers should use.

```swift
// Client interface
@DependencyClient
struct ContactsClient: Sendable {
    var fetchContacts: @Sendable () async throws -> [Contact]
    var addContact: @Sendable (Contact) async throws -> Void
    var updateContact: @Sendable (Contact) async throws -> Void
    var deleteContact: @Sendable (UUID) async throws -> Void
    var streamContacts: @Sendable () -> AsyncStream<[Contact]>
}

// Live implementation
struct LiveContactsClient: ContactsClient {
    private let storageAdapter: StorageClient

    init(storageAdapter: StorageClient) {
        self.storageAdapter = storageAdapter
    }

    func fetchContacts() async throws -> [Contact] {
        let documents = try await storageAdapter.getCollection("contacts")
        return documents.compactMap { Contact.fromDocument($0) }
    }

    func addContact(_ contact: Contact) async throws {
        try await storageAdapter.addDocument(
            "contacts/\(contact.id)",
            data: contact.toDictionary()
        )
    }

    // Other method implementations...
}

// Registration with dependency system
extension ContactsClient: DependencyKey {
    static let liveValue: ContactsClient = LiveContactsClient(
        storageAdapter: FirebaseStorageAdapter()
    )
    static let testValue: ContactsClient = MockContactsClient()
}

extension DependencyValues {
    var contactsClient: ContactsClient {
        get { self[ContactsClient.self] }
        set { self[ContactsClient.self] = newValue }
    }
}
```

### 4. Infrastructure Adapter Layer

The Infrastructure Adapter Layer creates a type-safe bridge for server clients:

- Implementing platform-specific interfaces for Firebase and Supabase
- Handling the technical details of communicating with backend services
- Converting between domain models and backend-specific data formats
- Encapsulating error handling and retry logic

**Key Principle**: Infrastructure adapters should be the only components that directly interact with backend SDKs.

```swift
// Infrastructure-agnostic interface
@DependencyClient
struct StorageClient: Sendable {
    var getDocument: @Sendable (String) async throws -> Document
    var getCollection: @Sendable (String) async throws -> [Document]
    var addDocument: @Sendable (String, [String: Any]) async throws -> Void
    var updateDocument: @Sendable (String, [String: Any]) async throws -> Void
    var deleteDocument: @Sendable (String) async throws -> Void
    var streamDocument: @Sendable (String) -> AsyncStream<Document>
    var streamCollection: @Sendable (String) -> AsyncStream<[Document]>
}

// Firebase implementation
struct FirebaseStorageAdapter: StorageClient {
    private let firestore = Firestore.firestore()

    func getDocument(_ path: String) async throws -> Document {
        let snapshot = try await firestore.document(path).getDocument()
        guard let data = snapshot.data() else {
            throw StorageError.documentNotFound
        }
        return Document(id: snapshot.documentID, data: data)
    }

    func getCollection(_ path: String) async throws -> [Document] {
        let snapshot = try await firestore.collection(path).getDocuments()
        return snapshot.documents.map { doc in
            Document(id: doc.documentID, data: doc.data())
        }
    }

    // Other method implementations...
}

// Supabase implementation
struct SupabaseStorageAdapter: StorageClient {
    private let supabase = SupabaseClient.shared

    func getDocument(_ path: String) async throws -> Document {
        let components = path.split(separator: "/")
        guard components.count == 2 else {
            throw StorageError.invalidPath
        }

        let table = String(components[0])
        let id = String(components[1])

        let response = try await supabase.from(table).select().eq("id", value: id).single().execute()
        guard let data = response.data else {
            throw StorageError.documentNotFound
        }

        return Document(id: id, data: data)
    }

    // Other method implementations...
}
```

### 5. Backend Layer

The Backend Layer consists of external services:

- Firebase for authentication and data storage
- Supabase for cloud functions and serverless computing
- Other third-party services as needed

## Communication Between Layers

Communication between layers follows these rules:

1. **Downward Dependencies Only**: Each layer can only depend on layers below it
2. **Interface-Based Communication**: Higher layers depend on interfaces, not concrete implementations
3. **Dependency Injection**: Dependencies are injected via TCA's dependency system
4. **No Skipping Layers**: No layer should skip intermediate layers

## Testing Strategy

This layered architecture enables effective testing:

1. **UI Tests**: Test the UI layer in isolation with mock stores
2. **Reducer Tests**: Test reducers with mock middleware clients
3. **Middleware Client Tests**: Test middleware clients with mock adapters
4. **Adapter Tests**: Test adapters with mock backend services

## Conclusion

By following this layered architecture with clear responsibilities for each layer, the LifeSignal application achieves:

1. **Separation of Concerns**: Each layer has a single responsibility
2. **Testability**: Each layer can be tested in isolation
3. **Flexibility**: Backend implementations can be changed without affecting business logic
4. **Maintainability**: Changes in one layer don't ripple through the entire codebase
5. **Scalability**: New features can be added without modifying existing code

Remember that reducers are responsible for business logic, middleware clients are the only clients reducers should use, and infrastructure adapters create a type-safe bridge for server clients.
