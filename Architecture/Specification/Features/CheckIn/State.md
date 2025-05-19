# CheckInFeature State

**Navigation:** [Back to CheckInFeature](README.md) | [Actions](Actions.md) | [Effects](Effects.md)

---

## Overview

This document provides detailed information about the state of the CheckInFeature in the LifeSignal iOS application. The state represents the current condition of the check-in functionality, including the user's check-in status, history, and settings.

## State Definition

```swift
@ObservableState
struct State: Equatable, Sendable {
    // Core state
    var lastCheckInTime: Date?
    var nextCheckInTime: Date?
    var checkInInterval: TimeInterval = 86400 // 24 hours in seconds
    var reminderInterval: TimeInterval = 7200 // 2 hours in seconds
    var checkInHistory: [CheckInRecord] = []
    var isCheckingIn: Bool = false
    var isLoadingHistory: Bool = false
    var error: String? = nil
    
    // Derived state (computed properties)
    var timeRemaining: TimeInterval {
        guard let nextCheckInTime = nextCheckInTime else { return 0 }
        return max(0, nextCheckInTime.timeIntervalSinceNow)
    }
    
    var isOverdue: Bool {
        guard let nextCheckInTime = nextCheckInTime else { return false }
        return Date() > nextCheckInTime
    }
    
    var formattedTimeRemaining: String {
        let timeRemaining = self.timeRemaining
        
        if timeRemaining <= 0 {
            return "Overdue"
        }
        
        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            let seconds = Int(timeRemaining) % 60
            return "\(minutes)m \(seconds)s"
        }
    }
    
    var formattedCheckInInterval: String {
        let hours = Int(checkInInterval) / 3600
        
        if hours == 24 {
            return "1 day"
        } else if hours == 48 {
            return "2 days"
        } else {
            return "\(hours) hours"
        }
    }
    
    // Presentation state
    @Presents var intervalSelection: IntervalSelectionFeature.State?
    @Presents var reminderSelection: ReminderSelectionFeature.State?
    @Presents var alert: AlertState<Action>?
}
```

## State Properties

### Core State

These properties represent the fundamental state of the check-in functionality:

#### `lastCheckInTime: Date?`

The timestamp of the user's most recent check-in. This is `nil` if the user has never checked in.

**Usage:**
- Displayed to the user to show when they last checked in
- Used to calculate the next check-in time
- Used to determine if the user is overdue for a check-in

**Persistence:**
- Stored in Firebase Firestore
- Cached locally for offline access

#### `nextCheckInTime: Date?`

The timestamp when the user's next check-in is due. This is calculated by adding the check-in interval to the last check-in time. This is `nil` if the user has never checked in.

**Usage:**
- Used to calculate the time remaining until the next check-in
- Used to determine if the user is overdue for a check-in
- Used to schedule check-in reminders

**Persistence:**
- Calculated from `lastCheckInTime` and `checkInInterval`
- Not stored directly

#### `checkInInterval: TimeInterval`

The interval between check-ins, in seconds. The default is 86400 seconds (24 hours).

**Usage:**
- Used to calculate the next check-in time
- Displayed to the user in a human-readable format
- Can be changed by the user

**Persistence:**
- Stored in Firebase Firestore
- Cached locally for offline access

#### `reminderInterval: TimeInterval`

The interval before the next check-in when the user should be reminded to check in, in seconds. The default is 7200 seconds (2 hours).

**Usage:**
- Used to schedule check-in reminders
- Can be changed by the user

**Persistence:**
- Stored in Firebase Firestore
- Cached locally for offline access

#### `checkInHistory: [CheckInRecord]`

An array of the user's check-in records, ordered by timestamp with the most recent first.

**Usage:**
- Displayed to the user to show their check-in history
- Used for analytics and reporting

**Persistence:**
- Stored in Firebase Firestore
- Cached locally for offline access

#### `isCheckingIn: Bool`

A boolean indicating whether a check-in operation is in progress.

**Usage:**
- Used to show a loading indicator when a check-in is in progress
- Used to disable the check-in button when a check-in is in progress

**Persistence:**
- Not persisted, only exists in memory

#### `isLoadingHistory: Bool`

A boolean indicating whether the check-in history is being loaded.

**Usage:**
- Used to show a loading indicator when the check-in history is being loaded

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

#### `timeRemaining: TimeInterval`

The time remaining until the next check-in is due, in seconds. This is 0 if the user is overdue for a check-in.

**Computation:**
```swift
var timeRemaining: TimeInterval {
    guard let nextCheckInTime = nextCheckInTime else { return 0 }
    return max(0, nextCheckInTime.timeIntervalSinceNow)
}
```

#### `isOverdue: Bool`

A boolean indicating whether the user is overdue for a check-in.

**Computation:**
```swift
var isOverdue: Bool {
    guard let nextCheckInTime = nextCheckInTime else { return false }
    return Date() > nextCheckInTime
}
```

#### `formattedTimeRemaining: String`

A human-readable string representing the time remaining until the next check-in.

**Computation:**
```swift
var formattedTimeRemaining: String {
    let timeRemaining = self.timeRemaining
    
    if timeRemaining <= 0 {
        return "Overdue"
    }
    
    let hours = Int(timeRemaining) / 3600
    let minutes = (Int(timeRemaining) % 3600) / 60
    
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    } else {
        let seconds = Int(timeRemaining) % 60
        return "\(minutes)m \(seconds)s"
    }
}
```

#### `formattedCheckInInterval: String`

A human-readable string representing the check-in interval.

**Computation:**
```swift
var formattedCheckInInterval: String {
    let hours = Int(checkInInterval) / 3600
    
    if hours == 24 {
        return "1 day"
    } else if hours == 48 {
        return "2 days"
    } else {
        return "\(hours) hours"
    }
}
```

### Presentation State

These properties represent the state of presentations (sheets, popovers, alerts) managed by the feature:

#### `@Presents var intervalSelection: IntervalSelectionFeature.State?`

The state of the interval selection sheet. This is `nil` when the sheet is not presented.

**Usage:**
- Used to present a sheet for selecting the check-in interval
- Contains the current interval and available interval options

#### `@Presents var reminderSelection: ReminderSelectionFeature.State?`

The state of the reminder selection sheet. This is `nil` when the sheet is not presented.

**Usage:**
- Used to present a sheet for selecting the reminder interval
- Contains the current reminder interval and available reminder interval options

#### `@Presents var alert: AlertState<Action>?`

The state of an alert. This is `nil` when no alert is presented.

**Usage:**
- Used to present alerts for errors, confirmations, and other messages
- Contains the alert title, message, and buttons

## Child Feature States

### IntervalSelectionFeature.State

```swift
@ObservableState
struct State: Equatable, Sendable {
    var currentInterval: TimeInterval
    var availableIntervals: [TimeInterval] = [
        28800,  // 8 hours
        57600,  // 16 hours
        86400,  // 24 hours
        172800  // 48 hours
    ]
}
```

### ReminderSelectionFeature.State

```swift
@ObservableState
struct State: Equatable, Sendable {
    var currentInterval: TimeInterval
    var availableIntervals: [TimeInterval] = [
        3600,   // 1 hour
        7200,   // 2 hours
        14400,  // 4 hours
        21600   // 6 hours
    ]
}
```

## Domain Models

### CheckInRecord

```swift
struct CheckInRecord: Equatable, Sendable, Identifiable {
    var id: String
    var timestamp: Date
    var userId: String
}
```

## State Initialization

The state is initialized with default values:

```swift
init(
    lastCheckInTime: Date? = nil,
    nextCheckInTime: Date? = nil,
    checkInInterval: TimeInterval = 86400,
    reminderInterval: TimeInterval = 7200,
    checkInHistory: [CheckInRecord] = [],
    isCheckingIn: Bool = false,
    isLoadingHistory: Bool = false,
    error: String? = nil
) {
    self.lastCheckInTime = lastCheckInTime
    self.nextCheckInTime = nextCheckInTime
    self.checkInInterval = checkInInterval
    self.reminderInterval = reminderInterval
    self.checkInHistory = checkInHistory
    self.isCheckingIn = isCheckingIn
    self.isLoadingHistory = isLoadingHistory
    self.error = error
}
```

## State Updates

The state is updated in response to actions dispatched to the feature's reducer. For detailed information on how the state is updated, see the [Actions](Actions.md) and [Effects](Effects.md) documents.

## State Persistence

The core state properties are persisted as follows:

- `lastCheckInTime`, `checkInInterval`, and `reminderInterval` are stored in Firebase Firestore
- `checkInHistory` is stored in Firebase Firestore
- Other properties are not persisted and only exist in memory

## State Access

The state is accessed by the feature's view and by parent features that include the CheckInFeature as a child feature.

Example of a parent feature accessing the CheckInFeature state:

```swift
@Reducer
struct HomeFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var checkIn: CheckInFeature.State = .init()
        // Other state properties...
    }
    
    // Rest of the feature implementation...
}
```

## Best Practices

When working with the CheckInFeature state, follow these best practices:

1. **Use Computed Properties for Derived State** - Use computed properties for state that can be derived from other state properties.

2. **Keep State Minimal** - Only include properties that are necessary for the feature's functionality.

3. **Use Optional Properties Appropriately** - Use optional properties for state that may not be available, such as `lastCheckInTime` and `nextCheckInTime`.

4. **Use Presentation Properties for Presentations** - Use `@Presents` properties for managing presentations, such as sheets, popovers, and alerts.

5. **Document State Properties** - Document the purpose and usage of each state property.

6. **Use Equatable and Sendable** - Ensure that the state conforms to `Equatable` and `Sendable` for compatibility with TCA.

7. **Initialize State with Default Values** - Provide default values for state properties to ensure the feature works correctly when initialized.
