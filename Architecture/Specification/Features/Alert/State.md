# AlertFeature State

**Navigation:** [Back to AlertFeature](README.md) | [Actions](Actions.md) | [Effects](Effects.md)

---

## Overview

This document provides detailed information about the state of the AlertFeature in the LifeSignal iOS application. The state represents the current condition of the alert functionality, including the user's alert status, history, and activation progress.

## State Definition

```swift
@ObservableState
struct State: Equatable, Sendable {
    // Core state
    var isAlertActive: Bool = false
    var activationProgress: Double = 0.0 // 0.0 to 1.0
    var deactivationProgress: Double = 0.0 // 0.0 to 1.0
    var alertStartTime: Date? = nil
    var alertEndTime: Date? = nil
    var alertHistory: [AlertRecord] = []
    var isActivatingAlert: Bool = false
    var isDeactivatingAlert: Bool = false
    var isLoadingHistory: Bool = false
    var error: String? = nil
    
    // Derived state (computed properties)
    var alertDuration: TimeInterval {
        guard let startTime = alertStartTime else { return 0 }
        if let endTime = alertEndTime {
            return endTime.timeIntervalSince(startTime)
        } else {
            return Date().timeIntervalSince(startTime)
        }
    }
    
    var formattedAlertDuration: String {
        let duration = Int(alertDuration)
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var canActivateAlert: Bool {
        return !isAlertActive && !isActivatingAlert && !isDeactivatingAlert
    }
    
    var canDeactivateAlert: Bool {
        return isAlertActive && !isActivatingAlert && !isDeactivatingAlert
    }
    
    var isFullyActivated: Bool {
        return activationProgress >= 1.0
    }
    
    var isFullyDeactivated: Bool {
        return deactivationProgress >= 1.0
    }
    
    // Presentation state
    @Presents var confirmationAlert: AlertState<Action>?
}
```

## State Properties

### Core State

These properties represent the fundamental state of the alert functionality:

#### `isAlertActive: Bool`

A boolean indicating whether an alert is currently active.

**Usage:**
- Displayed to the user to show the current alert status
- Used to determine whether to show activation or deactivation UI
- Used to determine whether to notify responders

**Persistence:**
- Stored in Firebase Firestore
- Cached locally for offline access

#### `activationProgress: Double`

A value between 0.0 and 1.0 representing the progress of the alert activation process. Each tap on the alert button increases this value by 0.25, and when it reaches 1.0, the alert is activated.

**Usage:**
- Used to display the activation progress to the user
- Used to determine when to activate the alert

**Persistence:**
- Not persisted, only exists in memory

#### `deactivationProgress: Double`

A value between 0.0 and 1.0 representing the progress of the alert deactivation process. As the user holds the deactivation button, this value increases, and when it reaches 1.0, the alert is deactivated.

**Usage:**
- Used to display the deactivation progress to the user
- Used to determine when to deactivate the alert

**Persistence:**
- Not persisted, only exists in memory

#### `alertStartTime: Date?`

The timestamp when the current alert was activated. This is `nil` if no alert is active.

**Usage:**
- Used to calculate the alert duration
- Used to display the alert start time to the user
- Used to create alert history records

**Persistence:**
- Stored in Firebase Firestore
- Cached locally for offline access

#### `alertEndTime: Date?`

The timestamp when the current alert was deactivated. This is `nil` if no alert is active or if an alert is active but has not been deactivated.

**Usage:**
- Used to calculate the alert duration
- Used to display the alert end time to the user
- Used to create alert history records

**Persistence:**
- Stored in Firebase Firestore
- Cached locally for offline access

#### `alertHistory: [AlertRecord]`

An array of the user's alert records, ordered by timestamp with the most recent first.

**Usage:**
- Displayed to the user to show their alert history
- Used for analytics and reporting

**Persistence:**
- Stored in Firebase Firestore
- Cached locally for offline access

#### `isActivatingAlert: Bool`

A boolean indicating whether an alert activation operation is in progress.

**Usage:**
- Used to show a loading indicator when an alert activation is in progress
- Used to disable the alert button when an alert activation is in progress

**Persistence:**
- Not persisted, only exists in memory

#### `isDeactivatingAlert: Bool`

A boolean indicating whether an alert deactivation operation is in progress.

**Usage:**
- Used to show a loading indicator when an alert deactivation is in progress
- Used to disable the alert button when an alert deactivation is in progress

**Persistence:**
- Not persisted, only exists in memory

#### `isLoadingHistory: Bool`

A boolean indicating whether the alert history is being loaded.

**Usage:**
- Used to show a loading indicator when the alert history is being loaded

**Persistence:**
- Not persisted, only exists in memory

#### `error: String?`

An error message to display to the user. This is `nil` if there is no error.

**Usage:**
- Displayed to the user when an error occurs
- Cleared when a new operation is started or when the user dismisses the error

**Persistence:**
- Not persisted, only exists in memory

### Derived State

These properties are computed from the core state and are not stored directly:

#### `alertDuration: TimeInterval`

The duration of the current alert, in seconds. If no alert is active, this is 0. If an alert is active but has not been deactivated, this is the time since the alert was activated.

**Computation:**
```swift
var alertDuration: TimeInterval {
    guard let startTime = alertStartTime else { return 0 }
    if let endTime = alertEndTime {
        return endTime.timeIntervalSince(startTime)
    } else {
        return Date().timeIntervalSince(startTime)
    }
}
```

#### `formattedAlertDuration: String`

A human-readable string representing the alert duration.

**Computation:**
```swift
var formattedAlertDuration: String {
    let duration = Int(alertDuration)
    let hours = duration / 3600
    let minutes = (duration % 3600) / 60
    let seconds = duration % 60
    
    if hours > 0 {
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    } else {
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
```

#### `canActivateAlert: Bool`

A boolean indicating whether the user can activate an alert. This is `true` if no alert is active and no alert operation is in progress.

**Computation:**
```swift
var canActivateAlert: Bool {
    return !isAlertActive && !isActivatingAlert && !isDeactivatingAlert
}
```

#### `canDeactivateAlert: Bool`

A boolean indicating whether the user can deactivate an alert. This is `true` if an alert is active and no alert operation is in progress.

**Computation:**
```swift
var canDeactivateAlert: Bool {
    return isAlertActive && !isActivatingAlert && !isDeactivatingAlert
}
```

#### `isFullyActivated: Bool`

A boolean indicating whether the alert activation progress is complete. This is `true` if `activationProgress` is greater than or equal to 1.0.

**Computation:**
```swift
var isFullyActivated: Bool {
    return activationProgress >= 1.0
}
```

#### `isFullyDeactivated: Bool`

A boolean indicating whether the alert deactivation progress is complete. This is `true` if `deactivationProgress` is greater than or equal to 1.0.

**Computation:**
```swift
var isFullyDeactivated: Bool {
    return deactivationProgress >= 1.0
}
```

### Presentation State

These properties represent the state of presentations (sheets, popovers, alerts) managed by the feature:

#### `@Presents var confirmationAlert: AlertState<Action>?`

The state of a confirmation alert. This is `nil` when no alert is presented.

**Usage:**
- Used to present alerts for confirmations, errors, and other messages
- Contains the alert title, message, and buttons

## Domain Models

### AlertRecord

```swift
struct AlertRecord: Equatable, Sendable, Identifiable {
    var id: String
    var startTime: Date
    var endTime: Date?
    var userId: String
    var isActive: Bool
}
```

## State Initialization

The state is initialized with default values:

```swift
init(
    isAlertActive: Bool = false,
    activationProgress: Double = 0.0,
    deactivationProgress: Double = 0.0,
    alertStartTime: Date? = nil,
    alertEndTime: Date? = nil,
    alertHistory: [AlertRecord] = [],
    isActivatingAlert: Bool = false,
    isDeactivatingAlert: Bool = false,
    isLoadingHistory: Bool = false,
    error: String? = nil
) {
    self.isAlertActive = isAlertActive
    self.activationProgress = activationProgress
    self.deactivationProgress = deactivationProgress
    self.alertStartTime = alertStartTime
    self.alertEndTime = alertEndTime
    self.alertHistory = alertHistory
    self.isActivatingAlert = isActivatingAlert
    self.isDeactivatingAlert = isDeactivatingAlert
    self.isLoadingHistory = isLoadingHistory
    self.error = error
}
```

## State Updates

The state is updated in response to actions dispatched to the feature's reducer. For detailed information on how the state is updated, see the [Actions](Actions.md) and [Effects](Effects.md) documents.

## State Persistence

The core state properties are persisted as follows:

- `isAlertActive`, `alertStartTime`, and `alertEndTime` are stored in Firebase Firestore
- `alertHistory` is stored in Firebase Firestore
- Other properties are not persisted and only exist in memory

## State Access

The state is accessed by the feature's view and by parent features that include the AlertFeature as a child feature.

Example of a parent feature accessing the AlertFeature state:

```swift
@Reducer
struct HomeFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var alert: AlertFeature.State = .init()
        // Other state properties...
    }
    
    // Rest of the feature implementation...
}
```

## Best Practices

When working with the AlertFeature state, follow these best practices:

1. **Use Computed Properties for Derived State** - Use computed properties for state that can be derived from other state properties.

2. **Keep State Minimal** - Only include properties that are necessary for the feature's functionality.

3. **Use Optional Properties Appropriately** - Use optional properties for state that may not be available, such as `alertStartTime` and `alertEndTime`.

4. **Use Presentation Properties for Presentations** - Use `@Presents` properties for managing presentations, such as sheets, popovers, and alerts.

5. **Document State Properties** - Document the purpose and usage of each state property.

6. **Use Equatable and Sendable** - Ensure that the state conforms to `Equatable` and `Sendable` for compatibility with TCA.

7. **Initialize State with Default Values** - Provide default values for state properties to ensure the feature works correctly when initialized.
