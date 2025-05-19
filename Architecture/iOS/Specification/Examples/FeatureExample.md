# TCA Feature Example: CheckInFeature

**Navigation:** [Back to Examples](README.md) | [View Example](ViewExample.md) | [Client Example](ClientExample.md) | [Adapter Example](AdapterExample.md)

---

## Overview

This document provides a complete example of a TCA feature implementation for the CheckInFeature in the LifeSignal iOS application. The CheckInFeature is responsible for managing the user's check-in functionality, including check-in status, history, and interval management.

## Feature Structure

A TCA feature consists of the following components:
- State: Defines the feature's state
- Action: Defines the actions that can be performed on the feature
- Reducer: Defines how the state changes in response to actions
- Dependencies: External dependencies used by the feature

## State Definition

```swift
@Reducer
struct CheckInFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        // Core state
        var lastCheckInTime: Date?
        var nextCheckInTime: Date?
        var checkInInterval: TimeInterval = 86400 // 24 hours in seconds
        var reminderInterval: TimeInterval = 7200 // 2 hours in seconds
        var isCheckingIn: Bool = false
        var error: String? = nil
        
        // Derived state
        var timeRemaining: TimeInterval {
            guard let nextCheckInTime = nextCheckInTime else { return 0 }
            return max(0, nextCheckInTime.timeIntervalSinceNow)
        }
        
        var isOverdue: Bool {
            guard let nextCheckInTime = nextCheckInTime else { return false }
            return Date() > nextCheckInTime
        }
        
        // Presentation state
        @Presents var intervalSelection: IntervalSelectionFeature.State?
    }
    
    // Rest of the feature implementation...
}
```

## Action Definition

```swift
enum Action: Equatable, Sendable {
    // User actions
    case checkInButtonTapped
    case checkInResponse(TaskResult<Date>)
    case setCheckInInterval(TimeInterval)
    case setReminderInterval(TimeInterval)
    case intervalSelectionButtonTapped
    
    // System actions
    case timerTick
    case appBecameActive
    case appBecameInactive
    
    // Presentation actions
    case intervalSelection(PresentationAction<IntervalSelectionFeature.Action>)
    
    // Error handling
    case setError(String?)
    case dismissError
}
```

## Reducer Implementation

```swift
@Dependency(\.checkInClient) var checkInClient
@Dependency(\.date) var date
@Dependency(\.continuousClock) var clock

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
            return .none
            
        case let .checkInResponse(.failure(error)):
            state.isCheckingIn = false
            state.error = error.localizedDescription
            return .none
            
        case let .setCheckInInterval(interval):
            state.checkInInterval = interval
            if let lastCheckInTime = state.lastCheckInTime {
                state.nextCheckInTime = lastCheckInTime.addingTimeInterval(interval)
            }
            return .none
            
        case let .setReminderInterval(interval):
            state.reminderInterval = interval
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
            
        case .timerTick:
            // Update any time-based state
            return .none
            
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
            
        case let .intervalSelection(.presented(.intervalSelected(interval))):
            state.intervalSelection = nil
            return .send(.setCheckInInterval(interval))
            
        case .intervalSelection:
            return .none
            
        case let .setError(error):
            state.error = error
            return .none
            
        case .dismissError:
            state.error = nil
            return .none
        }
    }
    .ifLet(\.$intervalSelection, action: \.intervalSelection) {
        IntervalSelectionFeature()
    }
}

// Cancellation ID for timer
private enum TimerID: Hashable {}
```

## Child Feature: IntervalSelectionFeature

```swift
@Reducer
struct IntervalSelectionFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var currentInterval: TimeInterval
        var availableIntervals: [TimeInterval]
    }
    
    enum Action: Equatable, Sendable {
        case intervalSelected(TimeInterval)
        case cancelButtonTapped
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .intervalSelected(interval):
                return .none
                
            case .cancelButtonTapped:
                return .none
            }
        }
    }
}
```

## Feature Usage in Parent Feature

```swift
@Reducer
struct HomeFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var checkIn: CheckInFeature.State = .init()
        var alert: AlertFeature.State = .init()
        // Other state...
    }
    
    enum Action: Equatable, Sendable {
        case checkIn(CheckInFeature.Action)
        case alert(AlertFeature.Action)
        // Other actions...
    }
    
    var body: some ReducerOf<Self> {
        Scope(state: \.checkIn, action: \.checkIn) {
            CheckInFeature()
        }
        
        Scope(state: \.alert, action: \.alert) {
            AlertFeature()
        }
        
        Reduce { state, action in
            // Handle HomeFeature-specific actions
            return .none
        }
    }
}
```

## Testing the Feature

```swift
@MainActor
final class CheckInFeatureTests: XCTestCase {
    func testCheckIn() async {
        let clock = TestClock()
        let checkInClient = CheckInClientMock()
        
        let store = TestStore(initialState: CheckInFeature.State()) {
            CheckInFeature()
        } withDependencies: {
            $0.checkInClient = checkInClient
            $0.continuousClock = clock
            $0.date = .constant(Date(timeIntervalSince1970: 0))
        }
        
        // Set up mock behavior
        checkInClient.checkInHandler = {
            return Date(timeIntervalSince1970: 0)
        }
        
        // Test check-in flow
        await store.send(.checkInButtonTapped) {
            $0.isCheckingIn = true
        }
        
        await store.receive(.checkInResponse(.success(Date(timeIntervalSince1970: 0)))) {
            $0.isCheckingIn = false
            $0.lastCheckInTime = Date(timeIntervalSince1970: 0)
            $0.nextCheckInTime = Date(timeIntervalSince1970: 86400) // 24 hours later
        }
        
        // Test interval change
        await store.send(.setCheckInInterval(172800)) { // 48 hours
            $0.checkInInterval = 172800
            $0.nextCheckInTime = Date(timeIntervalSince1970: 172800) // 48 hours later
        }
    }
    
    func testCheckInFailure() async {
        let checkInClient = CheckInClientMock()
        
        let store = TestStore(initialState: CheckInFeature.State()) {
            CheckInFeature()
        } withDependencies: {
            $0.checkInClient = checkInClient
        }
        
        // Set up mock behavior to throw an error
        struct CheckInError: Error, Equatable {}
        checkInClient.checkInHandler = {
            throw CheckInError()
        }
        
        // Test check-in failure
        await store.send(.checkInButtonTapped) {
            $0.isCheckingIn = true
        }
        
        await store.receive(.checkInResponse(.failure(CheckInError()))) {
            $0.isCheckingIn = false
            $0.error = CheckInError().localizedDescription
        }
    }
}

// Mock implementation of CheckInClient for testing
final class CheckInClientMock: CheckInClient {
    var checkInHandler: () async throws -> Date = { fatalError("Not implemented") }
    
    func checkIn() async throws -> Date {
        try await checkInHandler()
    }
}
```

## Best Practices

1. **State Management**
   - Use `@ObservableState` for all state structs
   - Keep state minimal and focused on the feature's responsibilities
   - Use computed properties for derived state

2. **Action Design**
   - Group actions by their source (user, system, presentation)
   - Use descriptive names that clearly indicate the action's purpose
   - Use `TaskResult` for handling asynchronous operations

3. **Reducer Implementation**
   - Keep reducers focused on a single responsibility
   - Use `Scope` to delegate to child reducers
   - Use `Reduce` to handle feature-specific actions

4. **Effect Handling**
   - Use `.run` for asynchronous operations
   - Use `.send` to dispatch new actions
   - Use `.cancel` to cancel long-running effects

5. **Testing**
   - Test all action paths
   - Use mocks for dependencies
   - Test success and failure cases
   - Test state transitions

## Conclusion

This example demonstrates a complete implementation of a TCA feature for the CheckInFeature in the LifeSignal iOS application. It shows how to define state, actions, and a reducer, as well as how to handle effects, dependencies, and testing.

When implementing a new feature, use this example as a reference to ensure consistency and adherence to the established architectural patterns.
