# Data Persistence and Streaming Strategy

**Navigation:** [Back to Infrastructure Layer](README.md) | [Firebase Integration](Firebase/README.md)

---

## Overview

This document outlines the strategy for implementing user data and contact collection persistence with streamed updates in the LifeSignal iOS application. It covers both the migration from the mock implementation to The Composable Architecture (TCA) and the long-term approach for handling real-time data synchronization between the client and server.

The persistence and streaming strategy follows a layered approach where platform-agnostic clients use platform-specific clients to interact with backend services. This design allows for flexibility in switching between different backend technologies (such as Firebase and Supabase) without affecting the rest of the application.

## Core Requirements

1. **User Data Persistence**: Store and retrieve user profile information
2. **Contact Collection Persistence**: Maintain a collection of user contacts with their relationships and status
3. **Streamed Updates**: Receive real-time updates from the server to the client
4. **Regular API Calls**: Use standard API calls to update server data
5. **Offline Support**: Cache data locally for offline access
6. **Synchronization**: Ensure data consistency between client and server

## Architecture Components

### 1. Client Interfaces

Client interfaces define the contract between the application and the infrastructure layer. They are protocol-based and infrastructure-agnostic. These interfaces are implemented by platform-agnostic clients, which in turn use platform-specific clients to interact with backend services.

```swift
// UserClientProtocol.swift
public protocol UserClientProtocol: Sendable {
    /// Get user document once
    func getUserDocument(_ userId: String) async throws -> UserModel

    /// Stream user document updates
    func streamUser(_ userId: String) -> AsyncStream<UserModel>

    /// Update user document
    func updateUserDocument(_ userId: String, _ data: [String: Any]) async throws -> Bool

    /// Update user profile
    func updateProfile(_ userId: String, _ profileUpdate: ProfileUpdate) async throws -> Bool

    /// Update notification preferences
    func updateNotificationPreferences(_ userId: String, _ preferences: NotificationPreferences) async throws -> Bool
}

// ContactsClientProtocol.swift
public protocol ContactsClientProtocol: Sendable {
    /// Stream contacts collection updates
    func streamContacts(_ userId: String) -> AsyncStream<[ContactModel]>

    /// Get contacts collection once
    func getContacts(_ userId: String) async throws -> [ContactModel]

    /// Add a new contact
    func addContact(_ userId: String, _ contactId: String, _ data: [String: Any]) async throws

    /// Update a contact
    func updateContact(_ userId: String, _ contactId: String, _ data: [String: Any]) async throws

    /// Delete a contact
    func deleteContact(_ userId: String, _ contactId: String) async throws

    /// Lookup a user by QR code
    func lookupUserByQRCode(_ qrCode: String) async throws -> UserModel
}
```

### 2. Persistence Strategies

The application uses multiple persistence strategies depending on the data type and requirements:

#### Server-Side Persistence (Firebase Firestore)

Primary storage for all user data and contacts, providing:
- Real-time synchronization
- Data consistency across devices
- Backup and recovery
- User authentication integration

#### Client-Side Persistence

Multiple layers of client-side persistence:

1. **TCA @Shared State** - For state that needs to be shared across features
   ```swift
   @Reducer
   struct UserFeature {
       @ObservableState
       struct State: Equatable {
           @Shared(.fileStorage(.userProfile)) var user: UserModel = UserModel(id: "")
           // Other state properties...
       }
       // Actions and reducer implementation...
   }
   ```

2. **File Storage** - For larger data structures and complex objects
   ```swift
   @Shared(.fileStorage(URL(fileURLWithPath: "contacts.json"))) var contacts: IdentifiedArrayOf<ContactModel> = []
   ```

3. **UserDefaults** - For simple preferences and settings
   ```swift
   @Shared(.appStorage("notificationPreferences")) var preferences: NotificationPreferences = .default
   ```

4. **In-Memory Cache** - For temporary data and performance optimization
   ```swift
   @Shared(.inMemory("currentSession")) var session: SessionData = SessionData()
   ```

### 3. Platform-Agnostic Clients

Platform-agnostic clients implement the client interfaces and use platform-specific clients to interact with backend services. This approach allows the application to switch between different backend technologies without changing the client interfaces or the features that use them.

```swift
// UserClient.swift
struct UserClient: UserClientProtocol {
    private let platformClient: any UserClientProtocol

    init(provider: InfrastructureProvider = Current.infrastructureProvider()) {
        self.platformClient = InfrastructureFactory.createUserClient(provider: provider)
    }

    func getUserDocument(_ userId: String) async throws -> UserModel {
        return try await platformClient.getUserDocument(userId)
    }

    func streamUser(_ userId: String) -> AsyncStream<UserModel> {
        return platformClient.streamUser(userId)
    }

    // Other method implementations...
}

// ContactsClient.swift
struct ContactsClient: ContactsClientProtocol {
    private let platformClient: any ContactsClientProtocol

    init(provider: InfrastructureProvider = Current.infrastructureProvider()) {
        self.platformClient = InfrastructureFactory.createContactsClient(provider: provider)
    }

    func streamContacts(_ userId: String) -> AsyncStream<[ContactModel]> {
        return platformClient.streamContacts(userId)
    }

    // Other method implementations...
}
```

### 4. Platform-Specific Clients

Platform-specific clients implement the actual integration with backend services. Currently, Firebase is the primary backend service, but in the future, Supabase will be used for some functionality.

```swift
// FirebaseUserClient.swift
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

    func streamUser(_ userId: String) -> AsyncStream<UserModel> {
        AsyncStream { continuation in
            let path = FirestorePath(path: "users/\(userId)")
            let listener = typedFirestore.addSnapshotListener(
                path,
                UserModelFirestoreConvertible.self,
                .default
            ) { result in
                switch result {
                case .success(let snapshot):
                    continuation.yield(snapshot.data)
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

// FirebaseContactsClient.swift
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

### 5. Mock Clients

Mock clients implement the client interfaces for testing and development:

```swift
// MockUserClient.swift
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

    func streamUser(_ userId: String) -> AsyncStream<UserModel> {
        AsyncStream { continuation in
            // Initial value
            Task {
                let user = try await getUserDocument(userId)
                continuation.yield(user)
            }

            // Set up notification observer for changes
            let observer = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("UserUpdated"),
                object: nil,
                queue: .main
            ) { _ in
                Task {
                    let user = try await getUserDocument(userId)
                    continuation.yield(user)
                }
            }

            continuation.onTermination = { _ in
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    // Other method implementations...
}

// MockContactsClient.swift
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

### 6. Dependency Injection

Client interfaces are registered as dependencies in TCA. The platform-agnostic clients are registered with the dependency injection system, and they in turn use the appropriate platform-specific clients based on the current infrastructure provider:

```swift
// DependencyValues+Extensions.swift
extension DependencyValues {
    var userClient: any UserClientProtocol {
        get { self[UserClientKey.self] }
        set { self[UserClientKey.self] = newValue }
    }

    var contactsClient: any ContactsClientProtocol {
        get { self[ContactsClientKey.self] }
        set { self[ContactsClientKey.self] = newValue }
    }
}

private enum UserClientKey: DependencyKey {
    static let liveValue: any UserClientProtocol = UserClient()
    static let testValue: any UserClientProtocol = MockUserClient()
}

private enum ContactsClientKey: DependencyKey {
    static let liveValue: any ContactsClientProtocol = ContactsClient()
    static let testValue: any ContactsClientProtocol = MockContactsClient()
}

// Infrastructure provider dependency
private enum InfrastructureProviderKey: DependencyKey {
    static let liveValue: InfrastructureProvider = .firebase
    static let testValue: InfrastructureProvider = .mock
}

extension DependencyValues {
    var infrastructureProvider: InfrastructureProvider {
        get { self[InfrastructureProviderKey.self] }
        set { self[InfrastructureProviderKey.self] = newValue }
    }
}
```

## Feature Implementation

### 1. User Feature

The UserFeature manages user profile data and operations:

```swift
@Reducer
struct UserFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.fileStorage(.userProfile)) var user: UserModel = UserModel(id: "")
        var isLoading: Bool = false
        var error: UserFacingError?
    }

    enum Action {
        case loadUser
        case userLoaded(UserModel)
        case userLoadFailed(UserFacingError)
        case updateProfile(ProfileUpdate)
        case profileUpdateSucceeded
        case profileUpdateFailed(UserFacingError)
        case streamUserUpdates
        case userUpdated(UserModel)
    }

    @Dependency(\.userClient) var userClient
    @Dependency(\.authClient) var authClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadUser:
                state.isLoading = true
                return .run { [userClient, authClient] send in
                    do {
                        let userId = try await authClient.currentUserId()
                        let user = try await userClient.getUserDocument(userId)
                        await send(.userLoaded(user))
                    } catch {
                        await send(.userLoadFailed(UserFacingError.from(error)))
                    }
                }

            case let .userLoaded(user):
                state.user = user
                state.isLoading = false
                return .none

            case .streamUserUpdates:
                return .run { [authClient, userClient] send in
                    do {
                        let userId = try await authClient.currentUserId()
                        for await user in userClient.streamUser(userId) {
                            await send(.userUpdated(user))
                        }
                    } catch {
                        // Handle stream error
                    }
                }

            case let .userUpdated(user):
                state.user = user
                return .none

            // Other action handlers...
            }
        }
    }
}
```

### 2. Contacts Feature

The ContactsFeature manages contact collection data and operations:

```swift
@Reducer
struct ContactsFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.fileStorage(.contacts)) var contacts: IdentifiedArrayOf<ContactModel> = []
        var isLoading: Bool = false
        var error: UserFacingError?
    }

    enum Action {
        case loadContacts
        case contactsLoaded([ContactModel])
        case contactsLoadFailed(UserFacingError)
        case addContact(String, [String: Any])
        case contactAdded
        case contactAddFailed(UserFacingError)
        case updateContact(String, [String: Any])
        case contactUpdated
        case contactUpdateFailed(UserFacingError)
        case deleteContact(String)
        case contactDeleted
        case contactDeleteFailed(UserFacingError)
        case streamContactUpdates
        case contactsUpdated([ContactModel])
    }

    @Dependency(\.contactsClient) var contactsClient
    @Dependency(\.authClient) var authClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadContacts:
                state.isLoading = true
                return .run { [contactsClient, authClient] send in
                    do {
                        let userId = try await authClient.currentUserId()
                        let contacts = try await contactsClient.getContacts(userId)
                        await send(.contactsLoaded(contacts))
                    } catch {
                        await send(.contactsLoadFailed(UserFacingError.from(error)))
                    }
                }

            case let .contactsLoaded(contacts):
                state.contacts = IdentifiedArray(uniqueElements: contacts)
                state.isLoading = false
                return .none

            case .streamContactUpdates:
                return .run { [authClient, contactsClient] send in
                    do {
                        let userId = try await authClient.currentUserId()
                        for await contacts in contactsClient.streamContacts(userId) {
                            await send(.contactsUpdated(contacts))
                        }
                    } catch {
                        // Handle stream error
                    }
                }

            case let .contactsUpdated(contacts):
                state.contacts = IdentifiedArray(uniqueElements: contacts)
                return .none

            // Other action handlers...
            }
        }
    }
}
```

### 3. App Feature

The AppFeature coordinates the streaming of data at the application level:

```swift
@Reducer
struct AppFeature {
    @ObservableState
    struct State {
        var user: UserFeature.State = .init()
        var contacts: ContactsFeature.State = .init()
        var isAuthenticated: Bool = false
        var needsOnboarding: Bool = false
        // Other app state...
    }

    enum Action {
        case user(UserFeature.Action)
        case contacts(ContactsFeature.Action)
        case onAppear
        case signIn
        case signOut
        // Other app actions...
    }

    @Dependency(\.authClient) var authClient

    var body: some ReducerOf<Self> {
        Scope(state: \.user, action: \.user) {
            UserFeature()
        }

        Scope(state: \.contacts, action: \.contacts) {
            ContactsFeature()
        }

        Reduce { state, action in
            switch action {
            case .onAppear:
                // Start streaming user and contacts data
                return .merge(
                    .send(.user(.streamUserUpdates)),
                    .send(.contacts(.streamContactUpdates))
                )

            case .signIn:
                state.isAuthenticated = true
                // Load initial data
                return .merge(
                    .send(.user(.loadUser)),
                    .send(.contacts(.loadContacts))
                )

            // Other action handlers...
            }
        }
    }
}
```

## Streaming Best Practices

### 1. Stream at the Top Level

Stream Firebase data at the top level of the application to ensure a single source of truth:

```swift
@Reducer
struct AppFeature {
    // State, Action, etc.

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appDidLaunch:
                return .run { send in
                    for await user in await authClient.authStateStream() {
                        await send(.authStateChanged(user))
                    }
                }
                .cancellable(id: CancelID.authStateStream)

            // Other action handlers...
            }
        }
    }
}
```

### 2. Use AsyncStream

Use AsyncStream to wrap Firebase listeners for type safety and proper resource management:

```swift
func authStateStream() -> AsyncStream<User?> {
    AsyncStream { continuation in
        let listener = Auth.auth().addStateDidChangeListener { _, firebaseUser in
            if let firebaseUser = firebaseUser {
                let user = User(firebaseUser: firebaseUser)
                continuation.yield(user)
            } else {
                continuation.yield(nil)
            }
        }

        continuation.onTermination = { _ in
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
}
```

### 3. Properly Cancel Streams

Ensure streams are properly cancelled when no longer needed:

```swift
case .viewWillDisappear:
    return .cancel(id: CancelID.contactsStream)
```

### 4. Handle Stream Errors

Handle stream errors at the appropriate level:

```swift
return .run { send in
    do {
        for try await contacts in await firestoreClient.listenToCollection(path) {
            await send(.contactsUpdated(contacts))
        }
    } catch {
        await send(.contactsStreamFailed(error))
    }
}
```

## Offline Support

### 1. Firebase Offline Persistence

Enable Firebase offline persistence to cache data locally:

```swift
// AppDelegate.swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Configure Firebase
    FirebaseApp.configure()

    // Enable offline persistence
    let settings = FirestoreSettings()
    settings.isPersistenceEnabled = true
    settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
    Firestore.firestore().settings = settings

    return true
}
```

### 2. Local Caching Strategy

Implement a multi-layered caching strategy:

1. **Firebase Cache**: Primary cache for all Firebase data
2. **TCA @Shared State**: Persistent state using file storage
3. **UserDefaults**: Simple preferences and settings
4. **In-Memory Cache**: Temporary data for performance

### 3. Sync Behavior

Define clear sync behavior for offline operations:

1. **Background Sync**: Attempt to sync data when app is in background
2. **Conflict Resolution**: Use server timestamp for conflict resolution
3. **Critical Actions**: Prioritize critical actions (alerts, check-ins) for sync

## Migration Strategy

### 1. Phase 1: Infrastructure Layer

1. Define client interfaces (UserClientProtocol, ContactsClientProtocol)
2. Implement platform-agnostic clients (UserClient, ContactsClient)
3. Implement platform-specific clients (FirebaseUserClient, FirebaseContactsClient)
4. Implement mock clients (MockUserClient, MockContactsClient)
5. Set up dependency injection with infrastructure provider selection

### 2. Phase 2: Feature Implementation

1. Implement UserFeature with streaming support
2. Implement ContactsFeature with streaming support
3. Update AppFeature to coordinate streaming

### 3. Phase 3: View Integration

1. Update views to use TCA stores
2. Implement WithPerceptionTracking for UI updates
3. Test offline behavior and sync

## Conclusion

This data persistence and streaming strategy provides a comprehensive approach to handling user data and contact collection persistence with streamed updates in the LifeSignal iOS application. By leveraging TCA's @Shared property wrapper, AsyncStream, and platform-specific client capabilities, the application can provide a responsive and reliable user experience with proper data synchronization between client and server.

The strategy ensures:
- Clean separation of concerns
- Type-safe data handling
- Real-time updates from server to client
- Persistence across app launches
- Offline support
- Testability with mock implementations
- Seamless integration with TCA
- Flexibility to switch between different backend technologies
- Support for mixed backend implementations (e.g., using both Firebase and Supabase)
