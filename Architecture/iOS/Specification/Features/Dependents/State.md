# DependentsFeature State

**Navigation:** [Back to DependentsFeature](README.md) | [Actions](Actions.md) | [Effects](Effects.md)

---

## Overview

This document provides detailed information about the state of the DependentsFeature in the LifeSignal iOS application. The state represents the current condition of the dependents functionality, including the list of dependents, UI state, and child feature states.

## State Definition

```swift
@ObservableState
struct State: Equatable, Sendable {
    /// Parent contacts feature state
    var contacts: ContactsFeature.State = .init()

    /// UI State
    var isLoading: Bool = false
    var error: UserFacingError? = nil
    
    /// Sorting options
    var sortOption: SortOption = .timeLeft
    
    /// Child feature states
    var contactDetails: ContactDetailsSheetViewFeature.State = .init()
    var qrScanner: QRScannerFeature.State = .init()
    var addContact: AddContactFeature.State = .init()
    
    /// Sort options for dependents
    enum SortOption: String, CaseIterable, Equatable, Sendable {
        case timeLeft = "Time Left"
        case name = "Name"
        case dateAdded = "Date Added"
    }
    
    /// Computed properties
    var nonResponsiveDependentsCount: Int {
        contacts.dependents.filter { $0.isNonResponsive || $0.manualAlertActive }.count
    }
}
```

## State Properties

### Parent State

#### `contacts: ContactsFeature.State`

The state of the parent ContactsFeature, which contains the list of all contacts including dependents. This is the source of truth for contact data.

### UI State

#### `isLoading: Bool`

A boolean indicating whether the feature is currently loading data. When true, UI elements should show loading indicators and disable user interaction.

#### `error: UserFacingError?`

An optional error that should be displayed to the user. When non-nil, an error alert should be shown.

### Sorting Options

#### `sortOption: SortOption`

The current sorting option for the dependents list. Can be one of:
- `.timeLeft` - Sort by time remaining until check-in
- `.name` - Sort alphabetically by name
- `.dateAdded` - Sort by the date the dependent was added

### Child Feature States

#### `contactDetails: ContactDetailsSheetViewFeature.State`

The state of the ContactDetailsSheetViewFeature, which is used to display and manage dependent details.

#### `qrScanner: QRScannerFeature.State`

The state of the QRScannerFeature, which is used to scan QR codes to add new dependents.

#### `addContact: AddContactFeature.State`

The state of the AddContactFeature, which is used to add new dependents.

### Computed Properties

#### `nonResponsiveDependentsCount: Int`

The number of dependents who are non-responsive or have an active alert. This is used to display a badge on the dependents tab.

## State Updates

The state is updated in response to actions dispatched to the feature's reducer. For detailed information on how the state is updated, see the [Actions](Actions.md) and [Effects](Effects.md) documents.

## State Persistence

The core state properties are persisted as follows:

- Contact data is stored in the backend and cached locally
- Sort option is stored in UserDefaults
- UI state is not persisted and only exists in memory
- Child feature states are managed by their respective features

## State Access

The state is accessed by the feature's view and by parent features that include the DependentsFeature as a child feature.

Example of a parent feature accessing the DependentsFeature state:

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

## Derived State

The DependentsFeature uses derived state to present the dependents list in different ways:

```swift
var sortedDependents: [ContactData] {
    switch sortOption {
    case .timeLeft:
        return contacts.dependents.sorted { 
            ($0.isNonResponsive ? 0 : $0.timeRemaining ?? Double.infinity) < 
            ($1.isNonResponsive ? 0 : $1.timeRemaining ?? Double.infinity)
        }
    case .name:
        return contacts.dependents.sorted { $0.name < $1.name }
    case .dateAdded:
        return contacts.dependents.sorted { 
            $0.dateAdded ?? Date.distantPast > $1.dateAdded ?? Date.distantPast 
        }
    }
}
```

This derived state:
1. Sorts dependents based on the current sort option
2. For time left sorting, non-responsive dependents are shown first
3. For name sorting, dependents are sorted alphabetically
4. For date added sorting, most recently added dependents are shown first

## Best Practices

When working with the DependentsFeature state, follow these best practices:

1. **Single Source of Truth** - Use the parent ContactsFeature state as the source of truth for contact data
2. **Immutable Updates** - Always update state immutably through actions
3. **Computed Properties** - Use computed properties for derived state
4. **Child Feature Composition** - Use child features for complex functionality
5. **Error Handling** - Use the error property for user-facing errors
