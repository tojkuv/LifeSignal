# Feature Architecture (Vertical Slices)

**Navigation:** [Back to iOS Architecture](README.md) | [TCA Implementation](TCAImplementation.md) | [Modern TCA Architecture](ComposableArchitecture.md) | [Core Principles](CorePrinciples.md)

---

> **Note:** As this is an MVP, the feature architecture and organization may evolve as the project matures.

## Vertical Slice Architecture

LifeSignal organizes features using vertical slice architecture, where each feature contains all the necessary components:

### Feature Organization

```
Features/
  ├── Auth/                  # Authentication feature
  │   ├── AuthFeature.swift  # TCA reducer
  │   ├── AuthView.swift     # SwiftUI view
  │   ├── Models/            # Feature-specific models
  │   └── Views/             # Feature-specific views
  │
  ├── Profile/               # Profile feature
  │   ├── ProfileFeature.swift
  │   ├── ProfileView.swift
  │   ├── Models/
  │   └── Views/
  │
  ├── Contacts/              # Contacts feature
  │   ├── ContactsFeature.swift
  │   ├── ContactsView.swift
  │   ├── Models/
  │   └── Views/
  │
  └── ...                    # Other features
```

### Feature Components

1. **Feature Reducer** - The TCA reducer that defines the feature's state, actions, and behavior
2. **Feature View** - The SwiftUI view that renders the feature's UI
3. **Feature Models** - Feature-specific domain models
4. **Feature Views** - Reusable UI components specific to the feature
5. **Feature Tests** - Comprehensive tests for the feature's behavior

### Feature Design Principles

- Each feature is self-contained and independent
- Features communicate through well-defined interfaces
- Features depend on infrastructure clients, not directly on infrastructure
- Features are organized by domain functionality, not technical layers
- Features should be testable in isolation
- Features should handle their own error states
- Features should manage their own loading states
- Features should be composable with other features

## Feature Composition

Features can be composed in several ways:

1. **Parent-Child Relationship** - A parent feature can present a child feature
2. **Feature Coordination** - Features can coordinate through shared state
3. **Feature Navigation** - Features can navigate to other features
4. **Feature Embedding** - Features can embed other features

### Parent-Child Relationship

```swift
@Reducer
struct ParentFeature {
    @ObservableState
    struct State: Equatable {
        @Presents var child: ChildFeature.State?
    }

    enum Action {
        case showChild
        case child(PresentationAction<ChildFeature.Action>)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .showChild:
                state.child = ChildFeature.State()
                return .none

            case .child:
                return .none
            }
        }
        .presents(
            state: \.$child,
            action: \.child
        ) {
            ChildFeature()
        }
    }
}
```

### Feature Coordination

```swift
@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var user = UserFeature.State()
        var contacts = ContactsFeature.State()
    }

    enum Action {
        case user(UserFeature.Action)
        case contacts(ContactsFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.user, action: \.user) {
            UserFeature()
        }

        Scope(state: \.contacts, action: \.contacts) {
            ContactsFeature()
        }

        Reduce { state, action in
            switch action {
            case .user(.delegate(.userUpdated(let user))):
                // Coordinate between features
                state.contacts.currentUserId = user.id
                return .none

            default:
                return .none
            }
        }
    }
}
```

### Feature Navigation

```swift
@Reducer
struct MainTabFeature {
    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .home
        var home = HomeFeature.State()
        var profile = ProfileFeature.State()
    }

    enum Action {
        case selectTab(Tab)
        case home(HomeFeature.Action)
        case profile(ProfileFeature.Action)
    }

    enum Tab {
        case home
        case profile
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .selectTab(tab):
                state.selectedTab = tab
                return .none

            case .home, .profile:
                return .none
            }
        }

        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }

        Scope(state: \.profile, action: \.profile) {
            ProfileFeature()
        }
    }
}
```

### Feature Embedding

```swift
@Reducer
struct DashboardFeature {
    @ObservableState
    struct State: Equatable {
        var checkIn = CheckInFeature.State()
        var recentContacts = RecentContactsFeature.State()
    }

    enum Action {
        case checkIn(CheckInFeature.Action)
        case recentContacts(RecentContactsFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.checkIn, action: \.checkIn) {
            CheckInFeature()
        }

        Scope(state: \.recentContacts, action: \.recentContacts) {
            RecentContactsFeature()
        }
    }
}
```

## Feature State Management

Each feature manages its own state using TCA:

1. **Local State** - State that is specific to the feature
2. **Presentation State** - State for presenting child features
3. **Shared State** - State that is shared with other features
4. **Derived State** - State that is derived from other state

### Local State

```swift
@ObservableState
struct State: Equatable {
    var isLoading: Bool = false
    var error: UserFacingError? = nil
    var contacts: [Contact] = []
}
```

### Presentation State

```swift
@ObservableState
struct State: Equatable {
    @Presents var editProfile: EditProfileFeature.State?
    @Presents var settings: SettingsFeature.State?
}
```

### Shared State

```swift
@ObservableState
struct State: Equatable {
    @Shared var user: UserState
}
```

### Derived State

```swift
@ObservableState
struct State: Equatable {
    var contacts: [Contact] = []

    var favoriteContacts: [Contact] {
        contacts.filter { $0.isFavorite }
    }

    var nonResponsiveContacts: [Contact] {
        contacts.filter { $0.isNonResponsive }
    }
}
```

## Feature Effect Management

Features manage side effects using TCA effects:

1. **Infrastructure Effects** - Effects that interact with infrastructure clients
2. **Navigation Effects** - Effects that trigger navigation
3. **Coordination Effects** - Effects that coordinate with other features
4. **Timer Effects** - Effects that are triggered by timers
5. **Cancellation Effects** - Effects that cancel other effects

### Infrastructure Effects

```swift
@Dependency(\.userClient) var userClient

case .checkInButtonTapped:
    state.isLoading = true
    return .run { send in
        do {
            let date = try await userClient.checkIn()
            await send(.checkInSuccess(date))
        } catch {
            await send(.checkInFailure(error))
        }
    }
```

### Navigation Effects

```swift
case .profileButtonTapped:
    state.profile = ProfileFeature.State(userId: state.currentUserId)
    return .none
```

### Coordination Effects

```swift
case .userUpdated(let user):
    return .send(.delegate(.userUpdated(user)))
```

### Timer Effects

```swift
case .startTimer:
    return .run { send in
        while true {
            try await Task.sleep(for: .seconds(1))
            await send(.timerTick)
        }
    }
    .cancellable(id: TimerCancelID.self)
```

### Cancellation Effects

```swift
case .stopTimer:
    return .cancel(id: TimerCancelID.self)
```

## Feature Example

```swift
@Reducer
struct ProfileFeature {
    @ObservableState
    struct State: Equatable {
        var user: User
        var isLoading: Bool = false
        var error: String? = nil

        @Presents var editProfile: EditProfileFeature.State?
    }

    enum Action {
        case onAppear
        case userResponse(TaskResult<User>)
        case updateProfile(User)
        case updateProfileResponse(TaskResult<Bool>)
        case editProfileButtonTapped
        case editProfile(PresentationAction<EditProfileFeature.Action>)
    }

    @Dependency(\.userClient) var userClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { [userId = state.user.id] send in
                    let result = await TaskResult { try await userClient.getUser(userId) }
                    await send(.userResponse(result))
                }

            case let .userResponse(.success(user)):
                state.isLoading = false
                state.user = user
                return .none

            case let .userResponse(.failure(error)):
                state.isLoading = false
                state.error = error.localizedDescription
                return .none

            case let .updateProfile(user):
                state.isLoading = true
                return .run { send in
                    let result = await TaskResult { try await userClient.updateUser(user) }
                    await send(.updateProfileResponse(result))
                }

            case .updateProfileResponse(.success):
                state.isLoading = false
                return .none

            case let .updateProfileResponse(.failure(error)):
                state.isLoading = false
                state.error = error.localizedDescription
                return .none

            case .editProfileButtonTapped:
                state.editProfile = EditProfileFeature.State(user: state.user)
                return .none

            case .editProfile(.presented(.saveButtonTapped)):
                if let editedUser = state.editProfile?.user {
                    return .send(.updateProfile(editedUser))
                }
                return .none

            case .editProfile:
                return .none
            }
        }
        .presents(
            state: \.$editProfile,
            action: \.editProfile
        ) {
            EditProfileFeature()
        }
    }
}
```
