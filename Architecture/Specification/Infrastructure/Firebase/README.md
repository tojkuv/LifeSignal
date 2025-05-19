# LifeSignal iOS Firebase Integration

**Navigation:** [Back to Infrastructure Layer](../README.md) | [Testing Strategy](../Testing/README.md)

---

## Overview

The LifeSignal iOS application uses Firebase as its primary backend service. This document provides detailed information on how Firebase is integrated into the application, including the Firebase services used, data models, security rules, and best practices.

## Firebase Services

The LifeSignal iOS application uses the following Firebase services:

1. **Firebase Authentication** - User authentication and session management
2. **Firebase Firestore** - NoSQL database for storing application data
3. **Firebase Cloud Messaging** - Push notifications
4. **Firebase Storage** - File storage for user profile pictures and other media
5. **Firebase Functions** - Serverless functions for backend logic
6. **Firebase Analytics** - User analytics and event tracking

## Firebase Authentication

Firebase Authentication is used for user authentication and session management. The application uses phone number authentication, which allows users to sign in using their phone number and a verification code sent via SMS.

### Authentication Flow

1. User enters their phone number
2. Application calls `verifyPhoneNumber` to send a verification code
3. User enters the verification code
4. Application calls `signInWithCredential` to complete the authentication
5. User is signed in and can access the application

### Authentication Adapters

The `FirebaseAuthAdapter` implements the `AuthClient` interface using Firebase Authentication. It provides methods for signing in, signing out, and checking the current authentication state.

```swift
struct FirebaseAuthAdapter {
    private let auth = Auth.auth()
    
    func signIn(phoneNumber: String, verificationCode: String) async throws -> String {
        // Implementation details...
    }
    
    func signOut() async throws {
        // Implementation details...
    }
    
    func getCurrentUser() -> String? {
        // Implementation details...
    }
    
    // Other methods...
}
```

## Firebase Firestore

Firebase Firestore is used as the primary database for storing application data. It stores user profiles, contacts, check-ins, alerts, pings, and other application data.

### Data Models

The following collections are used in Firestore:

1. **users** - User profiles
   - `id`: String (User ID)
   - `firstName`: String
   - `lastName`: String
   - `phoneNumber`: String
   - `profilePictureURL`: String (optional)
   - `emergencyNote`: String (optional)
   - `lastCheckInTime`: Timestamp
   - `checkInInterval`: Number (seconds)
   - `reminderInterval`: Number (seconds)
   - `createdAt`: Timestamp
   - `updatedAt`: Timestamp

2. **contacts** - User contacts and relationships
   - `id`: String (Contact ID)
   - `userId`: String (User ID)
   - `contactId`: String (Contact User ID)
   - `isResponder`: Boolean
   - `isDependent`: Boolean
   - `createdAt`: Timestamp
   - `updatedAt`: Timestamp

3. **checkIns** - User check-ins
   - `id`: String (Check-in ID)
   - `userId`: String (User ID)
   - `timestamp`: Timestamp
   - `createdAt`: Timestamp

4. **alerts** - User alerts
   - `id`: String (Alert ID)
   - `userId`: String (User ID)
   - `timestamp`: Timestamp
   - `isActive`: Boolean
   - `createdAt`: Timestamp
   - `updatedAt`: Timestamp

5. **pings** - User pings
   - `id`: String (Ping ID)
   - `senderId`: String (Sender User ID)
   - `recipientId`: String (Recipient User ID)
   - `timestamp`: Timestamp
   - `isResponded`: Boolean
   - `respondedAt`: Timestamp (optional)
   - `createdAt`: Timestamp

6. **notifications** - User notifications
   - `id`: String (Notification ID)
   - `userId`: String (User ID)
   - `type`: String (alert, ping, role, removed, added, checkIn)
   - `relatedUserId`: String (optional)
   - `timestamp`: Timestamp
   - `isRead`: Boolean
   - `createdAt`: Timestamp

### Firestore Adapters

The following adapters implement the client interfaces using Firebase Firestore:

1. **FirebaseUserAdapter** - Implements `UserClient`
2. **FirebaseContactAdapter** - Implements `ContactClient`
3. **FirebaseCheckInAdapter** - Implements `CheckInClient`
4. **FirebaseAlertAdapter** - Implements `AlertClient`
5. **FirebasePingAdapter** - Implements `PingClient`
6. **FirebaseNotificationAdapter** - Implements `NotificationClient`

Example adapter implementation:

```swift
struct FirebaseUserAdapter {
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    
    func getUser() async throws -> User {
        guard let userId = auth.currentUser?.uid else {
            throw UserError.notAuthenticated
        }
        
        let document = try await db.collection("users").document(userId).getDocument()
        
        guard let data = document.data() else {
            throw UserError.userNotFound
        }
        
        return try mapToUser(data, id: userId)
    }
    
    func updateUser(_ user: User) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw UserError.notAuthenticated
        }
        
        let data = mapToData(user)
        
        try await db.collection("users").document(userId).updateData(data)
    }
    
    // Other methods...
    
    private func mapToUser(_ data: [String: Any], id: String) throws -> User {
        guard
            let firstName = data["firstName"] as? String,
            let lastName = data["lastName"] as? String,
            let phoneNumber = data["phoneNumber"] as? String
        else {
            throw UserError.invalidData
        }
        
        return User(
            id: id,
            firstName: firstName,
            lastName: lastName,
            phoneNumber: phoneNumber,
            profilePictureURL: data["profilePictureURL"] as? String,
            emergencyNote: data["emergencyNote"] as? String,
            lastCheckInTime: (data["lastCheckInTime"] as? Timestamp)?.dateValue(),
            checkInInterval: (data["checkInInterval"] as? NSNumber)?.doubleValue ?? 86400,
            reminderInterval: (data["reminderInterval"] as? NSNumber)?.doubleValue ?? 7200
        )
    }
    
    private func mapToData(_ user: User) -> [String: Any] {
        var data: [String: Any] = [
            "firstName": user.firstName,
            "lastName": user.lastName,
            "phoneNumber": user.phoneNumber,
            "checkInInterval": user.checkInInterval,
            "reminderInterval": user.reminderInterval,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        if let profilePictureURL = user.profilePictureURL {
            data["profilePictureURL"] = profilePictureURL
        }
        
        if let emergencyNote = user.emergencyNote {
            data["emergencyNote"] = emergencyNote
        }
        
        if let lastCheckInTime = user.lastCheckInTime {
            data["lastCheckInTime"] = Timestamp(date: lastCheckInTime)
        }
        
        return data
    }
}
```

## Firebase Cloud Messaging

Firebase Cloud Messaging (FCM) is used for push notifications. The application uses FCM to send notifications for alerts, pings, check-in reminders, and other events.

### Notification Types

The application sends the following types of notifications:

1. **Alert Notifications** - Sent when a user triggers an alert
2. **Ping Notifications** - Sent when a user pings another user
3. **Check-In Reminders** - Sent when a user's check-in is due
4. **Role Change Notifications** - Sent when a user's role (responder or dependent) changes
5. **Contact Notifications** - Sent when a user is added or removed as a contact

### FCM Integration

The `FirebaseNotificationAdapter` implements the `NotificationClient` interface using Firebase Cloud Messaging. It provides methods for registering for notifications, handling notification payloads, and managing notification preferences.

```swift
struct FirebaseNotificationAdapter {
    private let messaging = Messaging.messaging()
    private let auth = Auth.auth()
    
    func registerForNotifications() async throws {
        guard let userId = auth.currentUser?.uid else {
            throw NotificationError.notAuthenticated
        }
        
        let token = try await messaging.token()
        
        try await Firestore.firestore().collection("users").document(userId).updateData([
            "fcmToken": token
        ])
    }
    
    func handleNotification(_ userInfo: [AnyHashable: Any]) async throws {
        // Implementation details...
    }
    
    // Other methods...
}
```

## Firebase Storage

Firebase Storage is used for storing user profile pictures and other media. The application uses Firebase Storage to upload and download images.

### Storage Adapters

The `FirebaseStorageAdapter` implements the `StorageClient` interface using Firebase Storage. It provides methods for uploading and downloading files.

```swift
struct FirebaseStorageAdapter {
    private let storage = Storage.storage()
    private let auth = Auth.auth()
    
    func uploadProfilePicture(_ imageData: Data) async throws -> String {
        guard let userId = auth.currentUser?.uid else {
            throw StorageError.notAuthenticated
        }
        
        let storageRef = storage.reference().child("profilePictures/\(userId).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        
        let downloadURL = try await storageRef.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    func downloadProfilePicture(url: String) async throws -> Data {
        let storageRef = storage.reference(forURL: url)
        
        let maxSize: Int64 = 1 * 1024 * 1024 // 1MB
        
        return try await storageRef.data(maxSize: maxSize)
    }
    
    // Other methods...
}
```

## Firebase Functions

Firebase Functions are used for serverless backend logic. The application uses Firebase Functions for operations that require server-side processing, such as sending SMS messages, processing alerts, and handling check-in reminders.

### Functions Integration

The application calls Firebase Functions using the Firebase Functions SDK. Functions are called from the appropriate adapters when server-side processing is required.

```swift
struct FirebaseFunctionsAdapter {
    private let functions = Functions.functions()
    
    func sendAlert(userId: String) async throws {
        let data: [String: Any] = [
            "userId": userId
        ]
        
        _ = try await functions.httpsCallable("sendAlert").call(data)
    }
    
    // Other methods...
}
```

## Firebase Analytics

Firebase Analytics is used for user analytics and event tracking. The application uses Firebase Analytics to track user behavior, feature usage, and application performance.

### Analytics Events

The application tracks the following events:

1. **User Sign-In** - When a user signs in
2. **User Sign-Out** - When a user signs out
3. **Check-In** - When a user checks in
4. **Alert Triggered** - When a user triggers an alert
5. **Ping Sent** - When a user sends a ping
6. **Ping Responded** - When a user responds to a ping
7. **Contact Added** - When a user adds a contact
8. **Contact Removed** - When a user removes a contact
9. **Role Changed** - When a user's role changes

### Analytics Integration

The `FirebaseAnalyticsAdapter` implements the `AnalyticsClient` interface using Firebase Analytics. It provides methods for tracking events and user properties.

```swift
struct FirebaseAnalyticsAdapter {
    func trackEvent(_ name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
    }
    
    func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }
    
    // Other methods...
}
```

## Firebase Configuration

The application uses Firebase configuration files to configure Firebase services. The configuration files are included in the application bundle and loaded at runtime.

### GoogleService-Info.plist

The `GoogleService-Info.plist` file contains the Firebase configuration for the application. It includes the Firebase project ID, API key, and other configuration parameters.

### Firebase App Initialization

The application initializes Firebase in the `AppDelegate` or `App` struct, depending on the application's lifecycle management.

```swift
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}
```

## Error Handling

Firebase adapters handle Firebase-specific errors and map them to domain-specific errors. This allows features to handle errors in a consistent way without knowing the specific Firebase implementation details.

Example error handling:

```swift
enum FirebaseError: Error, LocalizedError {
    case notAuthenticated
    case networkError
    case serverError
    case permissionDenied
    case documentNotFound
    case invalidData
    case unknownError(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You are not signed in. Please sign in to continue."
        case .networkError:
            return "A network error occurred. Please check your internet connection and try again."
        case .serverError:
            return "The server is currently unavailable. Please try again later."
        case .permissionDenied:
            return "You do not have permission to perform this action."
        case .documentNotFound:
            return "The requested document was not found."
        case .invalidData:
            return "The data is invalid or corrupted."
        case let .unknownError(error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}
```

## Best Practices

When working with Firebase in the LifeSignal iOS application, follow these best practices:

1. **Use Firebase adapters** - Use Firebase adapters to implement client interfaces, keeping Firebase-specific code isolated from the rest of the application.

2. **Handle Firebase-specific errors** - Handle Firebase-specific errors and map them to domain-specific errors.

3. **Use Firebase DTOs** - Use DTOs to map between domain models and Firebase data structures.

4. **Batch operations when possible** - Use Firebase batch operations to perform multiple operations atomically.

5. **Use Firebase transactions for concurrent updates** - Use Firebase transactions to handle concurrent updates to the same document.

6. **Optimize queries** - Use Firebase query optimization techniques, such as compound queries and query cursors, to improve performance.

7. **Use Firebase security rules** - Use Firebase security rules to enforce access control and data validation.

8. **Monitor Firebase usage** - Monitor Firebase usage to ensure the application stays within Firebase's free tier limits or budget.

9. **Use Firebase offline capabilities** - Use Firebase's offline capabilities to provide a good user experience when the device is offline.

10. **Test Firebase integration** - Test Firebase integration thoroughly, including error handling, data mapping, and offline behavior.
