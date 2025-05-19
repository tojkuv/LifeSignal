# LifeSignal iOS Client Interfaces

**Navigation:** [Back to Infrastructure](README.md) | [Back to Application Specification](../README.md) | [Backend Integration](BackendIntegration.md)

---

## Overview

This document provides detailed specifications for the client interfaces used in the LifeSignal iOS application. Client interfaces define the contract between features and infrastructure, allowing features to interact with external services without depending on specific implementations.

## Client Interface Pattern

The LifeSignal application uses a consistent pattern for client interfaces:

```swift
// Client interface
struct ClientName: Sendable {
    var functionName: @Sendable (Parameters) async throws -> ReturnType
    
    // Other functions
}

// Dependency registration
extension ClientName: DependencyKey {
    static var liveValue: Self {
        Self(
            functionName: { parameters in
                // Implementation
            }
        )
    }
    
    static var testValue: Self {
        Self(
            functionName: { parameters in
                // Test implementation
            }
        )
    }
}

extension DependencyValues {
    var clientName: ClientName {
        get { self[ClientName.self] }
        set { self[ClientName.self] = newValue }
    }
}
```

This pattern provides several benefits:

1. **Dependency Injection**: Clients can be injected into features using TCA's dependency injection system
2. **Testability**: Test implementations can be provided for testing
3. **Flexibility**: Different implementations can be provided for different environments
4. **Type Safety**: Function signatures provide type safety for parameters and return values

## Core Client Interfaces

### AuthClient

The AuthClient interface provides authentication operations:

```swift
struct AuthClient: Sendable {
    var signIn: @Sendable (String) async throws -> Void
    var verify: @Sendable (String) async throws -> User
    var signOut: @Sendable () async throws -> Void
    var currentUser: @Sendable () async throws -> User?
    var authStateStream: @Sendable () async -> AsyncStream<User?>
}
```

#### Function Signatures

- **signIn**: Initiates the sign-in process with a phone number
  - Parameters: Phone number (String)
  - Returns: Void
  - Throws: AuthError

- **verify**: Verifies a verification code
  - Parameters: Verification code (String)
  - Returns: User
  - Throws: AuthError

- **signOut**: Signs out the current user
  - Parameters: None
  - Returns: Void
  - Throws: AuthError

- **currentUser**: Gets the current user
  - Parameters: None
  - Returns: User? (optional)
  - Throws: AuthError

- **authStateStream**: Streams authentication state changes
  - Parameters: None
  - Returns: AsyncStream<User?>
  - Throws: None

### UserClient

The UserClient interface provides user profile operations:

```swift
struct UserClient: Sendable {
    var currentUser: @Sendable () async throws -> User
    var updateProfile: @Sendable (String, String, String) async throws -> Void
    var updateProfileImage: @Sendable (UIImage) async throws -> URL
    var refreshQRCodeID: @Sendable () async throws -> Void
    var userStream: @Sendable () async -> AsyncStream<User>
    var currentUserID: @Sendable () -> UUID
}
```

#### Function Signatures

- **currentUser**: Gets the current user's profile
  - Parameters: None
  - Returns: User
  - Throws: UserError

- **updateProfile**: Updates the user's profile
  - Parameters: First name (String), Last name (String), Emergency note (String)
  - Returns: Void
  - Throws: UserError

- **updateProfileImage**: Updates the user's profile image
  - Parameters: Image (UIImage)
  - Returns: URL (of the uploaded image)
  - Throws: UserError

- **refreshQRCodeID**: Refreshes the user's QR code ID
  - Parameters: None
  - Returns: Void
  - Throws: UserError

- **userStream**: Streams user profile changes
  - Parameters: None
  - Returns: AsyncStream<User>
  - Throws: None

- **currentUserID**: Gets the current user's ID
  - Parameters: None
  - Returns: UUID
  - Throws: None

### ContactClient

The ContactClient interface provides contact operations:

```swift
struct ContactClient: Sendable {
    var getContacts: @Sendable () async throws -> IdentifiedArrayOf<Contact>
    var getContact: @Sendable (UUID) async throws -> Contact
    var addContact: @Sendable (UUID, String, String, String, Bool, Bool) async throws -> Contact
    var updateContact: @Sendable (Contact) async throws -> Contact
    var removeContact: @Sendable (UUID) async throws -> Void
    var getContactInfo: @Sendable (String) async throws -> ContactInfo
    var contactsStream: @Sendable () async -> AsyncStream<IdentifiedArrayOf<Contact>>
}
```

#### Function Signatures

- **getContacts**: Gets all contacts
  - Parameters: None
  - Returns: IdentifiedArrayOf<Contact>
  - Throws: ContactError

- **getContact**: Gets a specific contact
  - Parameters: Contact ID (UUID)
  - Returns: Contact
  - Throws: ContactError

- **addContact**: Adds a new contact
  - Parameters: Contact ID (UUID), First name (String), Last name (String), Phone number (String), Is responder (Bool), Is dependent (Bool)
  - Returns: Contact
  - Throws: ContactError

- **updateContact**: Updates a contact
  - Parameters: Contact
  - Returns: Contact
  - Throws: ContactError

- **removeContact**: Removes a contact
  - Parameters: Contact ID (UUID)
  - Returns: Void
  - Throws: ContactError

- **getContactInfo**: Gets contact information from a QR code
  - Parameters: QR code (String)
  - Returns: ContactInfo
  - Throws: ContactError

- **contactsStream**: Streams contact changes
  - Parameters: None
  - Returns: AsyncStream<IdentifiedArrayOf<Contact>>
  - Throws: None

### CheckInClient

The CheckInClient interface provides check-in operations:

```swift
struct CheckInClient: Sendable {
    var checkIn: @Sendable () async throws -> Date
    var getCheckInHistory: @Sendable (Int?) async throws -> [CheckInRecord]
    var getCheckInInterval: @Sendable () async throws -> TimeInterval
    var setCheckInInterval: @Sendable (TimeInterval) async throws -> Void
    var getReminderInterval: @Sendable () async throws -> TimeInterval
    var setReminderInterval: @Sendable (TimeInterval) async throws -> Void
}
```

#### Function Signatures

- **checkIn**: Records a check-in
  - Parameters: None
  - Returns: Date (of the check-in)
  - Throws: CheckInError

- **getCheckInHistory**: Gets check-in history
  - Parameters: Limit (Int?, optional)
  - Returns: [CheckInRecord]
  - Throws: CheckInError

- **getCheckInInterval**: Gets the check-in interval
  - Parameters: None
  - Returns: TimeInterval
  - Throws: CheckInError

- **setCheckInInterval**: Sets the check-in interval
  - Parameters: Interval (TimeInterval)
  - Returns: Void
  - Throws: CheckInError

- **getReminderInterval**: Gets the reminder interval
  - Parameters: None
  - Returns: TimeInterval
  - Throws: CheckInError

- **setReminderInterval**: Sets the reminder interval
  - Parameters: Interval (TimeInterval)
  - Returns: Void
  - Throws: CheckInError

### AlertClient

The AlertClient interface provides alert operations:

```swift
struct AlertClient: Sendable {
    var activateAlert: @Sendable () async throws -> Void
    var deactivateAlert: @Sendable () async throws -> Void
    var getAlertHistory: @Sendable (Int?) async throws -> [Alert]
    var isAlertActive: @Sendable () async throws -> Bool
    var alertStream: @Sendable () async -> AsyncStream<Alert?>
}
```

#### Function Signatures

- **activateAlert**: Activates an alert
  - Parameters: None
  - Returns: Void
  - Throws: AlertError

- **deactivateAlert**: Deactivates an alert
  - Parameters: None
  - Returns: Void
  - Throws: AlertError

- **getAlertHistory**: Gets alert history
  - Parameters: Limit (Int?, optional)
  - Returns: [Alert]
  - Throws: AlertError

- **isAlertActive**: Checks if an alert is active
  - Parameters: None
  - Returns: Bool
  - Throws: AlertError

- **alertStream**: Streams alert changes
  - Parameters: None
  - Returns: AsyncStream<Alert?>
  - Throws: None

### PingClient

The PingClient interface provides ping operations:

```swift
struct PingClient: Sendable {
    var sendPing: @Sendable (UUID) async throws -> Void
    var respondToPing: @Sendable (UUID) async throws -> Void
    var respondToAllPings: @Sendable () async throws -> Void
    var getPendingPings: @Sendable () async throws -> IdentifiedArrayOf<Ping>
    var getSentPings: @Sendable () async throws -> IdentifiedArrayOf<Ping>
    var pingStream: @Sendable () async -> AsyncStream<Ping>
}
```

#### Function Signatures

- **sendPing**: Sends a ping to a contact
  - Parameters: Contact ID (UUID)
  - Returns: Void
  - Throws: PingError

- **respondToPing**: Responds to a ping
  - Parameters: Ping ID (UUID)
  - Returns: Void
  - Throws: PingError

- **respondToAllPings**: Responds to all pending pings
  - Parameters: None
  - Returns: Void
  - Throws: PingError

- **getPendingPings**: Gets pending pings
  - Parameters: None
  - Returns: IdentifiedArrayOf<Ping>
  - Throws: PingError

- **getSentPings**: Gets sent pings
  - Parameters: None
  - Returns: IdentifiedArrayOf<Ping>
  - Throws: PingError

- **pingStream**: Streams ping changes
  - Parameters: None
  - Returns: AsyncStream<Ping>
  - Throws: None

### NotificationClient

The NotificationClient interface provides notification operations:

```swift
struct NotificationClient: Sendable {
    var getNotifications: @Sendable () async throws -> IdentifiedArrayOf<Notification>
    var markAsRead: @Sendable (UUID) async throws -> Void
    var markAllAsRead: @Sendable () async throws -> Void
    var deleteNotification: @Sendable (UUID) async throws -> Void
    var deleteAllNotifications: @Sendable () async throws -> Void
    var scheduleCheckInReminder: @Sendable (Date) async throws -> Void
    var updateNotificationSettings: @Sendable (NotificationPreferences) async throws -> Void
    var notificationStream: @Sendable () async -> AsyncStream<Notification>
}
```

#### Function Signatures

- **getNotifications**: Gets all notifications
  - Parameters: None
  - Returns: IdentifiedArrayOf<Notification>
  - Throws: NotificationError

- **markAsRead**: Marks a notification as read
  - Parameters: Notification ID (UUID)
  - Returns: Void
  - Throws: NotificationError

- **markAllAsRead**: Marks all notifications as read
  - Parameters: None
  - Returns: Void
  - Throws: NotificationError

- **deleteNotification**: Deletes a notification
  - Parameters: Notification ID (UUID)
  - Returns: Void
  - Throws: NotificationError

- **deleteAllNotifications**: Deletes all notifications
  - Parameters: None
  - Returns: Void
  - Throws: NotificationError

- **scheduleCheckInReminder**: Schedules a check-in reminder
  - Parameters: Reminder time (Date)
  - Returns: Void
  - Throws: NotificationError

- **updateNotificationSettings**: Updates notification settings
  - Parameters: Notification preferences (NotificationPreferences)
  - Returns: Void
  - Throws: NotificationError

- **notificationStream**: Streams notification changes
  - Parameters: None
  - Returns: AsyncStream<Notification>
  - Throws: None

### QRCodeClient

The QRCodeClient interface provides QR code operations:

```swift
struct QRCodeClient: Sendable {
    var generateQRCode: @Sendable (UUID) async throws -> UIImage
    var parseQRCode: @Sendable (String) async throws -> UUID
}
```

#### Function Signatures

- **generateQRCode**: Generates a QR code image
  - Parameters: QR code ID (UUID)
  - Returns: UIImage
  - Throws: QRCodeError

- **parseQRCode**: Parses a QR code string
  - Parameters: QR code string (String)
  - Returns: UUID
  - Throws: QRCodeError

### SettingsClient

The SettingsClient interface provides settings operations:

```swift
struct SettingsClient: Sendable {
    var getNotificationPreferences: @Sendable () async throws -> NotificationPreferences
    var updateNotificationPreferences: @Sendable (NotificationPreferences) async throws -> Void
}
```

#### Function Signatures

- **getNotificationPreferences**: Gets notification preferences
  - Parameters: None
  - Returns: NotificationPreferences
  - Throws: SettingsError

- **updateNotificationPreferences**: Updates notification preferences
  - Parameters: Notification preferences (NotificationPreferences)
  - Returns: Void
  - Throws: SettingsError

### StorageClient

The StorageClient interface provides storage operations:

```swift
struct StorageClient: Sendable {
    var uploadImage: @Sendable (UIImage) async throws -> URL
    var downloadImage: @Sendable (URL) async throws -> UIImage
    var deleteImage: @Sendable (URL) async throws -> Void
}
```

#### Function Signatures

- **uploadImage**: Uploads an image
  - Parameters: Image (UIImage)
  - Returns: URL (of the uploaded image)
  - Throws: StorageError

- **downloadImage**: Downloads an image
  - Parameters: URL
  - Returns: UIImage
  - Throws: StorageError

- **deleteImage**: Deletes an image
  - Parameters: URL
  - Returns: Void
  - Throws: StorageError

### ImageClient

The ImageClient interface provides image operations:

```swift
struct ImageClient: Sendable {
    var resizeImage: @Sendable (UIImage, CGSize) -> UIImage
    var cropImage: @Sendable (UIImage, CGRect) -> UIImage
    var compressImage: @Sendable (UIImage, CGFloat) -> Data
}
```

#### Function Signatures

- **resizeImage**: Resizes an image
  - Parameters: Image (UIImage), Size (CGSize)
  - Returns: UIImage
  - Throws: None

- **cropImage**: Crops an image
  - Parameters: Image (UIImage), Rect (CGRect)
  - Returns: UIImage
  - Throws: None

- **compressImage**: Compresses an image
  - Parameters: Image (UIImage), Quality (CGFloat)
  - Returns: Data
  - Throws: None

## Error Handling

Client interfaces use a consistent error handling approach:

```swift
enum ClientNameError: Error, Equatable, Sendable {
    case networkError(String)
    case authenticationError(String)
    case validationError(String)
    case notFoundError(String)
    case serverError(String)
    case unknownError(String)
}
```

This approach provides:

1. **Type Safety**: Errors are strongly typed
2. **Error Context**: Errors include descriptive messages
3. **Error Categorization**: Errors are categorized by type
4. **Error Handling**: Errors can be handled appropriately by features

## Client Implementation

Client interfaces are implemented using adapters that bridge between the interface and the backend service:

```swift
class BackendNameClientNameAdapter {
    private let backendService: BackendService
    
    init(backendService: BackendService = .shared) {
        self.backendService = backendService
    }
    
    func functionName(parameters: Parameters) async throws -> ReturnType {
        // Implementation using backendService
    }
    
    // Other functions
}
```

The adapter is then used to create a live implementation of the client interface:

```swift
extension ClientName: DependencyKey {
    static var liveValue: Self {
        let adapter = BackendNameClientNameAdapter()
        
        return Self(
            functionName: { parameters in
                try await adapter.functionName(parameters: parameters)
            }
        )
    }
}
```

## Testing

Client interfaces are designed to be easily testable:

```swift
extension ClientName: DependencyKey {
    static var testValue: Self {
        Self(
            functionName: { parameters in
                // Test implementation
            }
        )
    }
}
```

Test implementations can:

1. **Return Mock Data**: For testing happy paths
2. **Throw Errors**: For testing error handling
3. **Record Calls**: For verifying function calls
4. **Simulate Delays**: For testing loading states
5. **Simulate Network Conditions**: For testing network handling

## Conclusion

The client interfaces provide a clean separation between features and infrastructure, allowing features to interact with external services without depending on specific implementations. This approach provides flexibility, testability, and maintainability for the LifeSignal iOS application.
