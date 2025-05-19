# ProfileFeature Actions

**Navigation:** [Back to ProfileFeature](README.md) | [State](State.md) | [Effects](Effects.md)

---

## Overview

This document provides detailed information about the actions of the ProfileFeature in the LifeSignal iOS application. Actions represent the events that can occur in the feature, including user interactions, system events, and responses from external dependencies.

## Action Definition

```swift
enum Action: Equatable, Sendable {
    // MARK: - Lifecycle Actions
    case onAppear
    case onDisappear
    
    // MARK: - Profile Operations
    case loadProfile
    case profileResponse(TaskResult<UserProfile>)
    case updateProfile
    case updateProfileResponse(TaskResult<Void>)
    case signOut
    case signOutSucceeded
    case signOutFailed(UserFacingError)
    
    // MARK: - UI Actions
    case startEditing
    case cancelEditing
    case setEditingName(String)
    case setEditingDescription(String)
    case presentImagePicker
    case dismissImagePicker
    case imageSelected(Data?)
    case updateProfilePicture
    case updateProfilePictureResponse(TaskResult<URL?>)
    case presentQRCode
    case dismissQRCode
    case presentSignOutConfirmation
    case dismissSignOutConfirmation
    case setError(UserFacingError?)
    
    // MARK: - Child Feature Actions
    case qrCode(PresentationAction<QRCodeFeature.Action>)
    case confirmSignOut(PresentationAction<Never>)
    
    // MARK: - Delegate Actions
    case delegate(DelegateAction)
    
    enum DelegateAction: Equatable, Sendable {
        case signedOut
        case profileUpdated(UserProfile)
    }
}
```

## Action Categories

### Lifecycle Actions

#### `onAppear`

Dispatched when the profile view appears. This action triggers the loading of the user's profile data.

#### `onDisappear`

Dispatched when the profile view disappears. This action can be used to clean up resources or cancel ongoing operations.

### Profile Operations

#### `loadProfile`

Dispatched to load the user's profile data from the backend.

#### `profileResponse(TaskResult<UserProfile>)`

Dispatched when the profile data has been loaded from the backend. This action contains the result of the operation, which can be either a success with the user's profile data or a failure with an error.

#### `updateProfile`

Dispatched when the user saves their profile changes. This action triggers the updating of the user's profile data in the backend.

#### `updateProfileResponse(TaskResult<Void>)`

Dispatched when the profile update operation has completed. This action contains the result of the operation, which can be either a success or a failure with an error.

#### `signOut`

Dispatched when the user initiates the sign-out process. This action triggers the sign-out operation in the backend.

#### `signOutSucceeded`

Dispatched when the sign-out operation has succeeded.

#### `signOutFailed(UserFacingError)`

Dispatched when the sign-out operation has failed. This action contains the error that occurred.

### UI Actions

#### `startEditing`

Dispatched when the user starts editing their profile.

#### `cancelEditing`

Dispatched when the user cancels editing their profile.

#### `setEditingName(String)`

Dispatched when the user changes their name in the editing form.

#### `setEditingDescription(String)`

Dispatched when the user changes their emergency note in the editing form.

#### `presentImagePicker`

Dispatched when the user initiates the process of selecting a new profile picture.

#### `dismissImagePicker`

Dispatched when the user dismisses the image picker without selecting an image.

#### `imageSelected(Data?)`

Dispatched when the user selects a new profile picture. This action contains the image data.

#### `updateProfilePicture`

Dispatched when the user confirms the new profile picture. This action triggers the uploading of the new profile picture to the backend.

#### `updateProfilePictureResponse(TaskResult<URL?>)`

Dispatched when the profile picture update operation has completed. This action contains the result of the operation, which can be either a success with the URL of the new profile picture or a failure with an error.

#### `presentQRCode`

Dispatched when the user taps the QR code button. This action triggers the presentation of the QR code sheet.

#### `dismissQRCode`

Dispatched when the user dismisses the QR code sheet.

#### `presentSignOutConfirmation`

Dispatched when the user taps the sign-out button. This action triggers the presentation of the sign-out confirmation alert.

#### `dismissSignOutConfirmation`

Dispatched when the user dismisses the sign-out confirmation alert.

#### `setError(UserFacingError?)`

Dispatched to set or clear the error state.

### Child Feature Actions

#### `qrCode(PresentationAction<QRCodeFeature.Action>)`

Dispatched when an action occurs in the QR code feature.

#### `confirmSignOut(PresentationAction<Never>)`

Dispatched when an action occurs in the sign-out confirmation alert.

### Delegate Actions

#### `delegate(DelegateAction)`

Dispatched to notify the parent feature of events that occurred in the ProfileFeature.

#### `DelegateAction.signedOut`

Dispatched when the user has successfully signed out.

#### `DelegateAction.profileUpdated(UserProfile)`

Dispatched when the user's profile has been updated. This action contains the updated profile data.

## Action Handling

Actions are handled by the feature's reducer, which defines how the state changes in response to actions and what effects are executed.

For detailed information on how actions are handled, see the [Effects](Effects.md) document.

## Action Examples

### Loading the User's Profile

```swift
case .onAppear:
    if !state.isLoading && state.name.isEmpty {
        return .send(.loadProfile)
    }
    return .none

case .loadProfile:
    state.isLoading = true
    return .run { send in
        do {
            let profile = try await userClient.getProfile()
            await send(.profileResponse(.success(profile)))
        } catch {
            await send(.profileResponse(.failure(error)))
        }
    }

case let .profileResponse(.success(profile)):
    state.isLoading = false
    state.name = profile.name
    state.phoneNumber = profile.phoneNumber
    state.emergencyNote = profile.emergencyNote
    state.profilePictureURL = profile.profilePictureURL
    return .none

case let .profileResponse(.failure(error)):
    state.isLoading = false
    state.error = UserFacingError.from(error)
    return .none
```

### Updating the User's Profile

```swift
case .updateProfile:
    state.isLoading = true
    return .run { [name = state.editingName, note = state.editingDescription] send in
        do {
            try await userClient.updateProfile(name: name, emergencyNote: note)
            await send(.updateProfileResponse(.success(())))
        } catch {
            await send(.updateProfileResponse(.failure(error)))
        }
    }

case .updateProfileResponse(.success):
    state.isLoading = false
    state.isEditing = false
    state.name = state.editingName
    state.emergencyNote = state.editingDescription
    return .send(.delegate(.profileUpdated(UserProfile(
        name: state.name,
        phoneNumber: state.phoneNumber,
        emergencyNote: state.emergencyNote,
        profilePictureURL: state.profilePictureURL
    ))))

case let .updateProfileResponse(.failure(error)):
    state.isLoading = false
    state.error = UserFacingError.from(error)
    return .none
```

### Signing Out

```swift
case .signOut:
    state.isLoading = true
    return .run { send in
        do {
            try await authClient.signOut()
            await send(.signOutSucceeded)
        } catch {
            await send(.signOutFailed(UserFacingError.from(error)))
        }
    }

case .signOutSucceeded:
    state.isLoading = false
    return .send(.delegate(.signedOut))

case let .signOutFailed(error):
    state.isLoading = false
    state.error = error
    return .none
```

## Best Practices

When working with the ProfileFeature actions, follow these best practices:

1. **Group Actions by Category** - Group actions into categories such as user actions, system actions, and presentation actions.

2. **Use Descriptive Action Names** - Use descriptive names that clearly indicate the action's purpose.

3. **Use TaskResult for Async Operations** - Use `TaskResult` for handling the results of asynchronous operations.

4. **Use Delegate Actions for Parent Communication** - Use delegate actions to communicate with parent features.

5. **Document Action Handling** - Document how each action is handled in the reducer.
