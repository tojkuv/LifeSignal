# LifeSignal iOS Testing Strategy

**Navigation:** [Back to Application Specification](README.md)

---

## Overview

This document outlines the comprehensive testing strategy for the LifeSignal iOS application. It covers unit testing, integration testing, UI testing, and performance testing approaches, as well as best practices for writing testable code.

**Important Note**: Testing should only be done in the TCA production application, not in the mock application. The mock application is for UI development only and should not contain any testing code or client implementations.

## Testing Layers

The LifeSignal iOS application is tested at multiple layers:

### 1. Unit Testing

Unit tests verify the behavior of individual components in isolation. In the context of TCA, this primarily means testing reducers and their effects.

#### Reducer Testing

Reducers are tested using TCA's `TestStore`, which allows for precise verification of state changes and effects:

```swift
@MainActor
func testCheckIn() async {
    let store = TestStore(
        initialState: CheckInFeature.State(),
        reducer: { CheckInFeature() }
    )

    // Override dependencies
    store.dependencies.checkInClient.checkIn = {
        return Date(timeIntervalSince1970: 1000)
    }

    // Test check-in button tapped
    await store.send(.checkInButtonTapped) {
        $0.isCheckingIn = true
    }

    // Test check-in response
    await store.receive(.checkInResponse(.success(Date(timeIntervalSince1970: 1000)))) {
        $0.isCheckingIn = false
        $0.lastCheckIn = Date(timeIntervalSince1970: 1000)
        $0.nextCheckInDue = Date(timeIntervalSince1970: 1000 + 24 * 3600)
    }
}
```

#### Client Testing

Client interfaces are tested using mock implementations:

```swift
@MainActor
func testUserClient() async {
    // Create a mock user
    let mockUser = User(
        id: UUID(),
        firstName: "John",
        lastName: "Doe",
        phoneNumber: "+1234567890",
        profileImageURL: nil,
        emergencyNote: "Test note",
        checkInInterval: 24 * 3600,
        reminderInterval: 2 * 3600,
        lastCheckInTime: nil,
        status: .active,
        qrCodeID: UUID()
    )

    // Create a mock client
    let userClient = UserClient(
        currentUser: {
            mockUser
        },
        updateProfile: { _, _, _ in
            // No-op in test
        },
        updateProfileImage: { _ in
            URL(string: "https://example.com/image.jpg")!
        },
        refreshQRCodeID: {
            // No-op in test
        },
        userStream: {
            AsyncStream { continuation in
                continuation.yield(mockUser)
                continuation.finish()
            }
        },
        currentUserID: {
            mockUser.id
        }
    )

    // Test the client
    let user = try await userClient.currentUser()
    XCTAssertEqual(user.id, mockUser.id)
    XCTAssertEqual(user.firstName, "John")
    XCTAssertEqual(user.lastName, "Doe")
}
```

#### Adapter Testing

Adapters are tested using mock backend services:

```swift
@MainActor
func testFirebaseUserAdapter() async {
    // Create a mock Firebase service
    let mockFirebaseService = MockFirebaseService()
    mockFirebaseService.mockUser = FirebaseUser(
        uid: "user123",
        displayName: "John Doe",
        phoneNumber: "+1234567890",
        photoURL: nil
    )

    // Create the adapter with the mock service
    let adapter = FirebaseUserAdapter(service: mockFirebaseService)

    // Test the adapter
    let user = try await adapter.currentUser()
    XCTAssertEqual(user.id.uuidString, "user123")
    XCTAssertEqual(user.firstName, "John")
    XCTAssertEqual(user.lastName, "Doe")
    XCTAssertEqual(user.phoneNumber, "+1234567890")
}
```

### 2. Integration Testing

Integration tests verify the interaction between multiple components. In the context of TCA, this means testing features that compose other features.

```swift
@MainActor
func testAppFeature() async {
    let store = TestStore(
        initialState: AppFeature.State(),
        reducer: { AppFeature() }
    )

    // Override dependencies
    store.dependencies.authClient.authStateStream = {
        AsyncStream { continuation in
            continuation.yield(User(id: UUID(), firstName: "John", lastName: "Doe", phoneNumber: "+1234567890", profileImageURL: nil, emergencyNote: "", checkInInterval: 24 * 3600, reminderInterval: 2 * 3600, lastCheckInTime: nil, status: .active, qrCodeID: UUID()))
            continuation.finish()
        }
    }

    // Test app launch
    await store.send(.appDidLaunch)

    // Test auth state changed
    await store.receive(.authStateChanged(User(id: UUID(), firstName: "John", lastName: "Doe", phoneNumber: "+1234567890", profileImageURL: nil, emergencyNote: "", checkInInterval: 24 * 3600, reminderInterval: 2 * 3600, lastCheckInTime: nil, status: .active, qrCodeID: UUID()))) {
        $0.isAuthenticated = true
        $0.needsOnboarding = false
        $0.mainTab = MainTabFeature.State()
    }
}
```

### 3. UI Testing

UI tests verify the user interface and user interactions. In the context of SwiftUI and TCA, this means testing views with test stores.

```swift
@MainActor
func testCheckInView() {
    let store = Store(
        initialState: CheckInFeature.State(
            lastCheckIn: Date(timeIntervalSince1970: 1000),
            nextCheckInDue: Date(timeIntervalSince1970: 1000 + 24 * 3600),
            checkInInterval: 24 * 3600,
            reminderInterval: 2 * 3600
        ),
        reducer: { CheckInFeature() }
    )

    let view = CheckInView(store: store)

    // Use ViewInspector to test the view
    let checkInButton = try view.inspect().find(button: "Check In")
    XCTAssertNotNil(checkInButton)

    // Test button tap
    try checkInButton.tap()

    // Verify state changes
    XCTAssertTrue(store.isCheckingIn)
}
```

### 4. Performance Testing

Performance tests verify the performance characteristics of the application, such as memory usage, CPU usage, and response time.

```swift
func testCheckInPerformance() {
    measure {
        let store = Store(
            initialState: CheckInFeature.State(),
            reducer: { CheckInFeature() }
        )

        let view = CheckInView(store: store)
        _ = view.body
    }
}
```

## Test Coverage

The LifeSignal iOS application aims for high test coverage, with a focus on critical paths and business logic:

1. **Reducers**: 90%+ coverage
2. **Clients**: 90%+ coverage
3. **Adapters**: 80%+ coverage
4. **Views**: 70%+ coverage

## Test Organization

Tests are organized to mirror the structure of the application:

```
LifeSignalTests/
├── Features/
│   ├── Auth/
│   │   ├── AuthFeatureTests.swift
│   │   └── AuthViewTests.swift
│   ├── CheckIn/
│   │   ├── CheckInFeatureTests.swift
│   │   └── CheckInViewTests.swift
│   └── ...
├── Infrastructure/
│   ├── Clients/
│   │   ├── AuthClientTests.swift
│   │   ├── UserClientTests.swift
│   │   └── ...
│   ├── Adapters/
│   │   ├── FirebaseAuthAdapterTests.swift
│   │   ├── FirebaseUserAdapterTests.swift
│   │   └── ...
│   └── ...
└── ...
```

## Test Doubles

The LifeSignal iOS application uses various test doubles to facilitate testing:

1. **Mocks**: Objects that record interactions and return predefined responses
2. **Stubs**: Objects that return predefined responses
3. **Fakes**: Simplified implementations of real objects
4. **Spies**: Objects that record interactions

### Example: Mock Client

```swift
struct MockUserClient: UserClientProtocol {
    var currentUserCalled = false
    var currentUserResult: Result<User, Error> = .success(User.mock)

    func currentUser() async throws -> User {
        currentUserCalled = true
        switch currentUserResult {
        case .success(let user):
            return user
        case .failure(let error):
            throw error
        }
    }

    // Other methods...
}
```

### Example: Stub Client

```swift
extension UserClient {
    static var stub: Self {
        Self(
            currentUser: {
                User.mock
            },
            updateProfile: { _, _, _ in
                // No-op
            },
            // Other methods...
        )
    }
}
```

## Dependency Injection

The LifeSignal iOS application uses TCA's dependency injection system to facilitate testing:

```swift
@MainActor
func testCheckIn() async {
    let store = TestStore(
        initialState: CheckInFeature.State(),
        reducer: { CheckInFeature() }
    )

    // Override dependencies
    store.dependencies.checkInClient.checkIn = {
        return Date(timeIntervalSince1970: 1000)
    }
    store.dependencies.notificationClient.scheduleCheckInReminder = { _ in
        // No-op in test
    }

    // Test check-in button tapped
    await store.send(.checkInButtonTapped) {
        $0.isCheckingIn = true
    }

    // Test check-in response
    await store.receive(.checkInResponse(.success(Date(timeIntervalSince1970: 1000)))) {
        $0.isCheckingIn = false
        $0.lastCheckIn = Date(timeIntervalSince1970: 1000)
        $0.nextCheckInDue = Date(timeIntervalSince1970: 1000 + 24 * 3600)
    }
}
```

## Test Data

The LifeSignal iOS application uses consistent test data across all tests:

```swift
extension User {
    static let mock = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        firstName: "John",
        lastName: "Doe",
        phoneNumber: "+1234567890",
        profileImageURL: nil,
        emergencyNote: "Test note",
        checkInInterval: 24 * 3600,
        reminderInterval: 2 * 3600,
        lastCheckInTime: nil,
        status: .active,
        qrCodeID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    )
}
```

## Test Helpers

The LifeSignal iOS application uses test helpers to simplify common testing tasks:

```swift
extension TestStore {
    func sendAndWait(_ action: Action) async {
        await send(action)
        await MainActor.run {
            // Wait for effects to complete
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
}
```

## Continuous Integration

The LifeSignal iOS application uses continuous integration to run tests automatically:

1. **Pull Request Checks**: Tests are run on every pull request
2. **Nightly Builds**: Full test suite is run nightly
3. **Release Builds**: Full test suite is run before each release

## Best Practices

When writing tests for the LifeSignal iOS application, follow these best practices:

1. **Test One Thing at a Time**: Each test should verify a single behavior
2. **Use Descriptive Test Names**: Test names should describe what is being tested
3. **Arrange-Act-Assert**: Structure tests with clear setup, action, and verification phases
4. **Avoid Test Interdependence**: Tests should not depend on each other
5. **Mock External Dependencies**: External dependencies should be mocked
6. **Test Edge Cases**: Test boundary conditions and error cases
7. **Keep Tests Fast**: Tests should run quickly
8. **Keep Tests Deterministic**: Tests should produce the same result every time
9. **Use Test Doubles Appropriately**: Use the right test double for the job
10. **Test Public API**: Test the public API, not implementation details

## Conclusion

The LifeSignal iOS application's testing strategy provides comprehensive coverage of the application's behavior, ensuring that it works correctly and reliably. By following the testing approach outlined in this document, developers can maintain high code quality and prevent regressions.

Remember that all testing should be implemented in the TCA production application. The mock application should focus solely on UI development and should not contain testing code or client implementations.
