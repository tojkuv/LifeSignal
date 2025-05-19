# Firebase Client Design

**Navigation:** [Back to Firebase Overview](Overview.md) | [Adapter Pattern](AdapterPattern.md) | [Streaming Data](StreamingData.md)

---

## Overview

Firebase clients in LifeSignal follow a structured design that ensures type safety, concurrency safety, and testability. This document outlines the design principles and patterns used for Firebase clients.

## Client Design Principles

### 1. Infrastructure Agnosticism

Clients define interfaces that are independent of Firebase:

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

This ensures:
- Features can work with any storage implementation
- Testing can be done without Firebase dependencies
- The application can switch to a different backend technology

### 2. Type Safety

All data is strongly typed using domain models:

```swift
struct User: Equatable, Sendable {
  var id: String
  var name: String
  var email: String
  var isVerified: Bool
  
  init(id: String, name: String, email: String, isVerified: Bool) {
    self.id = id
    self.name = name
    self.email = email
    self.isVerified = isVerified
  }
  
  init(firebaseUser: FirebaseAuth.User) {
    self.id = firebaseUser.uid
    self.name = firebaseUser.displayName ?? ""
    self.email = firebaseUser.email ?? ""
    self.isVerified = firebaseUser.isEmailVerified
  }
}
```

This ensures:
- Compile-time type checking
- Clear data structures
- No runtime type errors

### 3. Concurrency Safety

All asynchronous operations use structured concurrency:

```swift
@DependencyClient
struct AuthClient: Sendable {
  var signIn: @Sendable (String, String) async throws -> User = { _, _ in
    throw AuthError.invalidCredentials
  }
}

extension AuthClient: DependencyKey {
  static let liveValue = Self(
    signIn: { email, password in
      let result = try await Auth.auth().signIn(withEmail: email, password: password)
      guard let firebaseUser = result.user else {
        throw AuthError.unknown("User is nil after sign in")
      }
      return User(firebaseUser: firebaseUser)
    }
  )
}
```

This ensures:
- Proper cancellation of asynchronous operations
- Clear error handling
- Compatibility with Swift's concurrency system

### 4. Error Handling

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

This ensures:
- User-friendly error messages
- Consistent error handling
- Domain-specific error types

### 5. Dependency Injection

Clients are provided via TCA's dependency system:

```swift
extension DependencyValues {
  var authClient: AuthClient {
    get { self[AuthClient.self] }
    set { self[AuthClient.self] = newValue }
  }
}

@Reducer
struct Feature {
  @Dependency(\.authClient) var authClient
  
  // State, Action, etc.
}
```

This ensures:
- Clients can be mocked for testing
- Clients can be configured for different environments
- Features don't need to create clients

## Client Types

### 1. Core Infrastructure Clients

Low-level clients that provide basic infrastructure operations:

#### StorageClient

```swift
@DependencyClient
struct StorageClient: Sendable {
  var getDocument: @Sendable (StoragePath) async throws -> DocumentSnapshot = { _ in
    throw InfrastructureError.unimplemented("StorageClient.getDocument")
  }
  
  var setDocument: @Sendable (StoragePath, [String: Any]) async throws -> Void = { _, _ in
    throw InfrastructureError.unimplemented("StorageClient.setDocument")
  }
  
  var updateDocument: @Sendable (StoragePath, [String: Any]) async throws -> Void = { _, _ in
    throw InfrastructureError.unimplemented("StorageClient.updateDocument")
  }
  
  var deleteDocument: @Sendable (StoragePath) async throws -> Void = { _ in
    throw InfrastructureError.unimplemented("StorageClient.deleteDocument")
  }
  
  var queryDocuments: @Sendable (CollectionPath, Query?) async throws -> [DocumentSnapshot] = { _, _ in
    throw InfrastructureError.unimplemented("StorageClient.queryDocuments")
  }
  
  var listenToDocument: @Sendable (StoragePath) -> AsyncStream<DocumentSnapshot> = { _ in
    AsyncStream { continuation in continuation.finish() }
  }
  
  var listenToCollection: @Sendable (CollectionPath, Query?) -> AsyncStream<[DocumentSnapshot]> = { _, _ in
    AsyncStream { continuation in continuation.finish() }
  }
}
```

#### AuthClient

```swift
@DependencyClient
struct AuthClient: Sendable {
  var currentUser: @Sendable () async -> User? = { nil }
  
  var signIn: @Sendable (String, String) async throws -> User = { _, _ in
    throw AuthError.invalidCredentials
  }
  
  var signUp: @Sendable (String, String) async throws -> User = { _, _ in
    throw AuthError.invalidCredentials
  }
  
  var signOut: @Sendable () async throws -> Void = { }
  
  var resetPassword: @Sendable (String) async throws -> Void = { _ in
    throw AuthError.invalidCredentials
  }
  
  var updatePassword: @Sendable (String) async throws -> Void = { _ in
    throw AuthError.invalidCredentials
  }
  
  var updateEmail: @Sendable (String) async throws -> Void = { _ in
    throw AuthError.invalidCredentials
  }
  
  var updateProfile: @Sendable (String, URL?) async throws -> Void = { _, _ in
    throw AuthError.invalidCredentials
  }
  
  var authStateStream: @Sendable () -> AsyncStream<User?> = {
    AsyncStream { continuation in continuation.finish() }
  }
}
```

#### StorageClient

```swift
@DependencyClient
struct FileStorageClient: Sendable {
  var uploadData: @Sendable (StoragePath, Data) async throws -> URL = { _, _ in
    throw StorageError.uploadFailed
  }
  
  var downloadData: @Sendable (StoragePath) async throws -> Data = { _ in
    throw StorageError.downloadFailed
  }
  
  var deleteFile: @Sendable (StoragePath) async throws -> Void = { _ in
    throw StorageError.deleteFailed
  }
  
  var getDownloadURL: @Sendable (StoragePath) async throws -> URL = { _ in
    throw StorageError.urlFailed
  }
}
```

#### MessagingClient

```swift
@DependencyClient
struct MessagingClient: Sendable {
  var getToken: @Sendable () async throws -> String = {
    throw MessagingError.tokenFailed
  }
  
  var deleteToken: @Sendable () async throws -> Void = {
    throw MessagingError.tokenFailed
  }
  
  var subscribe: @Sendable (String) async throws -> Void = { _ in
    throw MessagingError.subscribeFailed
  }
  
  var unsubscribe: @Sendable (String) async throws -> Void = { _ in
    throw MessagingError.unsubscribeFailed
  }
  
  var tokenStream: @Sendable () -> AsyncStream<String> = {
    AsyncStream { continuation in continuation.finish() }
  }
  
  var messageStream: @Sendable () -> AsyncStream<RemoteMessage> = {
    AsyncStream { continuation in continuation.finish() }
  }
}
```

### 2. Domain-Specific Clients

Higher-level clients that use core infrastructure clients:

#### UserClient

```swift
@DependencyClient
struct UserClient: Sendable {
  var getCurrentUser: @Sendable () async throws -> User = {
    throw UserError.notAuthenticated
  }
  
  var updateProfile: @Sendable (User) async throws -> Void = { _ in
    throw UserError.updateFailed
  }
  
  var updateProfileImage: @Sendable (Data) async throws -> URL = { _ in
    throw UserError.updateFailed
  }
  
  var getUserByID: @Sendable (String) async throws -> User = { _ in
    throw UserError.notFound
  }
  
  var userStream: @Sendable () -> AsyncStream<User?> = {
    AsyncStream { continuation in continuation.finish() }
  }
}
```

#### ContactsClient

```swift
@DependencyClient
struct ContactsClient: Sendable {
  var getContacts: @Sendable () async throws -> [Contact] = {
    throw ContactsError.loadFailed
  }
  
  var addContact: @Sendable (Contact) async throws -> Void = { _ in
    throw ContactsError.addFailed
  }
  
  var updateContact: @Sendable (Contact) async throws -> Void = { _ in
    throw ContactsError.updateFailed
  }
  
  var deleteContact: @Sendable (String) async throws -> Void = { _ in
    throw ContactsError.deleteFailed
  }
  
  var contactsStream: @Sendable () -> AsyncStream<[Contact]> = {
    AsyncStream { continuation in continuation.finish() }
  }
}
```

## Client Implementation

### Core Infrastructure Client Implementation

```swift
extension StorageClient: DependencyKey {
  static let liveValue = Self(
    getDocument: { path in
      let snapshot = try await Firestore.firestore().document(path.rawValue).getDocument()
      guard let data = snapshot.data() else {
        throw StorageError.documentNotFound
      }
      return DocumentSnapshot(id: snapshot.documentID, data: data)
    },
    
    setDocument: { path, data in
      try await Firestore.firestore().document(path.rawValue).setData(data)
    },
    
    updateDocument: { path, data in
      try await Firestore.firestore().document(path.rawValue).updateData(data)
    },
    
    deleteDocument: { path in
      try await Firestore.firestore().document(path.rawValue).delete()
    },
    
    queryDocuments: { collectionPath, query in
      var queryRef = Firestore.firestore().collection(collectionPath.rawValue)
      
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
      
      let querySnapshot = try await queryRef.getDocuments()
      
      return querySnapshot.documents.map { snapshot in
        DocumentSnapshot(id: snapshot.documentID, data: snapshot.data())
      }
    },
    
    listenToDocument: { path in
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
    },
    
    listenToCollection: { collectionPath, query in
      AsyncStream { continuation in
        var queryRef = Firestore.firestore().collection(collectionPath.rawValue)
        
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
  )
}
```

### Domain-Specific Client Implementation

```swift
extension UserClient: DependencyKey {
  static let liveValue = Self(
    getCurrentUser: {
      guard let firebaseUser = Auth.auth().currentUser else {
        throw UserError.notAuthenticated
      }
      
      let userDoc = try await Firestore.firestore().document("users/\(firebaseUser.uid)").getDocument()
      
      guard let userData = userDoc.data() else {
        // Create user document if it doesn't exist
        let user = User(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? "",
          email: firebaseUser.email ?? "",
          isVerified: firebaseUser.isEmailVerified
        )
        
        try await Firestore.firestore().document("users/\(firebaseUser.uid)").setData(user.toDictionary())
        
        return user
      }
      
      return User.fromDictionary(id: firebaseUser.uid, data: userData)
    },
    
    updateProfile: { user in
      guard let firebaseUser = Auth.auth().currentUser else {
        throw UserError.notAuthenticated
      }
      
      // Update Auth profile
      let changeRequest = firebaseUser.createProfileChangeRequest()
      changeRequest.displayName = user.name
      try await changeRequest.commitChanges()
      
      // Update Firestore document
      try await Firestore.firestore().document("users/\(user.id)").updateData(user.toDictionary())
    },
    
    updateProfileImage: { imageData in
      guard let firebaseUser = Auth.auth().currentUser else {
        throw UserError.notAuthenticated
      }
      
      // Upload image to Storage
      let storageRef = Storage.storage().reference().child("users/\(firebaseUser.uid)/profile.jpg")
      let metadata = StorageMetadata()
      metadata.contentType = "image/jpeg"
      
      _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
      let downloadURL = try await storageRef.downloadURL()
      
      // Update Auth profile
      let changeRequest = firebaseUser.createProfileChangeRequest()
      changeRequest.photoURL = downloadURL
      try await changeRequest.commitChanges()
      
      // Update Firestore document
      try await Firestore.firestore().document("users/\(firebaseUser.uid)").updateData([
        "photoURL": downloadURL.absoluteString
      ])
      
      return downloadURL
    },
    
    getUserByID: { userID in
      let userDoc = try await Firestore.firestore().document("users/\(userID)").getDocument()
      
      guard let userData = userDoc.data() else {
        throw UserError.notFound
      }
      
      return User.fromDictionary(id: userID, data: userData)
    },
    
    userStream: {
      AsyncStream { continuation in
        let authStateListener = Auth.auth().addStateDidChangeListener { _, firebaseUser in
          if let firebaseUser = firebaseUser {
            Task {
              do {
                let userDoc = try await Firestore.firestore().document("users/\(firebaseUser.uid)").getDocument()
                
                if let userData = userDoc.data() {
                  let user = User.fromDictionary(id: firebaseUser.uid, data: userData)
                  continuation.yield(user)
                } else {
                  // Create user document if it doesn't exist
                  let user = User(
                    id: firebaseUser.uid,
                    name: firebaseUser.displayName ?? "",
                    email: firebaseUser.email ?? "",
                    isVerified: firebaseUser.isEmailVerified
                  )
                  
                  try await Firestore.firestore().document("users/\(firebaseUser.uid)").setData(user.toDictionary())
                  
                  continuation.yield(user)
                }
              } catch {
                continuation.yield(nil)
              }
            }
          } else {
            continuation.yield(nil)
          }
        }
        
        continuation.onTermination = { _ in
          Auth.auth().removeStateDidChangeListener(authStateListener)
        }
      }
    }
  )
}
```

## Client Registration

Clients are registered with TCA's dependency system:

```swift
// Register individual clients
extension DependencyValues {
  var storageClient: StorageClient {
    get { self[StorageClient.self] }
    set { self[StorageClient.self] = newValue }
  }
  
  var authClient: AuthClient {
    get { self[AuthClient.self] }
    set { self[AuthClient.self] = newValue }
  }
  
  var fileStorageClient: FileStorageClient {
    get { self[FileStorageClient.self] }
    set { self[FileStorageClient.self] = newValue }
  }
  
  var messagingClient: MessagingClient {
    get { self[MessagingClient.self] }
    set { self[MessagingClient.self] = newValue }
  }
  
  var userClient: UserClient {
    get { self[UserClient.self] }
    set { self[UserClient.self] = newValue }
  }
  
  var contactsClient: ContactsClient {
    get { self[ContactsClient.self] }
    set { self[ContactsClient.self] = newValue }
  }
}

// Register namespaced clients
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

## Best Practices

### 1. Keep Clients Focused

Each client should have a single responsibility:

```swift
// ❌ Too many responsibilities
@DependencyClient
struct UserClient: Sendable {
  var getCurrentUser: @Sendable () async throws -> User = { /* ... */ }
  var updateProfile: @Sendable (User) async throws -> Void = { /* ... */ }
  var getContacts: @Sendable () async throws -> [Contact] = { /* ... */ }
  var addContact: @Sendable (Contact) async throws -> Void = { /* ... */ }
}

// ✅ Focused
@DependencyClient
struct UserClient: Sendable {
  var getCurrentUser: @Sendable () async throws -> User = { /* ... */ }
  var updateProfile: @Sendable (User) async throws -> Void = { /* ... */ }
}

@DependencyClient
struct ContactsClient: Sendable {
  var getContacts: @Sendable () async throws -> [Contact] = { /* ... */ }
  var addContact: @Sendable (Contact) async throws -> Void = { /* ... */ }
}
```

### 2. Use Structured Concurrency

Use structured concurrency for all asynchronous operations:

```swift
// ❌ Unstructured concurrency
getCurrentUser: {
  return await withCheckedContinuation { continuation in
    Auth.auth().currentUser { user, error in
      if let error = error {
        continuation.resume(throwing: error)
      } else if let user = user {
        continuation.resume(returning: User(firebaseUser: user))
      } else {
        continuation.resume(throwing: AuthError.notAuthenticated)
      }
    }
  }
}

// ✅ Structured concurrency
getCurrentUser: {
  guard let firebaseUser = Auth.auth().currentUser else {
    throw AuthError.notAuthenticated
  }
  return User(firebaseUser: firebaseUser)
}
```

### 3. Provide Default Values

Provide default values for non-throwing closures:

```swift
@DependencyClient
struct DateClient: Sendable {
  var now: @Sendable () -> Date = { Date() }
  var calendar: @Sendable () -> Calendar = { Calendar.current }
  var timeZone: @Sendable () -> TimeZone = { TimeZone.current }
}
```

### 4. Map Errors

Map Firebase errors to domain-specific errors:

```swift
signIn: { email, password in
  do {
    let result = try await Auth.auth().signIn(withEmail: email, password: password)
    guard let firebaseUser = result.user else {
      throw AuthError.unknown("User is nil after sign in")
    }
    return User(firebaseUser: firebaseUser)
  } catch {
    throw AuthError(from: error)
  }
}
```

### 5. Use Strong Types

Use strongly typed domain models instead of dictionaries:

```swift
// ❌ Dictionaries
updateProfile: { userID, data in
  try await Firestore.firestore().document("users/\(userID)").updateData(data)
}

// ✅ Domain models
updateProfile: { user in
  try await Firestore.firestore().document("users/\(user.id)").updateData(user.toDictionary())
}
```

### 6. Stream at Top Level

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

### 7. Handle Offline Mode

Properly handle offline capabilities:

```swift
@DependencyClient
struct OfflineClient: Sendable {
  var enableOfflinePersistence: @Sendable () async -> Void = { }
  var disableNetwork: @Sendable () async -> Void = { }
  var enableNetwork: @Sendable () async -> Void = { }
  var isOffline: @Sendable () -> Bool = { false }
}

extension OfflineClient: DependencyKey {
  static let liveValue = Self(
    enableOfflinePersistence: {
      let settings = FirestoreSettings()
      settings.isPersistenceEnabled = true
      settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
      Firestore.firestore().settings = settings
    },
    disableNetwork: {
      try await Firestore.firestore().disableNetwork()
    },
    enableNetwork: {
      try await Firestore.firestore().enableNetwork()
    },
    isOffline: {
      // Check network connectivity
      return false
    }
  )
}
```

### 8. Use Atomic Operations

Use atomic operations when appropriate:

```swift
incrementCounter: { counterID in
  try await Firestore.firestore().document("counters/\(counterID)")
    .updateData(["count": FieldValue.increment(Int64(1))])
}
```

### 9. Test Thoroughly

Provide comprehensive test implementations:

```swift
extension UserClient: DependencyKey {
  static let liveValue = Self(
    getCurrentUser: { /* Live implementation */ },
    updateProfile: { /* Live implementation */ }
  )
  
  static let testValue = Self(
    getCurrentUser: { User.mock },
    updateProfile: { _ in }
  )
  
  static var mocks = Self(
    getCurrentUser: { User.mock },
    updateProfile: { _ in }
  )
  
  static func failing(
    getCurrentUser: @escaping @Sendable () async throws -> User = { throw UserError.testError },
    updateProfile: @escaping @Sendable (User) async throws -> Void = { _ in throw UserError.testError }
  ) -> Self {
    Self(
      getCurrentUser: getCurrentUser,
      updateProfile: updateProfile
    )
  }
}
```

## Conclusion

Firebase client design in LifeSignal follows a structured approach that ensures type safety, concurrency safety, and testability. By following the principles and patterns outlined in this document, you can create Firebase clients that are easy to understand, modify, and test.
