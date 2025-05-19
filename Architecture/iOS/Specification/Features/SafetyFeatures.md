# LifeSignal iOS Safety Features

**Navigation:** [Back to Features](README.md) | [Core Features](CoreFeatures.md) | [Contact Features](ContactFeatures.md) | [Utility Features](UtilityFeatures.md)

---

## Overview

This document provides detailed specifications for the safety features of the LifeSignal iOS application. Safety features provide the core safety functionality, including check-ins, alerts, and pings.

## CheckInFeature

The [CheckInFeature](CheckIn/README.md) manages the user's check-in functionality.

### State

```swift
@ObservableState
struct State: Equatable, Sendable {
    @Shared(.fileStorage(.userProfile)) var user: User = User(id: UUID())
    var lastCheckIn: Date?
    var nextCheckInDue: Date?
    var checkInInterval: TimeInterval
    var reminderInterval: TimeInterval
    var isCheckingIn: Bool = false
    var error: UserFacingError?
    @Presents var destination: Destination.State?

    enum Destination: Equatable, Sendable {
        case intervalSelection(IntervalSelectionFeature.State)
    }
}
```

### Action

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
    case destination(PresentationAction<Destination.Action>)

    // Error handling
    case setError(UserFacingError?)
    case dismissError

    enum Destination: Equatable, Sendable {
        case intervalSelection(IntervalSelectionFeature.Action)
    }
}
```

### Dependencies

- **CheckInClient**: For check-in operations
- **UserClient**: For user profile operations
- **NotificationClient**: For notification operations

### Responsibilities

- Manages check-in status
- Handles check-in operations
- Manages check-in intervals
- Provides countdown to next check-in
- Sends check-in reminders

### Implementation Details

The CheckInFeature manages the check-in functionality:

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
            state.lastCheckIn = checkInTime
            state.nextCheckInDue = checkInTime.addingTimeInterval(state.checkInInterval)

            // Schedule local notification for reminder
            let reminderTime = state.nextCheckInDue!.addingTimeInterval(-state.reminderInterval)

            return .run { _ in
                try await notificationClient.scheduleCheckInReminder(at: reminderTime)
            }

        case let .checkInResponse(.failure(error)):
            state.isCheckingIn = false
            state.error = UserFacingError(error)
            return .none

        case let .setCheckInInterval(interval):
            state.checkInInterval = interval

            // Update next check-in due time if there's a last check-in
            if let lastCheckIn = state.lastCheckIn {
                state.nextCheckInDue = lastCheckIn.addingTimeInterval(interval)

                // Schedule local notification for reminder
                let reminderTime = state.nextCheckInDue!.addingTimeInterval(-state.reminderInterval)

                return .run { _ in
                    try await notificationClient.scheduleCheckInReminder(at: reminderTime)
                }
            }

            return .run { _ in
                try await checkInClient.setCheckInInterval(interval)
            }

        case let .setReminderInterval(interval):
            state.reminderInterval = interval

            // Update reminder notification if there's a next check-in due
            if let nextCheckInDue = state.nextCheckInDue {
                let reminderTime = nextCheckInDue.addingTimeInterval(-interval)

                return .run { _ in
                    try await notificationClient.scheduleCheckInReminder(at: reminderTime)
                    try await checkInClient.setReminderInterval(interval)
                }
            }

            return .run { _ in
                try await checkInClient.setReminderInterval(interval)
            }

        case .intervalSelectionButtonTapped:
            state.destination = .intervalSelection(
                IntervalSelectionFeature.State(
                    checkInInterval: state.checkInInterval,
                    reminderInterval: state.reminderInterval
                )
            )
            return .none

        case .timerTick:
            // Update UI for countdown
            return .none

        case .appBecameActive:
            // Refresh check-in status
            return .run { send in
                do {
                    let checkInHistory = try await checkInClient.getCheckInHistory(limit: 1)
                    if let lastCheckIn = checkInHistory.first {
                        await send(.checkInResponse(.success(lastCheckIn.timestamp)))
                    }
                } catch {
                    // Silently fail, don't update UI
                }
            }

        case .appBecameInactive:
            // Save state
            return .none

        // Navigation and error handling...
        }
    }
    .ifLet(\.$destination, action: \.destination)
}
```

## AlertFeature

The [AlertFeature](Alert/README.md) manages the user's alert functionality.

### State

```swift
@ObservableState
struct State: Equatable, Sendable {
    @Shared(.fileStorage(.userProfile)) var user: User = User(id: UUID())
    var isAlertActive: Bool = false
    var alertActivationProgress: Double = 0.0
    var alertDeactivationProgress: Double = 0.0
    var isActivating: Bool = false
    var isDeactivating: Bool = false
    var error: UserFacingError?
}
```

### Action

```swift
enum Action: Equatable, Sendable {
    // User actions
    case alertButtonPressed
    case alertButtonReleased
    case alertActivationProgressUpdated(Double)
    case alertDeactivationProgressUpdated(Double)

    // System actions
    case activateAlert
    case deactivateAlert
    case alertActivated
    case alertDeactivated
    case alertActivationFailed(UserFacingError)
    case alertDeactivationFailed(UserFacingError)

    // Error handling
    case setError(UserFacingError?)
    case dismissError
}
```

### Dependencies

- **AlertClient**: For alert operations
- **UserClient**: For user profile operations
- **NotificationClient**: For notification operations

### Responsibilities

- Manages alert status
- Handles alert activation and deactivation
- Provides visual feedback during activation/deactivation
- Notifies responders of alerts

### Implementation Details

The AlertFeature manages the alert functionality:

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case .alertButtonPressed:
            // Start tracking progress for activation/deactivation
            if state.isAlertActive {
                state.isDeactivating = true
                state.alertDeactivationProgress = 0.0
            } else {
                state.isActivating = true
                state.alertActivationProgress = 0.0
            }
            return .none

        case .alertButtonReleased:
            // Cancel activation/deactivation if not complete
            if state.isActivating {
                state.isActivating = false
                state.alertActivationProgress = 0.0
            }

            if state.isDeactivating {
                state.isDeactivating = false
                state.alertDeactivationProgress = 0.0
            }
            return .none

        case let .alertActivationProgressUpdated(progress):
            state.alertActivationProgress = progress

            // Complete activation when progress reaches 1.0
            if progress >= 1.0 {
                state.isActivating = false
                return .send(.activateAlert)
            }
            return .none

        case let .alertDeactivationProgressUpdated(progress):
            state.alertDeactivationProgress = progress

            // Complete deactivation when progress reaches 1.0
            if progress >= 1.0 {
                state.isDeactivating = false
                return .send(.deactivateAlert)
            }
            return .none

        case .activateAlert:
            return .run { send in
                do {
                    try await alertClient.activateAlert()
                    await send(.alertActivated)
                } catch {
                    await send(.alertActivationFailed(UserFacingError(error)))
                }
            }

        case .deactivateAlert:
            return .run { send in
                do {
                    try await alertClient.deactivateAlert()
                    await send(.alertDeactivated)
                } catch {
                    await send(.alertDeactivationFailed(UserFacingError(error)))
                }
            }

        case .alertActivated:
            state.isAlertActive = true
            return .none

        case .alertDeactivated:
            state.isAlertActive = false
            return .none

        case let .alertActivationFailed(error):
            state.error = error
            return .none

        case let .alertDeactivationFailed(error):
            state.error = error
            return .none

        // Error handling...
        }
    }
}
```

## PingFeature

The [PingFeature](Ping/README.md) manages ping functionality between users.

### State

```swift
@ObservableState
struct State: Equatable, Sendable {
    var pendingPings: IdentifiedArrayOf<Ping> = []
    var sentPings: IdentifiedArrayOf<Ping> = []
    var isLoading: Bool = false
    var error: UserFacingError?
}
```

### Action

```swift
enum Action: Equatable, Sendable {
    // Lifecycle actions
    case onAppear

    // User actions
    case sendPing(UUID)
    case respondToPing(UUID)
    case respondToAllPings

    // System actions
    case loadPings
    case pingsLoaded(pendingPings: IdentifiedArrayOf<Ping>, sentPings: IdentifiedArrayOf<Ping>)
    case pingsLoadFailed(UserFacingError)
    case pingResponse(TaskResult<Void>)
    case respondToPingResponse(TaskResult<Void>)
    case respondToAllPingsResponse(TaskResult<Void>)
    case streamPingUpdates
    case pingUpdated(Ping)

    // Error handling
    case setError(UserFacingError?)
    case dismissError
}
```

### Dependencies

- **PingClient**: For ping operations
- **ContactClient**: For contact operations
- **NotificationClient**: For notification operations

### Responsibilities

- Manages pending and sent pings
- Handles sending pings to dependents
- Handles responding to pings from responders
- Streams ping updates from the server
- Provides ping history

### Implementation Details

The PingFeature manages the ping functionality:

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case .onAppear:
            return .merge(
                .send(.loadPings),
                .send(.streamPingUpdates)
            )

        case .loadPings:
            state.isLoading = true
            return .run { send in
                do {
                    let pendingPings = try await pingClient.getPendingPings()
                    let sentPings = try await pingClient.getSentPings()
                    await send(.pingsLoaded(pendingPings: pendingPings, sentPings: sentPings))
                } catch {
                    await send(.pingsLoadFailed(UserFacingError(error)))
                }
            }

        case let .pingsLoaded(pendingPings, sentPings):
            state.isLoading = false
            state.pendingPings = pendingPings
            state.sentPings = sentPings
            return .none

        case let .pingsLoadFailed(error):
            state.isLoading = false
            state.error = error
            return .none

        case let .sendPing(contactID):
            return .run { send in
                do {
                    try await pingClient.sendPing(contactID: contactID)
                    await send(.pingResponse(.success))
                } catch {
                    await send(.pingResponse(.failure(error)))
                }
            }

        case let .respondToPing(pingID):
            return .run { send in
                do {
                    try await pingClient.respondToPing(pingID: pingID)
                    await send(.respondToPingResponse(.success))
                } catch {
                    await send(.respondToPingResponse(.failure(error)))
                }
            }

        case .respondToAllPings:
            return .run { send in
                do {
                    try await pingClient.respondToAllPings()
                    await send(.respondToAllPingsResponse(.success))
                } catch {
                    await send(.respondToAllPingsResponse(.failure(error)))
                }
            }

        case .pingResponse(.success):
            // Ping sent successfully, will be updated via stream
            return .none

        case let .pingResponse(.failure(error)):
            state.error = UserFacingError(error)
            return .none

        case .respondToPingResponse(.success):
            // Ping response sent successfully, will be updated via stream
            return .none

        case let .respondToPingResponse(.failure(error)):
            state.error = UserFacingError(error)
            return .none

        case .respondToAllPingsResponse(.success):
            // All ping responses sent successfully, will be updated via stream
            return .none

        case let .respondToAllPingsResponse(.failure(error)):
            state.error = UserFacingError(error)
            return .none

        case .streamPingUpdates:
            return .run { send in
                for await ping in await pingClient.pingStream() {
                    await send(.pingUpdated(ping))
                }
            }
            .cancellable(id: CancelID.pingStream)

        case let .pingUpdated(ping):
            // Update pending or sent pings based on ping direction
            if ping.recipientID == userClient.currentUserID() {
                // This is a pending ping
                if let index = state.pendingPings.firstIndex(where: { $0.id == ping.id }) {
                    state.pendingPings[index] = ping
                } else {
                    state.pendingPings.append(ping)
                }

                // Remove from pending if responded
                if ping.status == .responded {
                    state.pendingPings.remove(id: ping.id)
                }
            } else {
                // This is a sent ping
                if let index = state.sentPings.firstIndex(where: { $0.id == ping.id }) {
                    state.sentPings[index] = ping
                } else {
                    state.sentPings.append(ping)
                }
            }
            return .none

        // Error handling...
        }
    }
}
```

## IntervalSelectionFeature

The IntervalSelectionFeature allows users to select check-in and reminder intervals.

### State

```swift
@ObservableState
struct State: Equatable, Sendable {
    var checkInInterval: TimeInterval
    var reminderInterval: TimeInterval
    var availableCheckInIntervals: [TimeInterval] = [
        8 * 3600,  // 8 hours
        16 * 3600, // 16 hours
        24 * 3600, // 1 day
        48 * 3600, // 2 days
        72 * 3600  // 3 days
    ]
    var availableReminderIntervals: [TimeInterval] = [
        1 * 3600,  // 1 hour
        2 * 3600,  // 2 hours
        4 * 3600,  // 4 hours
        8 * 3600   // 8 hours
    ]
}
```

### Action

```swift
enum Action: Equatable, Sendable {
    // User actions
    case checkInIntervalSelected(TimeInterval)
    case reminderIntervalSelected(TimeInterval)
    case saveButtonTapped
    case cancelButtonTapped

    // Delegate actions
    case delegate(DelegateAction)

    enum DelegateAction: Equatable, Sendable {
        case intervalsSelected(checkInInterval: TimeInterval, reminderInterval: TimeInterval)
        case cancelled
    }
}
```

### Dependencies

None

### Responsibilities

- Provides selection of check-in intervals
- Provides selection of reminder intervals
- Validates interval selections
- Returns selected intervals to parent feature

### Implementation Details

The IntervalSelectionFeature manages interval selection:

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case let .checkInIntervalSelected(interval):
            state.checkInInterval = interval

            // Ensure reminder interval is less than check-in interval
            if state.reminderInterval >= interval {
                // Find the largest reminder interval that's less than the check-in interval
                if let newReminderInterval = state.availableReminderIntervals
                    .filter({ $0 < interval })
                    .max() {
                    state.reminderInterval = newReminderInterval
                } else {
                    // If no suitable reminder interval found, set to 1 hour
                    state.reminderInterval = 3600
                }
            }

            return .none

        case let .reminderIntervalSelected(interval):
            // Ensure reminder interval is less than check-in interval
            if interval < state.checkInInterval {
                state.reminderInterval = interval
            }
            return .none

        case .saveButtonTapped:
            return .send(.delegate(.intervalsSelected(
                checkInInterval: state.checkInInterval,
                reminderInterval: state.reminderInterval
            )))

        case .cancelButtonTapped:
            return .send(.delegate(.cancelled))
        }
    }
}
```

## Feature Composition

The safety features are composed in a hierarchical structure:

```
HomeFeature
├── CheckInFeature
│   └── IntervalSelectionFeature
└── AlertFeature

PingFeature (can be accessed from multiple places)
```

This composition allows for a modular application structure where features can be developed, tested, and maintained independently.

## Feature Dependencies

The safety features depend on the following clients:

- **CheckInClient**: For check-in operations
- **AlertClient**: For alert operations
- **PingClient**: For ping operations
- **UserClient**: For user profile operations
- **NotificationClient**: For notification operations

These clients are injected using TCA's dependency injection system.
