# Firebase Adapter Pattern

**Navigation:** [Back to Firebase Overview](Overview.md) | [Client Design](ClientDesign.md) | [Streaming Data](StreamingData.md)

---

## Introduction

The Adapter Pattern is a structural design pattern that allows objects with incompatible interfaces to collaborate. In modern iOS applications using TCA, adapters bridge between infrastructure-agnostic interfaces and Firebase-specific implementations. This approach ensures that application code remains independent of Firebase, making it more testable, maintainable, and flexible.

By implementing the Adapter Pattern, we create a clean separation between Firebase implementation details and application logic, allowing us to:

1. Test features without real Firebase dependencies
2. Switch to a different backend technology with minimal changes
3. Ensure type safety and concurrency safety throughout the codebase
4. Provide consistent error handling and domain modeling

## Core Principles

The Firebase Adapter Pattern follows these core principles:

1. **Infrastructure Agnosticism**: Application code should not depend directly on Firebase types or APIs
2. **Type Safety**: All interfaces between layers use strongly-typed Swift types
3. **Concurrency Safety**: All async operations use structured concurrency (async/await)
4. **Error Mapping**: Firebase errors are mapped to domain-specific errors
5. **Testability**: Adapters can be replaced with mock implementations for testing

## Adapter Pattern Implementation

The Adapter Pattern is implemented using three main components:

### 1. Infrastructure-Agnostic Interfaces

We define infrastructure-agnostic interfaces that our application code depends on:

```swift
@DependencyClient
struct StorageClient: Sendable {
  var getDocument: @Sendable (StoragePath) async throws -> DocumentSnapshot
  var updateDocument: @Sendable (StoragePath, [String: Any]) async throws -> Void
  var deleteDocument: @Sendable (StoragePath) async throws -> Void
  var documentStream: @Sendable (StoragePath) async -> AsyncStream<DocumentSnapshot>

  // Other methods...
}

struct StoragePath: Hashable, Sendable {
  let rawValue: String

  init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

struct DocumentSnapshot: Equatable, Sendable {
  let id: String
  let data: [String: Any]
  let exists: Bool
}
```

### 2. Firebase Adapters

We implement these interfaces using Firebase:

```swift
struct FirebaseStorageAdapter: StorageClient {
  func getDocument(_ path: StoragePath) async throws -> DocumentSnapshot {
    do {
      let snapshot = try await Firestore.firestore().document(path.rawValue).getDocument()
      return DocumentSnapshot(
        id: snapshot.documentID,
        data: snapshot.data() ?? [:],
        exists: snapshot.exists
      )
    } catch {
      throw StorageError(from: error)
    }
  }

  func updateDocument(_ path: StoragePath, _ data: [String: Any]) async throws -> Void {
    do {
      try await Firestore.firestore().document(path.rawValue).updateData(data)
    } catch {
      throw StorageError(from: error)
    }
  }

  func deleteDocument(_ path: StoragePath) async throws -> Void {
    do {
      try await Firestore.firestore().document(path.rawValue).delete()
    } catch {
      throw StorageError(from: error)
    }
  }

  func documentStream(_ path: StoragePath) async -> AsyncStream<DocumentSnapshot> {
    AsyncStream { continuation in
      let listener = Firestore.firestore().document(path.rawValue)
        .addSnapshotListener { snapshot, error in
          if let error = error {
            print("Error listening to document: \(error)")
            return
          }

          guard let snapshot = snapshot else { return }

          let documentSnapshot = DocumentSnapshot(
            id: snapshot.documentID,
            data: snapshot.data() ?? [:],
            exists: snapshot.exists
          )

          continuation.yield(documentSnapshot)
        }

      continuation.onTermination = { _ in
        listener.remove()
      }
    }
  }
}
```

### 3. Domain Models

We map Firebase data to strongly-typed Swift types:

```swift
struct User: Equatable, Identifiable, Sendable {
  let id: String
  var name: String
  var email: String
  var profileImageURL: URL?
  var createdAt: Date

  init(id: String, name: String, email: String, profileImageURL: URL? = nil, createdAt: Date) {
    self.id = id
    self.name = name
    self.email = email
    self.profileImageURL = profileImageURL
    self.createdAt = createdAt
  }

  init?(snapshot: DocumentSnapshot) {
    guard snapshot.exists,
          let name = snapshot.data["name"] as? String,
          let email = snapshot.data["email"] as? String,
          let createdAtTimestamp = snapshot.data["createdAt"] as? Timestamp else {
      return nil
    }

    self.id = snapshot.id
    self.name = name
    self.email = email
    self.profileImageURL = (snapshot.data["profileImageURL"] as? String).flatMap { URL(string: $0) }
    self.createdAt = createdAtTimestamp.dateValue()
  }

  var asDictionary: [String: Any] {
    var dict: [String: Any] = [
      "name": name,
      "email": email,
      "createdAt": Timestamp(date: createdAt)
    ]

    if let profileImageURL = profileImageURL {
      dict["profileImageURL"] = profileImageURL.absoluteString
    }

    return dict
  }
}
```

### 4. Error Mapping

We map Firebase errors to domain-specific errors:

```swift
enum StorageError: Error, Equatable {
  case documentNotFound
  case permissionDenied
  case networkError
  case invalidData
  case unknown(String)

  init(from firebaseError: Error) {
    let nsError = firebaseError as NSError
    switch nsError.code {
    case FirestoreErrorCode.notFound.rawValue:
      self = .documentNotFound
    case FirestoreErrorCode.permissionDenied.rawValue:
      self = .permissionDenied
    case FirestoreErrorCode.unavailable.rawValue:
      self = .networkError
    case FirestoreErrorCode.invalidArgument.rawValue:
      self = .invalidData
    default:
      self = .unknown(nsError.localizedDescription)
    }
  }
}
```

## Adapter Implementation

### Firebase Storage Adapter

```swift
struct FirebaseStorageAdapter: StorageClient {
  func getDocument(path: StoragePath) async throws -> DocumentSnapshot {
    do {
      let snapshot = try await Firestore.firestore().document(path.rawValue).getDocument()
      guard let data = snapshot.data() else {
        throw StorageError.documentNotFound
      }
      return DocumentSnapshot(id: snapshot.documentID, data: data)
    } catch {
      throw StorageError(from: error)
    }
  }

  func setDocument(path: StoragePath, data: [String: Any]) async throws -> Void {
    do {
      try await Firestore.firestore().document(path.rawValue).setData(data)
    } catch {
      throw StorageError(from: error)
    }
  }

  func updateDocument(path: StoragePath, data: [String: Any]) async throws -> Void {
    do {
      try await Firestore.firestore().document(path.rawValue).updateData(data)
    } catch {
      throw StorageError(from: error)
    }
  }

  func deleteDocument(path: StoragePath) async throws -> Void {
    do {
      try await Firestore.firestore().document(path.rawValue).delete()
    } catch {
      throw StorageError(from: error)
    }
  }

  func queryDocuments(collection: CollectionPath, query: Query?) async throws -> [DocumentSnapshot] {
    do {
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

      let querySnapshot = try await queryRef.getDocuments()

      return querySnapshot.documents.map { snapshot in
        DocumentSnapshot(id: snapshot.documentID, data: snapshot.data())
      }
    } catch {
      throw StorageError(from: error)
    }
  }

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
}
```

### Firebase Auth Adapter

```swift
struct FirebaseAuthAdapter: AuthClient {
  func currentUser() async -> User? {
    guard let firebaseUser = Auth.auth().currentUser else {
      return nil
    }
    return User(firebaseUser: firebaseUser)
  }

  func signIn(email: String, password: String) async throws -> User {
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

  func signUp(email: String, password: String) async throws -> User {
    do {
      let result = try await Auth.auth().createUser(withEmail: email, password: password)
      guard let firebaseUser = result.user else {
        throw AuthError.unknown("User is nil after sign up")
      }
      return User(firebaseUser: firebaseUser)
    } catch {
      throw AuthError(from: error)
    }
  }

  func signOut() async throws {
    do {
      try Auth.auth().signOut()
    } catch {
      throw AuthError(from: error)
    }
  }

  func resetPassword(email: String) async throws {
    do {
      try await Auth.auth().sendPasswordReset(withEmail: email)
    } catch {
      throw AuthError(from: error)
    }
  }

  func updatePassword(password: String) async throws {
    do {
      guard let firebaseUser = Auth.auth().currentUser else {
        throw AuthError.notAuthenticated
      }
      try await firebaseUser.updatePassword(to: password)
    } catch {
      throw AuthError(from: error)
    }
  }

  func updateEmail(email: String) async throws {
    do {
      guard let firebaseUser = Auth.auth().currentUser else {
        throw AuthError.notAuthenticated
      }
      try await firebaseUser.updateEmail(to: email)
    } catch {
      throw AuthError(from: error)
    }
  }

  func updateProfile(displayName: String, photoURL: URL?) async throws {
    do {
      guard let firebaseUser = Auth.auth().currentUser else {
        throw AuthError.notAuthenticated
      }
      let changeRequest = firebaseUser.createProfileChangeRequest()
      changeRequest.displayName = displayName
      if let photoURL = photoURL {
        changeRequest.photoURL = photoURL
      }
      try await changeRequest.commitChanges()
    } catch {
      throw AuthError(from: error)
    }
  }

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
}
```

### Firebase Storage Adapter

```swift
struct FirebaseFileStorageAdapter: FileStorageClient {
  func uploadData(path: StoragePath, data: Data) async throws -> URL {
    do {
      let storageRef = Storage.storage().reference().child(path.rawValue)
      let metadata = StorageMetadata()
      metadata.contentType = contentTypeForPath(path.rawValue)

      _ = try await storageRef.putDataAsync(data, metadata: metadata)
      return try await storageRef.downloadURL()
    } catch {
      throw StorageError(from: error)
    }
  }

  func downloadData(path: StoragePath) async throws -> Data {
    do {
      let storageRef = Storage.storage().reference().child(path.rawValue)
      let maxSize: Int64 = 10 * 1024 * 1024 // 10MB
      return try await storageRef.data(maxSize: maxSize)
    } catch {
      throw StorageError(from: error)
    }
  }

  func deleteFile(path: StoragePath) async throws {
    do {
      let storageRef = Storage.storage().reference().child(path.rawValue)
      try await storageRef.delete()
    } catch {
      throw StorageError(from: error)
    }
  }

  func getDownloadURL(path: StoragePath) async throws -> URL {
    do {
      let storageRef = Storage.storage().reference().child(path.rawValue)
      return try await storageRef.downloadURL()
    } catch {
      throw StorageError(from: error)
    }
  }

  private func contentTypeForPath(_ path: String) -> String {
    let ext = (path as NSString).pathExtension.lowercased()
    switch ext {
    case "jpg", "jpeg":
      return "image/jpeg"
    case "png":
      return "image/png"
    case "gif":
      return "image/gif"
    case "pdf":
      return "application/pdf"
    case "doc", "docx":
      return "application/msword"
    case "xls", "xlsx":
      return "application/vnd.ms-excel"
    case "ppt", "pptx":
      return "application/vnd.ms-powerpoint"
    case "txt":
      return "text/plain"
    case "html", "htm":
      return "text/html"
    case "json":
      return "application/json"
    case "xml":
      return "application/xml"
    case "mp3":
      return "audio/mpeg"
    case "mp4":
      return "video/mp4"
    default:
      return "application/octet-stream"
    }
  }
}
```

### Firebase Messaging Adapter

```swift
struct FirebaseMessagingAdapter: MessagingClient {
  func getToken() async throws -> String {
    do {
      return try await Messaging.messaging().token()
    } catch {
      throw MessagingError(from: error)
    }
  }

  func deleteToken() async throws {
    do {
      try await Messaging.messaging().deleteToken()
    } catch {
      throw MessagingError(from: error)
    }
  }

  func subscribe(topic: String) async throws {
    do {
      try await Messaging.messaging().subscribe(toTopic: topic)
    } catch {
      throw MessagingError(from: error)
    }
  }

  func unsubscribe(topic: String) async throws {
    do {
      try await Messaging.messaging().unsubscribe(fromTopic: topic)
    } catch {
      throw MessagingError(from: error)
    }
  }

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

  func messageStream() -> AsyncStream<RemoteMessage> {
    AsyncStream { continuation in
      let delegate = MessagingDelegate.shared
      delegate.messageHandler = { message in
        continuation.yield(RemoteMessage(firebaseMessage: message))
      }

      continuation.onTermination = { _ in
        delegate.messageHandler = nil
      }
    }
  }
}

class MessagingDelegate: NSObject, MessagingDelegate {
  static let shared = MessagingDelegate()

  var tokenHandler: ((String) -> Void)?
  var messageHandler: ((FirebaseMessaging.RemoteMessage) -> Void)?

  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    if let fcmToken = fcmToken {
      tokenHandler?(fcmToken)
    }
  }

  func messaging(_ messaging: Messaging, didReceive remoteMessage: FirebaseMessaging.RemoteMessage) {
    messageHandler?(remoteMessage)
  }
}
```

## Adapter Registration

Adapters are registered with TCA's dependency system:

```swift
extension StorageClient: DependencyKey {
  static let liveValue: StorageClient = FirebaseStorageAdapter()
  static let testValue: StorageClient = MockStorageClient()
  static let previewValue: StorageClient = PreviewStorageClient()
}

extension DependencyValues {
  var storageClient: StorageClient {
    get { self[StorageClient.self] }
    set { self[StorageClient.self] = newValue }
  }
}

extension AuthClient: DependencyKey {
  static let liveValue: AuthClient = FirebaseAuthAdapter()
  static let testValue: AuthClient = MockAuthClient()
  static let previewValue: AuthClient = PreviewAuthClient()
}

extension DependencyValues {
  var authClient: AuthClient {
    get { self[AuthClient.self] }
    set { self[AuthClient.self] = newValue }
  }
}

extension FileStorageClient: DependencyKey {
  static let liveValue: FileStorageClient = FirebaseFileStorageAdapter()
  static let testValue: FileStorageClient = MockFileStorageClient()
  static let previewValue: FileStorageClient = PreviewFileStorageClient()
}

extension DependencyValues {
  var fileStorageClient: FileStorageClient {
    get { self[FileStorageClient.self] }
    set { self[FileStorageClient.self] = newValue }
  }
}

extension MessagingClient: DependencyKey {
  static let liveValue: MessagingClient = FirebaseMessagingAdapter()
  static let testValue: MessagingClient = MockMessagingClient()
  static let previewValue: MessagingClient = PreviewMessagingClient()
}

extension DependencyValues {
  var messagingClient: MessagingClient {
    get { self[MessagingClient.self] }
    set { self[MessagingClient.self] = newValue }
  }
}
```

## Adapter Initialization

Adapters are initialized at app startup:

```swift
struct FirebaseAdapter {
  static func registerLiveValues() {
    // Register Firebase implementations as live values
    DependencyValues._current[StorageClient.self] = FirebaseStorageAdapter()
    DependencyValues._current[AuthClient.self] = FirebaseAuthAdapter()
    DependencyValues._current[FileStorageClient.self] = FirebaseFileStorageAdapter()
    DependencyValues._current[MessagingClient.self] = FirebaseMessagingAdapter()

    // Register domain-specific clients
    DependencyValues._current[UserClient.self] = UserClient.liveValue
    DependencyValues._current[ContactsClient.self] = ContactsClient.liveValue

    // Register Firebase app client
    DependencyValues._current[FirebaseAppClient.self] = FirebaseAppClient.liveValue

    // Configure Firebase
    FirebaseAppClient.liveValue.configure()
  }

  static func registerTestValues() {
    // Register test implementations
    DependencyValues._current[StorageClient.self] = MockStorageClient()
    DependencyValues._current[AuthClient.self] = MockAuthClient()
    DependencyValues._current[FileStorageClient.self] = MockFileStorageClient()
    DependencyValues._current[MessagingClient.self] = MockMessagingClient()

    // Register domain-specific clients
    DependencyValues._current[UserClient.self] = UserClient.testValue
    DependencyValues._current[ContactsClient.self] = ContactsClient.testValue

    // Register Firebase app client
    DependencyValues._current[FirebaseAppClient.self] = FirebaseAppClient.testValue
  }
}
```

## Best Practices

### 1. Keep Adapters Focused

Each adapter should have a single responsibility:

```swift
// ❌ Too many responsibilities
struct FirebaseAdapter: StorageClient, AuthClient, FileStorageClient, MessagingClient {
  // Implementation...
}

// ✅ Focused
struct FirebaseStorageAdapter: StorageClient {
  // Implementation...
}

struct FirebaseAuthAdapter: AuthClient {
  // Implementation...
}

struct FirebaseFileStorageAdapter: FileStorageClient {
  // Implementation...
}

struct FirebaseMessagingAdapter: MessagingClient {
  // Implementation...
}
```

### 2. Handle Firebase Errors

Map Firebase errors to domain-specific errors:

```swift
func signIn(email: String, password: String) async throws -> User {
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

### 3. Map Domain Models

Map between domain models and Firebase models:

```swift
struct User: Equatable, Sendable {
  var id: String
  var name: String
  var email: String
  var isVerified: Bool

  init(firebaseUser: FirebaseAuth.User) {
    self.id = firebaseUser.uid
    self.name = firebaseUser.displayName ?? ""
    self.email = firebaseUser.email ?? ""
    self.isVerified = firebaseUser.isEmailVerified
  }

  func toDictionary() -> [String: Any] {
    return [
      "name": name,
      "email": email,
      "isVerified": isVerified
    ]
  }

  static func fromDictionary(id: String, data: [String: Any]) -> User {
    return User(
      id: id,
      name: data["name"] as? String ?? "",
      email: data["email"] as? String ?? "",
      isVerified: data["isVerified"] as? Bool ?? false
    )
  }
}
```

### 4. Use Structured Concurrency

Use structured concurrency for all asynchronous operations:

```swift
func getDocument(path: StoragePath) async throws -> DocumentSnapshot {
  do {
    let snapshot = try await Firestore.firestore().document(path.rawValue).getDocument()
    guard let data = snapshot.data() else {
      throw StorageError.documentNotFound
    }
    return DocumentSnapshot(id: snapshot.documentID, data: data)
  } catch {
    throw StorageError(from: error)
  }
}
```

### 5. Properly Handle Streams

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

### 6. Test Adapters

Provide mock implementations for testing:

```swift
struct MockStorageClient: StorageClient {
  var getDocumentImpl: (StoragePath) async throws -> DocumentSnapshot = { _ in
    throw StorageError.documentNotFound
  }

  func getDocument(path: StoragePath) async throws -> DocumentSnapshot {
    try await getDocumentImpl(path)
  }

  // Other methods...
}
```

### 7. Document Adapters

Add documentation to adapters:

```swift
/// An adapter that implements the `StorageClient` protocol using Firebase Firestore.
struct FirebaseStorageAdapter: StorageClient {
  /// Gets a document from Firestore.
  /// - Parameter path: The path to the document.
  /// - Returns: The document snapshot.
  /// - Throws: `StorageError.documentNotFound` if the document doesn't exist.
  func getDocument(path: StoragePath) async throws -> DocumentSnapshot {
    // Implementation...
  }

  // Other methods...
}
```

## Conclusion

The Firebase Adapter Pattern provides a clean separation between Firebase implementation details and application logic. By following this pattern, you can create a more testable, maintainable, and flexible codebase that is easier to evolve over time.

The key benefits of this pattern include:

1. **Testability**: You can easily test your application logic without Firebase dependencies
2. **Maintainability**: Changes to Firebase APIs don't affect your application logic
3. **Flexibility**: You can switch to a different backend technology with minimal changes
4. **Type Safety**: All interfaces use strongly-typed Swift types
5. **Concurrency Safety**: All async operations use structured concurrency (async/await)

By implementing the Adapter Pattern with modern Swift features like structured concurrency, property wrappers, and macros, you can create a robust and flexible integration between Firebase and your TCA application.
