# LifeSignal iOS Dependency Injection Graph

**Navigation:** [Back to iOS Specification](README.md) | [Project Structure](ProjectStructure.md) | [Module Graph](ModuleGraph.md) | [Feature List](FeatureList.md) | [User Experience](UserExperience.md)

---

## Dependency Injection System

LifeSignal uses TCA's dependency injection system to provide dependencies to features. This document outlines the dependency graph and registration system.

## Dependency Keys and Values

Dependencies are registered using TCA's `DependencyKey` and `DependencyValues` system:

```swift
// Define the dependency client
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

// Conform to DependencyKey
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

// Register with DependencyValues
extension DependencyValues {
    var auth: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}
```

## Dependency Registration

Dependencies are registered in a central location:

```swift
// Register live dependencies
func registerLiveDependencies() {
    // Firebase adapters
    let firebaseAuthAdapter = FirebaseAuthAdapter()
    let firebaseStorageAdapter = FirebaseStorageAdapter()
    let firebaseUserAdapter = FirebaseUserAdapter(
        auth: firebaseAuthAdapter,
        storage: firebaseStorageAdapter
    )
    
    // Register infrastructure clients
    AuthClient.liveValue = firebaseAuthAdapter.authClient
    StorageClient.liveValue = firebaseStorageAdapter.storageClient
    UserClient.liveValue = firebaseUserAdapter.userClient
    // ... other clients
}
```

## Dependency Graph

The following diagram shows the dependency injection graph for the LifeSignal application:

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                         Feature Reducers                            │
│                                                                     │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                      Infrastructure Clients                         │
│                                                                     │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                       Backend Adapters                              │
│                                                                     │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                         Backend SDKs                                │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Client Dependencies

The following diagram shows the dependencies between different clients:

```
AuthClient ◄─── UserClient ◄─── ProfileFeature
    │               │
    │               ▼
    │           ContactClient ◄─── ContactsFeature
    │               │
    │               ▼
    └───────► CheckInClient ◄─── CheckInFeature
                    │
                    ▼
                AlertClient ◄─── AlertFeature
                    │
                    ▼
                PingClient ◄─── PingFeature
                    │
                    ▼
            NotificationClient ◄─── NotificationFeature
```

## Dependency Implementations

Each client has multiple implementations:

1. **Live Implementation** - Used in production
2. **Test Implementation** - Used in tests
3. **Preview Implementation** - Used in SwiftUI previews

### Live Implementation

Live implementations use backend adapters:

```swift
// Firebase auth adapter
struct FirebaseAuthAdapter {
    let authClient: AuthClient
    
    init() {
        self.authClient = AuthClient(
            currentUser: {
                // Firebase implementation
                guard let firebaseUser = Auth.auth().currentUser else {
                    return nil
                }
                return User(id: firebaseUser.uid, phoneNumber: firebaseUser.phoneNumber)
            },
            signIn: { phoneNumber, verificationCode in
                // Firebase implementation
                // ...
            },
            signOut: {
                // Firebase implementation
                try Auth.auth().signOut()
            },
            authStateStream: {
                // Firebase implementation
                AsyncStream { continuation in
                    let handle = Auth.auth().addStateDidChangeListener { auth, user in
                        if let user = user {
                            continuation.yield(User(id: user.uid, phoneNumber: user.phoneNumber))
                        } else {
                            continuation.yield(nil)
                        }
                    }
                    continuation.onTermination = { _ in
                        Auth.auth().removeStateDidChangeListener(handle)
                    }
                }
            }
        )
    }
}
```

### Test Implementation

Test implementations use mock data:

```swift
// Test values
extension AuthClient {
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
```

### Preview Implementation

Preview implementations use mock data optimized for previews:

```swift
// Preview values
extension AuthClient {
    static let previewValue = Self(
        currentUser: { User.preview },
        signIn: { _, _ in User.preview },
        signOut: { },
        authStateStream: {
            AsyncStream { continuation in
                continuation.yield(User.preview)
                continuation.finish()
            }
        }
    )
}
```

## Using Dependencies in Features

Dependencies are injected into features using the `@Dependency` property wrapper:

```swift
@Reducer
struct ProfileFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var user: User?
        var isLoading = false
        var error: Error?
    }
    
    enum Action: Equatable, Sendable {
        case onAppear
        case userResponse(User?)
        case updateName(String)
        case updateNameResponse(TaskResult<Void>)
    }
    
    @Dependency(\.userClient) var userClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    let user = try await userClient.currentUser()
                    await send(.userResponse(user))
                }
                
            case let .userResponse(user):
                state.isLoading = false
                state.user = user
                return .none
                
            case let .updateName(name):
                guard var user = state.user else { return .none }
                user.name = name
                state.user = user
                return .run { send in
                    await send(.updateNameResponse(
                        TaskResult { try await userClient.updateUser(user) }
                    ))
                }
                
            case let .updateNameResponse(.success):
                // Handle success
                return .none
                
            case let .updateNameResponse(.failure(error)):
                state.error = error
                return .none
            }
        }
    }
}
```

## Testing with Dependencies

Dependencies can be overridden in tests:

```swift
func testProfileFeature() async {
    let store = TestStore(
        initialState: ProfileFeature.State(),
        reducer: { ProfileFeature() }
    )
    
    // Override dependencies
    store.dependencies.userClient = UserClient(
        currentUser: { User.mock },
        updateUser: { _ in }
    )
    
    await store.send(.onAppear) {
        $0.isLoading = true
    }
    
    await store.receive(.userResponse(User.mock)) {
        $0.isLoading = false
        $0.user = User.mock
    }
    
    await store.send(.updateName("New Name")) {
        $0.user?.name = "New Name"
    }
    
    await store.receive(.updateNameResponse(.success))
}
```

## Dependency Organization

Dependencies are organized into logical groups:

```swift
// Firebase dependencies
extension DependencyValues {
    var firebase: FirebaseDependencies {
        get { self[FirebaseDependencies.self] }
        set { self[FirebaseDependencies.self] = newValue }
    }
}

struct FirebaseDependencies: Sendable {
    var auth: AuthClient
    var storage: StorageClient
    var messaging: MessagingClient
}

extension FirebaseDependencies: DependencyKey {
    static let liveValue = FirebaseDependencies(
        auth: AuthClient.liveValue,
        storage: StorageClient.liveValue,
        messaging: MessagingClient.liveValue
    )
    
    static let testValue = FirebaseDependencies(
        auth: AuthClient.testValue,
        storage: StorageClient.testValue,
        messaging: MessagingClient.testValue
    )
}
```

This organization allows for more structured access to dependencies:

```swift
@Dependency(\.firebase.auth) var auth
@Dependency(\.firebase.storage) var storage
```
