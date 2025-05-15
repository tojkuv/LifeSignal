# TCA Implementation

**Navigation:** [Back to iOS Architecture](README.md) | [Modern TCA Architecture](ComposableArchitecture.md) | [Feature Architecture](FeatureArchitecture.md) | [Core Principles](CorePrinciples.md)

---

> **Note:** This document outlines the modern TCA implementation patterns used in the LifeSignal application.

## TCA Overview

LifeSignal uses The Composable Architecture (TCA) for state management and UI coordination. TCA provides a consistent way to structure applications with the following core components:

1. **State** - The single source of truth for a feature
2. **Action** - Events that can change the state
3. **Reducer** - Pure functions that handle actions and update state
4. **Effect** - Side effects that interact with the outside world
5. **Store** - Connects the reducer to the view
6. **Dependencies** - External services and clients injected into reducers

## TCA Components

### State

- Must be `Equatable` and `Sendable`
- Should use value types (`struct`)
- Must use `@ObservableState` macro for SwiftUI integration
- Should use `@Presents` for presentation state instead of optionals
- Should use `@Shared` for state that needs to be shared across features
- Should avoid storing optionals when a default value makes sense
- Should use value types for all properties

```swift
@ObservableState
struct State: Equatable, Sendable {
    // User data
    var user: User?

    // UI state
    var isLoading: Bool = false
    var error: UserFacingError? = nil

    // Presentation state
    @Presents var editProfile: EditProfileFeature.State?
    @Presents var settings: SettingsFeature.State?

    // Shared state
    @Shared var session: SessionState
}
```

### Action

- Must be `Equatable` and `Sendable`
- Should use `enum` with associated values
- Should use `PresentationAction` for child feature actions
- Should use `BindableAction` for form fields and controls
- Should avoid using `TaskResult` in actions; handle errors in reducers
- Should use case paths for action routing
- Should group related actions into nested enums

```swift
enum Action: Equatable, Sendable {
    // Lifecycle actions
    case onAppear
    case onDisappear

    // User actions
    case profileButtonTapped
    case checkInButtonTapped
    case logoutButtonTapped

    // Effect responses
    case userLoaded(TaskResult<User>)
    case checkInCompleted(TaskResult<Date>)
    case logoutCompleted(TaskResult<Void>)

    // Child feature actions
    case editProfile(PresentationAction<EditProfileFeature.Action>)
    case settings(PresentationAction<SettingsFeature.Action>)

    // Delegate actions
    case delegate(DelegateAction)

    // Delegate action enum
    enum DelegateAction: Equatable, Sendable {
        case userUpdated(User)
        case loggedOut
    }
}
```

### Reducer

- Must use `@Reducer` macro for all feature definitions
- Should use composition over inheritance for feature organization
- Should handle errors within reducers
- Should use `Scope` for child features
- Should keep features focused on a single responsibility
- Should use `.onChange` for selective effect execution
- Should use `.presents` for presentation state management

```swift
@Reducer
struct ProfileFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var user: User?
        var isLoading: Bool = false
        var error: UserFacingError? = nil

        @Presents var editProfile: EditProfileFeature.State?
    }

    enum Action: Equatable, Sendable {
        case onAppear
        case userLoaded(TaskResult<User>)
        case editProfileButtonTapped
        case editProfile(PresentationAction<EditProfileFeature.Action>)
    }

    @Dependency(\.userClient) var userClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    let result = await TaskResult { try await userClient.getCurrentUser() }
                    await send(.userLoaded(result))
                }

            case let .userLoaded(.success(user)):
                state.isLoading = false
                state.user = user
                return .none

            case let .userLoaded(.failure(error)):
                state.isLoading = false
                state.error = UserFacingError.from(error)
                return .none

            case .editProfileButtonTapped:
                guard let user = state.user else { return .none }
                state.editProfile = EditProfileFeature.State(user: user)
                return .none

            case .editProfile(.presented(.saveButtonTapped)):
                guard let editedUser = state.editProfile?.user else { return .none }
                state.user = editedUser
                state.editProfile = nil
                return .run { send in
                    let result = await TaskResult { try await userClient.updateUser(editedUser) }
                    if case .failure(let error) = result {
                        await send(.userLoaded(.failure(error)))
                    }
                }

            case .editProfile(.dismiss):
                state.editProfile = nil
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

### Effect

- Should use `.run` for all asynchronous operations
- Should use structured concurrency with async/await
- Should handle errors within effects, not in actions or state
- Must specify cancellation IDs for long-running or repeating effects
- Should use `Task.yield()` for CPU-intensive work in effects
- Should return `.none` for synchronous state updates with no side effects
- Should avoid using raw `Task` creation in reducers

```swift
// Simple effect
return .run { send in
    let result = await TaskResult { try await userClient.getCurrentUser() }
    await send(.userLoaded(result))
}

// Effect with cancellation
return .run { send in
    while true {
        try await Task.sleep(for: .seconds(1))
        await send(.timerTick)
    }
}
.cancellable(id: TimerCancelID.self)

// Effect with dependencies
@Dependency(\.userClient) var userClient
@Dependency(\.continuousClock) var clock

return .run { send in
    try await clock.sleep(for: .seconds(1))
    let result = await TaskResult { try await userClient.getCurrentUser() }
    await send(.userLoaded(result))
}
```

### Store

- Should use `@Bindable var store: StoreOf<Feature>` in views
- Should use `$store.scope(state:action:)` for navigation stack binding
- Should use `$store` syntax for form controls with `BindableAction`
- Should use `.analyticsScreen()` or similar view modifiers for cross-cutting concerns
- Should use `#Preview(trait: .dependencies { ... })` for dependency overrides in previews

```swift
struct ProfileView: View {
    @Bindable var store: StoreOf<ProfileFeature>

    var body: some View {
        VStack(spacing: 16) {
            if let user = store.user {
                UserInfoView(user: user)

                Button("Edit Profile") {
                    store.send(.editProfileButtonTapped)
                }
                .buttonStyle(.borderedProminent)
            }

            if store.isLoading {
                ProgressView()
            }

            if let error = store.error {
                Text(error.localizedDescription)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .onAppear {
            store.send(.onAppear)
        }
        .sheet(
            store: $store.scope(state: \.$editProfile, action: \.editProfile)
        ) { store in
            EditProfileView(store: store)
        }
        .analyticsScreen(name: "profile")
    }
}
```

## TCA Patterns and Best Practices

### Dependency Management

```swift
// Define a dependency client using @DependencyClient macro
@DependencyClient
struct UserClient: Sendable {
    var getCurrentUser: @Sendable () async throws -> User = {
        throw UserError.notAuthenticated
    }

    var updateUser: @Sendable (User) async throws -> Void = { _ in
        throw UserError.updateFailed
    }

    var observeCurrentUser: @Sendable () -> AsyncStream<User> = {
        AsyncStream { continuation in continuation.finish() }
    }
}

// Register the dependency with DependencyValues
extension UserClient: DependencyKey {
    static let liveValue = Self(
        getCurrentUser: {
            // Live implementation using Firebase or other backend
            let auth = Auth.auth()
            guard let user = auth.currentUser else {
                throw UserError.notAuthenticated
            }
            return try await fetchUserProfile(for: user.uid)
        },
        updateUser: { user in
            // Live implementation
            try await updateUserProfile(user)
        },
        observeCurrentUser: {
            // Live implementation using Firebase listeners
            AsyncStream { continuation in
                let listener = listenForUserChanges { user in
                    continuation.yield(user)
                }
                continuation.onTermination = { _ in
                    listener.remove()
                }
            }
        }
    )

    static let testValue = Self(
        getCurrentUser: unimplemented("UserClient.getCurrentUser"),
        updateUser: unimplemented("UserClient.updateUser"),
        observeCurrentUser: unimplemented("UserClient.observeCurrentUser")
    )
}

extension DependencyValues {
    var userClient: UserClient {
        get { self[UserClient.self] }
        set { self[UserClient.self] = newValue }
    }
}

// Using the dependency in a feature
@Reducer
struct ProfileFeature {
    // ...

    @Dependency(\.\.userClient) var userClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    do {
                        let user = try await userClient.getCurrentUser()
                        await send(.userLoaded(.success(user)))
                    } catch {
                        await send(.userLoaded(.failure(error)))
                    }
                }

                // ...
            }
        }
    }
}
```

### Testing with Dependencies

```swift
@Test
func testProfileFeature() async {
    let store = TestStore(initialState: ProfileFeature.State()) {
        ProfileFeature()
    } withDependencies: {
        $0.userClient.getCurrentUser = {
            User(id: "test-id", name: "Test User", email: "test@example.com")
        }
        $0.userClient.updateUser = { _ in }
    }

    await store.send(.onAppear) {
        $0.isLoading = true
    }

    await store.receive(\.\.userLoaded(.success)) {
        $0.user = User(id: "test-id", name: "Test User", email: "test@example.com")
        $0.isLoading = false
    }
}
```

### Parent-Child Communication

```swift
// Child feature with delegate actions
@Reducer
struct ChildFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var value: String = ""
    }

    enum Action: Equatable, Sendable {
        case setValue(String)
        case saveButtonTapped
        case cancelButtonTapped
        case delegate(DelegateAction)

        enum DelegateAction: Equatable, Sendable {
            case saved(String)
            case cancelled
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .setValue(value):
                state.value = value
                return .none

            case .saveButtonTapped:
                return .send(.delegate(.saved(state.value)))

            case .cancelButtonTapped:
                return .send(.delegate(.cancelled))

            case .delegate:
                return .none
            }
        }
    }
}

// Parent feature handling delegate actions
@Reducer
struct ParentFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var savedValue: String = ""
        @Presents var child: ChildFeature.State?
    }

    enum Action: Equatable, Sendable {
        case showChild
        case child(PresentationAction<ChildFeature.Action>)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .showChild:
                state.child = ChildFeature.State()
                return .none

            case .child(.presented(.delegate(.saved(let value)))):
                state.savedValue = value
                state.child = nil
                return .none

            case .child(.presented(.delegate(.cancelled))):
                state.child = nil
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

### Form Handling with BindableAction

```swift
@Reducer
struct ProfileFormFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        @BindingState var name: String = ""
        @BindingState var email: String = ""
        @BindingState var phoneNumber: String = ""

        var isValid: Bool {
            !name.isEmpty && !email.isEmpty && !phoneNumber.isEmpty
        }
    }

    enum Action: Equatable, Sendable, BindableAction {
        case binding(BindingAction<State>)
        case saveButtonTapped
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .saveButtonTapped:
                // Handle save action
                return .none
            }
        }
    }
}

struct ProfileFormView: View {
    @Bindable var store: StoreOf<ProfileFormFeature>

    var body: some View {
        Form {
            TextField("Name", text: $store.name)
            TextField("Email", text: $store.email)
            TextField("Phone Number", text: $store.phoneNumber)

            Button("Save") {
                store.send(.saveButtonTapped)
            }
            .disabled(!store.isValid)
        }
    }
}
```

### Navigation with TCA

```swift
@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var path = StackState<Path.State>()
        var home = HomeFeature.State()
    }

    enum Action: Equatable, Sendable {
        case path(StackAction<Path.State, Path.Action>)
        case home(HomeFeature.Action)
    }

    @Reducer
    struct Path {
        enum State: Equatable, Sendable {
            case profile(ProfileFeature.State)
            case settings(SettingsFeature.State)
            case details(DetailsFeature.State)
        }

        enum Action: Equatable, Sendable {
            case profile(ProfileFeature.Action)
            case settings(SettingsFeature.Action)
            case details(DetailsFeature.Action)
        }

        var body: some ReducerOf<Self> {
            Scope(state: /State.profile, action: /Action.profile) {
                ProfileFeature()
            }
            Scope(state: /State.settings, action: /Action.settings) {
                SettingsFeature()
            }
            Scope(state: /State.details, action: /Action.details) {
                DetailsFeature()
            }
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .home(.profileButtonTapped):
                state.path.append(.profile(ProfileFeature.State()))
                return .none

            case .home(.settingsButtonTapped):
                state.path.append(.settings(SettingsFeature.State()))
                return .none

            case .home(.detailsButtonTapped(let id)):
                state.path.append(.details(DetailsFeature.State(id: id)))
                return .none

            case .path:
                return .none

            case .home:
                return .none
            }
        }
        .forEach(\.path, action: \.path) {
            Path()
        }

        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
    }
}

struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        NavigationStack(
            path: $store.scope(state: \.path, action: \.path)
        ) {
            HomeView(
                store: store.scope(state: \.home, action: \.home)
            )
            .navigationDestination(
                for: StackState<AppFeature.Path.State>.Element.self
            ) { element in
                switch element.state {
                case .profile:
                    ProfileView(
                        store: store.scope(
                            state: { _ in element.state },
                            action: { .path(.element(id: element.id, action: $0)) }
                        )
                    )
                case .settings:
                    SettingsView(
                        store: store.scope(
                            state: { _ in element.state },
                            action: { .path(.element(id: element.id, action: $0)) }
                        )
                    )
                case .details:
                    DetailsView(
                        store: store.scope(
                            state: { _ in element.state },
                            action: { .path(.element(id: element.id, action: $0)) }
                        )
                    )
                }
            }
        }
    }
}
```

## Performance Optimization

### Using onChange for Selective Effect Execution

```swift
@Reducer
struct FeatureWithOptimization {
    @ObservableState
    struct State: Equatable, Sendable {
        var count = 0
        var name = ""
        var isEnabled = false
    }

    enum Action: Equatable, Sendable, BindableAction {
        case binding(BindingAction<State>)
        case countChanged(Int)
        case nameChanged(String)
        case enabledChanged(Bool)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .countChanged, .nameChanged, .enabledChanged:
                return .none
            }
        }
        .onChange(of: \.count) { oldValue, newValue in
            // This effect only runs when count changes
            return .send(.countChanged(newValue))
        }
        .onChange(of: \.name) { oldValue, newValue in
            // This effect only runs when name changes
            return .send(.nameChanged(newValue))
        }
        .onChange(of: \.isEnabled) { oldValue, newValue in
            // This effect only runs when isEnabled changes
            return .send(.enabledChanged(newValue))
        }
    }
}
```

### Debugging State Changes

```swift
// During development, use _printChanges() to identify unnecessary state updates
var body: some ReducerOf<Self> {
    Reduce { state, action in
        // ...
    }
    ._printChanges()
}
```

### CPU-Intensive Work

```swift
// Use Task.yield() for CPU-intensive work
return .run { send in
    var result = // ...
    for (index, value) in someLargeCollection.enumerated() {
        // Some intense computation with value

        // Yield every once in awhile to cooperate in the thread pool
        if index.isMultiple(of: 1_000) {
            await Task.yield()
        }
    }
    await send(.computationResponse(result))
}
```
