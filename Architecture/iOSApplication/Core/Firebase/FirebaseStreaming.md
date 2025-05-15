# Firebase Streaming

**Navigation:** [Back to iOS Architecture](../../README.md) | [Firebase Integration](./FirebaseIntegration.md) | [Firebase Clients](./FirebaseClients.md) | [Firebase Adapters](./FirebaseAdapters.md)

---

> **Note:** As this is an MVP, the Firebase streaming approach may evolve as the project matures.

## Streaming Design Principles

Firebase data streaming in LifeSignal follows these core principles:

1. **Top-Level Streaming**: Stream Firebase data at the top level of the application
2. **Clean Actions**: Streams emit clean, `Equatable`/`Sendable` actions
3. **Error Handling**: Stream errors are handled at the top level
4. **Cancellation**: Streams are properly cancelled when no longer needed
5. **Structured Concurrency**: Streams use Swift's structured concurrency

## Streaming Implementation

Firebase data is streamed using Swift's `AsyncStream`:

```swift
func authStateStream() -> AsyncStream<User?> {
    AsyncStream { continuation in
        let handle = Auth.auth().addStateDidChangeListener { _, firebaseUser in
            if let firebaseUser = firebaseUser {
                let user = User(
                    id: firebaseUser.uid,
                    name: firebaseUser.displayName ?? "",
                    email: firebaseUser.email,
                    // Other properties...
                )
                continuation.yield(user)
            } else {
                continuation.yield(nil)
            }
        }
        
        continuation.onTermination = { _ in
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
```

## Streaming in TCA

Streams are integrated with TCA using the `.run` effect:

```swift
case .appDidLaunch:
  return .run { send in
    for await user in await authClient.authStateStream() {
      await send(.authStateChanged(user))
    }
  }
  .cancellable(id: CancelID.authStateStream)

case .loggedOut:
  return .cancel(id: CancelID.authStateStream)
```

## Firestore Document Streaming

Firestore documents are streamed using `AsyncStream`:

```swift
func observeDocument(_ path: StoragePath) -> AsyncStream<DocumentSnapshot> {
    AsyncStream { continuation in
        let firestore = Firestore.firestore()
        let docRef = firestore.document(path.stringPath)
        
        let listener = docRef.addSnapshotListener { snapshot, error in
            if let error = error {
                // Handle error
                return
            }
            
            if let snapshot = snapshot {
                let documentSnapshot = FirebaseDocumentSnapshot(snapshot: snapshot)
                continuation.yield(documentSnapshot)
            }
        }
        
        continuation.onTermination = { _ in
            listener.remove()
        }
    }
}
```

## Firestore Collection Streaming

Firestore collections are streamed using `AsyncStream`:

```swift
func observeCollection(_ path: StoragePath) -> AsyncStream<[DocumentSnapshot]> {
    AsyncStream { continuation in
        let firestore = Firestore.firestore()
        let collectionRef = firestore.collection(path.stringPath)
        
        let listener = collectionRef.addSnapshotListener { snapshot, error in
            if let error = error {
                // Handle error
                return
            }
            
            if let snapshot = snapshot {
                let documentSnapshots = snapshot.documents.map { 
                    FirebaseDocumentSnapshot(snapshot: $0)
                }
                continuation.yield(documentSnapshots)
            }
        }
        
        continuation.onTermination = { _ in
            listener.remove()
        }
    }
}
```

## Authentication State Streaming

Authentication state is streamed using `AsyncStream`:

```swift
func authStateStream() -> AsyncStream<User?> {
    AsyncStream { continuation in
        let handle = Auth.auth().addStateDidChangeListener { _, firebaseUser in
            if let firebaseUser = firebaseUser {
                let user = User(
                    id: firebaseUser.uid,
                    name: firebaseUser.displayName ?? "",
                    email: firebaseUser.email,
                    // Other properties...
                )
                continuation.yield(user)
            } else {
                continuation.yield(nil)
            }
        }
        
        continuation.onTermination = { _ in
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
```

## Push Notification Streaming

Push notifications are streamed using `AsyncStream`:

```swift
func messageStream() -> AsyncStream<RemoteMessage> {
    AsyncStream { continuation in
        let handle = Messaging.messaging().delegate = MessagingDelegate { message in
            let remoteMessage = RemoteMessage(
                messageID: message.messageID ?? "",
                data: message.appData,
                // Other properties...
            )
            continuation.yield(remoteMessage)
        }
        
        continuation.onTermination = { _ in
            Messaging.messaging().delegate = nil
        }
    }
}
```

## Stream Error Handling

Stream errors are handled at the top level:

```swift
case .appDidLaunch:
  return .run { send in
    do {
      for await user in await authClient.authStateStream() {
        await send(.authStateChanged(user))
      }
    } catch {
      await send(.authStateStreamFailed(error))
    }
  }
  .cancellable(id: CancelID.authStateStream)

case .authStateStreamFailed(let error):
  state.error = error
  return .none
```

## Stream Cancellation

Streams are cancelled when no longer needed:

```swift
case .loggedOut:
  return .cancel(id: CancelID.authStateStream)
```

## Streaming User Data

User data is streamed at the top level:

```swift
case .authStateChanged(let user):
  state.user = user
  
  if let user = user {
    return .run { send in
      for await userData in await userClient.observeUser(user.id) {
        await send(.userDataChanged(userData))
      }
    }
    .cancellable(id: CancelID.userDataStream)
  } else {
    return .cancel(id: CancelID.userDataStream)
  }
```

## Streaming Contacts

Contacts are streamed at the top level:

```swift
case .authStateChanged(let user):
  state.user = user
  
  if let user = user {
    return .merge(
      .run { send in
        for await userData in await userClient.observeUser(user.id) {
          await send(.userDataChanged(userData))
        }
      }
      .cancellable(id: CancelID.userDataStream),
      
      .run { send in
        for await contacts in await contactsClient.observeContacts(user.id) {
          await send(.contactsChanged(contacts))
        }
      }
      .cancellable(id: CancelID.contactsStream)
    )
  } else {
    return .merge(
      .cancel(id: CancelID.userDataStream),
      .cancel(id: CancelID.contactsStream)
    )
  }
```

## Best Practices

1. **Stream at Top Level**: Stream Firebase data at the top level of the application
2. **Use AsyncStream**: Use Swift's `AsyncStream` for all streaming operations
3. **Handle Cancellation**: Properly cancel streams when no longer needed
4. **Handle Errors**: Handle stream errors at the top level
5. **Use Clean Actions**: Streams should emit clean, `Equatable`/`Sendable` actions
6. **Avoid Duplicate Streams**: Avoid creating duplicate streams for the same data
7. **Test Thoroughly**: Provide comprehensive tests for streaming operations
8. **Document Limitations**: Document any limitations or constraints of the Firebase implementation
