# TCA Shared State Migration Plan

## Executive Summary

This migration plan transforms the current LifeSignal architecture to follow the TCA Shared State Pattern, implementing Rust-inspired ownership and mutability constraints that provide compile-time safety guarantees.

**Current State**: Direct shared state mutations using `$shared.withLock`  
**Target State**: Exclusive write access through Clients via `fileprivate init`, read-only access for Features  
**Key Mechanism**: `fileprivate init` enforcement - Clients and shared state in SAME file, Features in SEPARATE files

## Critical Violations Analysis

### 🚨 HIGH PRIORITY VIOLATIONS

#### 1. Missing Read-Only Wrapper Pattern (BREAKS ENFORCEMENT)
**Current**: Direct mutations using `$shared.withLock`
```swift
// ContactsClient.swift - VIOLATES PATTERN  
$contacts.withLock { $0.append(newContact) }  // ❌ Direct mutation
```

**Target**: Read-only wrapper with `fileprivate init`
```swift
// ContactsClient.swift - CORRECT PATTERN
struct ContactsState { var contacts: [Contact] = [] }
struct ReadOnlyContactsState {
    fileprivate init(_ state: ContactsState) { ... }  // ✅ Client can access
}
@DependencyClient struct ContactsClient { ... }  // ✅ Same file = access to fileprivate
```

**Impact**: Without read-only wrappers, Features can directly mutate shared state
**Fix**: Create read-only wrappers WITH `fileprivate init` in Client files

#### 2. Direct Shared State Mutations in Clients
**Violations Found**:
- **ContactsClient.swift**: Lines 438-439, 452-453, 458-462, 490-491, 537-541
- **UserClient.swift**: Lines 671, 718, 744, 756, 771-777, 811  
- **NotificationClient.swift**: Lines 949, 956-959, 966-975
- **SessionClient.swift**: Lines 881-906

**Current Pattern**:
```swift
// ❌ WRONG - Direct mutation
$contacts.withLock { $0.append(newContact) }
```

**Target Pattern**:
```swift
// ✅ CORRECT - Read-only wrapper creation
let newState = ContactsState(contacts: updatedContacts)
sharedState = ReadOnlyContactsState(newState)  // fileprivate access
```

#### 3. Feature Direct Access Violations
**HomeFeature.swift** (Lines 245-276):
```swift
// ❌ WRONG - Feature accessing shared images directly
@Shared(.userQRCodeImage) var qrCodeImage
@Shared(.userShareableQRCodeImage) var shareableImage
```

**Fix**: Route through UserClient methods

## Migration Strategy

### Phase 1: Add Read-Only Wrappers to Existing Client Files (FOUNDATION)

#### 1.1 Update ContactsClient.swift (Add Read-Only Wrapper)
```swift
// UPDATED: ContactsClient.swift - ADD to existing file
import Foundation

// 1. Mutable internal state (private to Client)
struct ContactsState {
    var contacts: [Contact] = []
    var lastSyncTimestamp: Date? = nil
    var isLoading: Bool = false
}

// 2. Read-only wrapper (prevents direct mutation)
struct ReadOnlyContactsState: Equatable {
    private let _state: ContactsState
    fileprivate init(_ state: ContactsState) { self._state = state }  // 🔑 Client can access (same file)
    
    // Read-only access
    var contacts: [Contact] { _state.contacts }
    var lastSyncTimestamp: Date? { _state.lastSyncTimestamp }
    var isLoading: Bool { _state.isLoading }
    var count: Int { _state.contacts.count }
    
    // Computed properties
    var responders: [Contact] { _state.contacts.filter(\.isResponder) }
    var dependents: [Contact] { _state.contacts.filter(\.isDependent) }
    
    func contact(by id: UUID) -> Contact? {
        _state.contacts.first { $0.id == id }
    }
    
    func contactIndex(for id: UUID) -> Int? {
        _state.contacts.firstIndex { $0.id == id }
    }
}

// 3. REPLACE existing shared key with read-only wrapper
extension SharedReaderKey where Self == InMemoryKey<ReadOnlyContactsState>.Default {
    static var contacts: Self {
        Self[.inMemory("contacts"), default: ReadOnlyContactsState(ContactsState())]
    }
}

// 4. Client remains in SAME FILE - enabling fileprivate access
@DependencyClient
struct ContactsClient {
    // ... existing methods
}
```

#### 1.2 Update UserClient.swift (Add Read-Only Wrapper)
```swift
// UPDATED: UserClient.swift - ADD to existing file
import Foundation

// 1. Mutable internal state (private to Client)
struct UserState {
    var user: User? = nil
    var avatarImageData: AvatarImageWithMetadata? = nil
    var qrCodeImageData: QRCodeImageWithMetadata? = nil
    var shareableQRCodeImageData: QRCodeImageWithMetadata? = nil
}

// 2. Read-only wrapper (prevents direct mutation)
struct ReadOnlyUserState: Equatable {
    private let _state: UserState
    fileprivate init(_ state: UserState) { self._state = state }  // 🔑 Client can access (same file)
    
    var user: User? { _state.user }
    var avatarImageData: AvatarImageWithMetadata? { _state.avatarImageData }
    var qrCodeImageData: QRCodeImageWithMetadata? { _state.qrCodeImageData }
    var shareableQRCodeImageData: QRCodeImageWithMetadata? { _state.shareableQRCodeImageData }
    
    // Computed properties
    var isAuthenticated: Bool { _state.user != nil }
    var userName: String { _state.user?.name ?? "" }
    var userPhoneNumber: String { _state.user?.phoneNumber ?? "" }
}

// 3. REPLACE existing shared key with read-only wrapper
extension SharedReaderKey where Self == InMemoryKey<ReadOnlyUserState>.Default {
    static var currentUser: Self {
        Self[.inMemory("currentUser"), default: ReadOnlyUserState(UserState())]
    }
}

// 4. Client remains in SAME FILE - enabling fileprivate access
@DependencyClient
struct UserClient {
    // ... existing methods
}
```

#### 1.3 Update NotificationClient.swift (Add Read-Only Wrapper)
```swift
// UPDATED: NotificationClient.swift - ADD to existing file
import Foundation

// 1. Mutable internal state (private to Client)
struct NotificationsState {
    var notifications: [NotificationItem] = []
    var unreadCount: Int = 0
    var lastUpdateTimestamp: Date? = nil
}

// 2. Read-only wrapper (prevents direct mutation)
struct ReadOnlyNotificationsState: Equatable {
    private let _state: NotificationsState
    fileprivate init(_ state: NotificationsState) { self._state = state }  // 🔑 Client can access (same file)
    
    var notifications: [NotificationItem] { _state.notifications }
    var unreadCount: Int { _state.unreadCount }
    var lastUpdateTimestamp: Date? { _state.lastUpdateTimestamp }
    
    // Computed properties
    var unreadNotifications: [NotificationItem] { 
        _state.notifications.filter { !$0.isRead } 
    }
    var recentNotifications: [NotificationItem] {
        Array(_state.notifications.prefix(10))
    }
    var hasUnreadNotifications: Bool { _state.unreadCount > 0 }
}

// 3. REPLACE existing shared key with read-only wrapper
extension SharedReaderKey where Self == InMemoryKey<ReadOnlyNotificationsState>.Default {
    static var notifications: Self {
        Self[.inMemory("notifications"), default: ReadOnlyNotificationsState(NotificationsState())]
    }
}

// 4. Client remains in SAME FILE - enabling fileprivate access
@DependencyClient
struct NotificationClient {
    // ... existing methods
}
```

#### 1.4 Update SessionClient.swift (Add Read-Only Wrapper)
```swift
// UPDATED: SessionClient.swift - ADD to existing file
import Foundation

// 1. Mutable internal state (private to Client)
struct SessionStateData {
    var sessionState: SessionState = .unauthenticated
    var needsOnboarding: Bool = false
    var authenticationToken: String? = nil
    var isNetworkConnected: Bool = true
    var lastNetworkCheck: Date? = nil
}

// 2. Read-only wrapper (prevents direct mutation)
struct ReadOnlySessionState: Equatable {
    private let _state: SessionStateData
    fileprivate init(_ state: SessionStateData) { self._state = state }  // 🔑 Client can access (same file)
    
    var sessionState: SessionState { _state.sessionState }
    var needsOnboarding: Bool { _state.needsOnboarding }
    var authenticationToken: String? { _state.authenticationToken }
    var isNetworkConnected: Bool { _state.isNetworkConnected }
    var lastNetworkCheck: Date? { _state.lastNetworkCheck }
    
    // Computed properties
    var isAuthenticated: Bool { _state.sessionState.isAuthenticated }
    var hasValidToken: Bool { _state.authenticationToken != nil }
    var isOffline: Bool { !_state.isNetworkConnected }
}

// 3. REPLACE existing shared key with read-only wrapper
extension SharedReaderKey where Self == InMemoryKey<ReadOnlySessionState>.Default {
    static var sessionState: Self {
        Self[.inMemory("sessionState"), default: ReadOnlySessionState(SessionStateData())]
    }
}

// 4. Client remains in SAME FILE - enabling fileprivate access
@DependencyClient
struct SessionClient {
    // ... existing methods
}
```

### Phase 2: Update Client Implementations (REMOVE DIRECT MUTATIONS)

#### 2.1 Update ContactsClient.swift
```swift
// UPDATED: ContactsClient.swift
import Foundation
import ComposableArchitecture

@DependencyClient
struct ContactsClient {
    var loadContacts: @Sendable () async throws -> [Contact] = { [] }
    var addContact: @Sendable (String, String, Bool, Bool) async throws -> Contact = { _, _, _, _ in Contact.mock }
    var updateContact: @Sendable (Contact) async throws -> Contact = { _ in Contact.mock }
    var removeContact: @Sendable (UUID) async throws -> Void = { _ in }
    var getContactByQRCode: @Sendable (String) async throws -> Contact = { _ in Contact.mock }
    var refreshContacts: @Sendable () async throws -> Void = { }
    var startListening: @Sendable () async throws -> Void = { }
    var stopListening: @Sendable () async throws -> Void = { }
}

extension ContactsClient: DependencyKey {
    static let liveValue = ContactsClient(
        addContact: { name, phoneNumber, isResponder, isDependent in
            // 1. gRPC call first
            let request = AddContactRequest(
                name: name,
                phoneNumber: phoneNumber, 
                isResponder: isResponder,
                isDependent: isDependent
            )
            let response = try await contactService.addContact(request)
            let newContact = response.contact.toDomain()
            
            // 2. Update shared state via fileprivate init (ONLY Clients can do this)
            @Shared(.contacts) var sharedContactsState
            var mutableState = ContactsState(
                contacts: sharedContactsState.contacts + [newContact],
                lastSyncTimestamp: Date(),
                isLoading: false
            )
            sharedContactsState = ReadOnlyContactsState(mutableState)  // ✅ fileprivate access
            
            return newContact
        },
        
        updateContact: { contact in
            // 1. gRPC call first
            let request = UpdateContactRequest(contact: contact.toGRPC())
            let response = try await contactService.updateContact(request)
            let updatedContact = response.contact.toDomain()
            
            // 2. Update shared state via fileprivate init
            @Shared(.contacts) var sharedContactsState
            var contacts = sharedContactsState.contacts
            if let index = contacts.firstIndex(where: { $0.id == updatedContact.id }) {
                contacts[index] = updatedContact
            }
            
            let mutableState = ContactsState(
                contacts: contacts,
                lastSyncTimestamp: Date(),
                isLoading: false
            )
            sharedContactsState = ReadOnlyContactsState(mutableState)  // ✅ fileprivate access
            
            return updatedContact
        },
        
        // Stream listener (only place that updates shared state)
        startListening: {
            contactStream.listen { contactUpdate in
                @Shared(.contacts) var contactsState
                
                // Client can create new read-only state (fileprivate access)
                var contacts = contactsState.contacts
                
                // Apply stream update
                switch contactUpdate.operation {
                case .added:
                    contacts.append(contactUpdate.contact)
                case .updated:
                    if let index = contacts.firstIndex(where: { $0.id == contactUpdate.contact.id }) {
                        contacts[index] = contactUpdate.contact
                    }
                case .removed:
                    contacts.removeAll { $0.id == contactUpdate.contact.id }
                }
                
                let mutableState = ContactsState(
                    contacts: contacts,
                    lastSyncTimestamp: Date(),
                    isLoading: false
                )
                
                // Replace with new read-only state
                contactsState = ReadOnlyContactsState(mutableState)  // ✅ fileprivate access
            }
        }
    )
    
    static let testValue = ContactsClient()
    static let mockValue = ContactsClient()
}
```

#### 2.2 Update UserClient.swift
```swift
// UPDATED: UserClient.swift (KEY CHANGES)
extension UserClient: DependencyKey {
    static let liveValue = UserClient(
        updateUser: { user in
            // 1. gRPC call first
            let request = UpdateUserRequest(user: user.toGRPC())
            let response = try await userService.updateUser(request)
            let updatedUser = response.user.toDomain()
            
            // 2. Update shared state via fileprivate init (ONLY Clients can do this)
            @Shared(.currentUser) var sharedUserState
            let mutableState = UserState(
                user: updatedUser,
                avatarImageData: sharedUserState.avatarImageData,
                qrCodeImageData: sharedUserState.qrCodeImageData,
                shareableQRCodeImageData: sharedUserState.shareableQRCodeImageData
            )
            sharedUserState = ReadOnlyUserState(mutableState)  // ✅ fileprivate access
            
            return updatedUser
        },
        
        updateAvatarData: { userId, imageData in
            // 1. Upload to server
            let request = UpdateAvatarRequest(userId: userId, imageData: imageData)
            let response = try await userService.updateAvatar(request)
            
            // 2. Update shared state
            @Shared(.currentUser) var sharedUserState
            let avatarMetadata = AvatarImageWithMetadata(
                image: imageData,
                metadata: AvatarMetadata(userId: userId, uploadedAt: Date())
            )
            
            let mutableState = UserState(
                user: sharedUserState.user,
                avatarImageData: avatarMetadata,
                qrCodeImageData: sharedUserState.qrCodeImageData,
                shareableQRCodeImageData: sharedUserState.shareableQRCodeImageData
            )
            sharedUserState = ReadOnlyUserState(mutableState)  // ✅ fileprivate access
        },
        
        // QR Code generation (moved from HomeFeature)
        generateQRCodeImage: { 
            guard let user = try await getUser() else { throw UserClientError.userNotFound }
            
            let qrImage = try UserClient.generateQRCodeImage(from: user.qrCodeId.uuidString, size: 300)
            let qrMetadata = QRCodeImageWithMetadata(
                image: qrImage.pngData() ?? Data(),
                metadata: QRCodeMetadata(qrCodeId: user.qrCodeId, generatedAt: Date())
            )
            
            @Shared(.currentUser) var sharedUserState
            let mutableState = UserState(
                user: sharedUserState.user,
                avatarImageData: sharedUserState.avatarImageData,
                qrCodeImageData: qrMetadata,
                shareableQRCodeImageData: sharedUserState.shareableQRCodeImageData
            )
            sharedUserState = ReadOnlyUserState(mutableState)  // ✅ fileprivate access
            
            return qrImage
        },
        
        generateShareableQRCodeImage: {
            guard let user = try await getUser() else { throw UserClientError.userNotFound }
            
            // Get or generate base QR code
            @Shared(.currentUser) var sharedUserState
            let qrImage: UIImage
            if let existingData = sharedUserState.qrCodeImageData?.image,
               let existingImage = UIImage(data: existingData) {
                qrImage = existingImage
            } else {
                qrImage = try UserClient.generateQRCodeImage(from: user.qrCodeId.uuidString, size: 300)
            }
            
            let shareableImage = try UserClient.generateShareableQRCodeImage(qrImage: qrImage, userName: user.name)
            let shareableMetadata = QRCodeImageWithMetadata(
                image: shareableImage.pngData() ?? Data(),
                metadata: QRCodeMetadata(qrCodeId: user.qrCodeId, generatedAt: Date())
            )
            
            let mutableState = UserState(
                user: sharedUserState.user,
                avatarImageData: sharedUserState.avatarImageData,
                qrCodeImageData: sharedUserState.qrCodeImageData,
                shareableQRCodeImageData: shareableMetadata
            )
            sharedUserState = ReadOnlyUserState(mutableState)  // ✅ fileprivate access
            
            return shareableImage
        }
    )
}
```

### Phase 3: Update Feature Dependencies (READ-ONLY ACCESS)

#### 3.1 Update HomeFeature.swift
```swift
// UPDATED: HomeFeature.swift (REMOVE DIRECT QR ACCESS)
@Reducer
struct HomeFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.currentUser) var currentUser: ReadOnlyUserState = ReadOnlyUserState(UserState())
        
        // Remove direct QR image access - use computed properties instead
        var qrCodeImage: UIImage? {
            guard let imageData = currentUser.qrCodeImageData?.image else { return nil }
            return UIImage(data: imageData)
        }
        
        var shareableImage: UIImage? {
            guard let imageData = currentUser.shareableQRCodeImageData?.image else { return nil }
            return UIImage(data: imageData)
        }
        
        var isQRCodeReady: Bool { qrCodeImage != nil }
        var isGeneratingQRCode: Bool = false
        // ... rest of state
    }
    
    enum Action {
        case generateQRCode
        case generateShareableQRCode
        case qrCodeGenerated(UIImage?)
        case shareableQRCodeGenerated(UIImage?)
        // ... rest of actions
    }
    
    @Dependency(\.userClient) var userClient  // Use UserClient for QR operations
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .generateQRCode:
                state.isGeneratingQRCode = true
                return .run { send in
                    do {
                        let qrImage = try await userClient.generateQRCodeImage()  // ✅ Through Client
                        await send(.qrCodeGenerated(qrImage))
                    } catch {
                        await send(.qrCodeGenerated(nil))
                    }
                }
                
            case .generateShareableQRCode:
                state.isGeneratingQRCode = true
                return .run { send in
                    do {
                        let shareableImage = try await userClient.generateShareableQRCodeImage()  // ✅ Through Client
                        await send(.shareableQRCodeGenerated(shareableImage))
                    } catch {
                        await send(.shareableQRCodeGenerated(nil))
                    }
                }
                
            case let .qrCodeGenerated(image):
                state.isGeneratingQRCode = false
                // No direct state update needed - shared state already updated by UserClient
                return .none
                
            // ... rest of reducer
            }
        }
    }
}
```

#### 3.2 Update All Features to Use Read-Only State
```swift
// ApplicationFeature.swift
@ObservableState
struct State: Equatable {
    @Shared(.currentUser) var currentUser: ReadOnlyUserState = ReadOnlyUserState(UserState())
    @Shared(.sessionState) var sessionState: ReadOnlySessionState = ReadOnlySessionState(SessionStateData())
    @Shared(.contacts) var contacts: ReadOnlyContactsState = ReadOnlyContactsState(ContactsState())
    // ... etc
}

// ProfileFeature.swift  
@ObservableState
struct State: Equatable {
    @Shared(.currentUser) var currentUser: ReadOnlyUserState = ReadOnlyUserState(UserState())
    @Shared(.sessionState) var sessionState: ReadOnlySessionState = ReadOnlySessionState(SessionStateData())
    // ... etc
}

// Similar updates for all other Features
```

### Phase 4: Remove Legacy Shared Keys (CLEANUP)

#### 4.1 Remove Old Shared Key Definitions
```swift
// DELETE FROM ContactsClient.swift:
extension SharedReaderKey where Self == InMemoryKey<[Contact]>.Default {
    static var contacts: Self { ... }  // ❌ DELETE - Now in ContactsSharedState.swift
}

// DELETE FROM UserClient.swift:
extension SharedReaderKey where Self == InMemoryKey<User?>.Default {
    static var currentUser: Self { ... }  // ❌ DELETE - Now in UserSharedState.swift
}

// Similar cleanup for all Client files
```

### Phase 5: Add Stream Management (REAL-TIME UPDATES)

#### 5.1 Enhanced Stream Handling in Clients
```swift
// ContactsClient.swift - Enhanced stream management
extension ContactsClient: DependencyKey {
    static let liveValue = ContactsClient(
        startListening: {
            // Firebase/gRPC stream listener with proper error handling
            contactStream.listen { result in
                switch result {
                case .success(let contactUpdate):
                    @Shared(.contacts) var contactsState
                    
                    var contacts = contactsState.contacts
                    
                    // Apply atomic stream update
                    switch contactUpdate.operation {
                    case .added:
                        if !contacts.contains(where: { $0.id == contactUpdate.contact.id }) {
                            contacts.append(contactUpdate.contact)
                        }
                    case .updated:
                        if let index = contacts.firstIndex(where: { $0.id == contactUpdate.contact.id }) {
                            contacts[index] = contactUpdate.contact
                        }
                    case .removed:
                        contacts.removeAll { $0.id == contactUpdate.contact.id }
                    }
                    
                    let mutableState = ContactsState(
                        contacts: contacts,
                        lastSyncTimestamp: Date(),
                        isLoading: false
                    )
                    
                    contactsState = ReadOnlyContactsState(mutableState)
                    
                case .failure(let error):
                    // Handle stream errors - could update loading state
                    @Shared(.contacts) var contactsState
                    let mutableState = ContactsState(
                        contacts: contactsState.contacts,
                        lastSyncTimestamp: contactsState.lastSyncTimestamp,
                        isLoading: false
                    )
                    contactsState = ReadOnlyContactsState(mutableState)
                }
            }
        }
    )
}
```

## Migration Checklist

### ✅ Phase 1: Foundation (Critical)
- [ ] Add read-only wrapper to `ContactsClient.swift` (keep Client in same file)
- [ ] Add read-only wrapper to `UserClient.swift` (keep Client in same file)  
- [ ] Add read-only wrapper to `NotificationClient.swift` (keep Client in same file)
- [ ] Add read-only wrapper to `SessionClient.swift` (keep Client in same file)
- [ ] Verify NO Features are in Client files (this breaks enforcement)

### ✅ Phase 2: Client Updates (High Priority)
- [ ] Remove all `$shared.withLock` mutations from ContactsClient
- [ ] Remove all `$shared.withLock` mutations from UserClient
- [ ] Remove all `$shared.withLock` mutations from NotificationClient  
- [ ] Remove all `$shared.withLock` mutations from SessionClient
- [ ] Implement proper read-only state creation with `fileprivate init`

### ✅ Phase 3: Feature Updates (Medium Priority)
- [ ] Update HomeFeature to use UserClient for QR operations
- [ ] Update all Features to use ReadOnly shared state types
- [ ] Remove direct shared state access from Features
- [ ] Verify Features only call Client methods for mutations

### ✅ Phase 4: Cleanup (Low Priority)  
- [ ] Clean up unused imports and code
- [ ] Update documentation and comments
- [ ] Verify architecture compliance

### ✅ Phase 5: Enhancement (Future)
- [ ] Implement enhanced stream error handling
- [ ] Add offline queue support
- [ ] Implement optimistic update patterns
- [ ] Add comprehensive testing

## Verification Steps

### 🔍 Compile-Time Verification
1. **File Separation Check**: Ensure no Feature reducers exist in shared state files
2. **Access Control Check**: Verify Features cannot create `ReadOnlyXState` instances
3. **Mutation Check**: Ensure no `$shared.withLock` calls remain in any code

### 🧪 Runtime Verification  
1. **State Consistency**: Verify shared state updates propagate correctly
2. **Performance**: Ensure no performance regressions
3. **Error Handling**: Test error scenarios and recovery

### 📋 Architecture Compliance
1. **Single Source of Truth**: Only Clients can mutate shared state
2. **Predictable Data Flow**: User Interaction → Feature → Client → Server → Stream → Shared State → UI
3. **No Feature-to-Feature Dependencies**: Communication only through shared state

## Benefits After Migration

### 🛡️ Compile-Time Safety
- **Impossible shared state corruption** by Features
- **Exclusive write access** enforced at compile time  
- **Predictable data flow** with clear boundaries

### 🧹 Clean Architecture
- **Single responsibility**: Features handle UI logic, Clients handle data operations
- **Clear separation**: No mixed concerns between layers
- **Testable**: Each layer can be tested independently

### 🚀 Maintainability  
- **Rust-inspired safety** without runtime overhead
- **Scalable patterns** that grow with the application
- **Developer ergonomics** with clear architectural guidelines

### 🔧 Developer Experience
- **Clear error messages** when patterns are violated
- **IDE support** for identifying mutation attempts
- **Self-documenting** architecture through type system

This migration transforms LifeSignal from a traditional shared state architecture to a Rust-inspired ownership model that prevents entire classes of state corruption bugs while maintaining excellent developer ergonomics and performance.