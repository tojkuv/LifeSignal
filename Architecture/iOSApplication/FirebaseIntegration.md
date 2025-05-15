# Firebase Integration with TCA

**Navigation:** [Back to iOS Architecture](README.md) | [TCA Implementation](TCAImplementation.md) | [Modern TCA Architecture](ComposableArchitecture.md) | [Core Principles](CorePrinciples.md)

---

> **Note:** This document outlines best practices for integrating Firebase with The Composable Architecture (TCA).

## Overview

LifeSignal uses Firebase as its primary backend service, integrated with TCA through a layered architecture that ensures:

1. **Infrastructure Agnosticism** - Features interact with infrastructure-agnostic clients, not Firebase directly
2. **Testability** - Firebase services can be mocked for testing
3. **Separation of Concerns** - Firebase-specific code is isolated in adapters
4. **Flexibility** - The application can switch to different backend technologies without changing feature code

## Firebase Integration Architecture

### Layered Approach

The Firebase integration follows a layered approach:

```
Feature Layer → Domain-Specific Clients → Core Infrastructure Clients → Firebase Adapters → Firebase SDK
(UserFeature)    (UserClient)            (StorageClient)              (FirebaseStorageAdapter)  (Firestore)
```

In this architecture:

1. **Feature Layer** - Uses domain-specific clients that are completely infrastructure-agnostic
2. **Domain-Specific Clients** - Implement business logic using core infrastructure clients
3. **Core Infrastructure Clients** - Provide infrastructure-agnostic interfaces for storage, auth, etc.
4. **Firebase Adapters** - Translate between infrastructure-agnostic interfaces and Firebase SDK
5. **Firebase SDK** - The actual Firebase implementation

### Firebase Adapter Structure

Firebase adapters should implement infrastructure-agnostic interfaces:

```swift
// Infrastructure-agnostic interface
public protocol StorageAdapter: Sendable {
    func getDocument(_ path: StoragePath) async throws -> DocumentSnapshot
    func setDocument(_ path: StoragePath, _ data: [String: Any], merge: Bool) async throws
    func updateDocument(_ path: StoragePath, _ data: [String: Any]) async throws
    func deleteDocument(_ path: StoragePath) async throws
    func documentStream(_ path: StoragePath) -> AsyncStream<DocumentSnapshot>
    // Other methods...
}

// Firebase-specific implementation
struct FirebaseStorageAdapter: StorageAdapter {
    func getDocument(_ path: StoragePath) async throws -> DocumentSnapshot {
        let firestore = Firestore.firestore()
        let docRef = firestore.document(path.stringPath)

        do {
            let snapshot = try await docRef.getDocument()
            return FirebaseDocumentSnapshot(snapshot: snapshot)
        } catch {
            throw StorageError.from(error)
        }
    }

    // Other implementations...
}
```

### Infrastructure-Agnostic Clients

The core infrastructure clients are type-safe and concurrency-safe, providing a clean interface for features:

```swift
@DependencyClient
public struct StorageClient: Sendable {
    public var getDocument: @Sendable (StoragePath) async throws -> DocumentSnapshot = { _ in
        throw InfrastructureError.unimplemented("StorageClient.getDocument")
    }

    public var updateDocument: @Sendable (StoragePath, [String: Any]) async throws -> Void = { _, _ in
        throw InfrastructureError.unimplemented("StorageClient.updateDocument")
    }

    // Other methods...
}

extension StorageClient: DependencyKey {
    public static let liveValue: Self = {
        // Create the Firebase adapter
        let adapter = FirebaseStorageAdapter()

        // Return a client that delegates to the adapter
        return Self(
            getDocument: { path in
                try await adapter.getDocument(path)
            },
            updateDocument: { path, data in
                try await adapter.updateDocument(path, data)
            }
            // Other methods...
        )
    }()

    public static let testValue = Self(
        getDocument: { _ in MockDocumentSnapshot() },
        updateDocument: { _, _ in }
        // Other test implementations...
    )
}

extension DependencyValues {
    public var storageClient: StorageClient {
        get { self[StorageClient.self] }
        set { self[StorageClient.self] = newValue }
    }
}
```

## Error Handling

### Domain-Specific Error Types

Define domain-specific error types instead of using raw Firebase errors:

```swift
enum FirebaseError: Error, Equatable, Sendable {
    case notAuthenticated
    case permissionDenied
    case documentNotFound
    case networkError
    case serverError
    case invalidData
    case operationFailed
    case unknown(String)

    static func from(_ error: Error) -> FirebaseError {
        if let nsError = error as NSError {
            switch nsError.domain {
            case FirestoreErrorDomain:
                switch nsError.code {
                case FirestoreErrorCode.notFound.rawValue:
                    return .documentNotFound
                case FirestoreErrorCode.permissionDenied.rawValue:
                    return .permissionDenied
                case FirestoreErrorCode.unauthenticated.rawValue:
                    return .notAuthenticated
                case FirestoreErrorCode.unavailable.rawValue:
                    return .networkError
                case FirestoreErrorCode.internal.rawValue:
                    return .serverError
                case FirestoreErrorCode.invalidArgument.rawValue:
                    return .invalidData
                default:
                    return .unknown(nsError.localizedDescription)
                }
            case AuthErrorDomain:
                switch nsError.code {
                case AuthErrorCode.userNotFound.rawValue:
                    return .notAuthenticated
                case AuthErrorCode.wrongPassword.rawValue:
                    return .notAuthenticated
                case AuthErrorCode.networkError.rawValue:
                    return .networkError
                default:
                    return .unknown(nsError.localizedDescription)
                }
            default:
                return .unknown(nsError.localizedDescription)
            }
        }
        return .unknown(error.localizedDescription)
    }
}
```

### Error Handling in Effects

Handle Firebase errors within effects:

```swift
@Dependency(\.firestoreClient) var firestoreClient

case .saveButtonTapped:
    let user = state.user
    state.isSaving = true
    return .run { send in
        do {
            try await firestoreClient.updateDocument(
                FirestorePath(collection: "users", document: user.id),
                user.toDictionary()
            )
            await send(.saveCompleted(.success(())))
        } catch {
            let mappedError = FirebaseError.from(error)
            await send(.saveCompleted(.failure(mappedError)))
        }
    }
```

## Real-Time Updates with AsyncStream

### Streaming Firestore Documents

Use AsyncStream to handle real-time updates from Firestore:

```swift
static let liveDocumentStream: @Sendable (FirestorePath) -> AsyncStream<DocumentSnapshot> = { path in
    AsyncStream { continuation in
        let firestore = Firestore.firestore()
        let docRef = firestore.document(path.stringPath)

        let listener = docRef.addSnapshotListener { snapshot, error in
            if let error = error {
                FirebaseLogger.firestore.error("Error listening to document: \(error.localizedDescription)")
                continuation.finish()
                return
            }

            guard let snapshot = snapshot else {
                FirebaseLogger.firestore.warning("Missing document snapshot")
                return
            }

            continuation.yield(FirebaseDocumentSnapshot(snapshot: snapshot))
        }

        continuation.onTermination = { _ in
            listener.remove()
        }
    }
}
```

### Using Streams in Features

Use streams in features with proper cancellation:

```swift
@Reducer
struct UserProfileFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var userId: String
        var profile: UserProfile?
        var isLoading: Bool = false
        var error: FirebaseError? = nil
    }

    enum Action: Equatable, Sendable {
        case onAppear
        case onDisappear
        case profileUpdated(UserProfile)
        case profileError(FirebaseError)
    }

    @Dependency(\.firestoreClient) var firestoreClient

    enum CancelID { case profileStream }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { [userId = state.userId] send in
                    for await snapshot in firestoreClient.documentStream(
                        FirestorePath(collection: "users", document: userId)
                    ) {
                        do {
                            if snapshot.exists {
                                let data = snapshot.data()
                                let profile = try UserProfile.fromDictionary(data)
                                await send(.profileUpdated(profile))
                            } else {
                                await send(.profileError(.documentNotFound))
                            }
                        } catch {
                            await send(.profileError(FirebaseError.from(error)))
                        }
                    }
                }
                .cancellable(id: CancelID.profileStream)

            case .onDisappear:
                return .cancel(id: CancelID.profileStream)

            case let .profileUpdated(profile):
                state.profile = profile
                state.isLoading = false
                return .none

            case let .profileError(error):
                state.error = error
                state.isLoading = false
                return .none
            }
        }
    }
}
```

## Firebase Authentication

### Auth State Management

Manage Firebase authentication state:

```swift
@DependencyClient
struct FirebaseAuthClient: Sendable {
    var currentUser: @Sendable () async -> User? = { nil }
    var signIn: @Sendable (AuthCredential) async throws -> AuthDataResult = { _ in
        throw FirebaseError.notAuthenticated
    }
    var signOut: @Sendable () async throws -> Void = { }
    var authStateStream: @Sendable () -> AsyncStream<User?> = {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}

extension FirebaseAuthClient: DependencyKey {
    static let liveValue = Self(
        currentUser: {
            Auth.auth().currentUser
        },
        signIn: { credential in
            try await Auth.auth().signIn(with: credential)
        },
        signOut: {
            try Auth.auth().signOut()
        },
        authStateStream: {
            AsyncStream { continuation in
                let handle = Auth.auth().addStateDidChangeListener { _, user in
                    continuation.yield(user)
                }
                continuation.onTermination = { _ in
                    Auth.auth().removeStateDidChangeListener(handle)
                }
            }
        }
    )
}
```

### Using Auth in Features

```swift
@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var isAuthenticated: Bool = false
        var authState: AuthState = .initializing
        var session: SessionFeature.State?
        var login: LoginFeature.State?

        enum AuthState: Equatable, Sendable {
            case initializing
            case authenticated(User)
            case unauthenticated
        }
    }

    enum Action: Equatable, Sendable {
        case appAppeared
        case authStateChanged(User?)
        case session(SessionFeature.Action)
        case login(LoginFeature.Action)
    }

    @Dependency(\.firebaseAuthClient) var authClient

    enum CancelID { case authStateListener }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appAppeared:
                return .run { send in
                    for await user in authClient.authStateStream() {
                        await send(.authStateChanged(user))
                    }
                }
                .cancellable(id: CancelID.authStateListener)

            case let .authStateChanged(user):
                if let user = user {
                    state.authState = .authenticated(user)
                    state.isAuthenticated = true
                    state.session = SessionFeature.State(userId: user.uid)
                    state.login = nil
                } else {
                    state.authState = .unauthenticated
                    state.isAuthenticated = false
                    state.session = nil
                    state.login = LoginFeature.State()
                }
                return .none

            case .session, .login:
                return .none
            }
        }
        .ifLet(\.session, action: /Action.session) {
            SessionFeature()
        }
        .ifLet(\.login, action: /Action.login) {
            LoginFeature()
        }
    }
}
```

## Testing Firebase Integration

### Mocking Firebase Clients

```swift
@Test
func testUserProfileFeature() async {
    let testProfile = UserProfile(id: "test-id", name: "Test User", email: "test@example.com")

    let store = TestStore(initialState: UserProfileFeature.State(userId: "test-id")) {
        UserProfileFeature()
    } withDependencies: {
        $0.firestoreClient.documentStream = { _ in
            AsyncStream { continuation in
                let mockSnapshot = MockDocumentSnapshot(
                    exists: true,
                    data: testProfile.toDictionary(),
                    id: "test-id"
                )
                continuation.yield(mockSnapshot)
                continuation.finish()
            }
        }
    }

    await store.send(.onAppear) {
        $0.isLoading = true
    }

    await store.receive(\.profileUpdated) {
        $0.profile = testProfile
        $0.isLoading = false
    }

    await store.send(.onDisappear)
}
```

### Testing Error Scenarios

```swift
@Test
func testUserProfileFeatureError() async {
    let store = TestStore(initialState: UserProfileFeature.State(userId: "test-id")) {
        UserProfileFeature()
    } withDependencies: {
        $0.firestoreClient.documentStream = { _ in
            AsyncStream { continuation in
                let mockSnapshot = MockDocumentSnapshot(
                    exists: false,
                    data: [:],
                    id: "test-id"
                )
                continuation.yield(mockSnapshot)
                continuation.finish()
            }
        }
    }

    await store.send(.onAppear) {
        $0.isLoading = true
    }

    await store.receive(\.profileError) {
        $0.error = .documentNotFound
        $0.isLoading = false
    }

    await store.send(.onDisappear)
}
```

## Firebase Initialization

### Configuring Firebase

```swift
@DependencyClient
struct FirebaseAppClient: Sendable {
    var configure: @Sendable () -> Void = { }
    var setupMessaging: @Sendable () async -> Void = { }
}

extension FirebaseAppClient: DependencyKey {
    static let liveValue = Self(
        configure: {
            if FirebaseApp.app() == nil {
                FirebaseApp.configure()
            }
        },
        setupMessaging: {
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }

            let messaging = Messaging.messaging()
            messaging.delegate = MessagingDelegate.shared
        }
    )
}

extension DependencyValues {
    var firebaseApp: FirebaseAppClient {
        get { self[FirebaseAppClient.self] }
        set { self[FirebaseAppClient.self] = newValue }
    }
}
```

### Using in App Startup

```swift
@main
struct LifeSignalApp: App {
    @Dependency(\.firebaseApp) var firebaseApp

    init() {
        firebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                store: Store(initialState: AppFeature.State()) {
                    AppFeature()
                }
            )
            .task {
                await firebaseApp.setupMessaging()
            }
        }
    }
}
```

## Centralized Firebase Adapter

### Firebase Adapter Registration

```swift
struct FirebaseAdapter {
    static func registerLiveValues() {
        // Register Firebase implementations as live values
        DependencyValues._current[FirebaseAppClient.self] = FirebaseAppClient.liveValue
        DependencyValues._current[FirebaseAuthClient.self] = FirebaseAuthClient.liveValue
        DependencyValues._current[FirestoreClient.self] = FirestoreClient.liveValue
        DependencyValues._current[FirebaseStorageClient.self] = FirebaseStorageClient.liveValue
        DependencyValues._current[FirebaseMessagingClient.self] = FirebaseMessagingClient.liveValue
        // Other Firebase clients...
    }

    static func registerTestValues() {
        // Register test implementations
        DependencyValues._current[FirebaseAppClient.self] = FirebaseAppClient.testValue
        DependencyValues._current[FirebaseAuthClient.self] = FirebaseAuthClient.testValue
        DependencyValues._current[FirestoreClient.self] = FirestoreClient.testValue
        DependencyValues._current[FirebaseStorageClient.self] = FirebaseStorageClient.testValue
        DependencyValues._current[FirebaseMessagingClient.self] = FirebaseMessagingClient.testValue
        // Other Firebase clients...
    }
}
```

### App Startup Configuration

```swift
@main
struct LifeSignalApp: App {
    init() {
        // Register Firebase implementations
        FirebaseAdapter.registerLiveValues()

        // Configure Firebase
        @Dependency(\.firebaseApp) var firebaseApp
        firebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                store: Store(initialState: AppFeature.State()) {
                    AppFeature()
                }
            )
        }
    }
}
```

## UI Implementation Guidelines

### Sheet Dismissal

Sheets should not have X buttons for dismissal. Instead, they should be dismissed using standard buttons:

```swift
// In a feature view with a sheet
struct ContactDetailView: View {
    @Bindable var store: StoreOf<ContactDetailFeature>

    var body: some View {
        NavigationStack {
            Form {
                // Contact details...

                Section {
                    Button("Update Roles") {
                        store.send(.updateRolesButtonTapped)
                    }
                }
            }
            .navigationTitle("Contact Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        store.send(.doneButtonTapped)
                    }
                }
            }
        }
        .sheet(item: $store.scope(state: \.roleUpdateSheet, action: \.roleUpdateSheet)) { store in
            NavigationStack {
                RoleUpdateView(store: store)
                    .navigationTitle("Update Roles")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                store.send(.cancelButtonTapped)
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                store.send(.saveButtonTapped)
                            }
                        }
                    }
                    // No X button for dismissal
            }
        }
    }
}
```

### Role Change Confirmation

When toggling contact roles, the system should show a confirmation dialog explaining the implications:

```swift
// In the RoleUpdateFeature reducer
@Reducer
struct RoleUpdateFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var contact: Contact
        var isResponder: Bool
        var isDependent: Bool
        var showConfirmation: Bool = false
        var isLoading: Bool = false
        var error: UserFacingError? = nil
    }

    enum Action: Equatable, Sendable {
        case responderToggled(Bool)
        case dependentToggled(Bool)
        case saveButtonTapped
        case cancelButtonTapped
        case confirmRoleChange
        case cancelRoleChange
        case roleUpdateResponse(TaskResult<Contact>)
        case delegate(Delegate)

        enum Delegate: Equatable, Sendable {
            case roleUpdated(Contact)
            case dismissed
        }
    }

    @Dependency(\contactsClient) var contactsClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .responderToggled(isResponder):
                state.isResponder = isResponder
                return .none

            case let .dependentToggled(isDependent):
                state.isDependent = isDependent
                return .none

            case .saveButtonTapped:
                // Show confirmation dialog if roles have changed
                if state.isResponder != state.contact.isResponder ||
                   state.isDependent != state.contact.isDependent {
                    state.showConfirmation = true
                    return .none
                } else {
                    return .send(.delegate(.dismissed))
                }

            case .confirmRoleChange:
                state.showConfirmation = false
                state.isLoading = true

                return .run { [contactId = state.contact.id, isResponder = state.isResponder, isDependent = state.isDependent] send in
                    await send(.roleUpdateResponse(TaskResult {
                        try await contactsClient.updateContactRole(
                            contactId: contactId,
                            isResponder: isResponder,
                            isDependent: isDependent
                        )

                        // Return updated contact
                        var updatedContact = state.contact
                        updatedContact.isResponder = isResponder
                        updatedContact.isDependent = isDependent
                        return updatedContact
                    }))
                }

            case .cancelRoleChange:
                state.showConfirmation = false
                return .none

            case let .roleUpdateResponse(.success(updatedContact)):
                state.isLoading = false
                return .send(.delegate(.roleUpdated(updatedContact)))

            case let .roleUpdateResponse(.failure(error)):
                state.isLoading = false
                state.error = UserFacingError.from(error)
                return .none

            case .cancelButtonTapped:
                return .send(.delegate(.dismissed))

            case .delegate:
                return .none
            }
        }
    }
}
```

```swift
// In the RoleUpdateView
struct RoleUpdateView: View {
    @Bindable var store: StoreOf<RoleUpdateFeature>

    var body: some View {
        Form {
            Section {
                Toggle("Responder", isOn: $store.isResponder)
                Toggle("Dependent", isOn: $store.isDependent)
            } header: {
                Text("Contact Roles")
            } footer: {
                Text("Responders can ping dependents and receive alerts. Dependents can be pinged by responders.")
            }
        }
        .disabled(store.isLoading)
        .alert("Confirm Role Change", isPresented: $store.showConfirmation) {
            Button("Cancel", role: .cancel) {
                store.send(.cancelRoleChange)
            }
            Button("Update", role: .destructive) {
                store.send(.confirmRoleChange)
            }
        } message: {
            Text("Changing roles may affect existing pings. If this contact becomes a dependent without being a responder, any outgoing pings will be cleared.")
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            }
        }
    }
}
```

## Feature-Specific Implementation

### Handling Role Changes

When a user's role changes (e.g., from dependent to responder or vice versa), we need to ensure that existing pings are updated to maintain the rule that only responders can ping dependents:

```swift
// In the ContactsClient implementation
public func updateContactRole(contactId: String, isResponder: Bool, isDependent: Bool) async throws {
    // 1. Update the contact role in the database
    try await storageClient.updateDocument(
        StoragePath(collection: "contacts", document: currentUserId, subcollection: "userContacts", subdocument: contactId),
        ["isResponder": isResponder, "isDependent": isDependent]
    )

    // 2. Check for existing pings that would violate the rule
    if !isResponder && isDependent {
        // If the user is now a dependent but not a responder, clear any outgoing pings
        try await pingClient.clearOutgoingPings(toUserId: contactId)
    }

    // 3. Notify the contact about the role change
    try await notificationClient.sendRoleChangeNotification(toUserId: contactId, isResponder: isResponder, isDependent: isDependent)
}
```

### Enforcing Ping Rules

The infrastructure layer should enforce the rule that only responders can ping dependents:

```swift
// In the PingClient implementation
public func pingDependent(dependentId: String) async throws {
    // 1. Verify the relationship
    let contact = try await contactsClient.getContact(contactId: dependentId)

    // 2. Enforce the rule that only responders can ping dependents
    guard contact.isDependent else {
        throw PingError.notADependent
    }

    // 3. Send the ping
    try await storageClient.updateDocument(
        StoragePath(collection: "contacts", document: currentUserId, subcollection: "userContacts", subdocument: dependentId),
        ["outgoingPingTimestamp": Date()]
    )

    // 4. Update the dependent's record
    try await storageClient.updateDocument(
        StoragePath(collection: "contacts", document: dependentId, subcollection: "userContacts", subdocument: currentUserId),
        ["incomingPingTimestamp": Date()]
    )

    // 5. Send a notification
    try await notificationClient.sendPingNotification(toUserId: dependentId)
}
```

## Key Principles for Firebase Integration

### Firebase Adapters vs. Infrastructure-Agnostic Clients

1. **Firebase Adapters**:
   - Directly interact with Firebase SDK
   - Don't need to be type-safe or concurrency-safe (that's handled by the infrastructure-agnostic layer)
   - Map Firebase-specific types to domain types
   - Handle Firebase-specific error mapping
   - Are not exposed to features

2. **Infrastructure-Agnostic Clients**:
   - Are fully type-safe and concurrency-safe
   - Use domain models and DTOs, not Firebase types
   - Provide a clean interface for features
   - Can be easily mocked for testing
   - Are the only clients that features should interact with

### Benefits of This Approach

By following these patterns, we can integrate Firebase with TCA in a way that:

1. Maintains the benefits of TCA's architecture
2. Keeps Firebase-specific code isolated in adapters
3. Ensures testability through dependency injection
4. Provides type safety and concurrency safety at the feature level
5. Enables easy switching between different backends
6. Simplifies Firebase adapter implementation by focusing on mapping, not safety

This approach allows us to leverage Firebase's powerful features while maintaining a clean, testable, and maintainable codebase that is not tied to any specific backend technology.
