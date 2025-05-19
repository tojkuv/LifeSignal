# RespondersFeature State

**Navigation:** [Back to RespondersFeature](README.md) | [Actions](Actions.md) | [Effects](Effects.md)

---

## Overview

This document provides detailed information about the state of the RespondersFeature in the LifeSignal iOS application. The state represents the current condition of the responders functionality, including the list of responders, UI state, and child feature states.

## State Definition

```swift
@ObservableState
struct State: Equatable, Sendable {
    /// Parent contacts feature state
    var contacts: ContactsFeature.State = .init()

    /// UI State
    var isLoading: Bool = false
    var error: UserFacingError? = nil
    
    /// Alert states
    var alerts: AlertState = .init()
    
    /// Child feature states
    var contactDetails: ContactDetailsSheetViewFeature.State = .init()
    var qrScanner: QRScannerFeature.State = .init()
    var addContact: AddContactFeature.State = .init()
    
    /// Alert state structure
    struct AlertState: Equatable, Sendable {
        var contactAdded: Bool = false
        var contactExists: Bool = false
        var contactError: Bool = false
    }
    
    /// Computed properties
    var pendingPingsCount: Int {
        contacts.responders.filter { $0.hasPendingPing }.count
    }
}
```

## State Properties

### Parent State

#### `contacts: ContactsFeature.State`

The state of the parent ContactsFeature, which contains the list of all contacts including responders. This is the source of truth for contact data.

### UI State

#### `isLoading: Bool`

A boolean indicating whether the feature is currently loading data. When true, UI elements should show loading indicators and disable user interaction.

#### `error: UserFacingError?`

An optional error that should be displayed to the user. When non-nil, an error alert should be shown.

### Alert States

#### `alerts: AlertState`

A structure containing boolean flags for different alert states:

- `contactAdded: Bool` - Whether to show the "Contact Added" alert
- `contactExists: Bool` - Whether to show the "Contact Already Exists" alert
- `contactError: Bool` - Whether to show the "Contact Error" alert

### Child Feature States

#### `contactDetails: ContactDetailsSheetViewFeature.State`

The state of the ContactDetailsSheetViewFeature, which is used to display and manage responder details.

#### `qrScanner: QRScannerFeature.State`

The state of the QRScannerFeature, which is used to scan QR codes to add new responders.

#### `addContact: AddContactFeature.State`

The state of the AddContactFeature, which is used to add new responders.

### Computed Properties

#### `pendingPingsCount: Int`

The number of responders who have pending pings that need to be responded to. This is used to display a badge on the responders tab.

## State Updates

The state is updated in response to actions dispatched to the feature's reducer. For detailed information on how the state is updated, see the [Actions](Actions.md) and [Effects](Effects.md) documents.

## State Persistence

The core state properties are persisted as follows:

- Contact data is stored in the backend and cached locally
- UI state is not persisted and only exists in memory
- Alert states are not persisted and only exist in memory
- Child feature states are managed by their respective features

## State Access

The state is accessed by the feature's view and by parent features that include the RespondersFeature as a child feature.

Example of a parent feature accessing the RespondersFeature state:

```swift
@Reducer
struct ContactsFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var responders: RespondersFeature.State = .init()
        var dependents: DependentsFeature.State = .init()
        // Other state...
    }
    
    enum Action: Equatable, Sendable {
        case responders(RespondersFeature.Action)
        case dependents(DependentsFeature.Action)
        // Other actions...
    }
    
    var body: some ReducerOf<Self> {
        Scope(state: \.responders, action: \.responders) {
            RespondersFeature()
        }
        
        Scope(state: \.dependents, action: \.dependents) {
            DependentsFeature()
        }
        
        Reduce { state, action in
            // Handle ContactsFeature-specific actions
            return .none
        }
    }
}
```

## Best Practices

When working with the RespondersFeature state, follow these best practices:

1. **Single Source of Truth** - Use the parent ContactsFeature state as the source of truth for contact data
2. **Immutable Updates** - Always update state immutably through actions
3. **Computed Properties** - Use computed properties for derived state
4. **Child Feature Composition** - Use child features for complex functionality
5. **Error Handling** - Use the error property for user-facing errors
