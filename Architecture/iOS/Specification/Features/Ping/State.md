# PingFeature State

**Navigation:** [Back to PingFeature](README.md) | [Actions](Actions.md) | [Effects](Effects.md)

---

## Overview

This document provides detailed information about the state of the PingFeature in the LifeSignal iOS application. The state represents the current condition of the ping functionality, including pending pings, ping history, and UI state.

## State Definition

```swift
@ObservableState
struct State: Equatable, Sendable {
    /// Ping data
    var pendingPings: [PingData] = []
    var pingHistory: [PingData] = []
    var isLoading: Bool = false
    var error: UserFacingError? = nil
    
    /// UI state
    var isPingSheetPresented: Bool = false
    var selectedPing: PingData? = nil
    
    /// Computed properties
    var hasPendingPings: Bool {
        !pendingPings.isEmpty
    }
    
    var pendingPingsCount: Int {
        pendingPings.count
    }
}
```

## State Properties

### Ping Data

#### `pendingPings: [PingData]`

An array of ping data objects representing pings that have been received but not yet responded to.

#### `pingHistory: [PingData]`

An array of ping data objects representing the history of pings that have been sent, received, responded to, or cleared.

#### `isLoading: Bool`

A boolean indicating whether the feature is currently loading data. When true, UI elements should show loading indicators.

#### `error: UserFacingError?`

An optional error that should be displayed to the user. When non-nil, an error alert should be shown.

### UI State

#### `isPingSheetPresented: Bool`

A boolean indicating whether the ping details sheet is currently presented.

#### `selectedPing: PingData?`

The currently selected ping for viewing details or taking action.

### Computed Properties

#### `hasPendingPings: Bool`

A boolean indicating whether there are any pending pings that need to be responded to.

#### `pendingPingsCount: Int`

The number of pending pings that need to be responded to. This is used to display a badge on the responders tab.

## Ping Data

The `PingData` type represents a single ping:

```swift
struct PingData: Identifiable, Equatable, Sendable {
    let id: String
    let senderID: String
    let recipientID: String
    let timestamp: Date
    var status: PingStatus
    var responseTimestamp: Date?
    
    // Additional properties
    var senderName: String?
    var recipientName: String?
    var senderProfilePictureURL: URL?
    var recipientProfilePictureURL: URL?
}
```

### Ping Status

The `PingStatus` enum defines the different states a ping can be in:

```swift
enum PingStatus: String, Equatable, Sendable {
    case pending = "Pending"
    case responded = "Responded"
    case cleared = "Cleared"
    case expired = "Expired"
}
```

## State Updates

The state is updated in response to actions dispatched to the feature's reducer. For detailed information on how the state is updated, see the [Actions](Actions.md) and [Effects](Effects.md) documents.

## State Persistence

The core state properties are persisted as follows:

- Ping data is stored in the backend and cached locally
- UI state is not persisted and only exists in memory

## State Access

The state is accessed by the feature's view and by parent features that include the PingFeature as a child feature.

Example of a parent feature accessing the PingFeature state:

```swift
@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var ping: PingFeature.State = .init()
        // Other state...
    }
    
    enum Action: Equatable, Sendable {
        case ping(PingFeature.Action)
        // Other actions...
    }
    
    var body: some ReducerOf<Self> {
        Scope(state: \.ping, action: \.ping) {
            PingFeature()
        }
        
        Reduce { state, action in
            // Handle AppFeature-specific actions
            return .none
        }
    }
}
```

## Derived State

The PingFeature uses derived state to present ping data in different ways:

```swift
var sortedPendingPings: [PingData] {
    pendingPings.sorted { $0.timestamp > $1.timestamp }
}

var sortedPingHistory: [PingData] {
    pingHistory.sorted { $0.timestamp > $1.timestamp }
}

var groupedPingHistory: [Date: [PingData]] {
    Dictionary(grouping: sortedPingHistory) { ping in
        Calendar.current.startOfDay(for: ping.timestamp)
    }
}
```

This derived state:
1. Sorts pending pings by timestamp (most recent first)
2. Sorts ping history by timestamp (most recent first)
3. Groups ping history by day for display in a sectioned list

## Best Practices

When working with the PingFeature state, follow these best practices:

1. **Immutable Updates** - Always update state immutably through actions
2. **Computed Properties** - Use computed properties for derived state
3. **Error Handling** - Use the error property for user-facing errors
4. **Status Management** - Use the PingStatus enum to track the status of pings
5. **Data Consistency** - Ensure that ping data is consistent between the backend and local state
