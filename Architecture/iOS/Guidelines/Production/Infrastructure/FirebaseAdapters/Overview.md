# Firebase Integration Overview

**Navigation:** [Back to iOS Architecture](../../../../README_copy.md) | [Client Design](ClientDesign.md) | [Adapter Pattern](AdapterPattern.md) | [Streaming Data](StreamingData.md)

---

## Introduction

Modern iOS applications using The Composable Architecture (TCA) can integrate Firebase services through a layered, infrastructure-agnostic approach. This design enables:

1. Clean separation between Firebase implementation details and application logic
2. Testing features without real Firebase dependencies
3. Type safety and concurrency safety throughout the codebase
4. Flexibility to switch to a different backend technology with minimal changes to application code
5. Consistent error handling and domain modeling

## Integration Architecture

```
Feature Layer → Domain-Specific Clients → Core Infrastructure Clients → Firebase Adapters → Firebase SDK
(UserFeature)    (UserClient)            (StorageClient)              (FirebaseAdapter)  (Firebase)
```

This layered architecture ensures:

1. **Infrastructure-Agnostic Interfaces**: Clients define interfaces that are independent of Firebase
2. **Dependency Injection**: Clients are provided via TCA's dependency system
3. **Structured Concurrency**: All asynchronous operations use async/await
4. **Error Handling**: Firebase errors are mapped to domain-specific errors
5. **Type Safety**: All data is strongly typed using domain models

## Core Components

### 1. Infrastructure-Agnostic Clients

Infrastructure-agnostic clients define interfaces that are independent of Firebase:

```swift
@DependencyClient
struct StorageClient: Sendable {
  var getDocument: @Sendable (StoragePath) async throws -> DocumentSnapshot = { _ in
    throw InfrastructureError.unimplemented("StorageClient.getDocument")
  }

  var updateDocument: @Sendable (StoragePath, [String: Any]) async throws -> Void = { _, _ in
    throw InfrastructureError.unimplemented("StorageClient.updateDocument")
  }

  // Other methods...
}
```

### 2. Domain-Specific Clients

Domain-specific clients use infrastructure-agnostic clients to provide domain-focused APIs:

```swift
@DependencyClient
struct UserClient: Sendable {
  var getCurrentUser: @Sendable () async throws -> User = {
    throw DomainError.unimplemented("UserClient.getCurrentUser")
  }

  var updateProfile: @Sendable (User) async throws -> Void = { _ in
    throw DomainError.unimplemented("UserClient.updateProfile")
  }

  // Other methods...
}
```

### 3. Firebase Adapters

Firebase adapters implement infrastructure-agnostic interfaces using Firebase:

```swift
struct FirebaseStorageAdapter: StorageClient {
  func getDocument(path: StoragePath) async throws -> DocumentSnapshot {
    let snapshot = try await Firestore.firestore().document(path.rawValue).getDocument()
    guard let data = snapshot.data() else {
      throw StorageError.documentNotFound
    }
    return DocumentSnapshot(id: snapshot.documentID, data: data)
  }

  // Other StorageClient methods implemented using Firebase
}
```

### 4. Firebase Clients

Firebase clients provide Firebase-specific functionality:

```swift
@DependencyClient
struct FirebaseAuthClient: Sendable {
  var currentUser: @Sendable () async -> FirebaseAuth.User? = { nil }
  var signIn: @Sendable (String, String) async throws -> FirebaseAuth.User = { _, _ in
    throw FirebaseAuthError.invalidCredentials
  }
  var signOut: @Sendable () async throws -> Void = { }
  var authStateStream: @Sendable () -> AsyncStream<FirebaseAuth.User?> = {
    AsyncStream { continuation in continuation.finish() }
  }
}
```

## Firebase Services Integration

### Authentication

Firebase Authentication is integrated with TCA using:

1. **Auth State Observation**: The app observes auth state changes via a stream
2. **Clean Auth API**: The auth client provides a clean API for auth operations
3. **Error Mapping**: Firebase auth errors are mapped to domain-specific errors
4. **User Mapping**: Firebase user objects are mapped to domain user models

```swift
@Reducer
struct AppFeature {
  // State, Action, etc.

  @Dependency(\.firebase.auth) var authClient

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

      // Other cases...
      }
    }
  }
}
```

### Firestore

Firestore integration follows these patterns:

1. **Document Operations**: The storage client provides methods for CRUD operations
2. **Collection Operations**: The storage client provides methods for querying collections
3. **Real-Time Updates**: The storage client provides methods for listening to document and collection changes
4. **Batch Operations**: The storage client provides methods for batch operations
5. **Transaction Operations**: The storage client provides methods for transaction operations

```swift
@Reducer
struct ContactsFeature {
  // State, Action, etc.

  @Dependency(\.firebase.firestore) var firestoreClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .viewDidAppear:
        return .run { send in
          let path = "users/\(state.currentUserID)/contacts"
          for await contacts in await firestoreClient.listenToCollection(path) {
            await send(.contactsUpdated(contacts))
          }
        }
        .cancellable(id: CancelID.contactsStream)

      // Other cases...
      }
    }
  }
}
```

### Storage

Firebase Storage integration follows these patterns:

1. **Upload Operations**: The storage client provides methods for uploading files
2. **Download Operations**: The storage client provides methods for downloading files
3. **Delete Operations**: The storage client provides methods for deleting files
4. **Metadata Operations**: The storage client provides methods for getting and updating metadata

```swift
@Reducer
struct ProfileFeature {
  // State, Action, etc.

  @Dependency(\.firebase.storage) var storageClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .profileImageSelected(let image):
        return .run { [userID = state.userID] send in
          let path = "users/\(userID)/profile.jpg"
          let data = image.jpegData(compressionQuality: 0.8)!
          let url = try await storageClient.uploadData(path, data)
          await send(.profileImageUploaded(url))
        }

      // Other cases...
      }
    }
  }
}
```

### Cloud Messaging

Firebase Cloud Messaging integration follows these patterns:

1. **Token Registration**: The messaging client provides methods for registering FCM tokens
2. **Notification Handling**: The messaging client provides methods for handling notifications
3. **Topic Subscription**: The messaging client provides methods for subscribing to topics

```swift
@Reducer
struct AppFeature {
  // State, Action, etc.

  @Dependency(\.firebase.messaging) var messagingClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .appDidLaunch:
        return .run { send in
          try await messagingClient.requestAuthorization()
          let token = try await messagingClient.getToken()
          await send(.fcmTokenUpdated(token))
        }

      // Other cases...
      }
    }
  }
}
```

## Dependency Registration

Firebase dependencies are registered using TCA's dependency system:

```swift
extension DependencyValues {
  var firebase: FirebaseDependencies {
    get { self[FirebaseDependencies.self] }
    set { self[FirebaseDependencies.self] = newValue }
  }
}

struct FirebaseDependencies: Sendable {
  var auth: FirebaseAuthClient
  var firestore: FirestoreClient
  var storage: FirebaseStorageClient
  var messaging: FirebaseMessagingClient
}

extension FirebaseDependencies: DependencyKey {
  static let liveValue = Self(
    auth: .liveValue,
    firestore: .liveValue,
    storage: .liveValue,
    messaging: .liveValue
  )

  static let testValue = Self(
    auth: .testValue,
    firestore: .testValue,
    storage: .testValue,
    messaging: .testValue
  )

  static let previewValue = Self(
    auth: .previewValue,
    firestore: .previewValue,
    storage: .previewValue,
    messaging: .previewValue
  )
}
```

## Firebase Initialization

Firebase is initialized at app startup using a dedicated client:

```swift
@DependencyClient
struct FirebaseAppClient: Sendable {
  var configure: @Sendable () -> Void
  var setupMessaging: @Sendable () async -> Void
  var setAnalyticsEnabled: @Sendable (Bool) -> Void
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
    },
    setAnalyticsEnabled: { enabled in
      Analytics.setAnalyticsCollectionEnabled(enabled)
    }
  )

  static let testValue = Self(
    configure: {},
    setupMessaging: {},
    setAnalyticsEnabled: { _ in }
  )
}

extension DependencyValues {
  var firebaseApp: FirebaseAppClient {
    get { self[FirebaseAppClient.self] }
    set { self[FirebaseAppClient.self] = newValue }
  }
}
```

The initialization is typically performed in the app's entry point:

```swift
@main
struct MyApp: App {
  init() {
    @Dependency(\.firebaseApp) var firebaseApp
    firebaseApp.configure()
  }

  var body: some Scene {
    WindowGroup {
      RootView(
        store: Store(initialState: RootFeature.State()) {
          RootFeature()
        }
      )
    }
  }
}
```

## Error Handling

Firebase errors are mapped to domain-specific errors:

```swift
enum AuthError: Error, Equatable {
  case notAuthenticated
  case invalidCredentials
  case emailAlreadyInUse
  case weakPassword
  case networkError
  case unknown(String)

  init(from firebaseError: Error) {
    let nsError = firebaseError as NSError
    switch nsError.code {
    case AuthErrorCode.notSignedIn.rawValue:
      self = .notAuthenticated
    case AuthErrorCode.wrongPassword.rawValue:
      self = .invalidCredentials
    case AuthErrorCode.emailAlreadyInUse.rawValue:
      self = .emailAlreadyInUse
    case AuthErrorCode.weakPassword.rawValue:
      self = .weakPassword
    case AuthErrorCode.networkError.rawValue:
      self = .networkError
    default:
      self = .unknown(nsError.localizedDescription)
    }
  }
}
```

## Best Practices

### 1. Stream at the Top Level

Stream Firebase data at the top level of the application (typically `AppFeature` or `SessionFeature`):

```swift
@Reducer
struct AppFeature {
  // State, Action, etc.

  @Dependency(\.firebase.auth) var authClient

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

      // Other cases...
      }
    }
  }
}
```

### 2. Use Clean Actions

Emit clean, `Equatable`/`Sendable` actions from Firebase streams:

```swift
// ❌ Raw Firebase types
case .authStateChanged(let firebaseUser):
  state.currentUser = firebaseUser != nil ? User(firebaseUser: firebaseUser!) : nil
  return .none

// ✅ Clean domain types
case .authStateChanged(let user):
  state.currentUser = user
  return .none
```

### 3. Handle Stream Errors

Handle stream errors at the top level:

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

### 4. Use Domain-Specific Error Types

Use domain-specific error types instead of raw Firebase errors:

```swift
// ❌ Raw Firebase errors
case let .signInFailed(error):
  state.error = error
  return .none

// ✅ Domain-specific errors
case let .signInFailed(error):
  state.error = AuthError(from: error)
  return .none
```

### 5. Encapsulate Authentication Checks

Encapsulate authentication checks in the dependency layer:

```swift
@DependencyClient
struct UserClient: Sendable {
  var getCurrentUser: @Sendable () async throws -> User
}

extension UserClient: DependencyKey {
  static let liveValue = Self(
    getCurrentUser: {
      guard let firebaseUser = Auth.auth().currentUser else {
        throw AuthError.notAuthenticated
      }
      return User(firebaseUser: firebaseUser)
    }
  )
}
```

### 6. Implement Generic Update Methods

Implement generic update/patch methods for common Firestore operations:

```swift
@DependencyClient
struct StorageClient: Sendable {
  var updateDocument: @Sendable (StoragePath, [String: Any]) async throws -> Void
  var patchDocument: @Sendable (StoragePath, [String: Any]) async throws -> Void
}

extension StorageClient: DependencyKey {
  static let liveValue = Self(
    updateDocument: { path, data in
      try await Firestore.firestore().document(path.rawValue).setData(data)
    },
    patchDocument: { path, data in
      try await Firestore.firestore().document(path.rawValue).updateData(data)
    }
  )
}
```

### 7. Use Atomic Operations

Use atomic operations when appropriate:

```swift
@DependencyClient
struct CounterClient: Sendable {
  var incrementCounter: @Sendable (String) async throws -> Void
}

extension CounterClient: DependencyKey {
  static let liveValue = Self(
    incrementCounter: { counterID in
      try await Firestore.firestore().document("counters/\(counterID)")
        .updateData(["count": FieldValue.increment(Int64(1))])
    }
  )
}
```

### 8. Handle Write Errors Locally

Handle write errors locally in the initiating feature:

```swift
@Reducer
struct ProfileFeature {
  // State, Action, etc.

  @Dependency(\.userClient) var userClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .saveButtonTapped:
        state.isSaving = true
        return .run { [user = state.user] send in
          do {
            try await userClient.updateProfile(user)
            await send(.profileSaved)
          } catch {
            await send(.profileSaveFailed(error))
          }
        }

      case .profileSaved:
        state.isSaving = false
        state.isEditing = false
        return .none

      case let .profileSaveFailed(error):
        state.isSaving = false
        state.error = error
        return .none

      // Other cases...
      }
    }
  }
}
```

### 9. Use Task.yield() for CPU-Intensive Work

Use `Task.yield()` for CPU-intensive work in Firebase-related effects:

```swift
case .processLargeDataSet:
  return .run { send in
    var result = [ProcessedItem]()
    for (index, item) in await firebaseClient.getLargeDataSet().enumerated() {
      // Process item...
      result.append(processedItem)

      // Yield periodically to prevent blocking the thread
      if index.isMultiple(of: 1000) {
        await Task.yield()
      }
    }
    await send(.dataProcessingComplete(result))
  }
```

### 10. Use Offline Capabilities

Leverage Firestore's offline capabilities:

```swift
@DependencyClient
struct FirestoreClient: Sendable {
  var enableNetwork: @Sendable () async throws -> Void
  var disableNetwork: @Sendable () async throws -> Void
  var waitForPendingWrites: @Sendable () async throws -> Void
}

extension FirestoreClient: DependencyKey {
  static let liveValue = Self(
    enableNetwork: {
      try await Firestore.firestore().enableNetwork()
    },
    disableNetwork: {
      try await Firestore.firestore().disableNetwork()
    },
    waitForPendingWrites: {
      try await Firestore.firestore().waitForPendingWrites()
    }
  )
}
```

## Conclusion

Firebase integration with TCA provides a powerful way to use Firebase services in a testable and maintainable manner. By following the principles and best practices outlined in this document, you can create a clean separation between Firebase implementation details and application logic, making your codebase more flexible and easier to test.

Modern Firebase integration with TCA leverages Swift's latest features like structured concurrency, property wrappers, and macros to provide a clean, type-safe, and testable approach to using Firebase services. The layered architecture ensures that your application code remains infrastructure-agnostic, making it easier to maintain and evolve over time.
