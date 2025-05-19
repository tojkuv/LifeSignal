# Notification Stream Specification

## Overview

This document outlines the requirements for implementing a notification stream in The Composable Architecture (TCA) for the LifeSignal app. The notification stream is responsible for receiving server-side notifications and updating the client's notification center in real-time.

## Core Requirements

1. **Server-Side Notifications**: All notifications tracked in the Notification Center are server-sided.
2. **Bidirectional Updates**: When a user or their contact changes a role, the server data is updated and both users receive a notification.
3. **Notification History**: The notification center history is server-sided, with clients updated through a stream.
4. **User-Specific Collection**: Each user has their own collection of notifications, similar to how each user has a collection of contacts.

## Data Model

### Notification Data

```swift
struct NotificationData: Identifiable, Equatable, Sendable {
    let id: String
    let type: NotificationType
    let title: String
    let message: String
    let timestamp: Date
    var isRead: Bool
    let relatedContactID: String?
    let relatedAlertID: String?
    let relatedPingID: String?
    
    // Additional properties for specific notification types
    var alertData: AlertData?
    var pingData: PingData?
    var contactData: ContactData?
}
```

### Notification Types

```swift
enum NotificationType: String, CaseIterable, Equatable, Sendable {
    case all = "All"
    case alert = "Alerts"
    case ping = "Pings"
    case role = "Roles"
    case removed = "Removed"
    case added = "Added"
    case checkIn = "Check-Ins"
}
```

## Infrastructure

### Notification Client Protocol

```swift
protocol NotificationClientProtocol: Sendable {
    /// Stream notifications from the server
    func streamNotifications(_ userId: String) -> AsyncStream<[NotificationData]>
    
    /// Get notifications once
    func getNotifications(_ userId: String, limit: Int) async throws -> [NotificationData]
    
    /// Mark a notification as read
    func markAsRead(_ userId: String, notificationId: String) async throws
    
    /// Mark all notifications as read
    func markAllAsRead(_ userId: String) async throws
    
    /// Delete a notification
    func deleteNotification(_ userId: String, notificationId: String) async throws
    
    /// Register for remote notifications
    func registerForRemoteNotifications() async throws
    
    /// Handle device token for push notifications
    func handleDeviceToken(_ deviceToken: Data) async
    
    /// Request notification authorization
    func requestAuthorization() async throws -> Bool
    
    /// Get current authorization status
    func getAuthorizationStatus() async -> UNAuthorizationStatus
    
    /// Stream FCM token updates
    func streamFCMTokenUpdates() -> AsyncStream<String>
}
```

### Firebase Implementation

```swift
struct FirebaseNotificationClient: NotificationClientProtocol {
    @Dependency(\.typedFirestore) private var typedFirestore
    @Dependency(\.firebaseMessaging) private var firebaseMessaging
    
    func streamNotifications(_ userId: String) -> AsyncStream<[NotificationData]> {
        AsyncStream { continuation in
            let path = FirestorePath(path: "notifications/\(userId)/history")
            let listener = typedFirestore.addSnapshotListener(
                path,
                NotificationDataFirestoreConvertible.self,
                .default
            ) { result in
                switch result {
                case .success(let snapshot):
                    let notifications = snapshot.documents.map { $0.data }
                        .sorted { $0.timestamp > $1.timestamp }
                    continuation.yield(notifications)
                case .failure:
                    continuation.finish()
                }
            }
            
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }
    
    // Other method implementations...
}
```

## Feature Implementation

### Notification Feature State

```swift
@Reducer
struct NotificationFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var notifications: IdentifiedArrayOf<NotificationData> = []
        var selectedFilter: NotificationType = .all
        var showUnreadOnly: Bool = false
        var isLoading: Bool = false
        var error: UserFacingError?
        var unreadCount: Int = 0
        
        var preferences: NotificationPreferencesFeature.State = .init()
        
        var filteredNotifications: IdentifiedArrayOf<NotificationData> {
            var filtered = notifications
            
            // Apply type filter
            if selectedFilter != .all {
                filtered = IdentifiedArray(
                    uniqueElements: filtered.filter { $0.type == selectedFilter }
                )
            }
            
            // Apply read/unread filter
            if showUnreadOnly {
                filtered = IdentifiedArray(
                    uniqueElements: filtered.filter { !$0.isRead }
                )
            }
            
            return filtered
        }
    }
    
    enum Action: Equatable, Sendable {
        // Data loading
        case viewDidAppear
        case loadNotifications
        case notificationsLoaded([NotificationData])
        case notificationsLoadFailed(UserFacingError)
        case notificationsUpdated([NotificationData])
        
        // Filtering
        case setFilter(NotificationType)
        case toggleShowUnreadOnly
        
        // Notification management
        case markAsRead(id: String)
        case markAllAsRead
        case deleteNotification(id: String)
        case notificationActionSucceeded
        case notificationActionFailed(UserFacingError)
        
        // Preferences
        case preferences(NotificationPreferencesFeature.Action)
        
        // Delegate actions
        case delegate(DelegateAction)
    }
    
    enum DelegateAction: Equatable, Sendable {
        case notificationsUpdated
        case unreadCountChanged(Int)
        case errorOccurred(UserFacingError)
    }
    
    @Dependency(\.notificationClient) private var notificationClient
    @Dependency(\.authClient) private var authClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .viewDidAppear:
                return .send(.loadNotifications)
                
            case .loadNotifications:
                state.isLoading = true
                
                return .run { [authClient, notificationClient] send in
                    do {
                        let userId = try await authClient.currentUserId()
                        
                        // Start streaming notifications
                        for await notifications in notificationClient.streamNotifications(userId) {
                            await send(.notificationsUpdated(notifications))
                        }
                    } catch {
                        let userFacingError = UserFacingError.from(error)
                        await send(.notificationsLoadFailed(userFacingError))
                    }
                }
                .cancellable(id: CancelID.notificationStream)
                
            case let .notificationsLoaded(notifications):
                state.isLoading = false
                state.notifications = IdentifiedArray(uniqueElements: notifications)
                state.unreadCount = notifications.filter { !$0.isRead }.count
                
                return .send(.delegate(.notificationsUpdated))
                
            case let .notificationsLoadFailed(error):
                state.isLoading = false
                state.error = error
                
                return .send(.delegate(.errorOccurred(error)))
                
            case let .notificationsUpdated(notifications):
                state.isLoading = false
                state.notifications = IdentifiedArray(uniqueElements: notifications)
                state.unreadCount = notifications.filter { !$0.isRead }.count
                
                return .merge(
                    .send(.delegate(.notificationsUpdated)),
                    .send(.delegate(.unreadCountChanged(state.unreadCount)))
                )
                
            // Other action handlers...
            }
        }
        .ifLet(\.preferences, action: \.preferences) {
            NotificationPreferencesFeature()
        }
    }
}
```

## Integration with App Feature

The notification stream should be initialized when the app launches and maintained throughout the app's lifecycle:

```swift
@Reducer
struct AppFeature {
    // State and other actions...
    
    enum Action: Equatable, Sendable {
        case appDidLaunch
        // Other actions...
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appDidLaunch:
                return .merge(
                    // Other initialization effects...
                    
                    // Initialize FCM token stream
                    .run { [notificationClient] send in
                        for await token in notificationClient.streamFCMTokenUpdates() {
                            await send(.notification(.updateFCMToken(token)))
                        }
                    }
                    .cancellable(id: CancelID.fcmTokenStream)
                )
                
            // Other action handlers...
            }
        }
        // Feature composition...
    }
}
```

## Notification Generation

Notifications are generated on the server side in the following scenarios:

1. **Role Changes**: When a user changes a contact's role (responder/dependent)
2. **Contact Addition**: When a user adds a new contact
3. **Contact Removal**: When a user removes a contact
4. **Check-In Reminders**: When a check-in is about to expire
5. **Check-In Expiration**: When a check-in has expired
6. **Manual Alerts**: When a user triggers or cancels a manual alert
7. **Pings**: When a user sends or responds to a ping

## Notification Delivery

Notifications are delivered through two channels:

1. **Push Notifications**: Immediate delivery using Firebase Cloud Messaging (FCM)
2. **Firestore Stream**: Real-time updates to the notification collection

The client should handle both channels:

- Push notifications trigger immediate UI updates and badge counts
- Firestore stream ensures the notification center is always up-to-date, even if push notifications are missed

## Testing

The notification stream should be tested with the following scenarios:

1. **Initial Load**: Verify notifications load correctly on app launch
2. **Real-Time Updates**: Verify new notifications appear in real-time
3. **Filtering**: Verify notification filtering works correctly
4. **Actions**: Verify marking as read and deletion work correctly
5. **Error Handling**: Verify error states are handled gracefully

## Mock Implementation

For testing and development, a mock implementation should be provided:

```swift
struct MockNotificationClient: NotificationClientProtocol {
    func streamNotifications(_ userId: String) -> AsyncStream<[NotificationData]> {
        AsyncStream { continuation in
            // Initial value
            Task {
                let notifications = try await getNotifications(userId, limit: 50)
                continuation.yield(notifications)
            }
            
            // Set up notification observer for changes
            let observer = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("NotificationsUpdated"),
                object: nil,
                queue: .main
            ) { _ in
                Task {
                    let notifications = try await getNotifications(userId, limit: 50)
                    continuation.yield(notifications)
                }
            }
            
            continuation.onTermination = { _ in
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    // Other method implementations...
}
```

## Conclusion

The notification stream is a critical component of the LifeSignal app, enabling real-time updates to the notification center. By implementing this stream using TCA's effect system, we can ensure that notifications are delivered reliably and efficiently, while maintaining a clean separation of concerns between the UI and the underlying infrastructure.
