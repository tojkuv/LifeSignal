# LifeSignal iOS Backend Integration

**Navigation:** [Back to Infrastructure](README.md) | [Back to Application Specification](../README.md) | [Client Interfaces](ClientInterfaces.md)

---

## Overview

This document provides detailed specifications for the backend integration of the LifeSignal iOS application. It covers the integration with Firebase and the future migration to Supabase for specific functionality.

## Backend Services

The LifeSignal iOS application integrates with the following backend services:

### Firebase

Firebase is the primary backend service for the LifeSignal application, providing:

- **Authentication**: Firebase Authentication for phone number authentication
- **Database**: Firebase Firestore for storing and retrieving data
- **Storage**: Firebase Storage for storing images and other files
- **Messaging**: Firebase Cloud Messaging for push notifications
- **Functions**: Firebase Cloud Functions for server-side logic

### Supabase (Future)

In the future, some functionality will be migrated to Supabase, providing:

- **Authentication**: Supabase Auth for phone number authentication
- **Database**: Supabase Database for storing and retrieving data
- **Storage**: Supabase Storage for storing images and other files
- **Functions**: Supabase Functions for server-side logic

## Integration Architecture

The LifeSignal iOS application uses a layered approach to backend integration:

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                          Feature Layer                              │
│                                                                     │
└───────────────────────────────────┬─────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                       Client Interface Layer                        │
│                                                                     │
└───────────────────────────────────┬─────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                         Adapter Layer                               │
│                                                                     │
└───────────────────────────────────┬─────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                        Backend SDK Layer                            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

This layered approach provides several benefits:

1. **Separation of Concerns**: Each layer has a specific responsibility
2. **Abstraction**: Higher layers are abstracted from lower-layer details
3. **Testability**: Each layer can be tested independently
4. **Flexibility**: Backend services can be changed without affecting features
5. **Maintainability**: Changes to one layer don't affect other layers

## Firebase Integration

### Firebase Authentication

Firebase Authentication is used for phone number authentication:

```swift
class FirebaseAuthAdapter {
    private let auth = Auth.auth()
    
    func signIn(phoneNumber: String) async throws {
        // Implementation using Firebase Authentication
    }
    
    func verify(verificationCode: String) async throws -> User {
        // Implementation using Firebase Authentication
    }
    
    func signOut() async throws {
        // Implementation using Firebase Authentication
    }
    
    func currentUser() async throws -> User? {
        // Implementation using Firebase Authentication
    }
    
    func authStateStream() -> AsyncStream<User?> {
        // Implementation using Firebase Authentication
    }
}
```

### Firebase Firestore

Firebase Firestore is used for storing and retrieving data:

```swift
class FirebaseFirestoreAdapter {
    private let db = Firestore.firestore()
    
    func getDocument<T: Decodable>(collection: String, id: String) async throws -> T {
        // Implementation using Firebase Firestore
    }
    
    func setDocument<T: Encodable>(collection: String, id: String, data: T) async throws {
        // Implementation using Firebase Firestore
    }
    
    func updateDocument<T: Encodable>(collection: String, id: String, data: T) async throws {
        // Implementation using Firebase Firestore
    }
    
    func deleteDocument(collection: String, id: String) async throws {
        // Implementation using Firebase Firestore
    }
    
    func getDocuments<T: Decodable>(collection: String, query: Query?) async throws -> [T] {
        // Implementation using Firebase Firestore
    }
    
    func documentStream<T: Decodable>(collection: String, id: String) -> AsyncStream<T?> {
        // Implementation using Firebase Firestore
    }
    
    func collectionStream<T: Decodable>(collection: String, query: Query?) -> AsyncStream<[T]> {
        // Implementation using Firebase Firestore
    }
}
```

### Firebase Storage

Firebase Storage is used for storing images and other files:

```swift
class FirebaseStorageAdapter {
    private let storage = Storage.storage()
    
    func uploadImage(image: UIImage, path: String) async throws -> URL {
        // Implementation using Firebase Storage
    }
    
    func downloadImage(url: URL) async throws -> UIImage {
        // Implementation using Firebase Storage
    }
    
    func deleteImage(url: URL) async throws {
        // Implementation using Firebase Storage
    }
}
```

### Firebase Cloud Messaging

Firebase Cloud Messaging is used for push notifications:

```swift
class FirebaseMessagingAdapter {
    private let messaging = Messaging.messaging()
    
    func registerForRemoteNotifications() async throws {
        // Implementation using Firebase Cloud Messaging
    }
    
    func unregisterForRemoteNotifications() async throws {
        // Implementation using Firebase Cloud Messaging
    }
    
    func getToken() async throws -> String {
        // Implementation using Firebase Cloud Messaging
    }
}
```

### Firebase Cloud Functions

Firebase Cloud Functions are used for server-side logic:

```swift
class FirebaseFunctionsAdapter {
    private let functions = Functions.functions()
    
    func callFunction<T: Decodable>(name: String, data: [String: Any]?) async throws -> T {
        // Implementation using Firebase Cloud Functions
    }
}
```

## Supabase Integration (Future)

### Supabase Auth

Supabase Auth will be used for phone number authentication:

```swift
class SupabaseAuthAdapter {
    private let client = SupabaseClient.shared
    
    func signIn(phoneNumber: String) async throws {
        // Implementation using Supabase Auth
    }
    
    func verify(verificationCode: String) async throws -> User {
        // Implementation using Supabase Auth
    }
    
    func signOut() async throws {
        // Implementation using Supabase Auth
    }
    
    func currentUser() async throws -> User? {
        // Implementation using Supabase Auth
    }
    
    func authStateStream() -> AsyncStream<User?> {
        // Implementation using Supabase Auth
    }
}
```

### Supabase Database

Supabase Database will be used for storing and retrieving data:

```swift
class SupabaseDatabaseAdapter {
    private let client = SupabaseClient.shared
    
    func getRecord<T: Decodable>(table: String, id: String) async throws -> T {
        // Implementation using Supabase Database
    }
    
    func insertRecord<T: Encodable>(table: String, data: T) async throws -> String {
        // Implementation using Supabase Database
    }
    
    func updateRecord<T: Encodable>(table: String, id: String, data: T) async throws {
        // Implementation using Supabase Database
    }
    
    func deleteRecord(table: String, id: String) async throws {
        // Implementation using Supabase Database
    }
    
    func getRecords<T: Decodable>(table: String, query: Query?) async throws -> [T] {
        // Implementation using Supabase Database
    }
    
    func recordStream<T: Decodable>(table: String, id: String) -> AsyncStream<T?> {
        // Implementation using Supabase Database
    }
    
    func tableStream<T: Decodable>(table: String, query: Query?) -> AsyncStream<[T]> {
        // Implementation using Supabase Database
    }
}
```

### Supabase Storage

Supabase Storage will be used for storing images and other files:

```swift
class SupabaseStorageAdapter {
    private let client = SupabaseClient.shared
    
    func uploadImage(image: UIImage, path: String) async throws -> URL {
        // Implementation using Supabase Storage
    }
    
    func downloadImage(url: URL) async throws -> UIImage {
        // Implementation using Supabase Storage
    }
    
    func deleteImage(url: URL) async throws {
        // Implementation using Supabase Storage
    }
}
```

### Supabase Functions

Supabase Functions will be used for server-side logic:

```swift
class SupabaseFunctionsAdapter {
    private let client = SupabaseClient.shared
    
    func callFunction<T: Decodable>(name: String, data: [String: Any]?) async throws -> T {
        // Implementation using Supabase Functions
    }
}
```

## Data Transfer Objects (DTOs)

Data Transfer Objects (DTOs) are used to map between domain models and backend data structures:

```swift
struct UserDTO: Codable {
    let id: String
    let firstName: String
    let lastName: String
    let phoneNumber: String
    let profileImageURL: String?
    let emergencyNote: String
    let checkInInterval: TimeInterval
    let reminderInterval: TimeInterval
    let lastCheckInTime: Date?
    let status: String
    let qrCodeID: String
    
    func toDomain() -> User {
        return User(
            id: UUID(uuidString: id) ?? UUID(),
            firstName: firstName,
            lastName: lastName,
            phoneNumber: phoneNumber,
            profileImageURL: profileImageURL.flatMap { URL(string: $0) },
            emergencyNote: emergencyNote,
            checkInInterval: checkInInterval,
            reminderInterval: reminderInterval,
            lastCheckInTime: lastCheckInTime,
            status: UserStatus(rawValue: status) ?? .active,
            qrCodeID: UUID(uuidString: qrCodeID) ?? UUID()
        )
    }
    
    static func fromDomain(_ user: User) -> UserDTO {
        return UserDTO(
            id: user.id.uuidString,
            firstName: user.firstName,
            lastName: user.lastName,
            phoneNumber: user.phoneNumber,
            profileImageURL: user.profileImageURL?.absoluteString,
            emergencyNote: user.emergencyNote,
            checkInInterval: user.checkInInterval,
            reminderInterval: user.reminderInterval,
            lastCheckInTime: user.lastCheckInTime,
            status: user.status.rawValue,
            qrCodeID: user.qrCodeID.uuidString
        )
    }
}
```

Similar DTOs are implemented for all domain models:

- **ContactDTO**: Maps between Contact domain model and backend data
- **CheckInRecordDTO**: Maps between CheckInRecord domain model and backend data
- **AlertDTO**: Maps between Alert domain model and backend data
- **PingDTO**: Maps between Ping domain model and backend data
- **NotificationDTO**: Maps between Notification domain model and backend data

## Client Implementation

Client interfaces are implemented using adapters that bridge between the interface and the backend service:

```swift
extension UserClient: DependencyKey {
    static var liveValue: Self {
        let adapter = FirebaseUserAdapter()
        
        return Self(
            currentUser: {
                try await adapter.currentUser()
            },
            updateProfile: { firstName, lastName, emergencyNote in
                try await adapter.updateProfile(
                    firstName: firstName,
                    lastName: lastName,
                    emergencyNote: emergencyNote
                )
            },
            updateProfileImage: { image in
                try await adapter.updateProfileImage(image: image)
            },
            refreshQRCodeID: {
                try await adapter.refreshQRCodeID()
            },
            userStream: {
                await adapter.userStream()
            },
            currentUserID: {
                adapter.currentUserID()
            }
        )
    }
}
```

## Error Handling

Backend errors are mapped to client errors:

```swift
enum UserError: Error, Equatable, Sendable {
    case networkError(String)
    case authenticationError(String)
    case validationError(String)
    case notFoundError(String)
    case serverError(String)
    case unknownError(String)
}

extension FirebaseUserAdapter {
    private func handleError(_ error: Error) -> UserError {
        if let nsError = error as NSError {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return .networkError("Not connected to the internet")
            case NSURLErrorTimedOut:
                return .networkError("Request timed out")
            default:
                break
            }
        }
        
        if let firebaseError = error as NSError {
            switch firebaseError.code {
            case AuthErrorCode.userNotFound.rawValue:
                return .notFoundError("User not found")
            case AuthErrorCode.userTokenExpired.rawValue:
                return .authenticationError("User token expired")
            case AuthErrorCode.invalidUserToken.rawValue:
                return .authenticationError("Invalid user token")
            default:
                break
            }
        }
        
        return .unknownError(error.localizedDescription)
    }
}
```

## Streaming Implementation

Streaming is implemented using AsyncStream to wrap Firebase listeners:

```swift
func userStream() -> AsyncStream<User> {
    AsyncStream { continuation in
        let userID = Auth.auth().currentUser?.uid ?? ""
        let listener = db.collection("users").document(userID)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    // Handle error
                    return
                }
                
                guard let snapshot = snapshot, snapshot.exists else {
                    // Handle missing document
                    return
                }
                
                do {
                    let userDTO = try snapshot.data(as: UserDTO.self)
                    let user = userDTO.toDomain()
                    continuation.yield(user)
                } catch {
                    // Handle decoding error
                }
            }
        
        continuation.onTermination = { _ in
            listener.remove()
        }
    }
}
```

## Migration Strategy

The migration from Firebase to Supabase will follow a phased approach:

1. **Phase 1**: Implement Supabase adapters alongside Firebase adapters
2. **Phase 2**: Migrate authentication to Supabase
3. **Phase 3**: Migrate database operations to Supabase
4. **Phase 4**: Migrate storage operations to Supabase
5. **Phase 5**: Migrate functions to Supabase

During the migration, both Firebase and Supabase adapters will be maintained, with a feature flag system to control which backend is used for each feature.

## Conclusion

The backend integration architecture provides a flexible, testable, and maintainable approach to integrating with backend services. By using a layered approach with client interfaces, adapters, and DTOs, the LifeSignal iOS application can easily switch between different backend services without affecting the feature layer.
