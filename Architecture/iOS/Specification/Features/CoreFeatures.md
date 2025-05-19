# LifeSignal iOS Core Features

**Navigation:** [Back to Features](README.md) | [Contact Features](ContactFeatures.md) | [Safety Features](SafetyFeatures.md) | [Utility Features](UtilityFeatures.md)

---

## Overview

This document provides detailed specifications for the core features of the LifeSignal iOS application. Core features provide the foundation for the application, including authentication, user management, and global application state.

## AppFeature

The AppFeature is the root feature that composes all other features and manages global application state.

### State

```swift
@ObservableState
struct State: Equatable, Sendable {
    var auth: AuthFeature.State = .init()
    var user: UserFeature.State = .init()
    var mainTab: MainTabFeature.State?
    var isAuthenticated: Bool = false
    var needsOnboarding: Bool = false
    var isInitializing: Bool = true
    var error: UserFacingError?
}
```

### Action

```swift
enum Action: Equatable, Sendable {
    // Lifecycle actions
    case appDidLaunch
    case appDidBecomeActive
    case appDidEnterBackground

    // Child feature actions
    case auth(AuthFeature.Action)
    case user(UserFeature.Action)
    case mainTab(MainTabFeature.Action)

    // Authentication actions
    case authStateChanged(User?)
    case signOut
    case signOutResponse(TaskResult<Void>)

    // Error handling
    case setError(UserFacingError?)
    case dismissError
}
```

### Dependencies

- **AuthClient**: For authentication operations
- **UserClient**: For user profile operations
- **NotificationClient**: For notification handling

### Responsibilities

- Initializes the application
- Manages authentication state
- Coordinates between features
- Handles deep links
- Manages push notifications
- Provides global error handling

### Implementation Details

The AppFeature initializes the application and sets up the authentication state:

```swift
var body: some ReducerOf<Self> {
    Scope(state: \.auth, action: \.auth) {
        AuthFeature()
    }

    Scope(state: \.user, action: \.user) {
        UserFeature()
    }

    Reduce { state, action in
        switch action {
        case .appDidLaunch:
            state.isInitializing = true
            return .run { send in
                for await user in await authClient.authStateStream() {
                    await send(.authStateChanged(user))
                }
            }
            .cancellable(id: CancelID.authStateStream)

        case let .authStateChanged(user):
            state.isInitializing = false
            state.isAuthenticated = user != nil

            if let user = user {
                if user.needsOnboarding {
                    state.needsOnboarding = true
                    state.mainTab = nil
                } else {
                    state.needsOnboarding = false
                    state.mainTab = MainTabFeature.State()
                }
            } else {
                state.mainTab = nil
            }

            return .none

        // Other action handlers...
        }
    }
}
```

## AuthFeature

The [AuthFeature](Auth/README.md) handles user authentication and session management.

### State

```swift
@ObservableState
struct State: Equatable, Sendable {
    var phoneNumber: String = ""
    var verificationCode: String = ""
    var isLoading: Bool = false
    var error: UserFacingError?
    @Presents var destination: Destination.State?

    enum Destination: Equatable, Sendable {
        case verification
    }
}
```

### Action

```swift
enum Action: Equatable, Sendable {
    // User actions
    case phoneNumberChanged(String)
    case verificationCodeChanged(String)
    case signInButtonTapped
    case verifyButtonTapped
    case resendCodeButtonTapped
    case debugSkipAuthButtonTapped

    // System actions
    case signInResponse(TaskResult<Void>)
    case verifyResponse(TaskResult<User>)
    case resendCodeResponse(TaskResult<Void>)

    // Navigation actions
    case destination(PresentationAction<Destination.Action>)

    enum Destination: Equatable, Sendable {
        case verification(VerificationAction)

        enum VerificationAction: Equatable, Sendable {
            case verificationCodeChanged(String)
            case verifyButtonTapped
            case resendCodeButtonTapped
            case cancelButtonTapped
        }
    }

    // Error handling
    case setError(UserFacingError?)
    case dismissError
}
```

### Dependencies

- **AuthClient**: For authentication operations

### Responsibilities

- Handles phone number entry
- Sends verification codes
- Verifies user identity
- Manages authentication state
- Provides debug authentication bypass

### Implementation Details

The AuthFeature handles the sign-in process:

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case let .phoneNumberChanged(phoneNumber):
            state.phoneNumber = phoneNumber
            return .none

        case .signInButtonTapped:
            state.isLoading = true
            return .run { [phoneNumber = state.phoneNumber] send in
                do {
                    try await authClient.signIn(phoneNumber: phoneNumber)
                    await send(.signInResponse(.success))
                } catch {
                    await send(.signInResponse(.failure(error)))
                }
            }

        case .signInResponse(.success):
            state.isLoading = false
            state.destination = .verification
            return .none

        case let .signInResponse(.failure(error)):
            state.isLoading = false
            state.error = UserFacingError(error)
            return .none

        // Other action handlers...
        }
    }
    .ifLet(\.$destination, action: \.destination)
}
```

## UserFeature

The [UserFeature](Profile/README.md) manages user profile information and settings.

### State

```swift
@ObservableState
struct State: Equatable, Sendable {
    @Shared(.fileStorage(.userProfile)) var user: User = User(id: UUID())
    var isLoading: Bool = false
    var error: UserFacingError?
}
```

### Action

```swift
enum Action: Equatable, Sendable {
    // Lifecycle actions
    case onAppear

    // User actions
    case updateFirstName(String)
    case updateLastName(String)
    case updateEmergencyNote(String)
    case updateCheckInInterval(TimeInterval)
    case updateReminderInterval(TimeInterval)
    case updateProfileImage(UIImage?)

    // System actions
    case loadUser
    case userLoaded(User)
    case userLoadFailed(UserFacingError)
    case updateProfileResponse(TaskResult<Void>)
    case streamUserUpdates
    case userUpdated(User)

    // Error handling
    case setError(UserFacingError?)
    case dismissError
}
```

### Dependencies

- **UserClient**: For user profile operations
- **StorageClient**: For image storage operations
- **ImageClient**: For image handling operations

### Responsibilities

- Manages user profile information
- Handles profile updates
- Manages user settings
- Provides user data to other features
- Streams user updates from the server

### Implementation Details

The UserFeature manages the user profile:

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case .onAppear:
            return .send(.loadUser)

        case .loadUser:
            state.isLoading = true
            return .run { send in
                do {
                    let user = try await userClient.currentUser()
                    await send(.userLoaded(user))
                } catch {
                    await send(.userLoadFailed(UserFacingError(error)))
                }
            }

        case let .userLoaded(user):
            state.isLoading = false
            state.user = user
            return .none

        case let .userLoadFailed(error):
            state.isLoading = false
            state.error = error
            return .none

        case let .updateFirstName(firstName):
            state.user.firstName = firstName
            return .send(.updateProfileResponse(.success))

        // Other action handlers...

        case .streamUserUpdates:
            return .run { send in
                for await user in await userClient.userStream() {
                    await send(.userUpdated(user))
                }
            }
            .cancellable(id: CancelID.userStream)

        case let .userUpdated(user):
            state.user = user
            return .none

        // Error handling...
        }
    }
}
```

## MainTabFeature

The MainTabFeature manages the main tab navigation of the application.

### State

```swift
@ObservableState
struct State: Equatable, Sendable {
    var selectedTab: Tab = .home
    var home: HomeFeature.State = .init()
    var contacts: ContactsFeature.State = .init()
    var notification: NotificationFeature.State = .init()
    var profile: ProfileFeature.State = .init()

    enum Tab: Equatable, Sendable {
        case home
        case contacts
        case notification
        case profile
    }
}
```

### Action

```swift
enum Action: Equatable, Sendable {
    // Tab selection
    case tabSelected(Tab)

    // Child feature actions
    case home(HomeFeature.Action)
    case contacts(ContactsFeature.Action)
    case notification(NotificationFeature.Action)
    case profile(ProfileFeature.Action)

    enum Tab: Equatable, Sendable {
        case home
        case contacts
        case notification
        case profile
    }
}
```

### Dependencies

None (delegates to child features)

### Responsibilities

- Manages tab navigation
- Coordinates between tab features
- Provides tab-based UI

### Implementation Details

The MainTabFeature manages the tab navigation:

```swift
var body: some ReducerOf<Self> {
    Scope(state: \.home, action: \.home) {
        HomeFeature()
    }

    Scope(state: \.contacts, action: \.contacts) {
        ContactsFeature()
    }

    Scope(state: \.notification, action: \.notification) {
        NotificationFeature()
    }

    Scope(state: \.profile, action: \.profile) {
        ProfileFeature()
    }

    Reduce { state, action in
        switch action {
        case let .tabSelected(tab):
            state.selectedTab = tab
            return .none

        // Other action handlers...
        }
    }
}
```

## Feature Composition

The core features are composed in a hierarchical structure:

```
AppFeature
├── AuthFeature
├── UserFeature
└── MainTabFeature
    ├── HomeFeature
    ├── ContactsFeature
    ├── NotificationFeature
    └── ProfileFeature
```

This composition allows for a modular application structure where features can be developed, tested, and maintained independently.

## Feature Dependencies

The core features depend on the following clients:

- **AuthClient**: For authentication operations
- **UserClient**: For user profile operations
- **NotificationClient**: For notification handling
- **StorageClient**: For data storage operations
- **ImageClient**: For image handling operations

These clients are injected using TCA's dependency injection system.
