# DependentsFeature Actions

**Navigation:** [Back to DependentsFeature](README.md) | [State](State.md) | [Effects](Effects.md)

---

## Overview

This document provides detailed information about the actions of the DependentsFeature in the LifeSignal iOS application. Actions represent the events that can occur in the feature, including user interactions, system events, and responses from external dependencies.

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
    case selectContact(ContactData)
    case setSortOption(State.SortOption)
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
- Loads dependent contacts if they haven't been loaded yet

**Example:**
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

#### `selectContact(ContactData)`

Triggered when the user selects a dependent from the list.

**Effect:**
- Shows the contact details sheet for the selected dependent

**Example:**
```swift
case let .selectContact(contact):
    state.contactDetails = ContactDetailsSheetViewFeature.State(
        contact: contact,
        isSheetPresented: true
    )
    return .none
```

#### `setSortOption(State.SortOption)`

Triggered when the user changes the sort option for the dependents list.

**Effect:**
- Updates the sort option and persists it to UserDefaults

**Example:**
```swift
case let .setSortOption(option):
    state.sortOption = option
    return .run { _ in
        await UserDefaults.standard.set(option.rawValue, forKey: "DependentsSortOption")
    }
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
- When a contact is added, closes the sheet

**Example:**
```swift
case .addContact(.contactAdded(_, let isDependent)):
    // When a contact is added, close the sheet
    state.addContact.isSheetPresented = false
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

The typical flow of actions in the DependentsFeature is as follows:

1. **Initialization**
   - `.onAppear` is dispatched when the view appears
   - This triggers loading of dependent contacts if needed

2. **User Interaction**
   - User taps on a dependent card, dispatching `.selectContact`
   - This shows the contact details sheet

3. **Adding a Dependent**
   - User taps the QR code button, dispatching `.qrScanner(.startScanning)`
   - When a QR code is scanned, `.qrScanner(.qrCodeScanned)` is dispatched
   - This shows the add contact sheet
   - When the contact is added, `.addContact(.contactAdded)` is dispatched
   - This closes the sheet

4. **Pinging a Dependent**
   - User taps "Ping" on a non-responsive dependent, dispatching `.ping(.pingDependent)`
   - This sends a ping to the dependent

5. **Clearing a Ping**
   - User taps "Clear Ping" on a pinged dependent, dispatching `.ping(.clearPing)`
   - This clears the ping

6. **Sorting Dependents**
   - User selects a sort option, dispatching `.setSortOption`
   - This updates the sort option and persists it

7. **Error Handling**
   - If an error occurs, `.setError` is dispatched
   - This shows an error alert to the user

## Best Practices

When working with DependentsFeature actions, follow these best practices:

1. **Action Naming** - Use clear, descriptive names for actions
2. **Action Organization** - Group related actions together
3. **Action Documentation** - Document the purpose and effect of each action
4. **Action Testing** - Test each action and its effect on the state
5. **Action Composition** - Use parent and child actions for feature composition
