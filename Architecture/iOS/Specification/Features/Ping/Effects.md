# PingFeature Effects

**Navigation:** [Back to PingFeature](README.md) | [State](State.md) | [Actions](Actions.md)

---

## Overview

This document provides detailed information about the effects of the PingFeature in the LifeSignal iOS application. Effects represent the side effects that occur in response to actions, such as API calls, timers, and other asynchronous operations.

## Effect Types

The PingFeature uses the following types of effects:

1. **API Effects** - Effects that interact with external services through clients
2. **Delegate Effects** - Effects that communicate with other features through delegates

## Dependencies

The PingFeature depends on the following clients for its effects:

```swift
@Dependency(\.pingClient) var pingClient
@Dependency(\.userClient) var userClient
@Dependency(\.contactClient) var contactClient
```

## Effect Implementation

The effects are implemented in the feature's reducer:

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case .onAppear:
            if state.pendingPings.isEmpty && state.pingHistory.isEmpty && !state.isLoading {
                return .send(.loadPings)
            }
            return .none
            
        // Other action handlers...
        }
    }
}
```

## API Effects

The PingFeature interacts with the following APIs:

### Load Pings

Loads pending pings and ping history from the backend:

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
    .cancellable(id: CancellationID.loadPings)
```

This effect:
1. Sets the loading state to true
2. Calls the `getPendingPings` and `getPingHistory` methods on the pingClient
3. Dispatches a success or failure action based on the result
4. Can be cancelled using the `loadPings` cancellation ID

### Ping Dependent

Sends a ping to a dependent:

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

This effect:
1. Calls the `pingDependent` method on the pingClient
2. Dispatches a success action with the dependent ID if successful
3. Dispatches a delegate action to notify other features of the new ping
4. Dispatches a failure action with the error if unsuccessful

### Respond to Ping

Responds to a ping:

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

This effect:
1. Calls the `respondToPing` method on the pingClient
2. Dispatches a success action with the ping ID if successful
3. Dispatches a delegate action to notify other features of the response
4. Dispatches a failure action with the error if unsuccessful

### Respond to All Pings

Responds to all pending pings:

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

This effect:
1. Calls the `respondToAllPings` method on the pingClient
2. Dispatches a success action if successful
3. Dispatches a failure action with the error if unsuccessful

### Clear Ping

Clears a ping:

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

This effect:
1. Calls the `clearPing` method on the pingClient
2. Dispatches a success action with the ping ID if successful
3. Dispatches a delegate action to notify other features of the cleared ping
4. Dispatches a failure action with the error if unsuccessful

## Delegate Effects

The PingFeature communicates with other features through delegate effects:

### Ping Added

Notifies other features that a ping has been added:

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

This effect:
1. Dispatches a delegate action with the new ping data
2. Other features can listen for this action to update their state

### Ping Responded

Notifies other features that a ping has been responded to:

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

This effect:
1. Dispatches a delegate action with the ping ID
2. Other features can listen for this action to update their state

### Ping Cleared

Notifies other features that a ping has been cleared:

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

This effect:
1. Dispatches a delegate action with the ping ID
2. Other features can listen for this action to update their state

### Pings Updated

Notifies other features that pings have been updated:

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
        
        await send(.delegate(.pingsUpdated))
    }
```

This effect:
1. Dispatches a delegate action to notify other features that pings have been updated
2. Other features can listen for this action to refresh their state

## Effect Cancellation

The PingFeature cancels effects in the following situations:

### Cancel API Calls

API calls are cancelled when the feature is deinitialized or when a new API call of the same type is made:

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
    .cancellable(id: CancellationID.loadPings)
```

This effect:
1. Assigns a cancellation ID to the effect
2. The effect will be cancelled if a new effect with the same ID is created
3. The effect will also be cancelled if the feature is deinitialized

## Effect Composition

The PingFeature composes effects by chaining them together:

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
        
        await send(.delegate(.pingsUpdated))
    }
```

This composition:
1. Updates the state with the responded pings
2. Dispatches delegate actions for each responded ping
3. Dispatches a delegate action to notify that all pings have been updated

## Best Practices

When working with PingFeature effects, follow these best practices:

1. **Effect Organization** - Group related effects together
2. **Effect Documentation** - Document the purpose and behavior of each effect
3. **Effect Testing** - Test each effect and its interaction with dependencies
4. **Effect Cancellation** - Use cancellation IDs for cancellable effects
5. **Effect Composition** - Chain effects together for complex operations
6. **Error Handling** - Handle errors consistently and provide user-friendly error messages
7. **Delegate Communication** - Use delegate actions to communicate with other features
