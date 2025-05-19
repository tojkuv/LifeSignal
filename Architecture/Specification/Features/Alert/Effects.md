# AlertFeature Effects

**Navigation:** [Back to AlertFeature](README.md) | [State](State.md) | [Actions](Actions.md)

---

## Overview

This document provides detailed information about the effects of the AlertFeature in the LifeSignal iOS application. Effects represent the side effects that occur in response to actions, such as API calls, timer operations, and other asynchronous operations.

## Effect Types

The AlertFeature uses the following types of effects:

1. **API Effects** - Effects that interact with external services through clients
2. **Timer Effects** - Effects that perform operations at regular intervals
3. **Navigation Effects** - Effects that handle navigation between screens
4. **Notification Effects** - Effects that handle local and push notifications

## Dependencies

The AlertFeature depends on the following clients for its effects:

```swift
@Dependency(\.alertClient) var alertClient
@Dependency(\.userClient) var userClient
@Dependency(\.notificationClient) var notificationClient
@Dependency(\.contactClient) var contactClient
@Dependency(\.date) var date
@Dependency(\.continuousClock) var clock
@Dependency(\.uuid) var uuid
```

## Effect Implementation

The effects are implemented in the feature's reducer:

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
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
            
        case let .alertActivationResponse(.success(startTime)):
            state.isActivatingAlert = false
            state.isAlertActive = true
            state.alertStartTime = startTime
            state.alertEndTime = nil
            state.activationProgress = 0
            state.error = nil
            
            // Notify responders
            return .run { send in
                do {
                    try await notificationClient.notifyRespondersOfAlert()
                } catch {
                    // Log the error but don't show it to the user
                    print("Failed to notify responders: \(error.localizedDescription)")
                }
            }
            
        case let .alertActivationResponse(.failure(error)):
            state.isActivatingAlert = false
            state.activationProgress = 0
            state.error = error.localizedDescription
            return .none
            
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
            
        case let .alertDeactivationResponse(.success(endTime)):
            state.isDeactivatingAlert = false
            state.isAlertActive = false
            state.alertEndTime = endTime
            state.deactivationProgress = 0
            state.error = nil
            
            // Notify responders
            return .run { send in
                do {
                    try await notificationClient.notifyRespondersOfAlertDeactivation()
                } catch {
                    // Log the error but don't show it to the user
                    print("Failed to notify responders: \(error.localizedDescription)")
                }
            }
            
        case let .alertDeactivationResponse(.failure(error)):
            state.isDeactivatingAlert = false
            state.deactivationProgress = 0
            state.error = error.localizedDescription
            return .none
            
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
            
        case let .alertHistoryResponse(.success(history)):
            state.isLoadingHistory = false
            state.alertHistory = history
            state.error = nil
            return .none
            
        case let .alertHistoryResponse(.failure(error)):
            state.isLoadingHistory = false
            state.error = error.localizedDescription
            return .none
            
        case .timerTick:
            // No state changes, but causes the UI to update due to computed properties
            return .none
            
        case .appBecameActive:
            // Start timer for UI updates and load alert status and history
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
            
        case .appBecameInactive:
            // Cancel timer when app is inactive
            return .cancel(id: TimerID.self)
            
        case .loadAlertStatus:
            return .run { send in
                do {
                    let (isActive, startTime) = try await alertClient.getAlertStatus()
                    await send(.alertStatusResponse(.success((isActive, startTime))))
                } catch {
                    await send(.alertStatusResponse(.failure(error)))
                }
            }
            
        case let .alertStatusResponse(.success((isActive, startTime))):
            state.isAlertActive = isActive
            state.alertStartTime = startTime
            state.error = nil
            return .none
            
        case let .alertStatusResponse(.failure(error)):
            state.error = error.localizedDescription
            return .none
            
        case .confirmationAlert(.dismiss):
            state.confirmationAlert = nil
            return .none
            
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
            
        case .dismissError:
            state.error = nil
            state.confirmationAlert = nil
            return .none
        }
    }
}

// Cancellation IDs
private enum TimerID: Hashable {}
private enum ActivationResetTimerID: Hashable {}
```

## Effect Details

### Alert Activation Effect

The alert activation effect is triggered by the `alertButtonTapped` action when `activationProgress` reaches 1.0 and performs the following operations:

1. Sets `isActivatingAlert` to `true` to show a loading indicator
2. Calls the `activateAlert` method on the `AlertClient`
3. Dispatches `alertActivationResponse` with the result
4. If successful, notifies responders of the alert

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

### Alert Deactivation Effect

The alert deactivation effect is triggered by the `alertDeactivationProgressChanged` action when `deactivationProgress` reaches 1.0 and performs the following operations:

1. Sets `isDeactivatingAlert` to `true` to show a loading indicator
2. Calls the `deactivateAlert` method on the `AlertClient`
3. Dispatches `alertDeactivationResponse` with the result
4. If successful, notifies responders of the alert deactivation

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

### Timer Effect

The timer effect is triggered by the `appBecameActive` action and performs the following operations:

1. Starts a timer that dispatches `timerTick` every second
2. Cancels the timer when the app becomes inactive

```swift
case .appBecameActive:
    // Start timer for UI updates
    return .run { send in
        for await _ in clock.timer(interval: .seconds(1)) {
            await send(.timerTick)
        }
    }
    .cancellable(id: TimerID.self)
    
case .appBecameInactive:
    // Cancel timer when app is inactive
    return .cancel(id: TimerID.self)
```

### Load Alert Status Effect

The load alert status effect is triggered by the `loadAlertStatus` action and performs the following operations:

1. Calls the `getAlertStatus` method on the `AlertClient`
2. Dispatches `alertStatusResponse` with the result

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

### Load Alert History Effect

The load alert history effect is triggered by the `loadAlertHistory` action and performs the following operations:

1. Sets `isLoadingHistory` to `true` to show a loading indicator
2. Calls the `getAlertHistory` method on the `AlertClient`
3. Dispatches `alertHistoryResponse` with the result

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

### Notify Responders Effect

The notify responders effect is triggered by the `alertActivationResponse` and `alertDeactivationResponse` actions and performs the following operations:

1. Calls the `notifyRespondersOfAlert` or `notifyRespondersOfAlertDeactivation` method on the `NotificationClient`
2. Logs any errors but does not show them to the user

```swift
case let .alertActivationResponse(.success(startTime)):
    state.isActivatingAlert = false
    state.isAlertActive = true
    state.alertStartTime = startTime
    state.alertEndTime = nil
    state.activationProgress = 0
    state.error = nil
    
    // Notify responders
    return .run { send in
        do {
            try await notificationClient.notifyRespondersOfAlert()
        } catch {
            // Log the error but don't show it to the user
            print("Failed to notify responders: \(error.localizedDescription)")
        }
    }
```

## Effect Cancellation

The AlertFeature uses the following cancellation IDs:

### TimerID

Used to cancel the timer effect when the app becomes inactive:

```swift
private enum TimerID: Hashable {}

case .appBecameActive:
    // Start timer for UI updates
    return .run { send in
        for await _ in clock.timer(interval: .seconds(1)) {
            await send(.timerTick)
        }
    }
    .cancellable(id: TimerID.self)
    
case .appBecameInactive:
    // Cancel timer when app is inactive
    return .cancel(id: TimerID.self)
```

### ActivationResetTimerID

Used to cancel the activation reset timer when the user taps the alert button again:

```swift
private enum ActivationResetTimerID: Hashable {}

case .alertButtonTapped:
    state.activationProgress += 0.25
    
    if state.isFullyActivated {
        // Activation logic...
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

## Effect Composition

The AlertFeature composes multiple effects using the `.merge` operator:

```swift
case .appBecameActive:
    // Start timer for UI updates and load alert status and history
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

## Effect Testing

The AlertFeature's effects are tested using the `TestStore` from TCA:

```swift
@MainActor
final class AlertFeatureTests: XCTestCase {
    func testAlertActivation() async {
        let store = TestStore(initialState: AlertFeature.State()) {
            AlertFeature()
        } withDependencies: {
            $0.alertClient = .mock(
                activateAlert: {
                    return Date(timeIntervalSince1970: 0)
                }
            )
            $0.notificationClient = .mock(
                notifyRespondersOfAlert: { }
            )
            $0.date = .constant(Date(timeIntervalSince1970: 0))
        }
        
        // Simulate 4 taps to reach 100% activation
        await store.send(.alertButtonTapped) {
            $0.activationProgress = 0.25
        }
        
        await store.send(.alertButtonTapped) {
            $0.activationProgress = 0.5
        }
        
        await store.send(.alertButtonTapped) {
            $0.activationProgress = 0.75
        }
        
        await store.send(.alertButtonTapped) {
            $0.activationProgress = 1.0
            $0.isActivatingAlert = true
        }
        
        await store.receive(.alertActivationResponse(.success(Date(timeIntervalSince1970: 0)))) {
            $0.isActivatingAlert = false
            $0.isAlertActive = true
            $0.alertStartTime = Date(timeIntervalSince1970: 0)
            $0.alertEndTime = nil
            $0.activationProgress = 0
        }
    }
    
    func testAlertDeactivation() async {
        let store = TestStore(
            initialState: AlertFeature.State(
                isAlertActive: true,
                alertStartTime: Date(timeIntervalSince1970: 0)
            )
        ) {
            AlertFeature()
        } withDependencies: {
            $0.alertClient = .mock(
                deactivateAlert: {
                    return Date(timeIntervalSince1970: 3600)
                }
            )
            $0.notificationClient = .mock(
                notifyRespondersOfAlertDeactivation: { }
            )
            $0.date = .constant(Date(timeIntervalSince1970: 3600))
        }
        
        await store.send(.alertDeactivationProgressChanged(1.0)) {
            $0.deactivationProgress = 1.0
            $0.isDeactivatingAlert = true
        }
        
        await store.receive(.alertDeactivationResponse(.success(Date(timeIntervalSince1970: 3600)))) {
            $0.isDeactivatingAlert = false
            $0.isAlertActive = false
            $0.alertEndTime = Date(timeIntervalSince1970: 3600)
            $0.deactivationProgress = 0
        }
    }
    
    // Additional tests for other effects...
}
```

## Best Practices

When working with the AlertFeature effects, follow these best practices:

1. **Use Dependency Injection** - Use dependency injection for all external dependencies to make effects testable.

2. **Handle Errors Gracefully** - Handle errors gracefully and provide meaningful error messages to the user.

3. **Use Cancellation IDs** - Use cancellation IDs to cancel long-running effects when they are no longer needed.

4. **Compose Effects** - Use the `.merge` operator to compose multiple effects.

5. **Test Effects** - Test effects thoroughly using the `TestStore` from TCA.

6. **Use Async/Await** - Use async/await for asynchronous operations to make code more readable and maintainable.

7. **Capture State in Closures** - Capture state in closures to avoid accessing stale state in long-running effects.

8. **Document Effects** - Document the purpose and behavior of each effect.

9. **Keep Effects Focused** - Keep effects focused on a single responsibility.

10. **Use Effect Builders** - Use effect builders like `.run`, `.send`, and `.cancel` to create effects.
