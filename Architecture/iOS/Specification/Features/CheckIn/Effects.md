# CheckInFeature Effects

**Navigation:** [Back to CheckInFeature](README.md) | [State](State.md) | [Actions](Actions.md)

---

## Overview

This document provides detailed information about the effects of the CheckInFeature in the LifeSignal iOS application. Effects represent the side effects that occur in response to actions, such as API calls, timer operations, and other asynchronous operations.

## Effect Types

The CheckInFeature uses the following types of effects:

1. **API Effects** - Effects that interact with external services through clients
2. **Timer Effects** - Effects that perform operations at regular intervals
3. **Navigation Effects** - Effects that handle navigation between screens
4. **Notification Effects** - Effects that handle local and push notifications

## Dependencies

The CheckInFeature depends on the following clients for its effects:

```swift
@Dependency(\.checkInClient) var checkInClient
@Dependency(\.userClient) var userClient
@Dependency(\.notificationClient) var notificationClient
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
            
        case let .checkInResponse(.success(checkInTime)):
            state.isCheckingIn = false
            state.lastCheckInTime = checkInTime
            state.nextCheckInTime = checkInTime.addingTimeInterval(state.checkInInterval)
            state.error = nil
            
            // Schedule a reminder notification
            return .run { [reminderInterval = state.reminderInterval, nextCheckInTime = state.nextCheckInTime] send in
                guard let nextCheckInTime = nextCheckInTime else { return }
                
                let reminderTime = nextCheckInTime.addingTimeInterval(-reminderInterval)
                
                do {
                    try await notificationClient.scheduleCheckInReminder(at: reminderTime)
                } catch {
                    // Log the error but don't show it to the user
                    print("Failed to schedule check-in reminder: \(error.localizedDescription)")
                }
            }
            
        case let .checkInResponse(.failure(error)):
            state.isCheckingIn = false
            state.error = error.localizedDescription
            return .none
            
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
            
        case let .checkInHistoryResponse(.success(history)):
            state.isLoadingHistory = false
            state.checkInHistory = history
            state.error = nil
            return .none
            
        case let .checkInHistoryResponse(.failure(error)):
            state.isLoadingHistory = false
            state.error = error.localizedDescription
            return .none
            
        case .timerTick:
            // No state changes, but causes the UI to update due to computed properties
            return .none
            
        case .appBecameActive:
            // Start timer for UI updates and load check-in settings and history
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
            
        case .appBecameInactive:
            // Cancel timer when app is inactive
            return .cancel(id: TimerID.self)
            
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
                    
                    // Reschedule reminder notification if needed
                    if let nextCheckInTime = state.nextCheckInTime {
                        let reminderTime = nextCheckInTime.addingTimeInterval(-state.reminderInterval)
                        try await notificationClient.scheduleCheckInReminder(at: reminderTime)
                    }
                } catch {
                    await send(.setError(error.localizedDescription))
                }
            }
            
        case .intervalSelection(.dismiss):
            state.intervalSelection = nil
            return .none
            
        case .intervalSelection:
            return .none
            
        case let .reminderSelection(.presented(.intervalSelected(interval))):
            state.reminderSelection = nil
            
            // Update the reminder interval
            state.reminderInterval = interval
            
            // Save the new interval
            return .run { [nextCheckInTime = state.nextCheckInTime] send in
                do {
                    try await checkInClient.setReminderInterval(interval)
                    
                    // Reschedule reminder notification if needed
                    if let nextCheckInTime = nextCheckInTime {
                        let reminderTime = nextCheckInTime.addingTimeInterval(-interval)
                        try await notificationClient.scheduleCheckInReminder(at: reminderTime)
                    }
                } catch {
                    await send(.setError(error.localizedDescription))
                }
            }
            
        case .reminderSelection(.dismiss):
            state.reminderSelection = nil
            return .none
            
        case .reminderSelection:
            return .none
            
        case .alert(.dismiss):
            state.alert = nil
            return .none
            
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
            
        case .dismissError:
            state.error = nil
            state.alert = nil
            return .none
        }
    }
    .ifLet(\.$intervalSelection, action: \.intervalSelection) {
        IntervalSelectionFeature()
    }
    .ifLet(\.$reminderSelection, action: \.reminderSelection) {
        ReminderSelectionFeature()
    }
}

// Cancellation ID for timer
private enum TimerID: Hashable {}
```

## Effect Details

### Check-In Effect

The check-in effect is triggered by the `checkInButtonTapped` action and performs the following operations:

1. Sets `isCheckingIn` to `true` to show a loading indicator
2. Calls the `checkIn` method on the `CheckInClient`
3. Dispatches `checkInResponse` with the result
4. If successful, schedules a reminder notification

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

### Load Check-In Settings Effect

The load check-in settings effect is triggered by the `loadCheckInSettings` action and performs the following operations:

1. Calls the `getCheckInInterval` and `getReminderInterval` methods on the `CheckInClient`
2. Dispatches `checkInSettingsResponse` with the result

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

### Load Check-In History Effect

The load check-in history effect is triggered by the `loadCheckInHistory` action and performs the following operations:

1. Sets `isLoadingHistory` to `true` to show a loading indicator
2. Calls the `getCheckInHistory` method on the `CheckInClient`
3. Dispatches `checkInHistoryResponse` with the result

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

### Set Check-In Interval Effect

The set check-in interval effect is triggered by the `intervalSelection(.presented(.intervalSelected(interval)))` action and performs the following operations:

1. Updates `checkInInterval` with the selected interval
2. Updates `nextCheckInTime` based on the new interval
3. Calls the `setCheckInInterval` method on the `CheckInClient`
4. Reschedules the reminder notification

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
            
            // Reschedule reminder notification if needed
            if let nextCheckInTime = state.nextCheckInTime {
                let reminderTime = nextCheckInTime.addingTimeInterval(-state.reminderInterval)
                try await notificationClient.scheduleCheckInReminder(at: reminderTime)
            }
        } catch {
            await send(.setError(error.localizedDescription))
        }
    }
```

### Set Reminder Interval Effect

The set reminder interval effect is triggered by the `reminderSelection(.presented(.intervalSelected(interval)))` action and performs the following operations:

1. Updates `reminderInterval` with the selected interval
2. Calls the `setReminderInterval` method on the `CheckInClient`
3. Reschedules the reminder notification

```swift
case let .reminderSelection(.presented(.intervalSelected(interval))):
    state.reminderSelection = nil
    
    // Update the reminder interval
    state.reminderInterval = interval
    
    // Save the new interval
    return .run { [nextCheckInTime = state.nextCheckInTime] send in
        do {
            try await checkInClient.setReminderInterval(interval)
            
            // Reschedule reminder notification if needed
            if let nextCheckInTime = nextCheckInTime {
                let reminderTime = nextCheckInTime.addingTimeInterval(-interval)
                try await notificationClient.scheduleCheckInReminder(at: reminderTime)
            }
        } catch {
            await send(.setError(error.localizedDescription))
        }
    }
```

## Effect Cancellation

The CheckInFeature uses the following cancellation IDs:

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

## Effect Composition

The CheckInFeature composes multiple effects using the `.merge` operator:

```swift
case .appBecameActive:
    // Start timer for UI updates and load check-in settings and history
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

## Effect Testing

The CheckInFeature's effects are tested using the `TestStore` from TCA:

```swift
@MainActor
final class CheckInFeatureTests: XCTestCase {
    func testCheckIn() async {
        let store = TestStore(initialState: CheckInFeature.State()) {
            CheckInFeature()
        } withDependencies: {
            $0.checkInClient = .mock(
                checkIn: {
                    return Date(timeIntervalSince1970: 0)
                }
            )
            $0.notificationClient = .mock(
                scheduleCheckInReminder: { _ in }
            )
            $0.date = .constant(Date(timeIntervalSince1970: 0))
        }
        
        await store.send(.checkInButtonTapped) {
            $0.isCheckingIn = true
        }
        
        await store.receive(.checkInResponse(.success(Date(timeIntervalSince1970: 0)))) {
            $0.isCheckingIn = false
            $0.lastCheckInTime = Date(timeIntervalSince1970: 0)
            $0.nextCheckInTime = Date(timeIntervalSince1970: 86400) // 24 hours later
        }
    }
    
    func testCheckInFailure() async {
        struct CheckInError: Error, Equatable {}
        
        let store = TestStore(initialState: CheckInFeature.State()) {
            CheckInFeature()
        } withDependencies: {
            $0.checkInClient = .mock(
                checkIn: {
                    throw CheckInError()
                }
            )
        }
        
        await store.send(.checkInButtonTapped) {
            $0.isCheckingIn = true
        }
        
        await store.receive(.checkInResponse(.failure(CheckInError()))) {
            $0.isCheckingIn = false
            $0.error = CheckInError().localizedDescription
        }
    }
    
    // Additional tests for other effects...
}
```

## Best Practices

When working with the CheckInFeature effects, follow these best practices:

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
