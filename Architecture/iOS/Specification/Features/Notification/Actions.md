# NotificationFeature Actions

**Navigation:** [Back to NotificationFeature](README.md) | [State](State.md) | [Effects](Effects.md)

---

## Overview

This document provides detailed information about the actions of the NotificationFeature in the LifeSignal iOS application. Actions represent the events that can occur in the feature, including user interactions, system events, and responses from external dependencies.

## Action Definition

```swift
@CasePathable
enum Action: Equatable, Sendable {
    // MARK: - Lifecycle Actions
    case onAppear
    case onDisappear
    
    // MARK: - Data Actions
    case loadNotifications
    case notificationsResponse(TaskResult<[NotificationData]>)
    case markAsRead(String)
    case markAsReadResponse(TaskResult<String>)
    case markAllAsRead
    case markAllAsReadResponse(TaskResult<Void>)
    case clearNotification(String)
    case clearNotificationResponse(TaskResult<String>)
    case clearAllNotifications
    case clearAllNotificationsResponse(TaskResult<Void>)
    
    // MARK: - Filter Actions
    case setFilter(NotificationType)
    case toggleUnreadOnly
    
    // MARK: - UI Actions
    case notificationTapped(NotificationData)
    case setPreferencesSheetPresented(Bool)
    case setError(UserFacingError?)
    
    // MARK: - Child Feature Actions
    case preferences(NotificationPreferencesFeature.Action)
    
    // MARK: - Push Notification Actions
    case registerForPushNotifications
    case pushNotificationRegistrationResponse(TaskResult<Void>)
    case handlePushNotification(UserInfo)
}
```

## Action Categories

### Lifecycle Actions

These actions are triggered by the view's lifecycle events:

#### `onAppear`

Triggered when the view appears. Used to initialize the feature and load data.

**Effect:**
- Loads notifications if they haven't been loaded yet

**Example:**
```swift
case .onAppear:
    if state.notifications.isEmpty && !state.isLoading {
        return .send(.loadNotifications)
    }
    return .none
```

#### `onDisappear`

Triggered when the view disappears. Used to clean up resources.

**Effect:**
- No direct effect

**Example:**
```swift
case .onDisappear:
    return .none
```

### Data Actions

These actions are related to loading and manipulating notification data:

#### `loadNotifications`

Triggered to load notifications from the backend.

**Effect:**
- Sets the loading state to true
- Calls the notification client to load notifications
- Dispatches a response action with the result

**Example:**
```swift
case .loadNotifications:
    state.isLoading = true
    return .run { send in
        do {
            let notifications = try await notificationClient.getNotifications()
            await send(.notificationsResponse(.success(notifications)))
        } catch {
            await send(.notificationsResponse(.failure(error as? UserFacingError ?? .unknown)))
        }
    }
```

#### `notificationsResponse(TaskResult<[NotificationData]>)`

Triggered when the notification loading operation completes.

**Effect:**
- Sets the loading state to false
- Updates the notifications array or sets an error

**Example:**
```swift
case let .notificationsResponse(.success(notifications)):
    state.isLoading = false
    state.notifications = notifications
    return .none
    
case let .notificationsResponse(.failure(error)):
    state.isLoading = false
    state.error = error
    return .none
```

#### `markAsRead(String)`

Triggered when the user marks a notification as read.

**Effect:**
- Calls the notification client to mark the notification as read
- Dispatches a response action with the result

**Example:**
```swift
case let .markAsRead(id):
    return .run { send in
        do {
            try await notificationClient.markAsRead(id)
            await send(.markAsReadResponse(.success(id)))
        } catch {
            await send(.markAsReadResponse(.failure(error as? UserFacingError ?? .unknown)))
        }
    }
```

#### `markAsReadResponse(TaskResult<String>)`

Triggered when the mark as read operation completes.

**Effect:**
- Updates the notification's read status or sets an error

**Example:**
```swift
case let .markAsReadResponse(.success(id)):
    if let index = state.notifications.firstIndex(where: { $0.id == id }) {
        state.notifications[index].isRead = true
    }
    return .none
    
case let .markAsReadResponse(.failure(error)):
    state.error = error
    return .none
```

#### `markAllAsRead`

Triggered when the user marks all notifications as read.

**Effect:**
- Calls the notification client to mark all notifications as read
- Dispatches a response action with the result

**Example:**
```swift
case .markAllAsRead:
    return .run { send in
        do {
            try await notificationClient.markAllAsRead()
            await send(.markAllAsReadResponse(.success(())))
        } catch {
            await send(.markAllAsReadResponse(.failure(error as? UserFacingError ?? .unknown)))
        }
    }
```

#### `markAllAsReadResponse(TaskResult<Void>)`

Triggered when the mark all as read operation completes.

**Effect:**
- Updates all notifications' read status or sets an error

**Example:**
```swift
case .markAllAsReadResponse(.success):
    state.notifications = state.notifications.map { notification in
        var updatedNotification = notification
        updatedNotification.isRead = true
        return updatedNotification
    }
    return .none
    
case let .markAllAsReadResponse(.failure(error)):
    state.error = error
    return .none
```

#### `clearNotification(String)`

Triggered when the user clears a notification.

**Effect:**
- Calls the notification client to clear the notification
- Dispatches a response action with the result

**Example:**
```swift
case let .clearNotification(id):
    return .run { send in
        do {
            try await notificationClient.clearNotification(id)
            await send(.clearNotificationResponse(.success(id)))
        } catch {
            await send(.clearNotificationResponse(.failure(error as? UserFacingError ?? .unknown)))
        }
    }
```

#### `clearNotificationResponse(TaskResult<String>)`

Triggered when the clear notification operation completes.

**Effect:**
- Removes the notification from the array or sets an error

**Example:**
```swift
case let .clearNotificationResponse(.success(id)):
    state.notifications.removeAll(where: { $0.id == id })
    return .none
    
case let .clearNotificationResponse(.failure(error)):
    state.error = error
    return .none
```

#### `clearAllNotifications`

Triggered when the user clears all notifications.

**Effect:**
- Calls the notification client to clear all notifications
- Dispatches a response action with the result

**Example:**
```swift
case .clearAllNotifications:
    return .run { send in
        do {
            try await notificationClient.clearAllNotifications()
            await send(.clearAllNotificationsResponse(.success(())))
        } catch {
            await send(.clearAllNotificationsResponse(.failure(error as? UserFacingError ?? .unknown)))
        }
    }
```

#### `clearAllNotificationsResponse(TaskResult<Void>)`

Triggered when the clear all notifications operation completes.

**Effect:**
- Clears the notifications array or sets an error

**Example:**
```swift
case .clearAllNotificationsResponse(.success):
    state.notifications = []
    return .none
    
case let .clearAllNotificationsResponse(.failure(error)):
    state.error = error
    return .none
```

### Filter Actions

These actions are related to filtering notifications:

#### `setFilter(NotificationType)`

Triggered when the user selects a notification type filter.

**Effect:**
- Updates the selected filter
- Persists the filter selection to UserDefaults

**Example:**
```swift
case let .setFilter(filter):
    state.selectedFilter = filter
    return .run { _ in
        await UserDefaults.standard.set(filter.rawValue, forKey: "NotificationFilter")
    }
```

#### `toggleUnreadOnly`

Triggered when the user toggles the unread only filter.

**Effect:**
- Toggles the show unread only state
- Persists the setting to UserDefaults

**Example:**
```swift
case .toggleUnreadOnly:
    state.showUnreadOnly.toggle()
    return .run { _ in
        await UserDefaults.standard.set(state.showUnreadOnly, forKey: "NotificationShowUnreadOnly")
    }
```

### UI Actions

These actions are triggered by user interactions with the UI:

#### `notificationTapped(NotificationData)`

Triggered when the user taps on a notification.

**Effect:**
- Marks the notification as read
- Navigates to the relevant screen based on the notification type

**Example:**
```swift
case let .notificationTapped(notification):
    if !notification.isRead {
        return .send(.markAsRead(notification.id))
    }
    
    // Navigate based on notification type
    switch notification.type {
    case .alert:
        if let alertID = notification.relatedAlertID {
            // Navigate to alert details
        }
    case .ping:
        if let pingID = notification.relatedPingID {
            // Navigate to ping details
        }
    case .role, .removed, .added:
        if let contactID = notification.relatedContactID {
            // Navigate to contact details
        }
    case .checkIn:
        // Navigate to check-in screen
    default:
        break
    }
    
    return .none
```

#### `setPreferencesSheetPresented(Bool)`

Triggered when the user opens or closes the notification preferences sheet.

**Effect:**
- Updates the preferences sheet presented state

**Example:**
```swift
case let .setPreferencesSheetPresented(isPresented):
    state.isPreferencesSheetPresented = isPresented
    return .none
```

#### `setError(UserFacingError?)`

Triggered to set an error to be displayed to the user.

**Effect:**
- Updates the error state

**Example:**
```swift
case let .setError(error):
    state.error = error
    return .none
```

### Child Feature Actions

These actions are forwarded to child features:

#### `preferences(NotificationPreferencesFeature.Action)`

Actions that should be handled by the NotificationPreferencesFeature.

**Effect:**
- Forwarded to the child feature

**Example:**
```swift
case .preferences:
    return .none
```

### Push Notification Actions

These actions are related to push notification handling:

#### `registerForPushNotifications`

Triggered to register for push notifications.

**Effect:**
- Calls the notification client to register for push notifications
- Dispatches a response action with the result

**Example:**
```swift
case .registerForPushNotifications:
    return .run { send in
        do {
            try await notificationClient.registerForPushNotifications()
            await send(.pushNotificationRegistrationResponse(.success(())))
        } catch {
            await send(.pushNotificationRegistrationResponse(.failure(error as? UserFacingError ?? .unknown)))
        }
    }
```

#### `pushNotificationRegistrationResponse(TaskResult<Void>)`

Triggered when the push notification registration operation completes.

**Effect:**
- Updates the notification preferences or sets an error

**Example:**
```swift
case .pushNotificationRegistrationResponse(.success):
    state.preferences.isNotificationsEnabled = true
    return .none
    
case let .pushNotificationRegistrationResponse(.failure(error)):
    state.error = error
    return .none
```

#### `handlePushNotification(UserInfo)`

Triggered when a push notification is received.

**Effect:**
- Processes the notification and updates the state accordingly
- May trigger navigation or other actions based on the notification type

**Example:**
```swift
case let .handlePushNotification(userInfo):
    // Process the notification
    if let notificationData = try? NotificationData.from(userInfo) {
        state.notifications.insert(notificationData, at: 0)
        
        // Handle based on notification type
        switch notificationData.type {
        case .alert:
            // Handle alert notification
        case .ping:
            // Handle ping notification
        case .role, .removed, .added:
            // Handle contact notification
        case .checkIn:
            // Handle check-in notification
        default:
            break
        }
    }
    
    return .none
```

## Best Practices

When working with NotificationFeature actions, follow these best practices:

1. **Action Naming** - Use clear, descriptive names for actions
2. **Action Organization** - Group related actions together
3. **Action Documentation** - Document the purpose and effect of each action
4. **Action Testing** - Test each action and its effect on the state
5. **Action Composition** - Use parent and child actions for feature composition
