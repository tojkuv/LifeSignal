# NotificationFeature Effects

**Navigation:** [Back to NotificationFeature](README.md) | [State](State.md) | [Actions](Actions.md)

---

## Overview

This document provides detailed information about the effects of the NotificationFeature in the LifeSignal iOS application. Effects represent the side effects that occur in response to actions, such as API calls, timers, and other asynchronous operations.

## Effect Types

The NotificationFeature uses the following types of effects:

1. **API Effects** - Effects that interact with external services through clients
2. **Persistence Effects** - Effects that persist data to local storage
3. **Navigation Effects** - Effects that handle navigation between screens
4. **Push Notification Effects** - Effects that handle push notification registration and processing

## Dependencies

The NotificationFeature depends on the following clients for its effects:

```swift
@Dependency(\.notificationClient) var notificationClient
@Dependency(\.userClient) var userClient
```

## Effect Implementation

The effects are implemented in the feature's reducer:

```swift
var body: some ReducerOf<Self> {
    Scope(state: \.preferences, action: \.preferences) {
        NotificationPreferencesFeature()
    }
    
    Reduce { state, action in
        switch action {
        case .onAppear:
            if state.notifications.isEmpty && !state.isLoading {
                return .send(.loadNotifications)
            }
            
            // Load filter settings from UserDefaults
            return .run { send in
                if let filterRawValue = await UserDefaults.standard.string(forKey: "NotificationFilter"),
                   let filter = NotificationType(rawValue: filterRawValue) {
                    await send(.setFilter(filter))
                }
                
                let showUnreadOnly = await UserDefaults.standard.bool(forKey: "NotificationShowUnreadOnly")
                if showUnreadOnly {
                    await send(.toggleUnreadOnly)
                }
            }
            
        // Other action handlers...
        }
    }
}
```

## API Effects

The NotificationFeature interacts with the following APIs:

### Load Notifications

Loads notifications from the backend:

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
    .cancellable(id: CancellationID.loadNotifications)
```

This effect:
1. Sets the loading state to true
2. Calls the `getNotifications` method on the notificationClient
3. Dispatches a success or failure action based on the result
4. Can be cancelled using the `loadNotifications` cancellation ID

### Mark Notification as Read

Marks a notification as read:

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

This effect:
1. Calls the `markAsRead` method on the notificationClient
2. Dispatches a success or failure action based on the result

### Mark All Notifications as Read

Marks all notifications as read:

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

This effect:
1. Calls the `markAllAsRead` method on the notificationClient
2. Dispatches a success or failure action based on the result

### Clear Notification

Clears a notification:

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

This effect:
1. Calls the `clearNotification` method on the notificationClient
2. Dispatches a success or failure action based on the result

### Clear All Notifications

Clears all notifications:

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

This effect:
1. Calls the `clearAllNotifications` method on the notificationClient
2. Dispatches a success or failure action based on the result

## Persistence Effects

The NotificationFeature persists data through the following effects:

### Save Filter Settings

Saves the filter settings to UserDefaults:

```swift
case let .setFilter(filter):
    state.selectedFilter = filter
    return .run { _ in
        await UserDefaults.standard.set(filter.rawValue, forKey: "NotificationFilter")
    }
```

This effect:
1. Updates the selected filter in the state
2. Persists the filter selection to UserDefaults

### Save Unread Only Setting

Saves the unread only setting to UserDefaults:

```swift
case .toggleUnreadOnly:
    state.showUnreadOnly.toggle()
    return .run { _ in
        await UserDefaults.standard.set(state.showUnreadOnly, forKey: "NotificationShowUnreadOnly")
    }
```

This effect:
1. Toggles the show unread only state
2. Persists the setting to UserDefaults

### Load Filter Settings

Loads the filter settings from UserDefaults:

```swift
case .onAppear:
    // Other effects...
    
    // Load filter settings from UserDefaults
    return .run { send in
        if let filterRawValue = await UserDefaults.standard.string(forKey: "NotificationFilter"),
           let filter = NotificationType(rawValue: filterRawValue) {
            await send(.setFilter(filter))
        }
        
        let showUnreadOnly = await UserDefaults.standard.bool(forKey: "NotificationShowUnreadOnly")
        if showUnreadOnly {
            await send(.toggleUnreadOnly)
        }
    }
```

This effect:
1. Retrieves the filter settings from UserDefaults
2. Dispatches actions to update the state with the persisted settings

## Push Notification Effects

The NotificationFeature handles push notifications through the following effects:

### Register for Push Notifications

Registers for push notifications:

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

This effect:
1. Calls the `registerForPushNotifications` method on the notificationClient
2. Dispatches a success or failure action based on the result

### Handle Push Notification

Handles a received push notification:

```swift
case let .handlePushNotification(userInfo):
    // Process the notification
    if let notificationData = try? NotificationData.from(userInfo) {
        state.notifications.insert(notificationData, at: 0)
        
        // Handle based on notification type
        switch notificationData.type {
        case .alert:
            // Handle alert notification
            return .send(.notificationTapped(notificationData))
        case .ping:
            // Handle ping notification
            return .none
        case .role, .removed, .added:
            // Handle contact notification
            return .none
        case .checkIn:
            // Handle check-in notification
            return .none
        default:
            return .none
        }
    }
    
    return .none
```

This effect:
1. Processes the notification data from the user info dictionary
2. Updates the notifications array with the new notification
3. May dispatch additional actions based on the notification type

## Navigation Effects

The NotificationFeature handles navigation through the following effects:

### Navigate Based on Notification Type

Navigates to the relevant screen when a notification is tapped:

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
            return .run { send in
                await send(.delegate(.navigateToAlert(alertID)))
            }
        }
    case .ping:
        if let pingID = notification.relatedPingID {
            // Navigate to ping details
            return .run { send in
                await send(.delegate(.navigateToPing(pingID)))
            }
        }
    case .role, .removed, .added:
        if let contactID = notification.relatedContactID {
            // Navigate to contact details
            return .run { send in
                await send(.delegate(.navigateToContact(contactID)))
            }
        }
    case .checkIn:
        // Navigate to check-in screen
        return .run { send in
            await send(.delegate(.navigateToCheckIn))
        }
    default:
        break
    }
    
    return .none
```

This effect:
1. Marks the notification as read if it's unread
2. Determines the appropriate navigation action based on the notification type
3. Dispatches a delegate action to handle the navigation

## Effect Cancellation

The NotificationFeature cancels effects in the following situations:

### Cancel API Calls

API calls are cancelled when the feature is deinitialized or when a new API call of the same type is made:

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
    .cancellable(id: CancellationID.loadNotifications)
```

This effect:
1. Assigns a cancellation ID to the effect
2. The effect will be cancelled if a new effect with the same ID is created
3. The effect will also be cancelled if the feature is deinitialized

## Effect Composition

The NotificationFeature composes effects with child features:

```swift
var body: some ReducerOf<Self> {
    Scope(state: \.preferences, action: \.preferences) {
        NotificationPreferencesFeature()
    }
    
    Reduce { state, action in
        // Action handlers...
    }
}
```

This composition:
1. Scopes the NotificationPreferencesFeature to handle preference-related actions
2. The parent feature handles its own effects

## Best Practices

When working with NotificationFeature effects, follow these best practices:

1. **Effect Organization** - Group related effects together
2. **Effect Documentation** - Document the purpose and behavior of each effect
3. **Effect Testing** - Test each effect and its interaction with dependencies
4. **Effect Cancellation** - Use cancellation IDs for cancellable effects
5. **Effect Composition** - Use parent and child effects for feature composition
6. **Error Handling** - Handle errors consistently and provide user-friendly error messages
