# Firebase Integration with TCA

**Navigation:** [Back to iOS Architecture](../../README.md) | [Firebase Clients](./FirebaseClients.md) | [Firebase Adapters](./FirebaseAdapters.md) | [Firebase Streaming](./FirebaseStreaming.md)

---

> **Note:** As this is an MVP, the Firebase integration approach may evolve as the project matures.

## Overview

LifeSignal integrates Firebase services with The Composable Architecture (TCA) using a layered, infrastructure-agnostic approach. This design enables us to:

1. Maintain clean separation between Firebase implementation details and application logic
2. Test features without real Firebase dependencies
3. Ensure type safety and concurrency safety throughout the codebase
4. Potentially switch to a different backend technology with minimal changes to application code

## Integration Architecture

```
Feature Layer → Domain-Specific Clients → Core Infrastructure Clients → Firebase Adapters → Firebase SDK
(UserFeature)    (UserClient)            (StorageClient)              (FirebaseAdapter)  (Firebase)
```

This layered architecture ensures:

1. **Type Safety**: All interfaces between layers use strongly-typed Swift types
2. **Concurrency Safety**: All async operations use structured concurrency (async/await)
3. **Infrastructure Agnosticism**: No Firebase-specific types leak into the application code
4. **Testability**: Each layer can be tested independently with appropriate mocks

## Firebase Client Design

Firebase clients in LifeSignal follow these principles:

1. **Infrastructure-Agnostic Interfaces**: Clients define interfaces that are independent of Firebase
2. **Dependency Injection**: Clients are provided via TCA's dependency system
3. **Structured Concurrency**: All asynchronous operations use async/await
4. **Error Handling**: Firebase errors are mapped to domain-specific errors
5. **Type Safety**: All data is strongly typed using domain models

## Firebase Dependency Registration

Firebase dependencies are registered using TCA's dependency system:

```swift
extension DependencyValues {
  var firebaseAuth: FirebaseAuthClient {
    get { self[FirebaseAuthClient.self] }
    set { self[FirebaseAuthClient.self] = newValue }
  }
}

extension FirebaseAuthClient: DependencyKey {
  static let liveValue = Self(
    // Live implementation using Firebase SDK
  )
  
  static let testValue = Self(
    // Test implementation for unit tests
  )
  
  static let previewValue = Self(
    // Preview implementation for SwiftUI previews
  )
}
```

## Firebase Data Streaming

Firebase data is streamed at the top level of the application (typically in `AppFeature` or `SessionFeature`):

1. **Stream Initialization**: Streams are initialized when the app starts or when a user logs in
2. **Clean Actions**: Streams emit clean, `Equatable`/`Sendable` actions
3. **Error Handling**: Stream errors are handled at the top level
4. **Cancellation**: Streams are properly cancelled when no longer needed

Example:

```swift
case .appDidLaunch:
  return .run { send in
    for await user in await authClient.authStateStream() {
      await send(.authStateChanged(user))
    }
  }
  .cancellable(id: CancelID.authStateStream)
```

## Firebase Authentication

Firebase Authentication is integrated with TCA using:

1. **Auth State Observation**: The app observes auth state changes via a stream
2. **Clean Auth API**: The auth client provides a clean API for auth operations
3. **Error Mapping**: Firebase auth errors are mapped to domain-specific errors
4. **User Mapping**: Firebase user objects are mapped to domain user models

## Firebase Firestore

Firestore integration follows these principles:

1. **Document Mapping**: Firestore documents are mapped to domain models
2. **Query Abstraction**: Firestore queries are abstracted behind client interfaces
3. **Atomic Operations**: Use of atomic operations like `FieldValue.increment()` when appropriate
4. **Offline Support**: Proper handling of offline capabilities

## Firebase Storage

Firebase Storage integration includes:

1. **Upload/Download Progress**: Proper handling of progress reporting
2. **Error Handling**: Comprehensive error handling for storage operations
3. **URL Management**: Clean management of storage URLs

## Error Handling

Firebase errors are handled using:

1. **Domain-Specific Errors**: Firebase errors are mapped to domain-specific errors
2. **Consistent Error Types**: Error types are consistent across the application
3. **User-Friendly Messages**: Errors include user-friendly messages

## Testing

Firebase integration is tested using:

1. **Mock Clients**: Mock implementations of Firebase clients
2. **Dependency Injection**: Overriding dependencies in tests
3. **Test Doubles**: Test doubles for Firebase services

## Implementation Examples

See the following files for detailed implementation examples:

- [Firebase Clients](./FirebaseClients.md): Detailed client implementations
- [Firebase Adapters](./FirebaseAdapters.md): Adapter implementations
- [Firebase Streaming](./FirebaseStreaming.md): Data streaming patterns
