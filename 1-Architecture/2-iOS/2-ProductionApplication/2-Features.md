# Production Application Features

## Purpose

This document outlines the feature architecture, organization, and state management for the iOS Production Application using The Composable Architecture (TCA).

## Core Principles

### Type Safety

- Use strongly typed state and actions
- Implement type-safe dependencies
- Create typed effects
- Use enums for representing all possible actions

### Modularity/Composability

- Organize code by features
- Compose child features into parent features
- Implement reusable reducers
- Create modular effects

### Testability

- Test reducers with TestStore
- Mock dependencies for isolated testing
- Create test cases for all action paths
- Verify state changes and effects

## Content Structure

### Feature Organization

#### Feature Structure

Each feature follows a consistent structure:

```
Features/
└── FeatureName/
    ├── FeatureNameFeature.swift  // Reducer, State, and Action
    ├── FeatureNameView.swift     // SwiftUI View
    └── FeatureNameTests.swift    // Tests
```

#### Top-Level AppState

The top-level AppState should be organized to reflect the application's structure:

```swift
@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        // Authentication state
        var authState: AuthState = .unauthenticated
        var user: User?

        // Main application tabs
        var mainTab: MainTabFeature.State?

        // Onboarding flow
        var onboarding: OnboardingFeature.State?

        // Authentication flow
        var authentication: AuthenticationFeature.State?

        // Deep linking
        var deepLinkTarget: DeepLinkTarget?

        // App lifecycle
        var isActive = true

        enum AuthState: Equatable, Sendable {
            case unauthenticated
            case authenticating
            case authenticated
        }
    }

    enum Action: Equatable, Sendable {
        // Authentication actions
        case authResponse(Result<User, Error>)
        case signOut

        // Child feature actions
        case mainTab(MainTabFeature.Action)
        case onboarding(OnboardingFeature.Action)
        case authentication(AuthenticationFeature.Action)

        // Deep linking
        case handleDeepLink(URL)
        case processDeepLink

        // App lifecycle
        case appDelegate(AppDelegateAction)
        case scenePhase(ScenePhase)
    }

    // ...
}
```

#### Feature Definition

Features are defined using the `@Reducer` macro:

```swift
@Reducer
struct FeatureName {
    @ObservableState
    struct State: Equatable, Sendable {
        // State properties
        var property: String = ""

        // Child feature states
        var childFeature: ChildFeature.State?

        // Presentation states
        @Presents var destination: Destination.State?
    }

    enum Action: Equatable, Sendable {
        // User actions
        case buttonTapped
        case textChanged(String)

        // Effect actions
        case dataLoaded(Result<Data, Error>)

        // Child feature actions
        case childFeature(ChildFeature.Action)

        // Presentation actions
        case destination(PresentationAction<Destination.Action>)
    }

    // Destinations enum for navigation
    enum Destination: Equatable, Sendable {
        case detail(DetailFeature.State)
        case settings(SettingsFeature.State)
    }

    // Dependencies
    @Dependency(\.apiClient) var apiClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            // Handle actions and return effects
            switch action {
            case .buttonTapped:
                return .run { send in
                    let result = try await apiClient.fetchData()
                    await send(.dataLoaded(result))
                }

            case let .textChanged(text):
                state.property = text
                return .none

            case let .dataLoaded(.success(data)):
                // Update state with loaded data
                return .none

            case .dataLoaded(.failure):
                // Handle error
                return .none

            case .childFeature, .destination:
                return .none
            }
        }
        .ifLet(\.childFeature, action: \.childFeature) {
            ChildFeature()
        }
        .ifLet(\.$destination, action: \.destination) {
            Destination()
        }
    }
}

// Destination reducer
@Reducer
struct Destination {
    @ObservableState
    enum State: Equatable, Sendable {
        case detail(DetailFeature.State)
        case settings(SettingsFeature.State)
    }

    enum Action: Equatable, Sendable {
        case detail(DetailFeature.Action)
        case settings(SettingsFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.detail, action: \.detail) {
            DetailFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
    }
}
```

### State Management

#### State Design

State is designed with the following principles:

1. **Immutability**: All state is immutable and only changed through reducers
2. **Equatable**: All state conforms to Equatable for efficient diffing
3. **Sendable**: All state conforms to Sendable for concurrency safety
4. **Minimal**: Only include what's necessary for the feature
5. **Hierarchical**: Parent features contain child feature states

#### State Sharing

State can be shared between features using:

1. **Parent-Child Relationship**: Parent features own child feature states
2. **Shared State**: Using the `@Shared` property wrapper
3. **Dependencies**: Injecting shared state through dependencies

### Action Design

Actions follow these principles:

1. **Comprehensive**: All possible actions are represented
2. **Categorized**: Actions are grouped by their source or purpose
3. **Descriptive**: Action names clearly describe their intent
4. **Payload-Carrying**: Actions carry necessary data as associated values

### Effect Management

Effects are implemented using:

1. **Run Effects**: Using `.run` for async operations
2. **Cancellation**: Using cancellation IDs for cancellable effects
3. **Error Handling**: Proper error handling within effects
4. **Composition**: Combining multiple effects when needed

Example:

```swift
case .loadData:
    return .run { send in
        do {
            let data = try await apiClient.fetchData()
            await send(.dataLoaded(.success(data)))
        } catch {
            await send(.dataLoaded(.failure(error)))
        }
    }
    .cancellable(id: CancelID.loadData)
```

### Navigation

Navigation is implemented using:

1. **Optional State**: Using optional state for destinations
2. **Presentation Actions**: Using `PresentationAction` for handling child actions
3. **Destination Enums**: Using enums for multiple destinations
4. **Navigation Stack**: Using `NavigationStackStore` for deep navigation

Example:

```swift
struct FeatureView: View {
    @Bindable var store: StoreOf<FeatureNameFeature>

    var body: some View {
        NavigationStack {
            VStack {
                // Content
                Button("Show Detail") {
                    store.send(.showDetail)
                }
            }
            .sheet(
                store: store.scope(
                    state: \.$destination.detail,
                    action: \.destination.detail
                )
            ) { store in
                DetailView(store: store)
            }
        }
    }
}
```

### Dependency Management

Dependencies are managed using:

1. **Dependency Protocol**: Defining interfaces for dependencies
2. **Dependency Values**: Implementing live, test, and preview values
3. **Dependency Injection**: Using the `@Dependency` property wrapper
4. **Dependency Overrides**: Overriding dependencies for testing

Example:

```swift
// Define the client protocol
protocol APIClientProtocol {
    func fetchData() async throws -> Data
}

// Define the dependency key
private enum APIClientKey: DependencyKey {
    static let liveValue: APIClientProtocol = LiveAPIClient()
    static let testValue: APIClientProtocol = MockAPIClient()
    static let previewValue: APIClientProtocol = PreviewAPIClient()
}

// Register the dependency
extension DependencyValues {
    var apiClient: APIClientProtocol {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}
```

### Migration from Mock Application

#### Navigation Transformation

Transform navigation from MVVM to TCA:

#### MVVM Navigation:

```swift
// Example: MVVM Tab Navigation
struct MainTabView: View {
    @ObservedObject var viewModel: MainTabViewModel

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            HomeView(viewModel: viewModel.homeViewModel)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(Tab.home)

            ProfileView(viewModel: viewModel.profileViewModel)
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .tag(Tab.profile)
        }
    }
}
```

#### TCA Navigation:

```swift
// Example: TCA Tab Navigation
@Reducer
struct MainTabFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var selectedTab: Tab = .home
        var home: HomeFeature.State
        var profile: ProfileFeature.State
    }

    enum Action: Equatable, Sendable {
        case selectedTabChanged(Tab)
        case home(HomeFeature.Action)
        case profile(ProfileFeature.Action)
    }

    enum Tab: Equatable, Sendable {
        case home
        case profile
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .selectedTabChanged(tab):
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

struct MainTabView: View {
    @Bindable var store: StoreOf<MainTabFeature>

    var body: some View {
        TabView(selection: $store.selectedTab) {
            HomeView(
                store: store.scope(
                    state: \.home,
                    action: \.home
                )
            )
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(MainTabFeature.Tab.home)

            ProfileView(
                store: store.scope(
                    state: \.profile,
                    action: \.profile
                )
            )
            .tabItem {
                Label("Profile", systemImage: "person")
            }
            .tag(MainTabFeature.Tab.profile)
        }
    }
}
```

#### Deep Linking

Migrate deep linking from MVVM to TCA:

```swift
// Example: TCA Deep Link Handler
@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var mainTab: MainTabFeature.State
        var deepLinkTarget: DeepLinkTarget?
    }

    enum Action: Equatable, Sendable {
        case mainTab(MainTabFeature.Action)
        case handleDeepLink(URL)
        case processDeepLink
    }

    enum DeepLinkTarget: Equatable, Sendable {
        case profile
        case item(String)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .handleDeepLink(url):
                guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                      let host = components.host else {
                    return .none
                }

                switch host {
                case "profile":
                    state.deepLinkTarget = .profile
                    return .send(.processDeepLink)

                case "item":
                    if let itemId = components.queryItems?.first(where: { $0.name == "id" })?.value {
                        state.deepLinkTarget = .item(itemId)
                        return .send(.processDeepLink)
                    }
                    return .none

                default:
                    return .none
                }

            case .processDeepLink:
                guard let target = state.deepLinkTarget else {
                    return .none
                }

                switch target {
                case .profile:
                    state.mainTab.selectedTab = .profile

                case let .item(itemId):
                    state.mainTab.selectedTab = .home
                    state.mainTab.home.selectedItemId = itemId
                }

                state.deepLinkTarget = nil
                return .none

            case .mainTab:
                return .none
            }
        }

        Scope(state: \.mainTab, action: \.mainTab) {
            MainTabFeature()
        }
    }
}
```

#### ViewModel to Reducer

Transform ViewModels to TCA Reducers by creating features from mock view models:

#### MVVM ViewModel:

```swift
// Example: MVVM ViewModel
class ProfileViewModel: ObservableObject {
    @Published var user: User
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showEditProfile = false

    private let userRepository: UserRepository

    init(user: User, userRepository: UserRepository = MockUserRepository()) {
        self.user = user
        self.userRepository = userRepository
    }

    var editProfileViewModel: EditProfileViewModel {
        EditProfileViewModel(user: user) { [weak self] updatedUser in
            self?.updateUser(updatedUser)
        }
    }

    func updateUser(_ updatedUser: User) {
        isLoading = true

        Task {
            do {
                let updated = try await userRepository.updateUser(
                    id: updatedUser.id,
                    displayName: updatedUser.displayName
                )

                await MainActor.run {
                    self.user = updated
                    self.isLoading = false
                    self.error = nil
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
}
```

#### TCA Reducer (created from the view model):

```swift
// Example: TCA Reducer
@Reducer
struct ProfileFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var user: User
        var isLoading = false
        var error: Error?
        @Presents var editProfile: EditProfileFeature.State?
    }

    enum Action: Equatable, Sendable {
        case editProfileButtonTapped
        case updateUser(User)
        case userUpdateResponse(Result<User, Error>)
        case editProfile(PresentationAction<EditProfileFeature.Action>)
    }

    @Dependency(\.userClient) var userClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .editProfileButtonTapped:
                state.editProfile = EditProfileFeature.State(user: state.user)
                return .none

            case let .updateUser(user):
                state.isLoading = true
                state.error = nil

                return .run { [id = user.id] send in
                    do {
                        let updatedUser = try await userClient.updateUser(
                            id: id,
                            displayName: user.displayName
                        )
                        await send(.userUpdateResponse(.success(updatedUser)))
                    } catch {
                        await send(.userUpdateResponse(.failure(error)))
                    }
                }

            case let .userUpdateResponse(.success(user)):
                state.user = user
                state.isLoading = false
                return .none

            case let .userUpdateResponse(.failure(error)):
                state.error = error
                state.isLoading = false
                return .none

            case .editProfile(.presented(.saveButtonTapped)):
                if let editedUser = state.editProfile?.user {
                    state.editProfile = nil
                    return .send(.updateUser(editedUser))
                }
                return .none

            case .editProfile(.dismiss):
                state.editProfile = nil
                return .none

            case .editProfile:
                return .none
            }
        }
        .ifLet(\.$editProfile, action: \.editProfile) {
            EditProfileFeature()
        }
    }
}
```

#### Feature Creation Strategy

When creating TCA features from MVVM view models:

1. **Identify State**: Map published properties to state properties
2. **Identify Actions**: Map view model methods to actions
3. **Implement Reducer**: Transform view model logic to reducer logic
4. **Add Dependencies**: Replace repositories with TCA clients
5. **Handle Child Features**: Create child features for nested view models

## Error Handling

### Error State in Features

Include error state in feature state:

```swift
@Reducer
struct ProfileFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var user: User?
        var isLoading = false
        var error: ErrorState?

        enum ErrorState: Equatable, Sendable {
            case networkError(message: String)
            case userError(message: String)
            case permissionError(message: String)
        }
    }

    enum Action: Equatable, Sendable {
        case loadUser(id: String)
        case userResponse(Result<User, Error>)
        case dismissError
        case retryLastAction
    }

    @Dependency(\userClient) var userClient

    private struct LoadUserCancelID: Hashable {}
    private var lastUserID: String?

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .loadUser(id):
                state.isLoading = true
                state.error = nil
                lastUserID = id

                return .run { send in
                    do {
                        let user = try await userClient.getUser(id)
                        await send(.userResponse(.success(user)))
                    } catch let error as NSError {
                        if error.domain == NSURLErrorDomain {
                            await send(.userResponse(.failure(error)))
                        } else if error.domain == "UserClientError" {
                            await send(.userResponse(.failure(error)))
                        } else {
                            await send(.userResponse(.failure(error)))
                        }
                    }
                }
                .cancellable(id: LoadUserCancelID())

            case let .userResponse(.success(user)):
                state.user = user
                state.isLoading = false
                return .none

            case let .userResponse(.failure(error)):
                state.isLoading = false

                // Map error to appropriate ErrorState
                if let nsError = error as? NSError {
                    if nsError.domain == NSURLErrorDomain {
                        state.error = .networkError(message: "Network error: \(nsError.localizedDescription)")
                    } else if nsError.domain == "UserClientError" {
                        state.error = .userError(message: "User error: \(nsError.localizedDescription)")
                    } else {
                        state.error = .networkError(message: "Unknown error: \(nsError.localizedDescription)")
                    }
                } else {
                    state.error = .networkError(message: "Unknown error occurred")
                }
                return .none

            case .dismissError:
                state.error = nil
                return .none

            case .retryLastAction:
                if let id = lastUserID {
                    return .send(.loadUser(id))
                }
                return .none
            }
        }
    }
}
```

### Error Handling in Views

Implement error handling in views:

```swift
struct ProfileView: View {
    @Bindable var store: StoreOf<ProfileFeature>

    var body: some View {
        ZStack {
            // Main content
            if let user = store.user {
                ProfileContentView(user: user)
            } else if store.isLoading {
                ProgressView()
            }

            // Error handling
            if let error = store.error {
                VStack {
                    Spacer()

                    errorView(for: error)
                        .transition(.move(edge: .bottom))

                    Spacer()
                }
                .zIndex(1)
                .transition(.opacity)
            }
        }
        .onAppear {
            if store.user == nil && !store.isLoading {
                store.send(.loadUser(id: "current"))
            }
        }
    }

    @ViewBuilder
    private func errorView(for error: ProfileFeature.State.ErrorState) -> some View {
        VStack(spacing: 16) {
            switch error {
            case let .networkError(message):
                Label("Network Error", systemImage: "wifi.exclamationmark")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)

                Button("Try Again") {
                    store.send(.retryLastAction)
                }
                .buttonStyle(.borderedProminent)

            case let .userError(message):
                Label("User Error", systemImage: "person.fill.questionmark")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)

            case let .permissionError(message):
                Label("Permission Error", systemImage: "lock.fill")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }

            Button("Dismiss") {
                withAnimation {
                    store.send(.dismissError)
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Material.regularMaterial)
        .cornerRadius(16)
        .shadow(radius: 4)
        .padding()
    }
}
```

### Error Logging and Analytics

* Implement centralized error logging
* Track error frequency and patterns
* Log detailed error information for debugging
* Implement crash reporting
* Use analytics to track error rates

### Error Recovery Strategies

* Implement retry mechanisms for network errors
* Provide user-initiated retry options
* Implement graceful degradation for non-critical features
* Cache data for offline access
* Implement automatic recovery for transient errors

## Testing

### Feature Testing

Test features using the TestStore from TCA:

```swift
// Example: Testing a feature with TestStore
import XCTest
import ComposableArchitecture
@testable import MyApp

final class ProfileFeatureTests: XCTestCase {
    func testProfileFeature_LoadUser_Success() async {
        // Arrange
        let store = TestStore(
            initialState: ProfileFeature.State(),
            reducer: { ProfileFeature() }
        )

        // Override the dependency
        let user = User(id: "123", displayName: "Test User", email: "test@example.com")
        store.dependencies.userClient.getUser = { _ in
            return user
        }

        // Act & Assert
        await store.send(.loadUser(id: "123")) {
            $0.isLoading = true
        }

        await store.receive(.userResponse(.success(user))) {
            $0.user = user
            $0.isLoading = false
        }
    }

    func testProfileFeature_LoadUser_Failure() async {
        // Arrange
        let store = TestStore(
            initialState: ProfileFeature.State(),
            reducer: { ProfileFeature() }
        )

        // Override the dependency
        struct TestError: Error, Equatable {}
        store.dependencies.userClient.getUser = { _ in
            throw TestError()
        }

        // Act & Assert
        await store.send(.loadUser(id: "123")) {
            $0.isLoading = true
        }

        await store.receive(.userResponse(.failure(TestError()))) {
            $0.isLoading = false
            $0.error = .networkError(message: "An unknown error occurred. Please try again.")
        }
    }

    func testProfileFeature_DismissError() async {
        // Arrange
        let store = TestStore(
            initialState: ProfileFeature.State(
                error: .networkError(message: "Test error")
            ),
            reducer: { ProfileFeature() }
        )

        // Act & Assert
        await store.send(.dismissError) {
            $0.error = nil
        }
    }
}
```

### Integration Testing

Test feature interactions using integration tests:

```swift
// Example: Integration testing with TestStore
import XCTest
import ComposableArchitecture
@testable import MyApp

final class AppFeatureIntegrationTests: XCTestCase {
    func testAppFeature_DeepLink_ToProfile() async {
        // Arrange
        let store = TestStore(
            initialState: AppFeature.State(),
            reducer: { AppFeature() }
        )

        // Override dependencies
        let user = User(id: "123", displayName: "Test User")
        store.dependencies.userClient.getUser = { _ in
            return user
        }

        // Act & Assert
        let profileURL = URL(string: "myapp://profile?id=123")!
        await store.send(.handleDeepLink(profileURL)) {
            $0.deepLinkTarget = .profile(id: "123")
        }

        await store.receive(.processDeepLink) {
            $0.mainTab.selectedTab = .profile
            $0.mainTab.profile.isLoading = true
            $0.deepLinkTarget = nil
        }

        await store.receive(.mainTab(.profile(.userResponse(.success(user))))) {
            $0.mainTab.profile.user = user
            $0.mainTab.profile.isLoading = false
        }
    }
}
```

### Performance Testing

* Test feature performance with large data sets
* Measure memory usage during complex operations
* Test animation performance during state transitions
* Verify background operations don't block the UI

## Best Practices

* Organize code by features
* Keep features small and focused
* Implement proper error handling
* Use typed state and actions
* Create reusable reducers
* Test all action paths
* Document feature interfaces
* Use dependencies for external services
* Implement proper logging
* Keep reducers pure and testable
* Use consistent naming conventions

## Anti-patterns

* Creating monolithic features
* Not handling errors properly
* Using untyped state or actions
* Implementing side effects in reducers
* Not testing all action paths
* Using global state instead of dependencies
* Hardcoding dependencies
* Not documenting feature interfaces
* Mixing UI and business logic