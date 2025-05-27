# TCA Shared State Pattern: Rust-Inspired Mutability Architecture

## Overview

This architectural pattern brings Rust's ownership and mutability concepts into Swift's The Composable Architecture (TCA), enforcing **exclusive write access** through Clients while giving Features **read-only access** to shared state.

## Core Principles

### 1. **Mutability Constraints (Compile-Time Enforced)**
- **Clients**: Exclusive write access to shared state (`&mut T` equivalent)
- **Features**: Read-only access to shared state (`&T` equivalent)  
- **Enforcement**: `fileprivate init` prevents Features from creating mutable state

### 2. **Compile-Time Safety Mechanism**
```swift
// ✅ In ContactsClient.swift - Can access fileprivate init
let mutableState = ContactsState(contacts: newContacts)
sharedState = ReadOnlyContactsState(mutableState)  // fileprivate access

// ❌ In any Feature file - COMPILE ERROR
// let mutableState = ContactsState(contacts: newContacts)  // Cannot access fileprivate init
// sharedState = ReadOnlyContactsState(mutableState)        // COMPILE ERROR
```

### 3. **Data Flow Direction**
```
User Interaction → Feature → Client → gRPC → Server → Stream → Shared State → Feature UI Update
```

### 4. **Dependency Rules**
- **No Client-to-Client dependencies** (except SessionClient orchestration)
- **Features depend on Clients** for mutations
- **Shared state is the communication layer** between Features

## 🚨 Golden Rule: File Separation

### **CRITICAL: Never put Feature reducers in the same file as Shared State + Client**

```swift
// ❌ WRONG - This breaks compile-time enforcement
// ContactsClient.swift
struct ContactsState { ... }
struct ReadOnlyContactsState { fileprivate init(...) }
@DependencyClient struct ContactsClient { ... }
@Reducer struct SomeFeature { ... }  // ❌ Can access fileprivate init!

// ✅ CORRECT - Separate files maintain compile-time barriers
// ContactsClient.swift
struct ContactsState { ... }
struct ReadOnlyContactsState { fileprivate init(...) }  // 🔒 Protected
@DependencyClient struct ContactsClient { ... }         // ✅ Can access

// SomeFeature.swift  
@Reducer struct SomeFeature {
    @Shared(.contacts) var contactsState: ReadOnlyContactsState  // ✅ Read-only
    // Cannot create ReadOnlyContactsState(...) - COMPILE ERROR    // 🔒 Protected
}
```

**Why this matters:**
- `fileprivate init` only works when Feature and Client are in **different files**
- Same file = Feature can access `fileprivate init` = Pattern broken
- **File separation is the enforcement mechanism** for the entire pattern

## Architecture Layers

### **UI Layer (SwiftUI Views)**
```swift
struct ContactDetailsView: View {
    let store: StoreOf<ContactDetailsFeature>
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            TextField("Name", text: viewStore.binding(
                get: \.contact.name,
                send: ContactDetailsFeature.Action.nameChanged
            ))
        }
    }
}
```

### **Feature Layer (TCA Reducers)**
```swift
@Reducer
struct ContactDetailsFeature {
    @ObservableState
    struct State {
        @Shared(.contacts) var contactsState: ReadOnlyContactsState  // READ-ONLY access
        var localContact: Contact                                    // Local optimistic state
        var isSaving: Bool = false
        var errorMessage: String?
        
        // Computed properties for convenient access
        var contacts: [Contact] { contactsState.contacts }
    }
    
    enum Action {
        case nameChanged(String)
        case saveContact
        case saveResponse(Result<Contact, Error>)
    }
    
    @Dependency(\.contactsClient) var contactsClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .nameChanged(name):
                // Immediate UI update with local state
                state.localContact.name = name
                return .none
                
            case .saveContact:
                state.isSaving = true
                return .run { [contact = state.localContact] send in
                    do {
                        // Client handles all mutations
                        let updatedContact = try await contactsClient.updateContact(contact)
                        await send(.saveResponse(.success(updatedContact)))
                    } catch {
                        await send(.saveResponse(.failure(error)))
                    }
                }
                
            case let .saveResponse(.success(contact)):
                state.isSaving = false
                // Shared state updated via stream, local state reconciles
                return .none
                
            case let .saveResponse(.failure(error)):
                state.isSaving = false
                state.errorMessage = error.localizedDescription
                return .none
            }
        }
    }
}
```

### **Client Layer (Dependency Clients)**
```swift
@DependencyClient
struct ContactsClient {
    // EXCLUSIVE WRITE ACCESS to shared state
    var loadContacts: @Sendable () async throws -> [Contact] = { [] }
    var addContact: @Sendable (Contact) async throws -> Contact = { _ in Contact.mock }
    var updateContact: @Sendable (Contact) async throws -> Contact = { _ in Contact.mock }
    var deleteContact: @Sendable (UUID) async throws -> Void = { _ in }
    
    // Stream management
    var startListening: @Sendable () async throws -> Void = { }
    var stopListening: @Sendable () async throws -> Void = { }
}

extension ContactsClient {
    static let mockValue = ContactsClient(
        loadContacts: {
            // gRPC call to load contacts
            let response = try await contactService.getContacts(request)
            let contacts = response.contacts.map { $0.toDomain() }
            
            // Update shared state via fileprivate init (ONLY Clients can do this)
            @Shared(.contacts) var sharedContactsState
            let newState = ContactsState(contacts: contacts)
            sharedContactsState = ReadOnlyContactsState(newState)  // ✅ fileprivate access
            
            return contacts
        },
        
        updateContact: { contact in
            // gRPC call first
            let request = UpdateContactRequest(contact: contact, authToken: authToken)
            let response = try await contactService.updateContact(request)
            
            // Stream will handle shared state update via fileprivate init
            // No direct manipulation here in production
            
            return response.contact.toDomain()
        },
        
        startListening: {
            // Firebase/gRPC stream listener
            contactStream.listen { contactUpdate in
                @Shared(.contacts) var contactsState
                
                // Client can create new read-only state (fileprivate access)
                var mutableState = ContactsState(contacts: contactsState.contacts)
                
                // Apply stream update to mutable copy
                if let index = mutableState.contacts.firstIndex(where: { $0.id == contactUpdate.id }) {
                    mutableState.contacts[index] = contactUpdate
                } else {
                    mutableState.contacts.append(contactUpdate)
                }
                
                // Replace with new read-only state
                contactsState = ReadOnlyContactsState(mutableState)  // ✅ fileprivate access
            }
        }
    )
}
```

### **Shared State Layer (Compile-Time Enforcement)**
```swift
// 1. Mutable internal state (private to Client files)
struct ContactsState {
    var contacts: [Contact] = []
}

// 2. Read-only wrapper (prevents direct mutation)
struct ReadOnlyContactsState {
    private let _state: ContactsState
    fileprivate init(_ state: ContactsState) { self._state = state }  // 🔑 KEY ENFORCEMENT
    
    var contacts: [Contact] { _state.contacts }
    var count: Int { _state.contacts.count }
    
    func contact(by id: UUID) -> Contact? {
        _state.contacts.first { $0.id == id }
    }
}

// 3. Shared key stores read-only wrapper
extension SharedReaderKey where Self == InMemoryKey<ReadOnlyContactsState>.Default {
    static var contacts: Self {
        Self[.inMemory("contacts"), default: ReadOnlyContactsState(ContactsState())]
    }
}

// Similar pattern for other shared state
struct NotificationsState {
    var notifications: [NotificationItem] = []
    var unreadCount: Int = 0
}

struct ReadOnlyNotificationsState {
    private let _state: NotificationsState
    fileprivate init(_ state: NotificationsState) { self._state = state }
    
    var notifications: [NotificationItem] { _state.notifications }
    var unreadCount: Int { _state.unreadCount }
    var unreadNotifications: [NotificationItem] { 
        _state.notifications.filter { !$0.isRead } 
    }
}

extension SharedReaderKey where Self == InMemoryKey<ReadOnlyNotificationsState>.Default {
    static var notifications: Self {
        Self[.inMemory("notifications"), default: ReadOnlyNotificationsState(NotificationsState())]
    }
}
```

## Session Orchestration Pattern

### **SessionClient: The Only Cross-Client Coordinator**
```swift
@DependencyClient  
struct SessionClient {
    // Can depend on other Clients for orchestration
    var contactsClient: ContactsClient
    var notificationClient: NotificationClient
    var userClient: UserClient
    
    // Multi-domain operations
    var clearAllReceivedPings: @Sendable () async throws -> Void = { }
    var signOut: @Sendable () async throws -> Void = { }
    var deleteAccount: @Sendable () async throws -> Void = { }
}

extension SessionClient {
    static let mockValue = SessionClient(
        clearAllReceivedPings: {
            // Single atomic gRPC operation
            let clearRequest = ClearAllPingsRequest(
                userId: currentUser.id,
                authToken: authToken
            )
            
            // Server handles all coordination atomically:
            // 1. Send acknowledgment notifications to contacts
            // 2. Clear user's received ping notifications
            // 3. Update contact ping states
            // 4. Add clear action to notification history
            try await sessionService.clearAllReceivedPings(clearRequest)
            
            // Multiple streams update their respective shared states:
            // - @Shared(.notifications) updates
            // - @Shared(.contacts) updates
            // - Features observe changes automatically
        },
        
        signOut: {
            // Coordinate cleanup across all domains
            try await userClient.signOut()
            try await notificationClient.cleanup()
            try await contactsClient.stopListening()
            
            // Clear all shared state
            @Shared(.currentUser) var user
            @Shared(.contacts) var contacts  
            @Shared(.notifications) var notifications
            
            $user.withLock { $0 = nil }
            $contacts.withLock { $0.removeAll() }
            $notifications.withLock { $0.removeAll() }
        }
    )
}
```

## Communication Patterns

### **Feature-to-Feature Communication**
```swift
// ❌ Direct communication (prevented by architecture)
// otherFeature.updateSomething()

// ✅ Shared state observation (automatic)
@Reducer
struct HomeFeature {
    @ObservableState
    struct State {
        @Shared(.contacts) var contacts: [Contact]  // Observes changes
        @Shared(.notifications) var notifications: [NotificationItem]
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            // Automatically receives updates when:
            // - ProfileFeature updates a contact via ContactsClient
            // - NotificationFeature clears notifications via NotificationClient
            // - Any other Feature modifies shared state through Clients
        }
    }
}
```

### **Optimistic Updates Pattern**
```swift
@Reducer
struct ContactEditFeature {
    @ObservableState  
    struct State {
        @Shared(.contacts) var contacts: [Contact]    // Server truth
        var editingContact: Contact                   // Local optimistic state
        var hasUnsavedChanges: Bool = false
        var isSaving: Bool = false
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .fieldChanged(field, value):
                // Immediate UI response
                state.editingContact = state.editingContact.updating(field, value)
                state.hasUnsavedChanges = true
                return .none
                
            case .save:
                state.isSaving = true
                return .run { [contact = state.editingContact] send in
                    try await contactsClient.updateContact(contact)
                    // Stream updates @Shared(.contacts)
                    // UI reconciles automatically
                    await send(.saveCompleted)
                }
                
            case .saveCompleted:
                state.isSaving = false
                state.hasUnsavedChanges = false
                // state.editingContact reconciles with shared state
                return .none
            }
        }
    }
}
```

## Error Handling Patterns

### **Client-Level Error Handling**
```swift
extension ContactsClient {
    static let mockValue = ContactsClient(
        updateContact: { contact in
            do {
                let response = try await contactService.updateContact(contact)
                // Success - stream will update shared state
                return response.contact.toDomain()
            } catch NetworkError.noConnection {
                // Queue for offline retry
                await offlineQueue.enqueue(.updateContact(contact))
                throw ContactClientError.offline("Changes will sync when online")
            } catch {
                // Server error - no shared state corruption
                throw ContactClientError.serverError(error.localizedDescription)
            }
        }
    )
}
```

### **Feature-Level Error Handling**
```swift
case .saveContact:
    state.isSaving = true
    state.errorMessage = nil
    return .run { [contact = state.editingContact] send in
        do {
            try await contactsClient.updateContact(contact)
            await send(.saveSuccess)
        } catch ContactClientError.offline(let message) {
            await send(.saveFailure(message, isOffline: true))
        } catch {
            await send(.saveFailure(error.localizedDescription, isOffline: false))
        }
    }

case let .saveFailure(message, isOffline):
    state.isSaving = false
    state.errorMessage = message
    state.showOfflineIndicator = isOffline
    // Local state preserved for retry
    return .none
```

## Testing Patterns

### **Feature Testing** 
```swift
func testContactNameUpdate() async {
    let store = TestStore(initialState: ContactEditFeature.State(
        editingContact: Contact.mock
    )) {
        ContactEditFeature()
    } withDependencies: {
        $0.contactsClient.updateContact = { contact in
            // Mock successful update
            return contact
        }
    }
    
    // Test local state changes (immediate)
    await store.send(.nameChanged("New Name")) {
        $0.editingContact.name = "New Name"
        $0.hasUnsavedChanges = true
    }
    
    // Test save flow
    await store.send(.save) {
        $0.isSaving = true
    }
    
    await store.receive(.saveCompleted) {
        $0.isSaving = false
        $0.hasUnsavedChanges = false
    }
}
```

### **Client Testing**
```swift
func testContactsClientUpdate() async {
    let mockService = MockContactService()
    let client = ContactsClient.live(service: mockService)
    
    // Test gRPC integration
    let contact = Contact.mock
    let updatedContact = try await client.updateContact(contact)
    
    XCTAssertEqual(updatedContact.id, contact.id)
    XCTAssertTrue(mockService.updateContactCalled)
}
```

## Benefits

### **1. Architectural Guarantees**
- **No accidental shared state corruption** by Features
- **Single source of truth** for mutations (Clients)
- **Predictable data flow** (always through Clients)

### **2. Rust-Inspired Safety**
- **Compile-time prevention** of direct mutations
- **Exclusive write access** through Client interfaces
- **Automatic change propagation** via shared state observation

### **3. Clean Separation of Concerns**
- **Features**: Business logic + UI state + user interactions
- **Clients**: Data persistence + network operations + state mutations  
- **Shared State**: Cross-feature communication + caching

### **4. Testability**
- **Mock Clients** for Feature testing
- **Independent testing** of each layer
- **Clear boundaries** for unit vs integration tests

### **5. Scalability**
- **No Feature-to-Feature coupling**
- **SessionClient orchestration** for complex operations
- **Stream-based consistency** across all Features

## Migration Strategy

### **Phase 1: Identify Shared State**
```swift
// Current direct manipulation
$contacts.withLock { $0.append(newContact) }

// Target Client-mediated pattern  
try await contactsClient.addContact(newContact)
```

### **Phase 2: Extract Client Interfaces**
```swift
// Move mutations from Features to Clients
@DependencyClient
struct ContactsClient {
    var addContact: (Contact) async throws -> Contact
    var updateContact: (Contact) async throws -> Contact  
    var deleteContact: (UUID) async throws -> Void
}
```

### **Phase 3: Create Read-Only Wrappers (🚨 CRITICAL FILE ORGANIZATION)**
```swift
// ContactsClient.swift - ONLY Client + Shared State
struct ContactsState { var contacts: [Contact] = [] }
struct ReadOnlyContactsState { 
    fileprivate init(_ state: ContactsState) { ... }  // 🔒 Protected
}
@DependencyClient struct ContactsClient { ... }

// ✅ Features MUST be in separate files for enforcement
// ContactDetailsFeature.swift - ONLY Feature code
@Reducer struct ContactDetailsFeature { ... }
```

### **Phase 4: Update Features**
```swift
// Remove direct shared state mutations
// Add Client dependencies
// Implement optimistic local state patterns
// ENSURE Features are in separate files from Clients
```

### **Phase 5: Add Stream Management**
```swift
// Implement real-time stream listeners in Clients
// Remove manual shared state updates from business logic
// Let streams handle all shared state synchronization
```

### **🚨 Migration Checklist**
- [ ] **File separation**: No Feature reducers in Client files
- [ ] **Read-only wrappers**: All shared state uses `fileprivate init`
- [ ] **Client dependencies**: Features call Clients for mutations
- [ ] **Stream management**: Clients handle shared state updates
- [ ] **Compile-time verification**: Features cannot create mutable state

This pattern provides **architectural safety** while maintaining **developer ergonomics**, ensuring shared state consistency and preventing entire classes of bugs through compile-time constraints.