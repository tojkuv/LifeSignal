# Production Application Views

## Purpose

This document outlines the view architecture, components, and design patterns for the iOS Production Application using The Composable Architecture (TCA).

## Core Principles

### Type Safety

- Use strongly typed view modifiers
- Implement type-safe theme constants
- Create typed wrappers for UI components
- Use enums for finite UI states

### Modularity/Composability

- Build small, reusable UI components
- Compose complex views from simpler components
- Implement consistent view builder patterns
- Create modular view modifiers

### Testability

- Create preview providers for all components
- Implement snapshot testing for UI verification
- Design components with testability in mind
- Use dependency injection for view dependencies

## Content Structure

### View Architecture

#### View Structure

Each view follows a consistent structure:

```
Views/
└── FeatureName/
    ├── FeatureNameView.swift     // Main view for the feature
    ├── FeatureNameComponents.swift // Subcomponents specific to the feature
    └── FeatureNameTests.swift    // View tests (snapshots, etc.)
```

#### View-Feature Connection

Views should be connected to their corresponding TCA features:

```swift
struct ProfileView: View {
    @Bindable var store: StoreOf<ProfileFeature>

    var body: some View {
        VStack {
            Text(store.user.displayName)
                .font(.title)

            Text(store.user.email)
                .font(.subheadline)

            Button("Edit Profile") {
                store.send(.editProfileButtonTapped)
            }
            .sheet(
                store: store.scope(
                    state: \.$editProfile,
                    action: \.editProfile
                )
            ) { store in
                EditProfileView(store: store)
            }
        }
    }
}
```

### View Components

#### Buttons

Button variants include:

- Primary buttons
- Secondary buttons
- Text buttons
- Icon buttons

Example implementation:

```swift
struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.accent)
                .cornerRadius(10)
        }
    }
}
```

#### Text Fields

Text field variants include:

- Standard text fields
- Secure text fields
- Text areas
- Search fields

Example implementation with TCA binding:

```swift
struct StandardTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .padding()
            .background(Color.secondaryBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}

// Usage in a TCA view
struct EditProfileView: View {
    @Bindable var store: StoreOf<EditProfileFeature>

    var body: some View {
        Form {
            StandardTextField(
                placeholder: "Name",
                text: $store.displayName
            )

            Button("Save") {
                store.send(.saveButtonTapped)
            }
        }
    }
}
```

#### Cards

Card components for displaying grouped content:

- Standard cards
- Interactive cards
- List item cards

Example implementation:

```swift
struct StandardCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(Color.secondaryBackground)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
```

### Navigation Patterns

#### Tab Navigation

Tab navigation using TCA:

```swift
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

#### Stack Navigation

Stack navigation using TCA:

```swift
struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.items) { item in
                    NavigationLink(
                        state: HomeFeature.Path.State.detail(
                            DetailFeature.State(item: item)
                        )
                    ) {
                        ItemRow(item: item)
                    }
                }
            }
            .navigationTitle("Home")
            .navigationDestination(
                for: HomeFeature.Path.State.self,
                destination: { state in
                    SwitchStore(store.scope(state: \.path, action: \.path)) { state in
                        switch state {
                        case .detail:
                            CaseLet(
                                /HomeFeature.Path.State.detail,
                                action: HomeFeature.Path.Action.detail,
                                then: DetailView.init(store:)
                            )
                        }
                    }
                }
            )
        }
    }
}
```

#### Modal Presentation

Modal presentation using TCA:

```swift
struct ProfileView: View {
    @Bindable var store: StoreOf<ProfileFeature>

    var body: some View {
        VStack {
            // Content

            Button("Edit Profile") {
                store.send(.editProfileButtonTapped)
            }
            .sheet(
                store: store.scope(
                    state: \.$editProfile,
                    action: \.editProfile
                )
            ) { store in
                EditProfileView(store: store)
            }
        }
    }
}
```

Example implementation:

```swift
Text("Label")
    .font(.body)
    .foregroundColor(.primaryText)
    .accessibilityLabel("Descriptive label")
    .accessibilityHint("Tap to perform action")
```

### Migration from Mock Application

#### Component Transformation

Transform SwiftUI views from MVVM to TCA by copying the view and updating it to use TCA instead of MVVM:

#### MVVM Component:

```swift
// Example: MVVM Profile View
struct ProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        VStack {
            Text(viewModel.user.displayName)
                .font(.title)

            Text(viewModel.user.email)
                .font(.subheadline)

            Button("Edit Profile") {
                viewModel.showEditProfile = true
            }
            .sheet(isPresented: $viewModel.showEditProfile) {
                EditProfileView(viewModel: viewModel.editProfileViewModel)
            }
        }
    }
}
```

#### TCA Component:

```swift
// Example: TCA Profile View (copied from MVVM view and updated)
struct ProfileView: View {
    @Bindable var store: StoreOf<ProfileFeature>

    var body: some View {
        VStack {
            Text(store.user.displayName)
                .font(.title)

            Text(store.user.email)
                .font(.subheadline)

            Button("Edit Profile") {
                store.send(.editProfileButtonTapped)
            }
            .sheet(
                store: store.scope(
                    state: \.$editProfile,
                    action: \.editProfile
                )
            ) { store in
                EditProfileView(store: store)
            }
        }
    }
}
```

#### View Migration Strategy

Instead of reusing or wrapping MVVM views, copy and transform them to TCA:

1. **Copy the View**: Copy the MVVM view to the production application
2. **Update Dependencies**: Change from @ObservedObject to @Bindable store
3. **Update Bindings**: Replace view model bindings with store bindings
4. **Update Actions**: Replace view model methods with store actions

```swift
// INCORRECT: Do not create wrappers around MVVM views
// ❌ Don't do this
struct ProfileViewWrapper: View {
    @Bindable var store: StoreOf<ProfileFeature>

    var body: some View {
        // Create a view model from TCA state
        let viewModel = ProfileViewModel(
            user: store.user,
            onUserUpdated: { updatedUser in
                // Send TCA action when user is updated
                store.send(.userUpdated(updatedUser))
            }
        )

        // Use the existing MVVM view
        ProfileView(viewModel: viewModel)
    }
}

// CORRECT: Copy and transform the view
// ✅ Do this instead
struct ProfileView: View {
    @Bindable var store: StoreOf<ProfileFeature>

    var body: some View {
        VStack {
            Text(store.user.displayName)
                .font(.title)

            Text(store.user.email)
                .font(.subheadline)

            Button("Edit Profile") {
                store.send(.editProfileButtonTapped)
            }
            .sheet(
                store: store.scope(
                    state: \.$editProfile,
                    action: \.editProfile
                )
            ) { store in
                EditProfileView(store: store)
            }
        }
    }
}
```

#### Binding Migration

Transform two-way bindings from MVVM to TCA:

#### MVVM Binding:

```swift
// Example: MVVM Binding
struct EditProfileView: View {
    @ObservedObject var viewModel: EditProfileViewModel

    var body: some View {
        Form {
            TextField("Name", text: $viewModel.displayName)

            Button("Save") {
                viewModel.save()
            }
        }
    }
}
```

#### TCA Binding:

```swift
// Example: TCA Binding
struct EditProfileView: View {
    @Bindable var store: StoreOf<EditProfileFeature>

    var body: some View {
        Form {
            TextField("Name", text: $store.displayName)

            Button("Save") {
                store.send(.saveButtonTapped)
            }
        }
    }
}
```

## Error Handling

### Error Types

The production application handles the following error types:

- **Network Errors**: Connection issues, timeouts, server unavailable
- **Authentication Errors**: Invalid credentials, expired tokens, unauthorized access
- **Data Errors**: Missing data, invalid format, parsing errors
- **Business Logic Errors**: Application-specific validation errors
- **Server Errors**: Backend failures, API errors, unexpected responses

### Error Presentation Patterns

#### Alert-Based Error Handling

```swift
struct ProfileView: View {
    @Bindable var store: StoreOf<ProfileFeature>

    var body: some View {
        VStack {
            // Main content
            if let user = store.user {
                ProfileContentView(user: user)
            } else if store.isLoading {
                ProgressView()
            }
        }
        .alert(
            store: store.scope(state: \.$alert, action: \.alert)
        )
        .onAppear {
            store.send(.loadProfile)
        }
    }
}

// In the Feature file
@Reducer
struct ProfileFeature {
    @ObservableState
    struct State: Equatable {
        var user: User?
        var isLoading = false
        @Presents var alert: AlertState<Action.Alert>?
    }

    enum Action: Equatable {
        case loadProfile
        case profileResponse(Result<User, Error>)
        case alert(PresentationAction<Alert>)
        case retry

        enum Alert: Equatable {}
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .profileResponse(.failure(let error)):
                state.isLoading = false
                state.alert = AlertState {
                    TextState("Error Loading Profile")
                } actions: {
                    ButtonState(role: .cancel) {
                        TextState("Dismiss")
                    }
                    ButtonState {
                        TextState("Retry")
                    } action: .retry
                } message: {
                    TextState(error.localizedDescription)
                }
                return .none

            case .retry:
                return .send(.loadProfile)

            // Other cases
            }
        }
    }
}
```

#### Inline Error Handling

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

            // Error overlay
            if let error = store.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)

                    Text(errorTitle(for: error))
                        .font(.headline)

                    Text(errorMessage(for: error))
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button("Try Again") {
                        store.send(.retry)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Dismiss") {
                        store.send(.dismissError)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Material.regularMaterial)
                .cornerRadius(16)
                .shadow(radius: 4)
                .padding()
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .onAppear {
            store.send(.loadProfile)
        }
    }

    private func errorTitle(for error: ProfileFeature.ErrorState) -> String {
        switch error {
        case .networkError:
            return "Network Error"
        case .authError:
            return "Authentication Error"
        case .serverError:
            return "Server Error"
        }
    }

    private func errorMessage(for error: ProfileFeature.ErrorState) -> String {
        switch error {
        case .networkError(let message):
            return message
        case .authError(let message):
            return message
        case .serverError(let message):
            return message
        }
    }
}
```

### Error State Mapping

Map low-level errors to user-friendly error states in the reducer:

```swift
private func mapError(_ error: Error) -> State.ErrorState {
    if let networkError = error as? NetworkError {
        switch networkError {
        case .connectionFailed:
            return .networkError(message: "Cannot connect to the server. Please check your internet connection.")
        case .timeout:
            return .networkError(message: "The request timed out. Please try again.")
        case .serverError(let statusCode):
            return .serverError(message: "Server error occurred (Code: \(statusCode)). Please try again later.")
        }
    } else if let authError = error as? AuthenticationError {
        return .authError(message: "Your session has expired. Please sign in again.")
    }

    return .serverError(message: "An unexpected error occurred. Please try again.")
}
```

### Error Recovery Patterns

- **Automatic Retry**: Implement automatic retry for transient errors
- **User-Initiated Retry**: Provide retry buttons for user-initiated recovery
- **Graceful Degradation**: Show partial content when possible
- **Offline Support**: Cache data for offline access
- **Error Logging**: Log errors for debugging and analytics

## Testing

### Unit Testing Strategy

The production application implements a comprehensive testing strategy:

1. **Component Testing**: Test individual UI components in isolation
2. **State Testing**: Verify UI renders correctly for different states
3. **Interaction Testing**: Test user interactions and state changes
4. **Accessibility Testing**: Ensure UI meets accessibility standards
5. **Responsive Testing**: Verify layouts across device sizes and orientations

### Preview Testing

Create comprehensive preview providers for all views:

```swift
#Preview("Default State") {
    ProfileView(
        store: Store(initialState: ProfileFeature.State()) {
            ProfileFeature()
        }
    )
}

#Preview("Loading State") {
    ProfileView(
        store: Store(initialState: ProfileFeature.State(isLoading: true)) {
            ProfileFeature()
        }
    )
}

#Preview("Loaded State") {
    ProfileView(
        store: Store(
            initialState: ProfileFeature.State(
                user: User(id: "1", name: "John Doe", email: "john@example.com")
            )
        ) {
            ProfileFeature()
        }
    )
}

#Preview("Error State") {
    ProfileView(
        store: Store(
            initialState: ProfileFeature.State(
                error: .networkError(message: "Cannot connect to the server")
            )
        ) {
            ProfileFeature()
        }
    )
}
```

### Snapshot Testing

Implement snapshot tests for UI verification:

```swift
import XCTest
import SnapshotTesting
import SwiftUI
import ComposableArchitecture
@testable import MyApp

class ProfileViewTests: XCTestCase {
    func testProfileView_DefaultState() {
        let view = ProfileView(
            store: Store(initialState: ProfileFeature.State()) {
                ProfileFeature()
            }
        )

        let hostingController = UIHostingController(rootView: view)
        assertSnapshot(matching: hostingController, as: .image(on: .iPhone13))
    }

    func testProfileView_LoadingState() {
        let view = ProfileView(
            store: Store(initialState: ProfileFeature.State(isLoading: true)) {
                ProfileFeature()
            }
        )

        let hostingController = UIHostingController(rootView: view)
        assertSnapshot(matching: hostingController, as: .image(on: .iPhone13))
    }

    func testProfileView_LoadedState() {
        let view = ProfileView(
            store: Store(
                initialState: ProfileFeature.State(
                    user: User(id: "1", name: "John Doe", email: "john@example.com")
                )
            ) {
                ProfileFeature()
            }
        )

        let hostingController = UIHostingController(rootView: view)
        assertSnapshot(matching: hostingController, as: .image(on: .iPhone13))
    }

    func testProfileView_ErrorState() {
        let view = ProfileView(
            store: Store(
                initialState: ProfileFeature.State(
                    error: .networkError(message: "Cannot connect to the server")
                )
            ) {
                ProfileFeature()
            }
        )

        let hostingController = UIHostingController(rootView: view)
        assertSnapshot(matching: hostingController, as: .image(on: .iPhone13))
    }
}
```

### Accessibility Testing

Test accessibility support:

```swift
func testProfileView_Accessibility() {
    let view = ProfileView(
        store: Store(
            initialState: ProfileFeature.State(
                user: User(id: "1", name: "John Doe", email: "john@example.com")
            )
        ) {
            ProfileFeature()
        }
    )

    let hostingController = UIHostingController(rootView: view)
    let accessibilityElements = hostingController.view.accessibilityElements ?? []

    XCTAssertTrue(accessibilityElements.count > 0, "View should have accessibility elements")

    // Verify specific accessibility elements
    let nameLabel = accessibilityElements.first {
        ($0 as? UIAccessibilityElement)?.accessibilityLabel == "Name: John Doe"
    }
    XCTAssertNotNil(nameLabel, "Name label should be accessible")

    let editButton = accessibilityElements.first {
        ($0 as? UIAccessibilityElement)?.accessibilityLabel == "Edit Profile"
    }
    XCTAssertNotNil(editButton, "Edit button should be accessible")
    XCTAssertEqual(
        (editButton as? UIAccessibilityElement)?.accessibilityTraits,
        .button,
        "Edit button should have button traits"
    )
}
```

### UI Testing with XCUITest

```swift
func testProfileView_EditProfile() {
    let app = XCUIApplication()
    app.launch()

    // Navigate to profile
    app.tabBars.buttons["Profile"].tap()

    // Verify profile elements
    XCTAssertTrue(app.staticTexts["John Doe"].exists)
    XCTAssertTrue(app.staticTexts["john@example.com"].exists)

    // Tap edit profile
    app.buttons["Edit Profile"].tap()

    // Verify edit profile sheet appeared
    XCTAssertTrue(app.textFields["Name"].exists)

    // Edit name
    let nameField = app.textFields["Name"]
    nameField.tap()
    nameField.typeText(" Updated")

    // Save changes
    app.buttons["Save"].tap()

    // Verify profile updated
    XCTAssertTrue(app.staticTexts["John Doe Updated"].exists)
}
```

### Testing Different Device Sizes and Orientations

```swift
func testProfileView_DifferentDevices() {
    let view = ProfileView(
        store: Store(
            initialState: ProfileFeature.State(
                user: User(id: "1", name: "John Doe", email: "john@example.com")
            )
        ) {
            ProfileFeature()
        }
    )

    // Test on iPhone SE (smallest supported device)
    assertSnapshot(matching: UIHostingController(rootView: view), as: .image(on: .iPhoneSE))

    // Test on iPhone 13 Pro Max (largest iPhone)
    assertSnapshot(matching: UIHostingController(rootView: view), as: .image(on: .iPhone13ProMax))

    // Test on iPad
    assertSnapshot(matching: UIHostingController(rootView: view), as: .image(on: .iPadPro11))

    // Test in landscape orientation
    assertSnapshot(
        matching: UIHostingController(rootView: view),
        as: .image(on: .iPhone13, traits: .landscapeRight)
    )
}
```

## Best Practices

* Use SwiftUI previews for rapid UI development
* Maintain consistent spacing and alignment
* Implement responsive layouts that adapt to different screen sizes
* Use semantic colors instead of hard-coded values
* Implement proper accessibility support
* Follow Apple's Human Interface Guidelines
* Break up complex views into computed properties for different sections
* Use TCA binding for form inputs
* Keep views focused on presentation, not logic
* Implement consistent error handling across all views

## Anti-patterns

* Creating reusable UI components that increase coupling
* Using local state in views (@State, @StateObject)
* Mixing UI and business logic
* Ignoring accessibility
* Inconsistent error handling
* Deeply nested view hierarchies
* Implementing business logic in views
* Not testing views with different states