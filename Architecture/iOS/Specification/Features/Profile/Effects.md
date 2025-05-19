# ProfileFeature Effects

**Navigation:** [Back to ProfileFeature](README.md) | [State](State.md) | [Actions](Actions.md)

---

## Overview

This document provides detailed information about the effects of the ProfileFeature in the LifeSignal iOS application. Effects represent the side effects that occur in response to actions, such as API calls, timer operations, and navigation.

## Effect Types

The ProfileFeature uses the following types of effects:

1. **API Effects** - Effects that interact with external services through clients
2. **Navigation Effects** - Effects that handle navigation between screens
3. **Image Effects** - Effects that handle image operations

## Dependencies

The ProfileFeature depends on the following clients for its effects:

```swift
@Dependency(\.userClient) var userClient
@Dependency(\.authClient) var authClient
@Dependency(\.storageClient) var storageClient
@Dependency(\.imageClient) var imageClient
@Dependency(\.uuid) var uuid
```

## Effect Implementation

The effects are implemented in the feature's reducer:

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        // MARK: - Lifecycle Effects
        
        case .onAppear:
            if !state.isLoading && state.name.isEmpty {
                return .send(.loadProfile)
            }
            return .none
            
        case .onDisappear:
            return .none
            
        // MARK: - Profile Operation Effects
        
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
            
            // Initialize editing state with current values
            state.editingName = profile.name
            state.editingDescription = profile.emergencyNote
            
            return .none
            
        case let .profileResponse(.failure(error)):
            state.isLoading = false
            state.error = UserFacingError.from(error)
            return .none
            
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
            
        // MARK: - UI Effects
        
        case .startEditing:
            state.isEditing = true
            state.editingName = state.name
            state.editingDescription = state.emergencyNote
            return .none
            
        case .cancelEditing:
            state.isEditing = false
            state.editingName = state.name
            state.editingDescription = state.emergencyNote
            state.newProfilePicture = nil
            return .none
            
        case let .setEditingName(name):
            state.editingName = name
            return .none
            
        case let .setEditingDescription(description):
            state.editingDescription = description
            return .none
            
        case .presentImagePicker:
            state.isImagePickerPresented = true
            return .none
            
        case .dismissImagePicker:
            state.isImagePickerPresented = false
            return .none
            
        case let .imageSelected(imageData):
            state.isImagePickerPresented = false
            state.newProfilePicture = imageData
            return .none
            
        case .updateProfilePicture:
            guard let imageData = state.newProfilePicture else {
                return .none
            }
            
            state.isLoading = true
            return .run { [userId = uuid()] send in
                do {
                    let url = try await storageClient.uploadProfilePicture(userId: userId, imageData: imageData)
                    await send(.updateProfilePictureResponse(.success(url)))
                } catch {
                    await send(.updateProfilePictureResponse(.failure(error)))
                }
            }
            
        case let .updateProfilePictureResponse(.success(url)):
            state.isLoading = false
            state.profilePictureURL = url
            state.newProfilePicture = nil
            
            return .send(.delegate(.profileUpdated(UserProfile(
                name: state.name,
                phoneNumber: state.phoneNumber,
                emergencyNote: state.emergencyNote,
                profilePictureURL: state.profilePictureURL
            ))))
            
        case let .updateProfilePictureResponse(.failure(error)):
            state.isLoading = false
            state.error = UserFacingError.from(error)
            return .none
            
        case .presentQRCode:
            state.qrCode = QRCodeFeature.State()
            return .none
            
        case .dismissQRCode:
            state.qrCode = nil
            return .none
            
        case .presentSignOutConfirmation:
            state.confirmSignOut = ConfirmationAlertState(
                title: "Sign Out",
                message: "Are you sure you want to sign out?",
                buttons: [
                    .destructive("Sign Out", action: .send(.signOut)),
                    .cancel("Cancel")
                ]
            )
            return .none
            
        case .dismissSignOutConfirmation:
            state.confirmSignOut = nil
            return .none
            
        case let .setError(error):
            state.error = error
            return .none
            
        // MARK: - Child Feature Effects
        
        case .qrCode:
            return .none
            
        case .confirmSignOut:
            return .none
            
        // MARK: - Delegate Effects
        
        case .delegate:
            return .none
        }
    }
    .ifLet(\.$qrCode, action: \.qrCode) {
        QRCodeFeature()
    }
}
```

## Effect Details

### Profile Loading Effect

The profile loading effect is triggered when the profile view appears and the profile data has not been loaded yet. It uses the `userClient` to fetch the user's profile data from the backend.

```swift
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
```

### Profile Update Effect

The profile update effect is triggered when the user saves their profile changes. It uses the `userClient` to update the user's profile data in the backend.

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
```

### Sign Out Effect

The sign out effect is triggered when the user confirms the sign-out action. It uses the `authClient` to sign the user out of the application.

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
```

### Profile Picture Update Effect

The profile picture update effect is triggered when the user selects a new profile picture and confirms the change. It uses the `storageClient` to upload the new profile picture to the backend.

```swift
case .updateProfilePicture:
    guard let imageData = state.newProfilePicture else {
        return .none
    }
    
    state.isLoading = true
    return .run { [userId = uuid()] send in
        do {
            let url = try await storageClient.uploadProfilePicture(userId: userId, imageData: imageData)
            await send(.updateProfilePictureResponse(.success(url)))
        } catch {
            await send(.updateProfilePictureResponse(.failure(error)))
        }
    }
```

## Error Handling

The ProfileFeature handles errors by converting them to user-facing errors and storing them in the state. These errors can then be displayed to the user in the UI.

```swift
case let .profileResponse(.failure(error)):
    state.isLoading = false
    state.error = UserFacingError.from(error)
    return .none
```

## Best Practices

When implementing effects for the ProfileFeature, follow these best practices:

1. **Use Dependency Injection** - Use dependency injection to provide clients and other dependencies to the feature.

2. **Handle Errors Gracefully** - Convert errors to user-facing errors and display them to the user.

3. **Use TaskResult for Async Operations** - Use `TaskResult` for handling the results of asynchronous operations.

4. **Capture State in Effect Closures** - Capture the necessary state in effect closures to avoid state changes affecting the effect.

5. **Use Delegate Actions for Parent Communication** - Use delegate actions to communicate with parent features.

6. **Document Effect Implementation** - Document how each effect is implemented in the reducer.
