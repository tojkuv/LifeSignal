# Firebase Adapters

**Navigation:** [Back to iOS Architecture](../../README.md) | [Firebase Integration](./FirebaseIntegration.md) | [Firebase Clients](./FirebaseClients.md) | [Firebase Streaming](./FirebaseStreaming.md)

---

> **Note:** As this is an MVP, the Firebase adapter implementation may evolve as the project matures.

## Adapter Design Principles

Firebase adapters in LifeSignal follow these core principles:

1. **Infrastructure Isolation**: Adapters isolate Firebase implementation details
2. **Type Conversion**: Adapters convert between Firebase types and domain types
3. **Error Mapping**: Adapters map Firebase errors to domain-specific errors
4. **Concurrency Safety**: Adapters ensure proper concurrency handling
5. **Implementation Details**: Adapters handle Firebase-specific implementation details

## Adapter Interfaces

Adapters implement infrastructure-agnostic interfaces:

```swift
public protocol StorageAdapter: Sendable {
    func getDocument(_ path: StoragePath) async throws -> DocumentSnapshot
    func setDocument(_ path: StoragePath, _ data: DocumentData) async throws
    func updateDocument(_ path: StoragePath, _ data: [String: Any]) async throws
    func deleteDocument(_ path: StoragePath) async throws
    func addDocument(_ path: StoragePath, _ data: DocumentData) async throws -> String
    func getCollection(_ path: StoragePath) async throws -> [DocumentSnapshot]
    func observeDocument(_ path: StoragePath) -> AsyncStream<DocumentSnapshot>
    func observeCollection(_ path: StoragePath) -> AsyncStream<[DocumentSnapshot]>
}

public protocol AuthAdapter: Sendable {
    func currentUser() async -> User?
    func signIn(email: String, password: String) async throws -> User
    func signOut() async throws
    func createUser(email: String, password: String) async throws -> User
    func sendPasswordReset(email: String) async throws
    func authStateStream() -> AsyncStream<User?>
}

public protocol StorageAdapter: Sendable {
    func uploadFile(_ path: StoragePath, _ data: Data) async throws -> URL
    func downloadFile(_ path: StoragePath) async throws -> Data
    func deleteFile(_ path: StoragePath) async throws
    func getDownloadURL(_ path: StoragePath) async throws -> URL
}

public protocol MessagingAdapter: Sendable {
    func getToken() async throws -> String
    func subscribe(topic: String) async throws
    func unsubscribe(topic: String) async throws
    func messageStream() -> AsyncStream<RemoteMessage>
}
```

## Firebase Firestore Adapter

The Firebase Firestore Adapter implements the `StorageAdapter` interface:

```swift
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

    func updateDocument(_ path: StoragePath, _ data: [String: Any]) async throws {
        let firestore = Firestore.firestore()
        let docRef = firestore.document(path.stringPath)

        do {
            try await docRef.updateData(data)
        } catch {
            throw StorageError.from(error)
        }
    }

    // Other methods...
}
```

## Firebase Auth Adapter

The Firebase Auth Adapter implements the `AuthAdapter` interface:

```swift
struct FirebaseAuthAdapter: AuthAdapter {
    func currentUser() async -> User? {
        guard let firebaseUser = Auth.auth().currentUser else {
            return nil
        }
        
        return User(
            id: firebaseUser.uid,
            name: firebaseUser.displayName ?? "",
            email: firebaseUser.email,
            phoneNumber: firebaseUser.phoneNumber ?? "",
            // Other properties...
        )
    }

    func signIn(email: String, password: String) async throws -> User {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            guard let firebaseUser = result.user else {
                throw AuthError.unknown("User is nil after sign in")
            }
            
            return User(
                id: firebaseUser.uid,
                name: firebaseUser.displayName ?? "",
                email: firebaseUser.email,
                phoneNumber: firebaseUser.phoneNumber ?? "",
                // Other properties...
            )
        } catch {
            throw AuthError.from(error)
        }
    }

    // Other methods...
}
```

## Firebase Storage Adapter

The Firebase Storage Adapter implements the `StorageAdapter` interface:

```swift
struct FirebaseStorageAdapter: StorageAdapter {
    func uploadFile(_ path: StoragePath, _ data: Data) async throws -> URL {
        let storage = Storage.storage()
        let storageRef = storage.reference().child(path.stringPath)
        
        do {
            _ = try await storageRef.putDataAsync(data)
            return try await storageRef.downloadURL()
        } catch {
            throw StorageError.from(error)
        }
    }

    // Other methods...
}
```

## Firebase Messaging Adapter

The Firebase Messaging Adapter implements the `MessagingAdapter` interface:

```swift
struct FirebaseMessagingAdapter: MessagingAdapter {
    func getToken() async throws -> String {
        do {
            return try await Messaging.messaging().token()
        } catch {
            throw MessagingError.from(error)
        }
    }

    // Other methods...
}
```

## Type Conversion

Adapters convert between Firebase types and domain types:

```swift
struct FirebaseDocumentSnapshot: DocumentSnapshot {
    private let snapshot: FirebaseFirestore.DocumentSnapshot
    
    init(snapshot: FirebaseFirestore.DocumentSnapshot) {
        self.snapshot = snapshot
    }
    
    var id: String {
        snapshot.documentID
    }
    
    var exists: Bool {
        snapshot.exists
    }
    
    var data: DocumentData? {
        guard let data = snapshot.data() else {
            return nil
        }
        
        return DocumentData(fields: data.mapValues { value in
            convertToStorageValue(value)
        })
    }
    
    private func convertToStorageValue(_ value: Any) -> StorageValue {
        // Convert Firebase value to StorageValue
    }
}
```

## Error Mapping

Adapters map Firebase errors to domain-specific errors:

```swift
extension AuthError {
    static func from(_ error: Error) -> AuthError {
        guard let nsError = error as NSError? else {
            return .unknown(error.localizedDescription)
        }
        
        switch nsError.code {
        case AuthErrorCode.wrongPassword.rawValue:
            return .invalidCredentials
        case AuthErrorCode.userNotFound.rawValue:
            return .userNotFound
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return .emailAlreadyInUse
        case AuthErrorCode.weakPassword.rawValue:
            return .weakPassword
        case AuthErrorCode.networkError.rawValue:
            return .networkError
        default:
            return .unknown(nsError.localizedDescription)
        }
    }
}
```

## Adapter Registration

Adapters are registered with the dependency system:

```swift
struct FirebaseAdapter {
    static func registerLiveValues() {
        // Register Firebase adapters as live values
        DependencyValues.register(\.storageAdapter, value: FirebaseStorageAdapter())
        DependencyValues.register(\.authAdapter, value: FirebaseAuthAdapter())
        DependencyValues.register(\.fileStorageAdapter, value: FirebaseStorageAdapter())
        DependencyValues.register(\.messagingAdapter, value: FirebaseMessagingAdapter())
        // Other adapters...
    }
}
```

## Best Practices

1. **Keep Adapters Focused**: Each adapter should have a single responsibility
2. **Handle Firebase-Specific Details**: Adapters should handle Firebase-specific implementation details
3. **Map Errors Comprehensively**: Map all Firebase errors to domain-specific errors
4. **Use Structured Concurrency**: Use async/await for all asynchronous operations
5. **Convert Types Safely**: Safely convert between Firebase types and domain types
6. **Test Thoroughly**: Provide comprehensive tests for adapters
7. **Handle Edge Cases**: Properly handle edge cases like offline mode
8. **Document Limitations**: Document any limitations or constraints of the Firebase implementation
