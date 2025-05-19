# LifeSignal iOS Utility Features

**Navigation:** [Back to Features](README.md) | [Core Features](CoreFeatures.md) | [Contact Features](ContactFeatures.md) | [Safety Features](SafetyFeatures.md)

---

## Overview

This document provides detailed specifications for the utility features of the LifeSignal iOS application. Utility features provide supporting functionality, including notifications, QR code generation and scanning, and settings.

## NotificationFeature

The [NotificationFeature](Notification/README.md) manages notifications and reminders.

### State

```swift
@ObservableState
struct State: Equatable, Sendable {
    var notifications: IdentifiedArrayOf<Notification> = []
    var selectedFilter: NotificationFilter = .all
    var isLoading: Bool = false
    var error: UserFacingError?

    enum NotificationFilter: String, Equatable, Sendable, CaseIterable {
        case all = "All"
        case alerts = "Alerts"
        case pings = "Pings"
        case roles = "Roles"
        case contacts = "Contacts"
        case checkIns = "Check-Ins"
    }
}
```

### Action

```swift
enum Action: Equatable, Sendable {
    // Lifecycle actions
    case onAppear

    // User actions
    case selectFilter(NotificationFilter)
    case markAsRead(UUID)
    case markAllAsRead
    case deleteNotification(UUID)
    case deleteAllNotifications

    // System actions
    case loadNotifications
    case notificationsLoaded(IdentifiedArrayOf<Notification>)
    case notificationsLoadFailed(UserFacingError)
    case markAsReadResponse(TaskResult<Void>)
    case markAllAsReadResponse(TaskResult<Void>)
    case deleteNotificationResponse(TaskResult<Void>)
    case deleteAllNotificationsResponse(TaskResult<Void>)
    case streamNotificationUpdates
    case notificationReceived(Notification)

    // Error handling
    case setError(UserFacingError?)
    case dismissError
}
```

### Dependencies

- **NotificationClient**: For notification operations

### Responsibilities

- Displays notifications
- Filters notifications by type
- Marks notifications as read
- Deletes notifications
- Streams notification updates from the server

### Implementation Details

The NotificationFeature manages notifications:

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case .onAppear:
            return .merge(
                .send(.loadNotifications),
                .send(.streamNotificationUpdates)
            )

        case .loadNotifications:
            state.isLoading = true
            return .run { send in
                do {
                    let notifications = try await notificationClient.getNotifications()
                    await send(.notificationsLoaded(notifications))
                } catch {
                    await send(.notificationsLoadFailed(UserFacingError(error)))
                }
            }

        case let .notificationsLoaded(notifications):
            state.isLoading = false
            state.notifications = notifications
            return .none

        case let .notificationsLoadFailed(error):
            state.isLoading = false
            state.error = error
            return .none

        case let .selectFilter(filter):
            state.selectedFilter = filter
            return .none

        case let .markAsRead(notificationID):
            return .run { send in
                do {
                    try await notificationClient.markAsRead(notificationID: notificationID)
                    await send(.markAsReadResponse(.success))
                } catch {
                    await send(.markAsReadResponse(.failure(error)))
                }
            }

        case .markAllAsRead:
            return .run { send in
                do {
                    try await notificationClient.markAllAsRead()
                    await send(.markAllAsReadResponse(.success))
                } catch {
                    await send(.markAllAsReadResponse(.failure(error)))
                }
            }

        case let .deleteNotification(notificationID):
            return .run { send in
                do {
                    try await notificationClient.deleteNotification(notificationID: notificationID)
                    await send(.deleteNotificationResponse(.success))
                } catch {
                    await send(.deleteNotificationResponse(.failure(error)))
                }
            }

        case .deleteAllNotifications:
            return .run { send in
                do {
                    try await notificationClient.deleteAllNotifications()
                    await send(.deleteAllNotificationsResponse(.success))
                } catch {
                    await send(.deleteAllNotificationsResponse(.failure(error)))
                }
            }

        case .markAsReadResponse(.success):
            // Notification marked as read, will be updated via stream
            return .none

        case let .markAsReadResponse(.failure(error)):
            state.error = UserFacingError(error)
            return .none

        case .markAllAsReadResponse(.success):
            // All notifications marked as read, will be updated via stream
            return .none

        case let .markAllAsReadResponse(.failure(error)):
            state.error = UserFacingError(error)
            return .none

        case .deleteNotificationResponse(.success):
            // Notification deleted, will be updated via stream
            return .none

        case let .deleteNotificationResponse(.failure(error)):
            state.error = UserFacingError(error)
            return .none

        case .deleteAllNotificationsResponse(.success):
            // All notifications deleted, will be updated via stream
            return .none

        case let .deleteAllNotificationsResponse(.failure(error)):
            state.error = UserFacingError(error)
            return .none

        case .streamNotificationUpdates:
            return .run { send in
                for await notification in await notificationClient.notificationStream() {
                    await send(.notificationReceived(notification))
                }
            }
            .cancellable(id: CancelID.notificationStream)

        case let .notificationReceived(notification):
            if let index = state.notifications.firstIndex(where: { $0.id == notification.id }) {
                state.notifications[index] = notification
            } else {
                state.notifications.append(notification)
            }
            return .none

        // Error handling...
        }
    }
}
```

## QRCodeFeature

The [QRCodeFeature](QRCode/README.md) manages QR code generation and sharing.

### State

```swift
@ObservableState
struct State: Equatable, Sendable {
    @Shared(.fileStorage(.userProfile)) var user: User = User(id: UUID())
    var qrCodeImage: UIImage?
    var isGenerating: Bool = false
    var error: UserFacingError?
}
```

### Action

```swift
enum Action: Equatable, Sendable {
    // Lifecycle actions
    case onAppear

    // User actions
    case refreshQRCode
    case shareQRCode

    // System actions
    case generateQRCode
    case qrCodeGenerated(UIImage)
    case qrCodeGenerationFailed(UserFacingError)

    // Error handling
    case setError(UserFacingError?)
    case dismissError
}
```

### Dependencies

- **QRCodeClient**: For QR code operations
- **UserClient**: For user profile operations

### Responsibilities

- Generates QR codes for contact sharing
- Refreshes QR codes
- Provides QR code sharing
- Displays QR code ID for manual entry

### Implementation Details

The QRCodeFeature manages QR code generation and sharing:

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case .onAppear:
            return .send(.generateQRCode)

        case .refreshQRCode:
            // Generate a new QR code ID
            return .run { send in
                do {
                    try await userClient.refreshQRCodeID()
                    await send(.generateQRCode)
                } catch {
                    await send(.setError(UserFacingError(error)))
                }
            }

        case .generateQRCode:
            state.isGenerating = true
            return .run { [qrCodeID = state.user.qrCodeID] send in
                do {
                    let qrCodeImage = try await qrCodeClient.generateQRCode(for: qrCodeID)
                    await send(.qrCodeGenerated(qrCodeImage))
                } catch {
                    await send(.qrCodeGenerationFailed(UserFacingError(error)))
                }
            }

        case let .qrCodeGenerated(image):
            state.isGenerating = false
            state.qrCodeImage = image
            return .none

        case let .qrCodeGenerationFailed(error):
            state.isGenerating = false
            state.error = error
            return .none

        case .shareQRCode:
            // Handled by the view
            return .none

        // Error handling...
        }
    }
}
```

## SettingsFeature

The SettingsFeature manages application settings.

### State

```swift
@ObservableState
struct State: Equatable, Sendable {
    @Shared(.appStorage("notificationPreferences")) var notificationPreferences: NotificationPreferences = .default
    var isLoading: Bool = false
    var error: UserFacingError?

    struct NotificationPreferences: Equatable, Codable, Sendable {
        var alertNotifications: Bool = true
        var pingNotifications: Bool = true
        var checkInNotifications: Bool = true
        var contactNotifications: Bool = true

        static let `default` = NotificationPreferences()
    }
}
```

### Action

```swift
enum Action: Equatable, Sendable {
    // Lifecycle actions
    case onAppear

    // User actions
    case toggleAlertNotifications
    case togglePingNotifications
    case toggleCheckInNotifications
    case toggleContactNotifications

    // System actions
    case loadSettings
    case settingsLoaded(NotificationPreferences)
    case settingsLoadFailed(UserFacingError)
    case updateSettingsResponse(TaskResult<Void>)

    // Error handling
    case setError(UserFacingError?)
    case dismissError
}
```

### Dependencies

- **SettingsClient**: For settings operations
- **NotificationClient**: For notification operations

### Responsibilities

- Manages notification preferences
- Persists settings
- Applies settings to the application

### Implementation Details

The SettingsFeature manages application settings:

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case .onAppear:
            return .send(.loadSettings)

        case .loadSettings:
            state.isLoading = true
            return .run { send in
                do {
                    let preferences = try await settingsClient.getNotificationPreferences()
                    await send(.settingsLoaded(preferences))
                } catch {
                    await send(.settingsLoadFailed(UserFacingError(error)))
                }
            }

        case let .settingsLoaded(preferences):
            state.isLoading = false
            state.notificationPreferences = preferences
            return .none

        case let .settingsLoadFailed(error):
            state.isLoading = false
            state.error = error
            return .none

        case .toggleAlertNotifications:
            state.notificationPreferences.alertNotifications.toggle()
            return .send(.updateSettingsResponse(.success))

        case .togglePingNotifications:
            state.notificationPreferences.pingNotifications.toggle()
            return .send(.updateSettingsResponse(.success))

        case .toggleCheckInNotifications:
            state.notificationPreferences.checkInNotifications.toggle()
            return .send(.updateSettingsResponse(.success))

        case .toggleContactNotifications:
            state.notificationPreferences.contactNotifications.toggle()
            return .send(.updateSettingsResponse(.success))

        case .updateSettingsResponse(.success):
            return .run { [preferences = state.notificationPreferences] _ in
                try await settingsClient.updateNotificationPreferences(preferences)
                try await notificationClient.updateNotificationSettings(preferences)
            }

        case let .updateSettingsResponse(.failure(error)):
            state.error = UserFacingError(error)
            return .none

        // Error handling...
        }
    }
}
```

## ProfileFeature

The ProfileFeature manages the user's profile information and settings.

### State

```swift
@ObservableState
struct State: Equatable, Sendable {
    @Shared(.fileStorage(.userProfile)) var user: User = User(id: UUID())
    var isEditing: Bool = false
    var editedFirstName: String = ""
    var editedLastName: String = ""
    var editedEmergencyNote: String = ""
    var isLoading: Bool = false
    var error: UserFacingError?
    @Presents var destination: Destination.State?

    enum Destination: Equatable, Sendable {
        case qrCode(QRCodeFeature.State)
        case settings(SettingsFeature.State)
    }
}
```

### Action

```swift
enum Action: Equatable, Sendable {
    // Lifecycle actions
    case onAppear

    // User actions
    case editButtonTapped
    case cancelEditButtonTapped
    case saveButtonTapped
    case firstNameChanged(String)
    case lastNameChanged(String)
    case emergencyNoteChanged(String)
    case signOutButtonTapped
    case qrCodeButtonTapped
    case settingsButtonTapped

    // System actions
    case updateProfileResponse(TaskResult<Void>)
    case signOutResponse(TaskResult<Void>)

    // Navigation actions
    case destination(PresentationAction<Destination.Action>)

    // Error handling
    case setError(UserFacingError?)
    case dismissError

    // Delegate actions
    case delegate(DelegateAction)

    enum DelegateAction: Equatable, Sendable {
        case signedOut
    }

    enum Destination: Equatable, Sendable {
        case qrCode(QRCodeFeature.Action)
        case settings(SettingsFeature.Action)
    }
}
```

### Dependencies

- **UserClient**: For user profile operations
- **AuthClient**: For authentication operations
- **ImageClient**: For image operations

### Responsibilities

- Displays user profile information
- Allows editing of profile information
- Provides access to QR code generation
- Provides access to settings
- Handles sign out

### Implementation Details

The ProfileFeature manages the user's profile:

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case .onAppear:
            return .none

        case .editButtonTapped:
            state.isEditing = true
            state.editedFirstName = state.user.firstName
            state.editedLastName = state.user.lastName
            state.editedEmergencyNote = state.user.emergencyNote
            return .none

        case .cancelEditButtonTapped:
            state.isEditing = false
            return .none

        case .saveButtonTapped:
            state.isEditing = false
            state.isLoading = true

            let firstName = state.editedFirstName
            let lastName = state.editedLastName
            let emergencyNote = state.editedEmergencyNote

            return .run { send in
                do {
                    try await userClient.updateProfile(
                        firstName: firstName,
                        lastName: lastName,
                        emergencyNote: emergencyNote
                    )
                    await send(.updateProfileResponse(.success))
                } catch {
                    await send(.updateProfileResponse(.failure(error)))
                }
            }

        case let .firstNameChanged(firstName):
            state.editedFirstName = firstName
            return .none

        case let .lastNameChanged(lastName):
            state.editedLastName = lastName
            return .none

        case let .emergencyNoteChanged(emergencyNote):
            state.editedEmergencyNote = emergencyNote
            return .none

        case .updateProfileResponse(.success):
            state.isLoading = false
            state.user.firstName = state.editedFirstName
            state.user.lastName = state.editedLastName
            state.user.emergencyNote = state.editedEmergencyNote
            return .none

        case let .updateProfileResponse(.failure(error)):
            state.isLoading = false
            state.error = UserFacingError(error)
            return .none

        case .signOutButtonTapped:
            state.isLoading = true
            return .run { send in
                do {
                    try await authClient.signOut()
                    await send(.signOutResponse(.success))
                } catch {
                    await send(.signOutResponse(.failure(error)))
                }
            }

        case .signOutResponse(.success):
            state.isLoading = false
            return .send(.delegate(.signedOut))

        case let .signOutResponse(.failure(error)):
            state.isLoading = false
            state.error = UserFacingError(error)
            return .none

        case .qrCodeButtonTapped:
            state.destination = .qrCode(QRCodeFeature.State())
            return .none

        case .settingsButtonTapped:
            state.destination = .settings(SettingsFeature.State())
            return .none

        // Navigation and error handling...
        }
    }
    .ifLet(\.$destination, action: \.destination)
}
```

## Feature Composition

The utility features are composed in a hierarchical structure:

```
MainTabFeature
├── NotificationFeature
└── ProfileFeature
    ├── QRCodeFeature
    └── SettingsFeature
```

This composition allows for a modular application structure where features can be developed, tested, and maintained independently.

## Feature Dependencies

The utility features depend on the following clients:

- **NotificationClient**: For notification operations
- **QRCodeClient**: For QR code operations
- **SettingsClient**: For settings operations
- **UserClient**: For user profile operations
- **AuthClient**: For authentication operations
- **ImageClient**: For image operations

These clients are injected using TCA's dependency injection system.
