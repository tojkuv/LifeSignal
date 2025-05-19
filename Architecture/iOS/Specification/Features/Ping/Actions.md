# PingFeature Actions

**Navigation:** [Back to PingFeature](README.md) | [State](State.md) | [Effects](Effects.md)

---

## Overview

This document provides detailed information about the actions of the PingFeature in the LifeSignal iOS application. Actions represent the events that can occur in the feature, including user interactions, system events, and responses from external dependencies.

## Action Definition

```swift
@CasePathable
enum Action: Equatable, Sendable {
    // MARK: - Lifecycle Actions
    case onAppear
    
    // MARK: - Data Actions
    case loadPings
    case pingsResponse(TaskResult<(pending: [PingData], history: [PingData])>)
    
    // MARK: - Ping Actions
    case pingDependent(id: String)
    case pingDependentSucceeded(String)
    case pingDependentFailed(UserFacingError)
    
    case respondToPing(id: String)
    case pingResponseSucceeded(String)
    case pingResponseFailed(UserFacingError)
    
    case respondToAllPings
    case allPingResponsesSucceeded
    case allPingResponsesFailed(UserFacingError)
    
    case clearPing(id: String)
    case clearPingSucceeded(String)
    case clearPingFailed(UserFacingError)
    
    // MARK: - UI Actions
    case setPingSheetPresented(Bool)
    case selectPing(PingData?)
    case setError(UserFacingError?)
    
    // MARK: - Delegate Actions
    case delegate(DelegateAction)
    
    enum DelegateAction: Equatable, Sendable {
        case pingsUpdated
        case pingAdded(PingData)
        case pingResponded(String)
        case pingCleared(String)
    }
}
```

## Action Categories

### Lifecycle Actions

These actions are triggered by the view's lifecycle events:

#### `onAppear`

Triggered when the view appears. Used to initialize the feature and load data.

**Effect:**
- Loads pings if they haven't been loaded yet

**Example:**
```swift
case .onAppear:
    if state.pendingPings.isEmpty && state.pingHistory.isEmpty && !state.isLoading {
        return .send(.loadPings)
    }
    return .none
```

### Data Actions

These actions are related to loading ping data:

#### `loadPings`

Triggered to load pings from the backend.

**Effect:**
- Sets the loading state to true
- Calls the ping client to load pings
- Dispatches a response action with the result

**Example:**
```swift
case .loadPings:
    state.isLoading = true
    return .run { send in
        do {
            let pendingPings = try await pingClient.getPendingPings()
            let pingHistory = try await pingClient.getPingHistory()
            await send(.pingsResponse(.success((pending: pendingPings, history: pingHistory))))
        } catch {
            await send(.pingsResponse(.failure(error as? UserFacingError ?? .unknown)))
        }
    }
```

#### `pingsResponse(TaskResult<(pending: [PingData], history: [PingData])>)`

Triggered when the ping loading operation completes.

**Effect:**
- Sets the loading state to false
- Updates the pending pings and ping history arrays or sets an error

**Example:**
```swift
case let .pingsResponse(.success(pings)):
    state.isLoading = false
    state.pendingPings = pings.pending
    state.pingHistory = pings.history
    return .none
    
case let .pingsResponse(.failure(error)):
    state.isLoading = false
    state.error = error
    return .none
```

### Ping Actions

These actions are related to ping operations:

#### `pingDependent(id: String)`

Triggered when a responder pings a dependent.

**Effect:**
- Calls the ping client to ping the dependent
- Dispatches a success or failure action based on the result

**Example:**
```swift
case let .pingDependent(id):
    return .run { send in
        do {
            let ping = try await pingClient.pingDependent(id)
            await send(.pingDependentSucceeded(id))
            await send(.delegate(.pingAdded(ping)))
        } catch {
            await send(.pingDependentFailed(error as? UserFacingError ?? .unknown))
        }
    }
```

#### `pingDependentSucceeded(String)`

Triggered when the ping dependent operation succeeds.

**Effect:**
- No direct state changes, but may trigger UI updates

**Example:**
```swift
case let .pingDependentSucceeded(id):
    // No direct state changes, but may trigger UI updates
    return .none
```

#### `pingDependentFailed(UserFacingError)`

Triggered when the ping dependent operation fails.

**Effect:**
- Sets an error to be displayed to the user

**Example:**
```swift
case let .pingDependentFailed(error):
    state.error = error
    return .none
```

#### `respondToPing(id: String)`

Triggered when a user responds to a ping.

**Effect:**
- Calls the ping client to respond to the ping
- Dispatches a success or failure action based on the result

**Example:**
```swift
case let .respondToPing(id):
    return .run { send in
        do {
            try await pingClient.respondToPing(id)
            await send(.pingResponseSucceeded(id))
            await send(.delegate(.pingResponded(id)))
        } catch {
            await send(.pingResponseFailed(error as? UserFacingError ?? .unknown))
        }
    }
```

#### `pingResponseSucceeded(String)`

Triggered when the ping response operation succeeds.

**Effect:**
- Updates the ping status in the state
- Moves the ping from pending to history

**Example:**
```swift
case let .pingResponseSucceeded(id):
    if let index = state.pendingPings.firstIndex(where: { $0.id == id }) {
        var ping = state.pendingPings[index]
        ping.status = .responded
        ping.responseTimestamp = Date()
        state.pendingPings.remove(at: index)
        state.pingHistory.append(ping)
    }
    return .none
```

#### `pingResponseFailed(UserFacingError)`

Triggered when the ping response operation fails.

**Effect:**
- Sets an error to be displayed to the user

**Example:**
```swift
case let .pingResponseFailed(error):
    state.error = error
    return .none
```

#### `respondToAllPings`

Triggered when a user responds to all pending pings.

**Effect:**
- Calls the ping client to respond to all pings
- Dispatches a success or failure action based on the result

**Example:**
```swift
case .respondToAllPings:
    return .run { send in
        do {
            try await pingClient.respondToAllPings()
            await send(.allPingResponsesSucceeded)
        } catch {
            await send(.allPingResponsesFailed(error as? UserFacingError ?? .unknown))
        }
    }
```

#### `allPingResponsesSucceeded`

Triggered when the respond to all pings operation succeeds.

**Effect:**
- Updates all pending pings to responded status
- Moves all pending pings to history

**Example:**
```swift
case .allPingResponsesSucceeded:
    let now = Date()
    let respondedPings = state.pendingPings.map { ping in
        var updatedPing = ping
        updatedPing.status = .responded
        updatedPing.responseTimestamp = now
        return updatedPing
    }
    
    state.pingHistory.append(contentsOf: respondedPings)
    state.pendingPings = []
    
    return .run { send in
        for ping in respondedPings {
            await send(.delegate(.pingResponded(ping.id)))
        }
    }
```

#### `allPingResponsesFailed(UserFacingError)`

Triggered when the respond to all pings operation fails.

**Effect:**
- Sets an error to be displayed to the user

**Example:**
```swift
case let .allPingResponsesFailed(error):
    state.error = error
    return .none
```

#### `clearPing(id: String)`

Triggered when a responder clears a ping.

**Effect:**
- Calls the ping client to clear the ping
- Dispatches a success or failure action based on the result

**Example:**
```swift
case let .clearPing(id):
    return .run { send in
        do {
            try await pingClient.clearPing(id)
            await send(.clearPingSucceeded(id))
            await send(.delegate(.pingCleared(id)))
        } catch {
            await send(.clearPingFailed(error as? UserFacingError ?? .unknown))
        }
    }
```

#### `clearPingSucceeded(String)`

Triggered when the clear ping operation succeeds.

**Effect:**
- Updates the ping status in the state
- Moves the ping from pending to history if it was pending

**Example:**
```swift
case let .clearPingSucceeded(id):
    // Check if the ping is in pending pings
    if let index = state.pendingPings.firstIndex(where: { $0.id == id }) {
        var ping = state.pendingPings[index]
        ping.status = .cleared
        state.pendingPings.remove(at: index)
        state.pingHistory.append(ping)
    }
    
    // Check if the ping is in history
    if let index = state.pingHistory.firstIndex(where: { $0.id == id }) {
        state.pingHistory[index].status = .cleared
    }
    
    return .none
```

#### `clearPingFailed(UserFacingError)`

Triggered when the clear ping operation fails.

**Effect:**
- Sets an error to be displayed to the user

**Example:**
```swift
case let .clearPingFailed(error):
    state.error = error
    return .none
```

### UI Actions

These actions are triggered by user interactions with the UI:

#### `setPingSheetPresented(Bool)`

Triggered when the user opens or closes the ping details sheet.

**Effect:**
- Updates the ping sheet presented state

**Example:**
```swift
case let .setPingSheetPresented(isPresented):
    state.isPingSheetPresented = isPresented
    if !isPresented {
        state.selectedPing = nil
    }
    return .none
```

#### `selectPing(PingData?)`

Triggered when the user selects a ping to view details.

**Effect:**
- Updates the selected ping
- Opens the ping details sheet

**Example:**
```swift
case let .selectPing(ping):
    state.selectedPing = ping
    if ping != nil {
        state.isPingSheetPresented = true
    }
    return .none
```

#### `setError(UserFacingError?)`

Triggered to set an error to be displayed to the user.

**Effect:**
- Updates the error state

**Example:**
```swift
case let .setError(error):
    state.error = error
    return .none
```

### Delegate Actions

These actions are used to communicate with other features:

#### `delegate(DelegateAction)`

Actions that should be handled by the delegate.

**Effect:**
- Depends on the specific delegate action

**Example:**
```swift
case .delegate:
    return .none
```

#### `DelegateAction.pingsUpdated`

Notifies the delegate that pings have been updated.

**Effect:**
- Depends on the delegate implementation

#### `DelegateAction.pingAdded(PingData)`

Notifies the delegate that a ping has been added.

**Effect:**
- Depends on the delegate implementation

#### `DelegateAction.pingResponded(String)`

Notifies the delegate that a ping has been responded to.

**Effect:**
- Depends on the delegate implementation

#### `DelegateAction.pingCleared(String)`

Notifies the delegate that a ping has been cleared.

**Effect:**
- Depends on the delegate implementation

## Action Flow

The typical flow of actions in the PingFeature is as follows:

1. **Initialization**
   - `.onAppear` is dispatched when the view appears
   - This triggers loading of pings if needed

2. **Ping Dependent**
   - User taps "Ping" on a non-responsive dependent, dispatching `.pingDependent`
   - This sends a ping to the dependent
   - On success, `.pingDependentSucceeded` is dispatched
   - On failure, `.pingDependentFailed` is dispatched

3. **Respond to Ping**
   - User taps "Respond" on a ping, dispatching `.respondToPing`
   - This marks the ping as responded
   - On success, `.pingResponseSucceeded` is dispatched
   - On failure, `.pingResponseFailed` is dispatched

4. **Respond to All Pings**
   - User taps "Respond to All" button, dispatching `.respondToAllPings`
   - This marks all pending pings as responded
   - On success, `.allPingResponsesSucceeded` is dispatched
   - On failure, `.allPingResponsesFailed` is dispatched

5. **Clear Ping**
   - User taps "Clear Ping" on a ping, dispatching `.clearPing`
   - This clears the ping
   - On success, `.clearPingSucceeded` is dispatched
   - On failure, `.clearPingFailed` is dispatched

6. **View Ping Details**
   - User taps on a ping, dispatching `.selectPing`
   - This shows the ping details sheet

7. **Error Handling**
   - If an error occurs, `.setError` is dispatched
   - This shows an error alert to the user

## Best Practices

When working with PingFeature actions, follow these best practices:

1. **Action Naming** - Use clear, descriptive names for actions
2. **Action Organization** - Group related actions together
3. **Action Documentation** - Document the purpose and effect of each action
4. **Action Testing** - Test each action and its effect on the state
5. **Action Composition** - Use delegate actions for feature communication
