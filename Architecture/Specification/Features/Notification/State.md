# NotificationFeature State

**Navigation:** [Back to NotificationFeature](README.md) | [Actions](Actions.md) | [Effects](Effects.md)

---

## Overview

This document provides detailed information about the state of the NotificationFeature in the LifeSignal iOS application. The state represents the current condition of the notification functionality, including the list of notifications, filter settings, and notification preferences.

## State Definition

```swift
@ObservableState
struct State: Equatable, Sendable {
    /// Notifications
    var notifications: [NotificationData] = []
    var isLoading: Bool = false
    var error: UserFacingError? = nil
    
    /// Filter settings
    var selectedFilter: NotificationType = .all
    var showUnreadOnly: Bool = false
    
    /// Notification preferences
    var preferences: NotificationPreferencesFeature.State = .init()
    
    /// UI state
    var isPreferencesSheetPresented: Bool = false
    
    /// Computed properties
    var filteredNotifications: [NotificationData] {
        notifications.filter { notification in
            // Filter by type
            if selectedFilter != .all && notification.type != selectedFilter {
                return false
            }
            
            // Filter by read status
            if showUnreadOnly && notification.isRead {
                return false
            }
            
            return true
        }
    }
    
    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }
}
```

## State Properties

### Notifications

#### `notifications: [NotificationData]`

An array of notification data objects. Each notification contains information about an event that occurred in the application.

#### `isLoading: Bool`

A boolean indicating whether the feature is currently loading notifications. When true, UI elements should show loading indicators.

#### `error: UserFacingError?`

An optional error that should be displayed to the user. When non-nil, an error alert should be shown.

### Filter Settings

#### `selectedFilter: NotificationType`

The currently selected notification type filter. Can be one of:
- `.all` - Show all notifications
- `.alert` - Show only alert notifications
- `.ping` - Show only ping notifications
- `.role` - Show only role change notifications
- `.removed` - Show only contact removal notifications
- `.added` - Show only contact addition notifications
- `.checkIn` - Show only check-in notifications

#### `showUnreadOnly: Bool`

A boolean indicating whether to show only unread notifications. When true, read notifications are hidden.

### Notification Preferences

#### `preferences: NotificationPreferencesFeature.State`

The state of the NotificationPreferencesFeature, which manages notification settings such as enabling/disabling notifications and setting reminder times.

### UI State

#### `isPreferencesSheetPresented: Bool`

A boolean indicating whether the notification preferences sheet is currently presented.

### Computed Properties

#### `filteredNotifications: [NotificationData]`

An array of notifications filtered based on the current filter settings. This is used to display the notifications in the UI.

#### `unreadCount: Int`

The number of unread notifications. This is used to display a badge on the notification tab.

## Notification Data

The `NotificationData` type represents a single notification:

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

The `NotificationType` enum defines the different types of notifications:

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

## State Updates

The state is updated in response to actions dispatched to the feature's reducer. For detailed information on how the state is updated, see the [Actions](Actions.md) and [Effects](Effects.md) documents.

## State Persistence

The core state properties are persisted as follows:

- Notifications are stored in the backend and cached locally
- Filter settings are stored in UserDefaults
- Notification preferences are stored in UserDefaults and the backend

## State Access

The state is accessed by the feature's view and by parent features that include the NotificationFeature as a child feature.

Example of a parent feature accessing the NotificationFeature state:

```swift
@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var notification: NotificationFeature.State = .init()
        // Other state...
    }
    
    enum Action: Equatable, Sendable {
        case notification(NotificationFeature.Action)
        // Other actions...
    }
    
    var body: some ReducerOf<Self> {
        Scope(state: \.notification, action: \.notification) {
            NotificationFeature()
        }
        
        Reduce { state, action in
            // Handle AppFeature-specific actions
            return .none
        }
    }
}
```

## Best Practices

When working with the NotificationFeature state, follow these best practices:

1. **Immutable Updates** - Always update state immutably through actions
2. **Computed Properties** - Use computed properties for derived state
3. **Child Feature Composition** - Use child features for complex functionality
4. **Error Handling** - Use the error property for user-facing errors
5. **Filter Management** - Keep filter logic in computed properties for easy testing
