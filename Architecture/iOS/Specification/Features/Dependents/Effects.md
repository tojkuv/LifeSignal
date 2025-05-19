# DependentsFeature Effects

**Navigation:** [Back to DependentsFeature](README.md) | [State](State.md) | [Actions](Actions.md)

---

## Overview

This document provides detailed information about the effects of the DependentsFeature in the LifeSignal iOS application. Effects represent the side effects that occur in response to actions, such as API calls, timers, and other asynchronous operations.

## Effect Types

The DependentsFeature uses the following types of effects:

1. **API Effects** - Effects that interact with external services through clients
2. **Navigation Effects** - Effects that handle navigation between screens
3. **Presentation Effects** - Effects that handle presentations such as alerts and sheets
4. **Persistence Effects** - Effects that persist data to local storage

## Dependencies

The DependentsFeature depends on the following clients for its effects:

```swift
@Dependency(\.contactClient) var contactClient
@Dependency(\.pingClient) var pingClient
@Dependency(\.userClient) var userClient
```

## Effect Implementation

The effects are implemented in the feature's reducer:

```swift
var body: some ReducerOf<Self> {
    Scope(state: \.contacts, action: \.contacts) {
        ContactsFeature()
    }
    
    Reduce { state, action in
        switch action {
        case .onAppear:
            if state.contacts.dependents.isEmpty && !state.isLoading {
                state.isLoading = true
                return .run { send in
                    await send(.contacts(.loadContacts))
                }
            }
            
            // Load sort option from UserDefaults
            return .run { send in
                if let sortOptionRawValue = await UserDefaults.standard.string(forKey: "DependentsSortOption"),
                   let sortOption = State.SortOption(rawValue: sortOptionRawValue) {
                    await send(.setSortOption(sortOption))
                }
            }
            
        // Other action handlers...
        }
    }
    .ifLet(\.contactDetails, action: \.contactDetails) {
        ContactDetailsSheetViewFeature()
    }
    .ifLet(\.qrScanner, action: \.qrScanner) {
        QRScannerFeature()
    }
    .ifLet(\.addContact, action: \.addContact) {
        AddContactFeature()
    }
}
```

## API Effects

The DependentsFeature interacts with the following APIs:

### Load Contacts

Loads the user's contacts from the backend:

```swift
case .onAppear:
    if state.contacts.dependents.isEmpty && !state.isLoading {
        state.isLoading = true
        return .run { send in
            await send(.contacts(.loadContacts))
        }
    }
    return .none
```

This effect:
1. Checks if contacts need to be loaded
2. Sets the loading state to true
3. Dispatches the `loadContacts` action to the parent ContactsFeature
4. The parent feature handles the actual API call

### Ping Dependent

Sends a ping to a non-responsive dependent:

```swift
case let .ping(.pingDependent(id)):
    return .run { send in
        do {
            try await pingClient.pingDependent(id)
            await send(.ping(.pingDependentSucceeded(id)))
        } catch {
            await send(.ping(.pingDependentFailed(error as? UserFacingError ?? .unknown)))
        }
    }
```

This effect:
1. Calls the `pingDependent` method on the pingClient
2. Dispatches a success or failure action based on the result

### Clear Ping

Clears a ping that has been sent to a dependent:

```swift
case let .ping(.clearPing(id)):
    return .run { send in
        do {
            try await pingClient.clearPing(id)
            await send(.ping(.clearPingSucceeded(id)))
        } catch {
            await send(.ping(.clearPingFailed(error as? UserFacingError ?? .unknown)))
        }
    }
```

This effect:
1. Calls the `clearPing` method on the pingClient
2. Dispatches a success or failure action based on the result

## Navigation Effects

The DependentsFeature handles navigation through the following effects:

### Show Contact Details

Shows the contact details sheet for a selected dependent:

```swift
case let .selectContact(contact):
    state.contactDetails = ContactDetailsSheetViewFeature.State(
        contact: contact,
        isSheetPresented: true
    )
    return .none
```

This effect:
1. Creates a new state for the ContactDetailsSheetViewFeature
2. Sets the selected contact
3. Sets the sheet to be presented

### Show QR Scanner

Shows the QR scanner for adding a new dependent:

```swift
case .showQRScanner:
    state.qrScanner = QRScannerFeature.State(
        isSheetPresented: true
    )
    return .none
```

This effect:
1. Creates a new state for the QRScannerFeature
2. Sets the sheet to be presented

## Persistence Effects

The DependentsFeature persists data through the following effects:

### Save Sort Option

Saves the sort option to UserDefaults:

```swift
case let .setSortOption(option):
    state.sortOption = option
    return .run { _ in
        await UserDefaults.standard.set(option.rawValue, forKey: "DependentsSortOption")
    }
```

This effect:
1. Updates the sort option in the state
2. Persists the sort option to UserDefaults

### Load Sort Option

Loads the sort option from UserDefaults:

```swift
case .onAppear:
    // Other effects...
    
    // Load sort option from UserDefaults
    return .run { send in
        if let sortOptionRawValue = await UserDefaults.standard.string(forKey: "DependentsSortOption"),
           let sortOption = State.SortOption(rawValue: sortOptionRawValue) {
            await send(.setSortOption(sortOption))
        }
    }
```

This effect:
1. Retrieves the sort option from UserDefaults
2. Dispatches the `setSortOption` action if a valid sort option is found

## Presentation Effects

The DependentsFeature handles presentations through the following effects:

### Show Error Alert

Shows an alert when an error occurs:

```swift
case let .setError(error):
    state.error = error
    return .none
```

This effect:
1. Sets the error state
2. The view will show an alert based on this state

## Effect Cancellation

The DependentsFeature cancels effects in the following situations:

### Cancel API Calls

API calls are cancelled when the feature is deinitialized or when a new API call of the same type is made:

```swift
case .onAppear:
    if state.contacts.dependents.isEmpty && !state.isLoading {
        state.isLoading = true
        return .run { send in
            await send(.contacts(.loadContacts))
        }
        .cancellable(id: CancellationID.loadContacts)
    }
    return .none
```

This effect:
1. Assigns a cancellation ID to the effect
2. The effect will be cancelled if a new effect with the same ID is created
3. The effect will also be cancelled if the feature is deinitialized

## Effect Composition

The DependentsFeature composes effects with child features:

```swift
var body: some ReducerOf<Self> {
    Scope(state: \.contacts, action: \.contacts) {
        ContactsFeature()
    }
    
    Reduce { state, action in
        // Action handlers...
    }
    .ifLet(\.contactDetails, action: \.contactDetails) {
        ContactDetailsSheetViewFeature()
    }
    .ifLet(\.qrScanner, action: \.qrScanner) {
        QRScannerFeature()
    }
    .ifLet(\.addContact, action: \.addContact) {
        AddContactFeature()
    }
}
```

This composition:
1. Scopes the ContactsFeature to handle contact-related actions
2. Uses the `ifLet` operator to conditionally include child features
3. Child features handle their own effects

## Best Practices

When working with DependentsFeature effects, follow these best practices:

1. **Effect Organization** - Group related effects together
2. **Effect Documentation** - Document the purpose and behavior of each effect
3. **Effect Testing** - Test each effect and its interaction with dependencies
4. **Effect Cancellation** - Use cancellation IDs for cancellable effects
5. **Effect Composition** - Use parent and child effects for feature composition
6. **Error Handling** - Handle errors consistently and provide user-friendly error messages
