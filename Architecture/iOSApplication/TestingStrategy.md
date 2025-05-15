# Testing Strategy

**Navigation:** [Back to iOS Architecture](README.md) | [TCA Implementation](TCAImplementation.md) | [Modern TCA Architecture](ComposableArchitecture.md) | [Core Principles](CorePrinciples.md)

---

> **Note:** As this is an MVP, the testing strategy may evolve as the project matures.

## Testing Approach

LifeSignal uses a comprehensive testing approach that covers all layers of the application:

1. **Unit Tests** - Test individual components in isolation
2. **Integration Tests** - Test interactions between components
3. **Feature Tests** - Test complete features
4. **UI Tests** - Test the user interface

## Testing Layers

### Infrastructure Testing

- Test domain models independently of infrastructure
- Test mappers with known input/output pairs
- Create mock implementations for core clients
- Test domain-specific clients with mocked core clients
- Test both success and error paths
- Test concurrency behavior
- Test offline behavior
- Test error handling

### Feature Testing

- Use `TestStore` to test reducers
- Test state changes for each action
- Test effect outputs
- Test child-parent feature interactions
- Mock dependencies using `withDependencies`
- Test navigation flows
- Test error states
- Test loading states
- Test edge cases

### Integration Testing

- Test feature composition
- Test feature coordination
- Test feature navigation
- Test feature embedding
- Test shared state
- Test end-to-end flows

### UI Testing

- Test view rendering
- Test user interactions
- Test accessibility
- Test dark mode
- Test dynamic type
- Test localization

## Testing Tools

### TestStore

The primary tool for testing TCA features is `TestStore`, which allows you to:

- Create a store with a specific initial state
- Send actions to the store
- Assert on state changes
- Assert on actions received from effects
- Override dependencies for testing

```swift
func testProfileFeature() async {
    let user = User(id: "123", name: "Test User", email: "test@example.com")
    let updatedUser = User(id: "123", name: "Updated User", email: "test@example.com")

    let store = TestStore(initialState: ProfileFeature.State(user: user)) {
        ProfileFeature()
    } withDependencies: {
        $0.userClient.getUser = { _ in user }
        $0.userClient.updateUser = { _ in true }
    }

    await store.send(.onAppear) {
        $0.isLoading = true
    }

    await store.receive(.userResponse(.success(user))) {
        $0.isLoading = false
        $0.user = user
    }

    await store.send(.editProfileButtonTapped) {
        $0.editProfile = EditProfileFeature.State(user: user)
    }

    await store.send(.editProfile(.presented(.updateName("Updated User")))) {
        $0.editProfile?.user.name = "Updated User"
    }

    await store.send(.editProfile(.presented(.saveButtonTapped)))

    await store.receive(.updateProfile(updatedUser)) {
        $0.isLoading = true
    }

    await store.receive(.updateProfileResponse(.success(true))) {
        $0.isLoading = false
    }
}
```

### Dependency Overrides

TCA makes it easy to override dependencies for testing:

```swift
// Override a single dependency
let store = TestStore(initialState: ProfileFeature.State()) {
    ProfileFeature()
} withDependencies: {
    $0.userClient.getCurrentUser = { User.mock }
}

// Override multiple dependencies
let store = TestStore(initialState: ProfileFeature.State()) {
    ProfileFeature()
} withDependencies: {
    $0.userClient = .mock(
        getCurrentUser: { User.mock },
        updateUser: { _ in true }
    )
    $0.continuousClock = ImmediateClock()
}

// Use the dependency trait
let store = TestStore(initialState: ProfileFeature.State()) {
    ProfileFeature()
}.dependency(\.userClient, .mock)
```

### Time-Based Testing

For testing time-based effects, use `ImmediateClock` or `TestClock`:

```swift
// Using ImmediateClock
let store = TestStore(initialState: TimerFeature.State()) {
    TimerFeature()
} withDependencies: {
    $0.continuousClock = ImmediateClock()
}

// Using TestClock
let clock = TestClock()
let store = TestStore(initialState: TimerFeature.State()) {
    TimerFeature()
} withDependencies: {
    $0.continuousClock = clock
}

await store.send(.startTimer)
await clock.advance(by: .seconds(1))
await store.receive(.timerTick)
```

### Mock Implementations

Create mock implementations for dependencies:

```swift
extension UserClient {
    static let mock = Self(
        getCurrentUser: { User.mock },
        updateUser: { _ in true },
        observeCurrentUser: {
            AsyncStream { continuation in
                continuation.yield(User.mock)
                continuation.finish()
            }
        },
        checkIn: { Date() },
        updateCheckInInterval: { _ in }
    )

    static func mock(
        getCurrentUser: @escaping () async throws -> User = { User.mock },
        updateUser: @escaping (User) async throws -> Bool = { _ in true },
        observeCurrentUser: @escaping () -> AsyncStream<User> = {
            AsyncStream { continuation in
                continuation.yield(User.mock)
                continuation.finish()
            }
        },
        checkIn: @escaping () async throws -> Date = { Date() },
        updateCheckInInterval: @escaping (TimeInterval) async throws -> Void = { _ in }
    ) -> Self {
        Self(
            getCurrentUser: getCurrentUser,
            updateUser: updateUser,
            observeCurrentUser: observeCurrentUser,
            checkIn: checkIn,
            updateCheckInInterval: updateCheckInInterval
        )
    }
}

extension User {
    static let mock = User(
        id: "123",
        name: "Test User",
        email: "test@example.com",
        phoneNumber: "+1234567890",
        lastCheckedIn: Date(),
        checkInInterval: 3600,
        checkInExpiration: Date().addingTimeInterval(3600),
        profileImageURL: nil,
        isOnboarded: true,
        createdAt: Date(),
        updatedAt: Date()
    )
}
```

## Testing Patterns

### Testing Success Paths

```swift
func testCheckInSuccess() async {
    let store = TestStore(initialState: CheckInFeature.State()) {
        CheckInFeature()
    } withDependencies: {
        $0.userClient.checkIn = { Date() }
    }

    await store.send(.checkInButtonTapped) {
        $0.isLoading = true
    }

    await store.receive(.checkInSuccess(Date())) {
        $0.isLoading = false
        $0.lastCheckedIn = $0.lastCheckedIn // Any date is fine
    }
}
```

### Testing Error Paths

```swift
func testCheckInFailure() async {
    let error = UserError.checkInFailed

    let store = TestStore(initialState: CheckInFeature.State()) {
        CheckInFeature()
    } withDependencies: {
        $0.userClient.checkIn = { throw error }
    }

    await store.send(.checkInButtonTapped) {
        $0.isLoading = true
    }

    await store.receive(.checkInFailure(error)) {
        $0.isLoading = false
        $0.error = UserFacingError.from(error)
    }
}
```

### Testing Navigation

```swift
func testNavigation() async {
    let store = TestStore(initialState: HomeFeature.State()) {
        HomeFeature()
    }

    await store.send(.profileButtonTapped) {
        $0.profile = ProfileFeature.State()
    }

    await store.send(.profile(.dismiss)) {
        $0.profile = nil
    }
}
```

### Testing Child-Parent Interactions

```swift
func testChildParentInteraction() async {
    let store = TestStore(initialState: ParentFeature.State()) {
        ParentFeature()
    }

    await store.send(.showChild) {
        $0.child = ChildFeature.State()
    }

    await store.send(.child(.presented(.setValue("New Value")))) {
        $0.child?.value = "New Value"
    }

    await store.send(.child(.presented(.saveButtonTapped)))

    await store.receive(.child(.presented(.delegate(.saved("New Value"))))) {
        $0.savedValue = "New Value"
        $0.child = nil
    }
}
```

### Testing Async Streams

```swift
func testAsyncStream() async {
    let user1 = User.mock
    let user2 = User(id: "456", name: "Another User", email: "another@example.com")

    let store = TestStore(initialState: UserStreamFeature.State()) {
        UserStreamFeature()
    } withDependencies: {
        $0.userClient.observeCurrentUser = {
            AsyncStream { continuation in
                continuation.yield(user1)
                continuation.yield(user2)
                continuation.finish()
            }
        }
    }

    await store.send(.startObserving)

    await store.receive(.userUpdated(user1)) {
        $0.user = user1
    }

    await store.receive(.userUpdated(user2)) {
        $0.user = user2
    }

    await store.receive(.observingEnded)
}
```

## Test Organization

Tests should be organized to mirror the structure of the application:

```
Tests/
├── Core/
│   ├── Domain/
│   │   └── Models/
│   │       ├── UserTests.swift
│   │       └── ContactTests.swift
│   │
│   ├── Infrastructure/
│   │   ├── Clients/
│   │   │   ├── StorageClientTests.swift
│   │   │   └── UserClientTests.swift
│   │   │
│   │   ├── DTOs/
│   │   │   └── DocumentDataTests.swift
│   │   │
│   │   └── Mapping/
│   │       └── UserMappingTests.swift
│   │
│   └── HelperUtilities/
│       └── TimeFormatterTests.swift
│
├── Features/
│   ├── Auth/
│   │   └── AuthFeatureTests.swift
│   │
│   ├── Profile/
│   │   └── ProfileFeatureTests.swift
│   │
│   └── Contacts/
│       └── ContactsFeatureTests.swift
│
└── Infrastructure/
    └── Firebase/
        ├── Adapters/
        │   └── FirebaseStorageAdapterTests.swift
        │
        └── Clients/
            └── FirebaseUserClientTests.swift
```

## Test Coverage

Aim for high test coverage, especially for critical paths:

- Core domain models: 100%
- Infrastructure clients: 90%+
- Feature reducers: 90%+
- UI components: 70%+

Use code coverage tools to identify untested code paths.
