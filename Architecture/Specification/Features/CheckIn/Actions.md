# CheckInFeature Actions

**Navigation:** [Back to CheckInFeature](README.md) | [State](State.md) | [Effects](Effects.md)

---

## Overview

This document provides detailed information about the actions of the CheckInFeature in the LifeSignal iOS application. Actions represent the events that can occur in the feature, including user interactions, system events, and responses from external dependencies.

## Action Definition

```swift
enum Action: Equatable, Sendable {
    // User actions
    case checkInButtonTapped
    case checkInResponse(TaskResult<Date>)
    case intervalSelectionButtonTapped
    case reminderSelectionButtonTapped
    case loadCheckInHistory
    case checkInHistoryResponse(TaskResult<[CheckInRecord]>)
    
    // System actions
    case timerTick
    case appBecameActive
    case appBecameInactive
    case loadCheckInSettings
    case checkInSettingsResponse(TaskResult<(TimeInterval, TimeInterval)>)
    
    // Presentation actions
    case intervalSelection(PresentationAction<IntervalSelectionFeature.Action>)
    case reminderSelection(PresentationAction<ReminderSelectionFeature.Action>)
    case alert(PresentationAction<Never>)
    
    // Error handling
    case setError(String?)
    case dismissError
}
```

## Action Categories

### User Actions

These actions are triggered by user interactions with the feature's UI:

#### `checkInButtonTapped`

Triggered when the user taps the check-in button.

**Effect:**
- Sets `isCheckingIn` to `true`
- Calls the `checkIn` method on the `CheckInClient`
- Dispatches `checkInResponse` with the result

**Example:**
```swift
case .checkInButtonTapped:
    state.isCheckingIn = true
    return .run { send in
        do {
            let checkInTime = try await checkInClient.checkIn()
            await send(.checkInResponse(.success(checkInTime)))
        } catch {
            await send(.checkInResponse(.failure(error)))
        }
    }
```

#### `checkInResponse(TaskResult<Date>)`

Triggered when a check-in operation completes, either successfully or with an error.

**Effect:**
- Sets `isCheckingIn` to `false`
- If successful, updates `lastCheckInTime` and `nextCheckInTime`
- If unsuccessful, sets `error` to the error message

**Example:**
```swift
case let .checkInResponse(.success(checkInTime)):
    state.isCheckingIn = false
    state.lastCheckInTime = checkInTime
    state.nextCheckInTime = checkInTime.addingTimeInterval(state.checkInInterval)
    state.error = nil
    return .none
    
case let .checkInResponse(.failure(error)):
    state.isCheckingIn = false
    state.error = error.localizedDescription
    return .none
```

#### `intervalSelectionButtonTapped`

Triggered when the user taps the button to change their check-in interval.

**Effect:**
- Presents the interval selection sheet

**Example:**
```swift
case .intervalSelectionButtonTapped:
    state.intervalSelection = IntervalSelectionFeature.State(
        currentInterval: state.checkInInterval,
        availableIntervals: [
            28800,  // 8 hours
            57600,  // 16 hours
            86400,  // 24 hours
            172800  // 48 hours
        ]
    )
    return .none
```

#### `reminderSelectionButtonTapped`

Triggered when the user taps the button to change their reminder interval.

**Effect:**
- Presents the reminder selection sheet

**Example:**
```swift
case .reminderSelectionButtonTapped:
    state.reminderSelection = ReminderSelectionFeature.State(
        currentInterval: state.reminderInterval,
        availableIntervals: [
            3600,   // 1 hour
            7200,   // 2 hours
            14400,  // 4 hours
            21600   // 6 hours
        ]
    )
    return .none
```

#### `loadCheckInHistory`

Triggered when the user navigates to the check-in history screen or pulls to refresh the history.

**Effect:**
- Sets `isLoadingHistory` to `true`
- Calls the `getCheckInHistory` method on the `CheckInClient`
- Dispatches `checkInHistoryResponse` with the result

**Example:**
```swift
case .loadCheckInHistory:
    state.isLoadingHistory = true
    return .run { send in
        do {
            let history = try await checkInClient.getCheckInHistory()
            await send(.checkInHistoryResponse(.success(history)))
        } catch {
            await send(.checkInHistoryResponse(.failure(error)))
        }
    }
```

#### `checkInHistoryResponse(TaskResult<[CheckInRecord]>)`

Triggered when a check-in history load operation completes, either successfully or with an error.

**Effect:**
- Sets `isLoadingHistory` to `false`
- If successful, updates `checkInHistory`
- If unsuccessful, sets `error` to the error message

**Example:**
```swift
case let .checkInHistoryResponse(.success(history)):
    state.isLoadingHistory = false
    state.checkInHistory = history
    state.error = nil
    return .none
    
case let .checkInHistoryResponse(.failure(error)):
    state.isLoadingHistory = false
    state.error = error.localizedDescription
    return .none
```

### System Actions

These actions are triggered by system events or internal feature logic:

#### `timerTick`

Triggered every second when the app is active to update time-based UI elements.

**Effect:**
- No direct state changes, but causes the UI to update due to computed properties

**Example:**
```swift
case .timerTick:
    // No state changes, but causes the UI to update due to computed properties
    return .none
```

#### `appBecameActive`

Triggered when the app becomes active (foreground).

**Effect:**
- Starts a timer that dispatches `timerTick` every second
- Loads check-in settings and history

**Example:**
```swift
case .appBecameActive:
    // Start timer for UI updates
    return .merge(
        .run { send in
            for await _ in clock.timer(interval: .seconds(1)) {
                await send(.timerTick)
            }
        }
        .cancellable(id: TimerID.self),
        
        .send(.loadCheckInSettings),
        .send(.loadCheckInHistory)
    )
```

#### `appBecameInactive`

Triggered when the app becomes inactive (background).

**Effect:**
- Cancels the timer

**Example:**
```swift
case .appBecameInactive:
    // Cancel timer when app is inactive
    return .cancel(id: TimerID.self)
```

#### `loadCheckInSettings`

Triggered when the feature needs to load the user's check-in settings.

**Effect:**
- Calls the `getCheckInInterval` and `getReminderInterval` methods on the `CheckInClient`
- Dispatches `checkInSettingsResponse` with the result

**Example:**
```swift
case .loadCheckInSettings:
    return .run { send in
        do {
            async let checkInInterval = checkInClient.getCheckInInterval()
            async let reminderInterval = checkInClient.getReminderInterval()
            
            let (interval, reminder) = try await (checkInInterval, reminderInterval)
            
            await send(.checkInSettingsResponse(.success((interval, reminder))))
        } catch {
            await send(.checkInSettingsResponse(.failure(error)))
        }
    }
```

#### `checkInSettingsResponse(TaskResult<(TimeInterval, TimeInterval)>)`

Triggered when a check-in settings load operation completes, either successfully or with an error.

**Effect:**
- If successful, updates `checkInInterval` and `reminderInterval`
- If unsuccessful, sets `error` to the error message

**Example:**
```swift
case let .checkInSettingsResponse(.success((interval, reminder))):
    state.checkInInterval = interval
    state.reminderInterval = reminder
    
    if let lastCheckInTime = state.lastCheckInTime {
        state.nextCheckInTime = lastCheckInTime.addingTimeInterval(interval)
    }
    
    state.error = nil
    return .none
    
case let .checkInSettingsResponse(.failure(error)):
    state.error = error.localizedDescription
    return .none
```

### Presentation Actions

These actions are related to presentations (sheets, popovers, alerts) managed by the feature:

#### `intervalSelection(PresentationAction<IntervalSelectionFeature.Action>)`

Handles actions from the interval selection sheet.

**Effect:**
- Depends on the specific presentation action

**Example:**
```swift
case let .intervalSelection(.presented(.intervalSelected(interval))):
    state.intervalSelection = nil
    
    // Update the check-in interval
    state.checkInInterval = interval
    
    if let lastCheckInTime = state.lastCheckInTime {
        state.nextCheckInTime = lastCheckInTime.addingTimeInterval(interval)
    }
    
    // Save the new interval
    return .run { send in
        do {
            try await checkInClient.setCheckInInterval(interval)
        } catch {
            await send(.setError(error.localizedDescription))
        }
    }
    
case .intervalSelection(.dismiss):
    state.intervalSelection = nil
    return .none
    
case .intervalSelection:
    return .none
```

#### `reminderSelection(PresentationAction<ReminderSelectionFeature.Action>)`

Handles actions from the reminder selection sheet.

**Effect:**
- Depends on the specific presentation action

**Example:**
```swift
case let .reminderSelection(.presented(.intervalSelected(interval))):
    state.reminderSelection = nil
    
    // Update the reminder interval
    state.reminderInterval = interval
    
    // Save the new interval
    return .run { send in
        do {
            try await checkInClient.setReminderInterval(interval)
        } catch {
            await send(.setError(error.localizedDescription))
        }
    }
    
case .reminderSelection(.dismiss):
    state.reminderSelection = nil
    return .none
    
case .reminderSelection:
    return .none
```

#### `alert(PresentationAction<Never>)`

Handles actions from alerts.

**Effect:**
- Depends on the specific presentation action

**Example:**
```swift
case .alert(.dismiss):
    state.alert = nil
    return .none
```

### Error Handling Actions

These actions are related to error handling:

#### `setError(String?)`

Sets the error message to display to the user.

**Effect:**
- Updates `error` with the provided message
- If the message is not nil, presents an alert with the error message

**Example:**
```swift
case let .setError(error):
    state.error = error
    
    if let error = error {
        state.alert = AlertState {
            TextState("Error")
        } actions: {
            ButtonState(role: .cancel) {
                TextState("OK")
            }
        } message: {
            TextState(error)
        }
    } else {
        state.alert = nil
    }
    
    return .none
```

#### `dismissError`

Dismisses the current error message.

**Effect:**
- Sets `error` to `nil`
- Dismisses any alert

**Example:**
```swift
case .dismissError:
    state.error = nil
    state.alert = nil
    return .none
```

## Child Feature Actions

### IntervalSelectionFeature.Action

```swift
enum Action: Equatable, Sendable {
    case intervalSelected(TimeInterval)
    case cancelButtonTapped
}
```

### ReminderSelectionFeature.Action

```swift
enum Action: Equatable, Sendable {
    case intervalSelected(TimeInterval)
    case cancelButtonTapped
}
```

## Action Handling

Actions are handled by the feature's reducer, which defines how the state changes in response to actions and what effects are executed.

For detailed information on how actions are handled, see the [Effects](Effects.md) document.

## Best Practices

When working with the CheckInFeature actions, follow these best practices:

1. **Group Actions by Category** - Group actions into categories such as user actions, system actions, and presentation actions.

2. **Use Descriptive Action Names** - Use descriptive names that clearly indicate the action's purpose.

3. **Use TaskResult for Async Operations** - Use `TaskResult` for handling the results of asynchronous operations.

4. **Handle Errors Consistently** - Handle errors consistently across all actions.

5. **Document Actions** - Document the purpose and effect of each action.

6. **Use PresentationAction for Presentations** - Use `PresentationAction` for handling actions from presentations.

7. **Keep Actions Focused** - Keep actions focused on a single responsibility.

8. **Use Equatable and Sendable** - Ensure that actions conform to `Equatable` and `Sendable` for compatibility with TCA.
