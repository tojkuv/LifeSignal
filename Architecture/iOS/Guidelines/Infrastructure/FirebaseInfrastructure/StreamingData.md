# Streaming Data from Firebase

**Navigation:** [Back to Firebase Overview](Overview.md) | [Client Design](ClientDesign.md) | [Adapter Pattern](AdapterPattern.md)

---

## Introduction

Firebase provides real-time data synchronization capabilities through Firestore listeners and Authentication state changes. In modern iOS applications using TCA, we integrate these streaming capabilities with The Composable Architecture (TCA) using AsyncStream and structured concurrency, ensuring type safety, concurrency safety, and proper resource management.

By leveraging Swift's latest concurrency features, we can create a clean, type-safe, and testable approach to streaming Firebase data that is both efficient and maintainable.

## Streaming Design Principles

### 1. Stream at the Top Level

Stream Firebase data at the top level of the application:

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

This ensures:
- Centralized data flow
- Consistent state updates
- Proper cancellation of streams

### 2. Use AsyncStream

Use AsyncStream to wrap Firebase listeners:

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

This ensures:
- Compatibility with Swift's concurrency system
- Proper resource cleanup
- Structured concurrency

### 3. Clean Actions

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

This ensures:
- Type safety
- Testability
- Separation from Firebase implementation details

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

This ensures:
- Proper error handling
- Graceful degradation
- User feedback

## Streaming Implementation

### Authentication State Stream

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

Usage in a reducer:

```swift
@Reducer
struct AppFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var currentUser: User?
    var isAuthenticated: Bool = false
  }

  enum Action: Equatable, Sendable {
    case appDidLaunch
    case authStateChanged(User?)
  }

  @Dependency(\.authClient) var authClient

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

      case let .authStateChanged(user):
        state.currentUser = user
        state.isAuthenticated = user != nil
        return .none
      }
    }
  }
}
```

### Document Stream

```swift
func listenToDocument(path: StoragePath) -> AsyncStream<DocumentSnapshot> {
  AsyncStream { continuation in
    let listener = Firestore.firestore().document(path.rawValue)
      .addSnapshotListener { snapshot, error in
        if let error = error {
          continuation.finish()
          return
        }

        guard let snapshot = snapshot, let data = snapshot.data() else {
          return
        }

        let documentSnapshot = DocumentSnapshot(id: snapshot.documentID, data: data)
        continuation.yield(documentSnapshot)
      }

    continuation.onTermination = { _ in
      listener.remove()
    }
  }
}
```

Usage in a reducer:

```swift
@Reducer
struct ProfileFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var user: User?
    var isLoading: Bool = false
    var error: Error?
  }

  enum Action: Equatable, Sendable {
    case viewDidAppear
    case userUpdated(User)
    case userStreamFailed(Error)
  }

  @Dependency(\.storageClient) var storageClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .viewDidAppear:
        guard let userID = state.user?.id else { return .none }

        return .run { send in
          do {
            for await snapshot in await storageClient.listenToDocument(path: "users/\(userID)") {
              let user = User.fromDictionary(id: snapshot.id, data: snapshot.data)
              await send(.userUpdated(user))
            }
          } catch {
            await send(.userStreamFailed(error))
          }
        }
        .cancellable(id: CancelID.userStream)

      case let .userUpdated(user):
        state.user = user
        return .none

      case let .userStreamFailed(error):
        state.error = error
        return .none
      }
    }
  }
}
```

### Collection Stream

```swift
func listenToCollection(collection: CollectionPath, query: Query?) -> AsyncStream<[DocumentSnapshot]> {
  AsyncStream { continuation in
    var queryRef = Firestore.firestore().collection(collection.rawValue)

    if let query = query {
      // Apply query parameters
      if let whereField = query.whereField, let whereValue = query.whereValue, let whereOperator = query.whereOperator {
        switch whereOperator {
        case .isEqualTo:
          queryRef = queryRef.whereField(whereField, isEqualTo: whereValue)
        case .isGreaterThan:
          queryRef = queryRef.whereField(whereField, isGreaterThan: whereValue)
        case .isLessThan:
          queryRef = queryRef.whereField(whereField, isLessThan: whereValue)
        }
      }

      if let orderBy = query.orderBy {
        queryRef = queryRef.order(by: orderBy, descending: query.descending)
      }

      if let limit = query.limit {
        queryRef = queryRef.limit(to: limit)
      }
    }

    let listener = queryRef.addSnapshotListener { querySnapshot, error in
      if let error = error {
        continuation.finish()
        return
      }

      guard let querySnapshot = querySnapshot else {
        return
      }

      let documentSnapshots = querySnapshot.documents.map { snapshot in
        DocumentSnapshot(id: snapshot.documentID, data: snapshot.data())
      }

      continuation.yield(documentSnapshots)
    }

    continuation.onTermination = { _ in
      listener.remove()
    }
  }
}
```

Usage in a reducer:

```swift
@Reducer
struct ContactsFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var contacts: [Contact] = []
    var isLoading: Bool = false
    var error: Error?
  }

  enum Action: Equatable, Sendable {
    case viewDidAppear
    case contactsUpdated([Contact])
    case contactsStreamFailed(Error)
  }

  @Dependency(\.contactsClient) var contactsClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .viewDidAppear:
        state.isLoading = true

        return .run { send in
          do {
            for await contacts in await contactsClient.contactsStream() {
              await send(.contactsUpdated(contacts))
            }
          } catch {
            await send(.contactsStreamFailed(error))
          }
        }
        .cancellable(id: CancelID.contactsStream)

      case let .contactsUpdated(contacts):
        state.contacts = contacts
        state.isLoading = false
        return .none

      case let .contactsStreamFailed(error):
        state.error = error
        state.isLoading = false
        return .none
      }
    }
  }
}
```

### FCM Token Stream

```swift
func tokenStream() -> AsyncStream<String> {
  AsyncStream { continuation in
    let delegate = MessagingDelegate.shared
    delegate.tokenHandler = { token in
      continuation.yield(token)
    }

    continuation.onTermination = { _ in
      delegate.tokenHandler = nil
    }
  }
}
```

Usage in a reducer:

```swift
@Reducer
struct AppFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var fcmToken: String?
  }

  enum Action: Equatable, Sendable {
    case appDidLaunch
    case fcmTokenUpdated(String)
  }

  @Dependency(\.messagingClient) var messagingClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .appDidLaunch:
        return .run { send in
          for await token in await messagingClient.tokenStream() {
            await send(.fcmTokenUpdated(token))
          }
        }
        .cancellable(id: CancelID.fcmTokenStream)

      case let .fcmTokenUpdated(token):
        state.fcmToken = token
        return .none
      }
    }
  }
}
```

## Advanced Streaming Patterns

### 1. Combining Multiple Streams

Combine multiple streams for a unified view:

```swift
@Reducer
struct DashboardFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var user: User?
    var contacts: [Contact] = []
    var notifications: [Notification] = []
    var isLoading: Bool = false
    var error: Error?
  }

  enum Action: Equatable, Sendable {
    case viewDidAppear
    case userUpdated(User?)
    case contactsUpdated([Contact])
    case notificationsUpdated([Notification])
    case streamFailed(Error)
  }

  @Dependency(\.userClient) var userClient
  @Dependency(\.contactsClient) var contactsClient
  @Dependency(\.notificationClient) var notificationClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .viewDidAppear:
        state.isLoading = true

        return .merge(
          .run { send in
            do {
              for await user in await userClient.userStream() {
                await send(.userUpdated(user))
              }
            } catch {
              await send(.streamFailed(error))
            }
          }
          .cancellable(id: CancelID.userStream),

          .run { send in
            do {
              for await contacts in await contactsClient.contactsStream() {
                await send(.contactsUpdated(contacts))
              }
            } catch {
              await send(.streamFailed(error))
            }
          }
          .cancellable(id: CancelID.contactsStream),

          .run { send in
            do {
              for await notifications in await notificationClient.notificationsStream() {
                await send(.notificationsUpdated(notifications))
              }
            } catch {
              await send(.streamFailed(error))
            }
          }
          .cancellable(id: CancelID.notificationsStream)
        )

      case let .userUpdated(user):
        state.user = user
        if state.isLoading && state.contacts.count > 0 && state.notifications.count > 0 {
          state.isLoading = false
        }
        return .none

      case let .contactsUpdated(contacts):
        state.contacts = contacts
        if state.isLoading && state.user != nil && state.notifications.count > 0 {
          state.isLoading = false
        }
        return .none

      case let .notificationsUpdated(notifications):
        state.notifications = notifications
        if state.isLoading && state.user != nil && state.contacts.count > 0 {
          state.isLoading = false
        }
        return .none

      case let .streamFailed(error):
        state.error = error
        state.isLoading = false
        return .none
      }
    }
  }
}
```

### 2. Filtering Stream Data

Filter stream data before sending actions:

```swift
@Reducer
struct NotificationsFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var notifications: [Notification] = []
    var unreadCount: Int = 0
  }

  enum Action: Equatable, Sendable {
    case viewDidAppear
    case notificationsUpdated([Notification])
    case markAsRead(String)
  }

  @Dependency(\.notificationClient) var notificationClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .viewDidAppear:
        return .run { send in
          for await notifications in await notificationClient.notificationsStream() {
            // Filter out deleted notifications
            let filteredNotifications = notifications.filter { !$0.isDeleted }
            await send(.notificationsUpdated(filteredNotifications))
          }
        }
        .cancellable(id: CancelID.notificationsStream)

      case let .notificationsUpdated(notifications):
        state.notifications = notifications
        state.unreadCount = notifications.filter { !$0.isRead }.count
        return .none

      case let .markAsRead(notificationID):
        if let index = state.notifications.firstIndex(where: { $0.id == notificationID }) {
          state.notifications[index].isRead = true
          state.unreadCount = state.notifications.filter { !$0.isRead }.count

          return .run { _ in
            try await notificationClient.markAsRead(notificationID)
          }
        }
        return .none
      }
    }
  }
}
```

### 3. Debouncing Stream Updates

Debounce rapid stream updates:

```swift
@Reducer
struct SearchFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var searchResults: [SearchResult] = []
    var isLoading: Bool = false
  }

  enum Action: Equatable, Sendable {
    case searchQueryChanged(String)
    case searchResultsUpdated([SearchResult])
  }

  @Dependency(\.searchClient) var searchClient
  @Dependency(\.continuousClock) var clock

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .searchQueryChanged(query):
        state.isLoading = true

        return .run { send in
          // Debounce search queries
          try await clock.sleep(for: .milliseconds(300))

          var latestResults: [SearchResult] = []
          var debounceTimer = Date()

          for await results in await searchClient.searchStream(query) {
            // Only update UI at most once per second
            if Date().timeIntervalSince(debounceTimer) >= 1.0 {
              await send(.searchResultsUpdated(results))
              debounceTimer = Date()
            }

            // Always keep track of the latest results
            latestResults = results
          }

          // Ensure the final results are always sent
          if !latestResults.isEmpty {
            await send(.searchResultsUpdated(latestResults))
          }
        }
        .cancellable(id: CancelID.searchStream)

      case let .searchResultsUpdated(results):
        state.searchResults = results
        state.isLoading = false
        return .none
      }
    }
  }
}
```

### 4. Handling Stream Reconnection

Handle stream reconnection after network failures:

```swift
@Reducer
struct ChatFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var messages: [Message] = []
    var isConnected: Bool = true
    var isReconnecting: Bool = false
  }

  enum Action: Equatable, Sendable {
    case viewDidAppear
    case messagesUpdated([Message])
    case connectionLost
    case reconnect
    case reconnected
  }

  @Dependency(\.chatClient) var chatClient
  @Dependency(\.continuousClock) var clock

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .viewDidAppear:
        return startMessageStream()

      case let .messagesUpdated(messages):
        state.messages = messages
        state.isConnected = true
        state.isReconnecting = false
        return .none

      case .connectionLost:
        state.isConnected = false

        return .run { send in
          // Wait before attempting to reconnect
          try await clock.sleep(for: .seconds(5))
          await send(.reconnect)
        }

      case .reconnect:
        state.isReconnecting = true

        return startMessageStream()

      case .reconnected:
        state.isConnected = true
        state.isReconnecting = false
        return .none
      }
    }
  }

  private func startMessageStream() -> Effect<Action> {
    .run { send in
      do {
        for try await messages in await chatClient.messagesStream() {
          await send(.messagesUpdated(messages))
        }
      } catch {
        await send(.connectionLost)
      }
    }
    .cancellable(id: CancelID.messagesStream)
  }
}
```

## Best Practices

### 1. Stream at the Top Level

Stream Firebase data at the top level of the application:

```swift
@Reducer
struct AppFeature {
  // State, Action, etc.

  @Dependency(\.authClient) var authClient

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

### 2. Use Cancellation IDs

Always specify cancellation IDs for streams:

```swift
enum CancelID {
  case authStateStream
  case userStream
  case contactsStream
  case notificationsStream
}

return .run { send in
  for await user in await authClient.authStateStream() {
    await send(.authStateChanged(user))
  }
}
.cancellable(id: CancelID.authStateStream)
```

### 3. Clean Up Resources

Ensure proper cleanup of Firebase listeners:

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

### 4. Handle Stream Errors

Handle stream errors at the appropriate level:

```swift
return .run { send in
  do {
    for try await contacts in await contactsClient.contactsStream() {
      await send(.contactsUpdated(contacts))
    }
  } catch {
    await send(.contactsStreamFailed(error))
  }
}
```

### 5. Map to Domain Models

Map Firebase models to domain models:

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

### 6. Test Streams

Provide test implementations for streams:

```swift
extension AuthClient: DependencyKey {
  static let testValue = Self(
    // Other methods...

    authStateStream: {
      AsyncStream { continuation in
        continuation.yield(User.mock)
        continuation.finish()
      }
    }
  )
}
```

### 7. Document Streams

Add documentation to streams:

```swift
/// A stream of authentication state changes.
/// - Returns: An async stream of optional User objects.
func authStateStream() -> AsyncStream<User?> {
  // Implementation...
}
```

## Conclusion

Streaming data from Firebase provides real-time updates to your application, enhancing the user experience. By following the principles and best practices outlined in this document, you can integrate Firebase's streaming capabilities with TCA in a way that is type-safe, concurrency-safe, and maintainable.

Modern TCA with Swift's structured concurrency provides a powerful foundation for working with Firebase's real-time data. The combination of `AsyncStream`, `.run` effects, and proper cancellation ensures that your application can efficiently process streaming data while maintaining a clean architecture and excellent testability.

By streaming data at the top level of your application and using clean, domain-specific types, you create a separation between Firebase implementation details and your application logic, making your codebase more flexible and easier to maintain over time.
