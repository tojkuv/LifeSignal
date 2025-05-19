# ProfileFeature State

**Navigation:** [Back to ProfileFeature](README.md) | [Actions](Actions.md) | [Effects](Effects.md)

---

## Overview

This document provides detailed information about the state of the ProfileFeature in the LifeSignal iOS application. The state represents the current condition of the user's profile, including personal information, settings, and UI state.

## State Definition

```swift
@ObservableState
struct State: Equatable, Sendable {
    // MARK: - User Profile Data
    var name: String = ""
    var phoneNumber: String = ""
    var emergencyNote: String = ""
    var profilePictureURL: URL? = nil
    
    // MARK: - Editing State
    var isEditing: Bool = false
    var editingName: String = ""
    var editingDescription: String = ""
    var isImagePickerPresented: Bool = false
    var newProfilePicture: Data? = nil
    
    // MARK: - UI State
    var isLoading: Bool = false
    var error: UserFacingError? = nil
    
    // MARK: - Child Feature States
    @Presents var qrCode: QRCodeFeature.State?
    @Presents var confirmSignOut: ConfirmationAlertState<Never>?
    
    // MARK: - Computed Properties
    var canSaveProfile: Bool {
        !editingName.isEmpty && 
        editingName != name || 
        editingDescription != emergencyNote
    }
    
    var displayName: String {
        name.isEmpty ? "User" : name
    }
    
    var hasProfilePicture: Bool {
        profilePictureURL != nil || newProfilePicture != nil
    }
}
```

## State Properties

### User Profile Data

#### `name: String`

The user's full name. This is displayed in the profile view and used in various parts of the application.

#### `phoneNumber: String`

The user's phone number. This is displayed in the profile view and is used for authentication.

#### `emergencyNote: String`

The user's emergency note. This contains important information that responders should know in case of an emergency.

#### `profilePictureURL: URL?`

The URL of the user's profile picture. This is used to display the user's profile picture in the profile view and in other parts of the application.

### Editing State

#### `isEditing: Bool`

A boolean indicating whether the user is currently editing their profile.

#### `editingName: String`

The user's name as it appears in the editing form. This is initialized with the current name when editing begins.

#### `editingDescription: String`

The user's emergency note as it appears in the editing form. This is initialized with the current emergency note when editing begins.

#### `isImagePickerPresented: Bool`

A boolean indicating whether the image picker is currently presented.

#### `newProfilePicture: Data?`

The data for a new profile picture that the user has selected but not yet saved.

### UI State

#### `isLoading: Bool`

A boolean indicating whether the feature is currently loading data or performing an operation.

#### `error: UserFacingError?`

An optional error that should be displayed to the user.

### Child Feature States

#### `@Presents var qrCode: QRCodeFeature.State?`

The state of the QR code feature, which is presented as a sheet when the user taps the QR code button.

#### `@Presents var confirmSignOut: ConfirmationAlertState<Never>?`

The state of the confirmation alert that is presented when the user attempts to sign out.

### Computed Properties

#### `canSaveProfile: Bool`

A boolean indicating whether the user can save their profile. This is true if the user has made changes to their name or emergency note.

#### `displayName: String`

The name to display in the UI. If the user's name is empty, this returns "User".

#### `hasProfilePicture: Bool`

A boolean indicating whether the user has a profile picture. This is true if either `profilePictureURL` or `newProfilePicture` is not nil.

## State Updates

The state is updated in response to actions dispatched to the feature's reducer. For detailed information on how the state is updated, see the [Actions](Actions.md) and [Effects](Effects.md) documents.

## State Persistence

The core state properties are persisted as follows:

- `name`, `phoneNumber`, `emergencyNote`, and `profilePictureURL` are stored in Firebase Firestore
- Other properties are not persisted and only exist in memory

## State Access

The state is accessed by the feature's view and by parent features that include the ProfileFeature as a child feature.

Example of a parent feature accessing the ProfileFeature state:

```swift
@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var profile: ProfileFeature.State = .init()
        // Other state...
    }
    
    enum Action: Equatable, Sendable {
        case profile(ProfileFeature.Action)
        // Other actions...
    }
    
    var body: some ReducerOf<Self> {
        Scope(state: \.profile, action: \.profile) {
            ProfileFeature()
        }
        
        Reduce { state, action in
            // Handle AppFeature-specific actions
            return .none
        }
    }
}
```

## Best Practices

When working with the ProfileFeature state, follow these best practices:

1. **Use Computed Properties for Derived State** - Use computed properties for state that can be derived from other state properties.

2. **Keep State Minimal** - Only include properties that are necessary for the feature's functionality.

3. **Use Optional Properties Appropriately** - Use optional properties for state that may not be available, such as `profilePictureURL` and `error`.

4. **Use Presentation Properties for Presentations** - Use `@Presents` properties for managing presentations, such as sheets, popovers, and alerts.

5. **Document State Properties** - Document the purpose and usage of each state property.
