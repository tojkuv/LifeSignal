# AlertFeature Actions

**Navigation:** [Back to AlertFeature](README.md) | [State](State.md) | [Effects](Effects.md)

---

## Overview

This document provides detailed information about the actions of the AlertFeature in the LifeSignal iOS application. Actions represent the events that can occur in the feature, including user interactions, system events, and responses from external dependencies.

## Action Definition

```swift
enum Action: Equatable, Sendable {
    // User actions
    case alertButtonTapped
    case alertActivationResponse(TaskResult<Date>)
    case alertDeactivationButtonTapped
    case alertDeactivationProgressChanged(Double)
    case alertDeactivationResponse(TaskResult<Date>)
    case loadAlertHistory
    case alertHistoryResponse(TaskResult<[AlertRecord]>)
    
    // System actions
    case timerTick
    case appBecameActive
    case appBecameInactive
    case loadAlertStatus
    case alertStatusResponse(TaskResult<(Bool, Date?)>)
    
    // Presentation actions
    case confirmationAlert(PresentationAction<Never>)
    
    // Error handling
    case setError(String?)
    case dismissError
}
```

## Action Categories

### User Actions

These actions are triggered by user interactions with the feature's UI:

#### `alertButtonTapped`

Triggered when the user taps the alert button.

**Effect:**
- Increments `activationProgress` by 0.25
- If `activationProgress` reaches 1.0, activates the alert
- If `activationProgress` is less than 1.0, starts a timer to reset `activationProgress` after a delay

**Example:**
```swift
case .alertButtonTapped:
    state.activationProgress += 0.25
    
    if state.isFullyActivated {
        state.isActivatingAlert = true
        return .run { send in
            do {
                let startTime = try await alertClient.activateAlert()
                await send(.alertActivationResponse(.success(startTime)))
            } catch {
                await send(.alertActivationResponse(.failure(error)))
            }
        }
    } else {
        // Start a timer to reset activation progress after a delay
        return .run { [progress = state.activationProgress] send in
            try await Task.sleep(for: .seconds(3))
            // Only reset if the progress hasn't changed
            if progress == state.activationProgress {
                await send(.setActivationProgress(0))
            }
        }
        .cancellable(id: ActivationResetTimerID.self)
    }
```

#### `alertActivationResponse(TaskResult<Date>)`

Triggered when an alert activation operation completes, either successfully or with an error.

**Effect:**
- Sets `isActivatingAlert` to `false`
- If successful, updates `isAlertActive`, `alertStartTime`, and `alertEndTime`
- If unsuccessful, sets `error` to the error message

**Example:**
```swift
case let .alertActivationResponse(.success(startTime)):
    state.isActivatingAlert = false
    state.isAlertActive = true
    state.alertStartTime = startTime
    state.alertEndTime = nil
    state.activationProgress = 0
    state.error = nil
    return .none
    
case let .alertActivationResponse(.failure(error)):
    state.isActivatingAlert = false
    state.activationProgress = 0
    state.error = error.localizedDescription
    return .none
```

#### `alertDeactivationButtonTapped`

Triggered when the user taps the alert deactivation button.

**Effect:**
- Shows a confirmation alert

**Example:**
```swift
case .alertDeactivationButtonTapped:
    state.confirmationAlert = AlertState {
        TextState("Deactivate Alert")
    } actions: {
        ButtonState(role: .destructive) {
            TextState("Deactivate")
        } action: {
            .deactivateAlertConfirmed
        }
        
        ButtonState(role: .cancel) {
            TextState("Cancel")
        }
    } message: {
        TextState("Are you sure you want to deactivate the alert? This will notify your responders that you are safe.")
    }
    return .none
```

#### `alertDeactivationProgressChanged(Double)`

Triggered when the user's hold on the deactivation button changes.

**Effect:**
- Updates `deactivationProgress`
- If `deactivationProgress` reaches 1.0, deactivates the alert

**Example:**
```swift
case let .alertDeactivationProgressChanged(progress):
    state.deactivationProgress = progress
    
    if state.isFullyDeactivated {
        state.isDeactivatingAlert = true
        return .run { send in
            do {
                let endTime = try await alertClient.deactivateAlert()
                await send(.alertDeactivationResponse(.success(endTime)))
            } catch {
                await send(.alertDeactivationResponse(.failure(error)))
            }
        }
    } else {
        return .none
    }
```

#### `alertDeactivationResponse(TaskResult<Date>)`

Triggered when an alert deactivation operation completes, either successfully or with an error.

**Effect:**
- Sets `isDeactivatingAlert` to `false`
- If successful, updates `isAlertActive` and `alertEndTime`
- If unsuccessful, sets `error` to the error message

**Example:**
```swift
case let .alertDeactivationResponse(.success(endTime)):
    state.isDeactivatingAlert = false
    state.isAlertActive = false
    state.alertEndTime = endTime
    state.deactivationProgress = 0
    state.error = nil
    return .none
    
case let .alertDeactivationResponse(.failure(error)):
    state.isDeactivatingAlert = false
    state.deactivationProgress = 0
    state.error = error.localizedDescription
    return .none
```

#### `loadAlertHistory`

Triggered when the user navigates to the alert history screen or pulls to refresh the history.

**Effect:**
- Sets `isLoadingHistory` to `true`
- Calls the `getAlertHistory` method on the `AlertClient`
- Dispatches `alertHistoryResponse` with the result

**Example:**
```swift
case .loadAlertHistory:
    state.isLoadingHistory = true
    return .run { send in
        do {
            let history = try await alertClient.getAlertHistory()
            await send(.alertHistoryResponse(.success(history)))
        } catch {
            await send(.alertHistoryResponse(.failure(error)))
        }
    }
```

#### `alertHistoryResponse(TaskResult<[AlertRecord]>)`

Triggered when an alert history load operation completes, either successfully or with an error.

**Effect:**
- Sets `isLoadingHistory` to `false`
- If successful, updates `alertHistory`
- If unsuccessful, sets `error` to the error message

**Example:**
```swift
case let .alertHistoryResponse(.success(history)):
    state.isLoadingHistory = false
    state.alertHistory = history
    state.error = nil
    return .none
    
case let .alertHistoryResponse(.failure(error)):
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
- Loads alert status and history

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
        
        .send(.loadAlertStatus),
        .send(.loadAlertHistory)
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

#### `loadAlertStatus`

Triggered when the feature needs to load the user's alert status.

**Effect:**
- Calls the `getAlertStatus` method on the `AlertClient`
- Dispatches `alertStatusResponse` with the result

**Example:**
```swift
case .loadAlertStatus:
    return .run { send in
        do {
            let (isActive, startTime) = try await alertClient.getAlertStatus()
            await send(.alertStatusResponse(.success((isActive, startTime))))
        } catch {
            await send(.alertStatusResponse(.failure(error)))
        }
    }
```

#### `alertStatusResponse(TaskResult<(Bool, Date?)>)`

Triggered when an alert status load operation completes, either successfully or with an error.

**Effect:**
- If successful, updates `isAlertActive` and `alertStartTime`
- If unsuccessful, sets `error` to the error message

**Example:**
```swift
case let .alertStatusResponse(.success((isActive, startTime))):
    state.isAlertActive = isActive
    state.alertStartTime = startTime
    state.error = nil
    return .none
    
case let .alertStatusResponse(.failure(error)):
    state.error = error.localizedDescription
    return .none
```

### Presentation Actions

These actions are related to presentations (sheets, popovers, alerts) managed by the feature:

#### `confirmationAlert(PresentationAction<Never>)`

Handles actions from confirmation alerts.

**Effect:**
- Depends on the specific presentation action

**Example:**
```swift
case .confirmationAlert(.dismiss):
    state.confirmationAlert = nil
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
        state.confirmationAlert = AlertState {
            TextState("Error")
        } actions: {
            ButtonState(role: .cancel) {
                TextState("OK")
            }
        } message: {
            TextState(error)
        }
    } else {
        state.confirmationAlert = nil
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
    state.confirmationAlert = nil
    return .none
```

## Action Handling

Actions are handled by the feature's reducer, which defines how the state changes in response to actions and what effects are executed.

For detailed information on how actions are handled, see the [Effects](Effects.md) document.

## Best Practices

When working with the AlertFeature actions, follow these best practices:

1. **Group Actions by Category** - Group actions into categories such as user actions, system actions, and presentation actions.

2. **Use Descriptive Action Names** - Use descriptive names that clearly indicate the action's purpose.

3. **Use TaskResult for Async Operations** - Use `TaskResult` for handling the results of asynchronous operations.

4. **Handle Errors Consistently** - Handle errors consistently across all actions.

5. **Document Actions** - Document the purpose and effect of each action.

6. **Use PresentationAction for Presentations** - Use `PresentationAction` for handling actions from presentations.

7. **Keep Actions Focused** - Keep actions focused on a single responsibility.

8. **Use Equatable and Sendable** - Ensure that actions conform to `Equatable` and `Sendable` for compatibility with TCA.
