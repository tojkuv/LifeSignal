# LifeSignal iOS Contact Features

**Navigation:** [Back to Features](README.md) | [Core Features](CoreFeatures.md) | [Safety Features](SafetyFeatures.md) | [Utility Features](UtilityFeatures.md)

---

## Overview

This document provides detailed specifications for the contact features of the LifeSignal iOS application. Contact features manage user relationships, including responders and dependents.

## ContactsFeature

The ContactsFeature is the parent feature that manages the user's contacts and provides navigation to responders and dependents.

### State

```swift
@ObservableState
struct State: Equatable, Sendable {
    var selectedTab: Tab = .responders
    var responders: RespondersFeature.State = .init()
    var dependents: DependentsFeature.State = .init()
    @Shared(.fileStorage(.contacts)) var contacts: IdentifiedArrayOf<Contact> = []
    var isLoading: Bool = false
    var error: UserFacingError?
    
    enum Tab: Equatable, Sendable {
        case responders
        case dependents
    }
}
```

### Action

```swift
enum Action: Equatable, Sendable {
    // Tab selection
    case tabSelected(Tab)
    
    // Child feature actions
    case responders(RespondersFeature.Action)
    case dependents(DependentsFeature.Action)
    
    // Contact management
    case loadContacts
    case contactsLoaded(IdentifiedArrayOf<Contact>)
    case contactsLoadFailed(UserFacingError)
    case streamContactUpdates
    case contactsUpdated(IdentifiedArrayOf<Contact>)
    
    // Error handling
    case setError(UserFacingError?)
    case dismissError
    
    enum Tab: Equatable, Sendable {
        case responders
        case dependents
    }
}
```

### Dependencies

- **ContactClient**: For contact operations

### Responsibilities

- Manages the user's contacts
- Provides navigation between responders and dependents
- Streams contact updates from the server
- Shares contact data with child features

### Implementation Details

The ContactsFeature manages the contacts and provides navigation:

```swift
var body: some ReducerOf<Self> {
    Scope(state: \.responders, action: \.responders) {
        RespondersFeature()
    }
    
    Scope(state: \.dependents, action: \.dependents) {
        DependentsFeature()
    }
    
    Reduce { state, action in
        switch action {
        case let .tabSelected(tab):
            state.selectedTab = tab
            return .none
            
        case .loadContacts:
            state.isLoading = true
            return .run { send in
                do {
                    let contacts = try await contactClient.getContacts()
                    await send(.contactsLoaded(contacts))
                } catch {
                    await send(.contactsLoadFailed(UserFacingError(error)))
                }
            }
            
        case let .contactsLoaded(contacts):
            state.isLoading = false
            state.contacts = contacts
            return .none
            
        case let .contactsLoadFailed(error):
            state.isLoading = false
            state.error = error
            return .none
            
        case .streamContactUpdates:
            return .run { send in
                for await contacts in await contactClient.contactsStream() {
                    await send(.contactsUpdated(contacts))
                }
            }
            .cancellable(id: CancelID.contactsStream)
            
        case let .contactsUpdated(contacts):
            state.contacts = contacts
            return .none
            
        // Error handling...
        
        // Delegate to child features...
        }
    }
}
```

## RespondersFeature

The RespondersFeature manages the user's responders.

### State

```swift
@ObservableState
struct State: Equatable, Sendable {
    @Shared(.fileStorage(.contacts)) var contacts: IdentifiedArrayOf<Contact> = []
    var responders: IdentifiedArrayOf<Contact> { contacts.filter(\.isResponder) }
    var isLoading: Bool = false
    var error: UserFacingError?
    @Presents var destination: Destination.State?
    
    enum Destination: Equatable, Sendable {
        case contactDetails(ContactDetailsFeature.State)
        case qrScanner(QRScannerFeature.State)
    }
}
```

### Action

```swift
enum Action: Equatable, Sendable {
    // Lifecycle actions
    case onAppear
    
    // User actions
    case selectContact(Contact)
    case addContactButtonTapped
    
    // System actions
    case loadResponders
    case respondersLoaded(IdentifiedArrayOf<Contact>)
    case respondersLoadFailed(UserFacingError)
    
    // Navigation actions
    case destination(PresentationAction<Destination.Action>)
    
    // Error handling
    case setError(UserFacingError?)
    case dismissError
    
    enum Destination: Equatable, Sendable {
        case contactDetails(ContactDetailsFeature.Action)
        case qrScanner(QRScannerFeature.Action)
    }
}
```

### Dependencies

- **ContactClient**: For contact operations

### Responsibilities

- Displays the user's responders
- Allows selection of responders for details
- Provides access to QR scanner for adding responders
- Filters contacts to show only responders

### Implementation Details

The RespondersFeature manages the responders:

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case .onAppear:
            return .send(.loadResponders)
            
        case .loadResponders:
            state.isLoading = true
            return .run { send in
                do {
                    let contacts = try await contactClient.getContacts()
                    await send(.respondersLoaded(contacts))
                } catch {
                    await send(.respondersLoadFailed(UserFacingError(error)))
                }
            }
            
        case let .respondersLoaded(contacts):
            state.isLoading = false
            state.contacts = contacts
            return .none
            
        case let .respondersLoadFailed(error):
            state.isLoading = false
            state.error = error
            return .none
            
        case let .selectContact(contact):
            state.destination = .contactDetails(ContactDetailsFeature.State(contact: contact))
            return .none
            
        case .addContactButtonTapped:
            state.destination = .qrScanner(QRScannerFeature.State())
            return .none
            
        // Navigation and error handling...
        }
    }
    .ifLet(\.$destination, action: \.destination)
}
```

## DependentsFeature

The DependentsFeature manages the user's dependents.

### State

```swift
@ObservableState
struct State: Equatable, Sendable {
    @Shared(.fileStorage(.contacts)) var contacts: IdentifiedArrayOf<Contact> = []
    var dependents: IdentifiedArrayOf<Contact> { contacts.filter(\.isDependent) }
    var sortOption: SortOption = .timeLeft
    var isLoading: Bool = false
    var error: UserFacingError?
    @Presents var destination: Destination.State?
    
    enum SortOption: String, Equatable, Sendable, CaseIterable {
        case timeLeft = "Time Left"
        case name = "Name"
        case dateAdded = "Date Added"
    }
    
    enum Destination: Equatable, Sendable {
        case contactDetails(ContactDetailsFeature.State)
        case qrScanner(QRScannerFeature.State)
        case addContact(AddContactFeature.State)
    }
}
```

### Action

```swift
@CasePathable
enum Action: Equatable, Sendable {
    // Lifecycle actions
    case onAppear
    
    // User actions
    case selectContact(Contact)
    case setSortOption(SortOption)
    case addContactButtonTapped
    
    // System actions
    case loadDependents
    case dependentsLoaded(IdentifiedArrayOf<Contact>)
    case dependentsLoadFailed(UserFacingError)
    
    // Navigation actions
    case destination(PresentationAction<Destination.Action>)
    
    // Error handling
    case setError(UserFacingError?)
    case dismissError
    
    // Delegate actions
    case delegate(DelegateAction)
    
    enum DelegateAction: Equatable, Sendable {
        case contactsUpdated
    }
    
    enum Destination: Equatable, Sendable {
        case contactDetails(ContactDetailsFeature.Action)
        case qrScanner(QRScannerFeature.Action)
        case addContact(AddContactFeature.Action)
    }
}
```

### Dependencies

- **ContactClient**: For contact operations

### Responsibilities

- Displays the user's dependents
- Allows selection of dependents for details
- Provides access to QR scanner for adding dependents
- Filters contacts to show only dependents
- Sorts dependents by different criteria

### Implementation Details

The DependentsFeature manages the dependents:

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case .onAppear:
            return .send(.loadDependents)
            
        case .loadDependents:
            state.isLoading = true
            return .run { send in
                do {
                    let contacts = try await contactClient.getContacts()
                    await send(.dependentsLoaded(contacts))
                } catch {
                    await send(.dependentsLoadFailed(UserFacingError(error)))
                }
            }
            
        case let .dependentsLoaded(contacts):
            state.isLoading = false
            state.contacts = contacts
            return .none
            
        case let .dependentsLoadFailed(error):
            state.isLoading = false
            state.error = error
            return .none
            
        case let .selectContact(contact):
            state.destination = .contactDetails(ContactDetailsFeature.State(contact: contact))
            return .none
            
        case let .setSortOption(sortOption):
            state.sortOption = sortOption
            return .none
            
        case .addContactButtonTapped:
            state.destination = .qrScanner(QRScannerFeature.State())
            return .none
            
        // Navigation and error handling...
        }
    }
    .ifLet(\.$destination, action: \.destination)
}
```

## ContactDetailsFeature

The ContactDetailsFeature displays and manages contact details.

### State

```swift
@ObservableState
struct State: Equatable, Sendable {
    var contact: Contact
    var isLoading: Bool = false
    var error: UserFacingError?
    @Presents var destination: Destination.State?
    
    enum Destination: Equatable, Sendable {
        case confirmRemove
        case confirmRoleChange(RoleChange)
    }
    
    enum RoleChange: Equatable, Sendable {
        case addResponder
        case removeResponder
        case addDependent
        case removeDependent
    }
}
```

### Action

```swift
enum Action: Equatable, Sendable {
    // Lifecycle actions
    case onAppear
    
    // User actions
    case toggleResponder
    case toggleDependent
    case removeContactButtonTapped
    case pingButtonTapped
    
    // System actions
    case updateContactResponse(TaskResult<Contact>)
    case removeContactResponse(TaskResult<Void>)
    case pingResponse(TaskResult<Void>)
    
    // Navigation actions
    case destination(PresentationAction<Destination.Action>)
    
    // Error handling
    case setError(UserFacingError?)
    case dismissError
    
    enum Destination: Equatable, Sendable {
        case confirmRemove(ConfirmRemoveAction)
        case confirmRoleChange(ConfirmRoleChangeAction)
        
        enum ConfirmRemoveAction: Equatable, Sendable {
            case confirmButtonTapped
            case cancelButtonTapped
        }
        
        enum ConfirmRoleChangeAction: Equatable, Sendable {
            case confirmButtonTapped
            case cancelButtonTapped
        }
    }
}
```

### Dependencies

- **ContactClient**: For contact operations
- **PingClient**: For ping operations

### Responsibilities

- Displays contact details
- Allows editing of contact roles
- Provides contact removal
- Allows pinging dependents
- Confirms role changes and contact removal

### Implementation Details

The ContactDetailsFeature manages contact details:

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case .onAppear:
            return .none
            
        case .toggleResponder:
            let newValue = !state.contact.isResponder
            
            // Prevent disabling the last role
            if !newValue && !state.contact.isDependent {
                state.error = UserFacingError(
                    title: "Cannot Remove Role",
                    message: "Contact must have at least one role."
                )
                return .none
            }
            
            state.destination = .confirmRoleChange(
                newValue ? .addResponder : .removeResponder
            )
            return .none
            
        case .toggleDependent:
            let newValue = !state.contact.isDependent
            
            // Prevent disabling the last role
            if !newValue && !state.contact.isResponder {
                state.error = UserFacingError(
                    title: "Cannot Remove Role",
                    message: "Contact must have at least one role."
                )
                return .none
            }
            
            state.destination = .confirmRoleChange(
                newValue ? .addDependent : .removeDependent
            )
            return .none
            
        case .removeContactButtonTapped:
            state.destination = .confirmRemove
            return .none
            
        case .pingButtonTapped:
            // Only allow pinging dependents
            guard state.contact.isDependent else {
                state.error = UserFacingError(
                    title: "Cannot Ping",
                    message: "You can only ping dependents."
                )
                return .none
            }
            
            state.isLoading = true
            return .run { [contactID = state.contact.id] send in
                do {
                    try await pingClient.sendPing(contactID: contactID)
                    await send(.pingResponse(.success))
                } catch {
                    await send(.pingResponse(.failure(error)))
                }
            }
            
        // Navigation and error handling...
        }
    }
    .ifLet(\.$destination, action: \.destination)
}
```

## AddContactFeature

The AddContactFeature handles adding new contacts.

### State

```swift
@ObservableState
struct State: Equatable, Sendable {
    var contactID: UUID?
    var firstName: String = ""
    var lastName: String = ""
    var phoneNumber: String = ""
    var isResponder: Bool = false
    var isDependent: Bool = false
    var isLoading: Bool = false
    var error: UserFacingError?
}
```

### Action

```swift
enum Action: Equatable, Sendable {
    // User actions
    case firstNameChanged(String)
    case lastNameChanged(String)
    case phoneNumberChanged(String)
    case toggleResponder
    case toggleDependent
    case addButtonTapped
    case cancelButtonTapped
    
    // System actions
    case setContactID(UUID)
    case addContactResponse(TaskResult<Contact>)
    
    // Error handling
    case setError(UserFacingError?)
    case dismissError
    
    // Delegate actions
    case delegate(DelegateAction)
    
    enum DelegateAction: Equatable, Sendable {
        case contactAdded(Contact)
        case dismissed
    }
}
```

### Dependencies

- **ContactClient**: For contact operations

### Responsibilities

- Collects contact information
- Validates contact input
- Adds new contacts
- Assigns roles to contacts

### Implementation Details

The AddContactFeature handles adding contacts:

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case let .firstNameChanged(firstName):
            state.firstName = firstName
            return .none
            
        case let .lastNameChanged(lastName):
            state.lastName = lastName
            return .none
            
        case let .phoneNumberChanged(phoneNumber):
            state.phoneNumber = phoneNumber
            return .none
            
        case .toggleResponder:
            state.isResponder.toggle()
            
            // Ensure at least one role is selected
            if !state.isResponder && !state.isDependent {
                state.isDependent = true
            }
            
            return .none
            
        case .toggleDependent:
            state.isDependent.toggle()
            
            // Ensure at least one role is selected
            if !state.isResponder && !state.isDependent {
                state.isResponder = true
            }
            
            return .none
            
        case .addButtonTapped:
            // Validate input
            if state.firstName.isEmpty || state.lastName.isEmpty {
                state.error = UserFacingError(
                    title: "Invalid Input",
                    message: "First name and last name are required."
                )
                return .none
            }
            
            if state.phoneNumber.isEmpty {
                state.error = UserFacingError(
                    title: "Invalid Input",
                    message: "Phone number is required."
                )
                return .none
            }
            
            if !state.isResponder && !state.isDependent {
                state.error = UserFacingError(
                    title: "Invalid Input",
                    message: "Contact must have at least one role."
                )
                return .none
            }
            
            state.isLoading = true
            return .run { [state] send in
                do {
                    let contact = try await contactClient.addContact(
                        contactID: state.contactID,
                        firstName: state.firstName,
                        lastName: state.lastName,
                        phoneNumber: state.phoneNumber,
                        isResponder: state.isResponder,
                        isDependent: state.isDependent
                    )
                    await send(.addContactResponse(.success(contact)))
                } catch {
                    await send(.addContactResponse(.failure(error)))
                }
            }
            
        case let .addContactResponse(.success(contact)):
            state.isLoading = false
            return .send(.delegate(.contactAdded(contact)))
            
        case let .addContactResponse(.failure(error)):
            state.isLoading = false
            state.error = UserFacingError(error)
            return .none
            
        case .cancelButtonTapped:
            return .send(.delegate(.dismissed))
            
        // Error handling...
        }
    }
}
```

## QRScannerFeature

The QRScannerFeature handles scanning QR codes for adding contacts.

### State

```swift
@ObservableState
struct State: Equatable, Sendable {
    var isScanning: Bool = false
    var error: UserFacingError?
    @Presents var destination: Destination.State?
    
    enum Destination: Equatable, Sendable {
        case addContact(AddContactFeature.State)
    }
}
```

### Action

```swift
enum Action: Equatable, Sendable {
    // Lifecycle actions
    case onAppear
    case onDisappear
    
    // User actions
    case cancelButtonTapped
    
    // System actions
    case qrCodeScanned(String)
    case contactInfoLoaded(ContactInfo)
    case contactInfoLoadFailed(UserFacingError)
    
    // Navigation actions
    case destination(PresentationAction<Destination.Action>)
    
    // Error handling
    case setError(UserFacingError?)
    case dismissError
    
    // Delegate actions
    case delegate(DelegateAction)
    
    enum DelegateAction: Equatable, Sendable {
        case contactAdded(Contact)
        case dismissed
    }
    
    enum Destination: Equatable, Sendable {
        case addContact(AddContactFeature.Action)
    }
}
```

### Dependencies

- **QRCodeClient**: For QR code operations
- **ContactClient**: For contact operations

### Responsibilities

- Scans QR codes
- Extracts contact information from QR codes
- Presents add contact form with pre-filled information
- Handles scanning errors

### Implementation Details

The QRScannerFeature handles scanning QR codes:

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case .onAppear:
            state.isScanning = true
            return .none
            
        case .onDisappear:
            state.isScanning = false
            return .none
            
        case let .qrCodeScanned(qrCode):
            state.isScanning = false
            
            return .run { send in
                do {
                    let contactInfo = try await contactClient.getContactInfo(qrCode: qrCode)
                    await send(.contactInfoLoaded(contactInfo))
                } catch {
                    await send(.contactInfoLoadFailed(UserFacingError(error)))
                }
            }
            
        case let .contactInfoLoaded(contactInfo):
            var addContactState = AddContactFeature.State()
            addContactState.contactID = contactInfo.id
            addContactState.firstName = contactInfo.firstName
            addContactState.lastName = contactInfo.lastName
            addContactState.phoneNumber = contactInfo.phoneNumber
            
            state.destination = .addContact(addContactState)
            return .none
            
        case let .contactInfoLoadFailed(error):
            state.error = error
            state.isScanning = true
            return .none
            
        case .cancelButtonTapped:
            return .send(.delegate(.dismissed))
            
        // Navigation and error handling...
        }
    }
    .ifLet(\.$destination, action: \.destination)
}
```

## Feature Composition

The contact features are composed in a hierarchical structure:

```
ContactsFeature
├── RespondersFeature
│   ├── ContactDetailsFeature
│   └── QRScannerFeature
│       └── AddContactFeature
└── DependentsFeature
    ├── ContactDetailsFeature
    └── QRScannerFeature
        └── AddContactFeature
```

This composition allows for a modular application structure where features can be developed, tested, and maintained independently.

## Feature Dependencies

The contact features depend on the following clients:

- **ContactClient**: For contact operations
- **PingClient**: For ping operations
- **QRCodeClient**: For QR code operations

These clients are injected using TCA's dependency injection system.
