# RespondersFeature Actions

**Navigation:** [Back to RespondersFeature](README.md) | [State](State.md) | [Effects](Effects.md)

---

## Overview

This document provides detailed information about the actions of the RespondersFeature in the LifeSignal iOS application. Actions represent the events that can occur in the feature, including user interactions, system events, and responses from external dependencies.

## Action Definition

```swift
@CasePathable
enum Action: Equatable, Sendable {
    // MARK: - Lifecycle Actions
    case onAppear

    // MARK: - Parent Feature Actions
    case contacts(ContactsFeature.Action)
    case ping(PingFeature.Action)

    // MARK: - UI Actions
    case setContactAddedAlert(Bool)
    case setContactExistsAlert(Bool)
    case setContactErrorAlert(Bool)
    case setError(UserFacingError?)

    // MARK: - Child Feature Actions
    case contactDetails(ContactDetailsSheetViewFeature.Action)
    case qrScanner(QRScannerFeature.Action)
    case addContact(AddContactFeature.Action)

    // MARK: - Delegate Actions
    case delegate(DelegateAction)

    enum DelegateAction: Equatable, Sendable {
        case contactsUpdated
    }
}
```

## Action Categories

### Lifecycle Actions

These actions are triggered by the view's lifecycle events:

#### `onAppear`

Triggered when the view appears. Used to initialize the feature and load data.

**Effect:**
- Loads responder contacts if they haven't been loaded yet

**Example:**
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

### Parent Feature Actions

These actions are forwarded to parent features:

#### `contacts(ContactsFeature.Action)`

Actions that should be handled by the parent ContactsFeature.

**Effect:**
- Forwarded to the parent feature

**Example:**
```swift
case .contacts:
    // Forward to parent feature
    return .none
```

#### `ping(PingFeature.Action)`

Actions related to ping functionality that should be handled by the PingFeature.

**Effect:**
- Forwarded to the PingFeature

**Example:**
```swift
case .ping:
    // Forward to PingFeature
    return .none
```

### UI Actions

These actions are triggered by user interactions with the UI:

#### `setContactAddedAlert(Bool)`

Sets whether the "Contact Added" alert should be shown.

**Effect:**
- Updates the `alerts.contactAdded` state

**Example:**
```swift
case let .setContactAddedAlert(isPresented):
    state.alerts.contactAdded = isPresented
    return .none
```

#### `setContactExistsAlert(Bool)`

Sets whether the "Contact Already Exists" alert should be shown.

**Effect:**
- Updates the `alerts.contactExists` state

**Example:**
```swift
case let .setContactExistsAlert(isPresented):
    state.alerts.contactExists = isPresented
    return .none
```

#### `setContactErrorAlert(Bool)`

Sets whether the "Contact Error" alert should be shown.

**Effect:**
- Updates the `alerts.contactError` state

**Example:**
```swift
case let .setContactErrorAlert(isPresented):
    state.alerts.contactError = isPresented
    return .none
```

#### `setError(UserFacingError?)`

Sets the error to be displayed to the user.

**Effect:**
- Updates the `error` state

**Example:**
```swift
case let .setError(error):
    state.error = error
    return .none
```

### Child Feature Actions

These actions are forwarded to child features:

#### `contactDetails(ContactDetailsSheetViewFeature.Action)`

Actions that should be handled by the ContactDetailsSheetViewFeature.

**Effect:**
- Forwarded to the child feature

**Example:**
```swift
case .contactDetails:
    return .none
```

#### `qrScanner(QRScannerFeature.Action)`

Actions that should be handled by the QRScannerFeature.

**Effect:**
- When a QR code is scanned, shows the add contact sheet

**Example:**
```swift
case .qrScanner(.qrCodeScanned):
    // When a QR code is scanned, show the add contact sheet
    state.addContact.isSheetPresented = true
    return .none

case .qrScanner:
    return .none
```

#### `addContact(AddContactFeature.Action)`

Actions that should be handled by the AddContactFeature.

**Effect:**
- When a contact is added, closes the sheet and shows confirmation

**Example:**
```swift
case .addContact(.contactAdded(let isResponder, _)):
    // When a contact is added, close the sheet and show confirmation
    state.addContact.isSheetPresented = false

    // Only show the "Contact Added" alert if the contact was added as a responder
    if isResponder {
        state.alerts.contactAdded = true
    }

    return .none

case .addContact:
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

#### `DelegateAction.contactsUpdated`

Notifies the delegate that contacts have been updated.

**Effect:**
- Depends on the delegate implementation

## Action Flow

The typical flow of actions in the RespondersFeature is as follows:

1. **Initialization**
   - `.onAppear` is dispatched when the view appears
   - This triggers loading of responder contacts if needed

2. **User Interaction**
   - User taps on a responder card, dispatching `.selectContact`
   - This shows the contact details sheet

3. **Adding a Responder**
   - User taps the QR code button, dispatching `.qrScanner(.startScanning)`
   - When a QR code is scanned, `.qrScanner(.qrCodeScanned)` is dispatched
   - This shows the add contact sheet
   - When the contact is added, `.addContact(.contactAdded)` is dispatched
   - This closes the sheet and shows a confirmation alert

4. **Responding to Pings**
   - User taps "Respond" on a ping, dispatching `.ping(.respondToPing)`
   - This marks the ping as responded

5. **Error Handling**
   - If an error occurs, `.setError` is dispatched
   - This shows an error alert to the user

## Best Practices

When working with RespondersFeature actions, follow these best practices:

1. **Action Naming** - Use clear, descriptive names for actions
2. **Action Organization** - Group related actions together
3. **Action Documentation** - Document the purpose and effect of each action
4. **Action Testing** - Test each action and its effect on the state
5. **Action Composition** - Use parent and child actions for feature composition
