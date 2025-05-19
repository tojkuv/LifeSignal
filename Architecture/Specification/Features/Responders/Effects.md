# RespondersFeature Effects

**Navigation:** [Back to RespondersFeature](README.md) | [State](State.md) | [Actions](Actions.md)

---

## Overview

This document provides detailed information about the effects of the RespondersFeature in the LifeSignal iOS application. Effects represent the side effects that occur in response to actions, such as API calls, timers, and other asynchronous operations.

## Effect Types

The RespondersFeature uses the following types of effects:

1. **API Effects** - Effects that interact with external services through clients
2. **Navigation Effects** - Effects that handle navigation between screens
3. **Presentation Effects** - Effects that handle presentations such as alerts and sheets

## Dependencies

The RespondersFeature depends on the following clients for its effects:

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
            if state.contacts.responders.isEmpty && !state.isLoading {
                state.isLoading = true
                return .run { send in
                    await send(.contacts(.loadContacts))
                }
            }
            return .none
            
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

The RespondersFeature interacts with the following APIs:

### Load Contacts

Loads the user's contacts from the backend:

```swift
case .onAppear:
    if state.contacts.responders.isEmpty && !state.isLoading {
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

### Respond to Ping

Responds to a ping from a responder:

```swift
case let .ping(.respondToPing(id)):
    return .run { send in
        do {
            try await pingClient.respondToPing(id)
            await send(.ping(.pingResponseSucceeded(id)))
        } catch {
            await send(.ping(.pingResponseFailed(error as? UserFacingError ?? .unknown)))
        }
    }
```

This effect:
1. Calls the `respondToPing` method on the pingClient
2. Dispatches a success or failure action based on the result

### Respond to All Pings

Responds to all pending pings:

```swift
case .ping(.respondToAllPings):
    return .run { send in
        do {
            try await pingClient.respondToAllPings()
            await send(.ping(.allPingResponsesSucceeded))
        } catch {
            await send(.ping(.allPingResponsesFailed(error as? UserFacingError ?? .unknown)))
        }
    }
```

This effect:
1. Calls the `respondToAllPings` method on the pingClient
2. Dispatches a success or failure action based on the result

## Navigation Effects

The RespondersFeature handles navigation through the following effects:

### Show Contact Details

Shows the contact details sheet for a selected responder:

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

Shows the QR scanner for adding a new responder:

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

## Presentation Effects

The RespondersFeature handles presentations through the following effects:

### Show Contact Added Alert

Shows an alert when a contact is added:

```swift
case .addContact(.contactAdded(let isResponder, _)):
    // When a contact is added, close the sheet and show confirmation
    state.addContact.isSheetPresented = false

    // Only show the "Contact Added" alert if the contact was added as a responder
    if isResponder {
        state.alerts.contactAdded = true
    }

    return .none
```

This effect:
1. Closes the add contact sheet
2. Sets the contact added alert to be shown if the contact was added as a responder

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

The RespondersFeature cancels effects in the following situations:

### Cancel API Calls

API calls are cancelled when the feature is deinitialized or when a new API call of the same type is made:

```swift
case .onAppear:
    if state.contacts.responders.isEmpty && !state.isLoading {
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

The RespondersFeature composes effects with child features:

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

When working with RespondersFeature effects, follow these best practices:

1. **Effect Organization** - Group related effects together
2. **Effect Documentation** - Document the purpose and behavior of each effect
3. **Effect Testing** - Test each effect and its interaction with dependencies
4. **Effect Cancellation** - Use cancellation IDs for cancellable effects
5. **Effect Composition** - Use parent and child effects for feature composition
6. **Error Handling** - Handle errors consistently and provide user-friendly error messages
