# Dependency Injection in TCA

**Navigation:** [Back to TCA Overview](Overview.md) | [State Management](StateManagement.md) | [Action Design](ActionDesign.md) | [Effect Management](EffectManagement.md)

---

## Overview

Dependency injection in The Composable Architecture (TCA) provides a way to manage external dependencies such as API clients, databases, and other services. TCA's dependency system makes it easy to inject dependencies into reducers, test with mock dependencies, and configure dependencies for different environments.

## Core Principles

### 1. Protocol-Based Dependencies

Dependencies are defined as protocols or struct-based clients:

```swift
// Protocol-based dependency
protocol NumberFactClient {
  func fetch(_ number: Int) async throws -> String
}

// Struct-based dependency with closures
struct NumberFactClient: Sendable {
  var fetch: @Sendable (Int) async throws -> String
}
```

This ensures:
- Clear interface for dependencies
- Easy mocking for testing
- Separation of interface and implementation

### 2. Dependency Injection

Dependencies are injected via TCA's dependency system:

```swift
@Reducer
struct Feature {
  @Dependency(\.numberFactClient) var numberFactClient

  // State, Action, body, etc.
}
```

This ensures:
- Dependencies are available where needed
- No need to pass dependencies through initializers
- Easy overriding for testing

### 3. Testability

Dependencies are designed to be testable:

```swift
@Test
func testNumberFact() async {
  let store = TestStore(initialState: Feature.State()) {
    Feature()
  } withDependencies: {
    $0.numberFactClient.fetch = { number in
      "Test fact for \(number)"
    }
  }

  await store.send(.numberFactButtonTapped) {
    $0.isLoading = true
  }

  await store.receive(.numberFactResponse("Test fact for 0")) {
    $0.isLoading = false
    $0.numberFact = "Test fact for 0"
  }
}
```

This ensures:
- Tests run without real dependencies
- Predictable test behavior
- Fast test execution

### 4. Configurability

Dependencies can be configured for different environments:

```swift
@main
struct MyApp: App {
  var body: some Scene {
    WindowGroup {
      RootView(
        store: Store(initialState: RootFeature.State()) {
          RootFeature()
        } withDependencies: {
          // Configure dependencies for the app
          $0.numberFactClient = .liveValue
          $0.continuousClock = ContinuousClock()
          $0.uuid = UUID.init
          $0.date = Date.init
        }
      )
    }
  }
}
```

This ensures:
- Different configurations for different environments
- Easy switching between implementations
- Centralized dependency configuration

## Dependency Definition

### Using @DependencyClient Macro

The `@DependencyClient` macro simplifies dependency definition by automatically generating default implementations and error handling:

```swift
@DependencyClient
struct NumberFactClient: Sendable {
  var fetch: @Sendable (Int) async throws -> String
}
```

This generates:
- A struct with closure properties
- Default implementations that throw unimplemented errors
- Sendable conformance for concurrency safety
- Proper error reporting for unimplemented methods

You can also provide default implementations for non-throwing methods:

```swift
@DependencyClient
struct DateClient: Sendable {
  var now: @Sendable () -> Date = { Date() }
  var calendar: @Sendable () -> Calendar = { Calendar.current }
}
```

### Manual Definition

Dependencies can also be defined manually:

```swift
struct NumberFactClient: Sendable {
  var fetch: @Sendable (Int) async throws -> String

  init(fetch: @escaping @Sendable (Int) async throws -> String) {
    self.fetch = fetch
  }
}
```

### Protocol-Based Definition

Dependencies can be defined as protocols:

```swift
protocol NumberFactClient: Sendable {
  func fetch(_ number: Int) async throws -> String
}

struct LiveNumberFactClient: NumberFactClient {
  func fetch(_ number: Int) async throws -> String {
    let (data, _) = try await URLSession.shared
      .data(from: URL(string: "http://numbersapi.com/\(number)")!)
    return String(decoding: data, as: UTF8.self)
  }
}

struct TestNumberFactClient: NumberFactClient {
  func fetch(_ number: Int) async throws -> String {
    "Test fact for \(number)"
  }
}
```

## Dependency Registration

### DependencyKey Conformance

Dependencies are registered with TCA's dependency system by conforming to `DependencyKey`:

```swift
extension NumberFactClient: DependencyKey {
  static let liveValue = Self(
    fetch: { number in
      let (data, _) = try await URLSession.shared
        .data(from: URL(string: "http://numbersapi.com/\(number)")!)
      return String(decoding: data, as: UTF8.self)
    }
  )

  static let testValue = Self(
    fetch: { number in
      "Test fact for \(number)"
    }
  )

  static let previewValue = Self(
    fetch: { number in
      "Preview fact for \(number)"
    }
  )
}
```

This provides:
- Live implementation for production
- Test implementation for testing
- Preview implementation for SwiftUI previews

### DependencyValues Extension

Dependencies are accessed through `DependencyValues`:

```swift
extension DependencyValues {
  var numberFactClient: NumberFactClient {
    get { self[NumberFactClient.self] }
    set { self[NumberFactClient.self] = newValue }
  }
}
```

This enables:
- Access to dependencies via `@Dependency` property wrapper
- Overriding dependencies for testing
- Configuring dependencies for different environments

## Dependency Usage

### Using @Dependency Property Wrapper

Dependencies are used in reducers via the `@Dependency` property wrapper:

```swift
@Reducer
struct Feature {
  @Dependency(\.numberFactClient) var numberFactClient
  @Dependency(\.continuousClock) var clock

  // State, Action, etc.

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .numberFactButtonTapped:
        state.isLoading = true
        return .run { [count = state.count] send in
          do {
            try await clock.sleep(for: .seconds(1))
            let fact = try await numberFactClient.fetch(count)
            await send(.numberFactResponse(fact))
          } catch {
            await send(.numberFactFailed(error))
          }
        }

      // Other cases...
      }
    }
  }
}
```

This enables:
- Access to dependencies without passing through initializers
- Easy overriding for testing
- Clear dependency declaration

### Dependency Overrides for Testing

Dependencies are overridden for testing using several approaches:

#### 1. Using withDependencies in TestStore

```swift
@Test
func testNumberFact() async {
  let store = TestStore(initialState: Feature.State()) {
    Feature()
  } withDependencies: {
    $0.numberFactClient.fetch = { number in
      "Test fact for \(number)"
    }
    $0.continuousClock = ImmediateClock()
  }

  await store.send(.numberFactButtonTapped) {
    $0.isLoading = true
  }

  await store.receive(.numberFactResponse("Test fact for 0")) {
    $0.isLoading = false
    $0.numberFact = "Test fact for 0"
  }
}
```

#### 2. Using Test Traits

```swift
@Test(.dependency(\.numberFactClient.fetch, { _ in "Test fact" }))
func testNumberFact() async {
  let store = TestStore(initialState: Feature.State()) {
    Feature()
  }

  // Test with overridden dependency...
}
```

#### 3. Using Suite-Level Overrides

```swift
@Suite(.dependencies {
  $0.continuousClock = ImmediateClock()
  $0.uuid = .incrementing
})
struct FeatureTests {
  @Test
  func testOne() async { /* ... */ }

  @Test
  func testTwo() async { /* ... */ }
}
```

These approaches enable:
- Testing without real dependencies
- Controlling dependency behavior in tests
- Fast test execution
- Sharing dependency overrides across multiple tests

## Dependency Types

### 1. Core Infrastructure Dependencies

Low-level dependencies for basic infrastructure operations:

```swift
@DependencyClient
struct StorageClient: Sendable {
  var getDocument: @Sendable (StoragePath) async throws -> DocumentSnapshot = { _ in
    throw InfrastructureError.unimplemented("StorageClient.getDocument")
  }

  var updateDocument: @Sendable (StoragePath, [String: Any]) async throws -> Void = { _, _ in
    throw InfrastructureError.unimplemented("StorageClient.updateDocument")
  }

  // Other methods...
}
```

### 2. Domain-Specific Dependencies

Higher-level dependencies for domain-specific operations:

```swift
@DependencyClient
struct UserClient: Sendable {
  var getCurrentUser: @Sendable () async throws -> User = {
    throw DomainError.unimplemented("UserClient.getCurrentUser")
  }

  var updateProfile: @Sendable (User) async throws -> Void = { _ in
    throw DomainError.unimplemented("UserClient.updateProfile")
  }

  // Other methods...
}
```

### 3. System Dependencies

Dependencies for system services:

```swift
@DependencyClient
struct NotificationClient: Sendable {
  var requestAuthorization: @Sendable () async throws -> Bool = {
    throw SystemError.unimplemented("NotificationClient.requestAuthorization")
  }

  var scheduleNotification: @Sendable (Notification) async throws -> Void = { _ in
    throw SystemError.unimplemented("NotificationClient.scheduleNotification")
  }

  // Other methods...
}
```

### 4. Utility Dependencies

Dependencies for utility functions:

```swift
extension DependencyValues {
  var uuid: @Sendable () -> UUID {
    get { self[UUIDGeneratorKey.self] }
    set { self[UUIDGeneratorKey.self] = newValue }
  }

  var date: @Sendable () -> Date {
    get { self[DateGeneratorKey.self] }
    set { self[DateGeneratorKey.self] = newValue }
  }

  var mainQueue: AnySchedulerOf<DispatchQueue> {
    get { self[MainQueueKey.self] }
    set { self[MainQueueKey.self] = newValue }
  }
}
```

## Dependency Namespacing

Related dependencies can be namespaced for cleaner access and better organization:

### 1. Using Nested Structs

```swift
extension DependencyValues {
  var firebase: FirebaseDependencies {
    get { self[FirebaseDependencies.self] }
    set { self[FirebaseDependencies.self] = newValue }
  }
}

struct FirebaseDependencies: Sendable {
  var auth: FirebaseAuthClient
  var firestore: FirestoreClient
  var storage: FirebaseStorageClient
  var messaging: FirebaseMessagingClient
}

extension FirebaseDependencies: DependencyKey {
  static let liveValue = Self(
    auth: .liveValue,
    firestore: .liveValue,
    storage: .liveValue,
    messaging: .liveValue
  )

  static let testValue = Self(
    auth: .testValue,
    firestore: .testValue,
    storage: .testValue,
    messaging: .testValue
  )

  static let previewValue = Self(
    auth: .previewValue,
    firestore: .previewValue,
    storage: .previewValue,
    messaging: .previewValue
  )
}
```

### 2. Using Nested Namespaces

```swift
// Define the namespace
enum FirebaseKey {}

// Add extensions for each client
extension DependencyValues {
  var firebaseAuth: FirebaseAuthClient {
    get { self[FirebaseKey.Auth.self] }
    set { self[FirebaseKey.Auth.self] = newValue }
  }

  var firebaseFirestore: FirestoreClient {
    get { self[FirebaseKey.Firestore.self] }
    set { self[FirebaseKey.Firestore.self] = newValue }
  }
}

// Define the dependency keys
extension FirebaseKey {
  enum Auth: DependencyKey {
    static let liveValue = FirebaseAuthClient.liveValue
    static let testValue = FirebaseAuthClient.testValue
    static let previewValue = FirebaseAuthClient.previewValue
  }

  enum Firestore: DependencyKey {
    static let liveValue = FirestoreClient.liveValue
    static let testValue = FirestoreClient.testValue
    static let previewValue = FirestoreClient.previewValue
  }
}
```

### Usage:

```swift
@Reducer
struct Feature {
  // Using nested struct approach
  @Dependency(\.firebase.auth) var authClient
  @Dependency(\.firebase.firestore) var firestoreClient

  // Or using nested namespace approach
  @Dependency(\.firebaseAuth) var authClient
  @Dependency(\.firebaseFirestore) var firestoreClient

  // State, Action, etc.
}
```

## Best Practices

### 1. Keep Dependencies Focused

Each dependency should have a single responsibility:

```swift
// ❌ Too many responsibilities
@DependencyClient
struct UserClient: Sendable {
  var getCurrentUser: @Sendable () async throws -> User = { /* ... */ }
  var updateProfile: @Sendable (User) async throws -> Void = { /* ... */ }
  var getNotifications: @Sendable () async throws -> [Notification] = { /* ... */ }
  var sendMessage: @Sendable (Message) async throws -> Void = { /* ... */ }
}

// ✅ Focused
@DependencyClient
struct UserClient: Sendable {
  var getCurrentUser: @Sendable () async throws -> User = { /* ... */ }
  var updateProfile: @Sendable (User) async throws -> Void = { /* ... */ }
}

@DependencyClient
struct NotificationClient: Sendable {
  var getNotifications: @Sendable () async throws -> [Notification] = { /* ... */ }
}

@DependencyClient
struct MessageClient: Sendable {
  var sendMessage: @Sendable (Message) async throws -> Void = { /* ... */ }
}
```

### 2. Use Descriptive Names

Dependency names should clearly describe their purpose:

```swift
// ❌ Unclear
@DependencyClient
struct Client: Sendable {
  var get: @Sendable () async throws -> Data = { /* ... */ }
  var update: @Sendable (Data) async throws -> Void = { /* ... */ }
}

// ✅ Descriptive
@DependencyClient
struct UserClient: Sendable {
  var getCurrentUser: @Sendable () async throws -> User = { /* ... */ }
  var updateUserProfile: @Sendable (User) async throws -> Void = { /* ... */ }
}
```

### 3. Provide Default Values

Provide default values for non-throwing closures:

```swift
@DependencyClient
struct DateClient: Sendable {
  var now: @Sendable () -> Date = { Date() }
  var calendar: @Sendable () -> Calendar = { Calendar.current }
  var timeZone: @Sendable () -> TimeZone = { TimeZone.current }
}
```

### 4. Remove Argument Labels

Remove argument labels in function types for cleaner syntax:

```swift
// ❌ With argument labels
@DependencyClient
struct UserClient: Sendable {
  var getCurrentUser: @Sendable () async throws -> User = { /* ... */ }
  var updateProfile: @Sendable (user: User) async throws -> Void = { /* ... */ }
}

// ✅ Without argument labels
@DependencyClient
struct UserClient: Sendable {
  var getCurrentUser: @Sendable () async throws -> User = { /* ... */ }
  var updateProfile: @Sendable (User) async throws -> Void = { /* ... */ }
}
```

### 5. Document Dependencies

Add documentation to dependencies:

```swift
/// A client for fetching and updating user data.
@DependencyClient
struct UserClient: Sendable {
  /// Fetches the current user.
  /// - Returns: The current user.
  /// - Throws: `UserError.notAuthenticated` if the user is not authenticated.
  var getCurrentUser: @Sendable () async throws -> User = { /* ... */ }

  /// Updates the user's profile.
  /// - Parameter user: The updated user profile.
  /// - Throws: `UserError.notAuthenticated` if the user is not authenticated.
  var updateProfile: @Sendable (User) async throws -> Void = { /* ... */ }
}
```

### 6. Test All Dependencies

Provide comprehensive test implementations:

```swift
extension UserClient: DependencyKey {
  static let liveValue = Self(
    getCurrentUser: { /* Live implementation */ },
    updateProfile: { /* Live implementation */ }
  )

  static let testValue = Self(
    getCurrentUser: { User.mock },
    updateProfile: { _ in }
  )

  static var mocks = Self(
    getCurrentUser: { User.mock },
    updateProfile: { _ in }
  )

  static func failing(
    getCurrentUser: @escaping @Sendable () async throws -> User = { throw UserError.testError },
    updateProfile: @escaping @Sendable (User) async throws -> Void = { _ in throw UserError.testError }
  ) -> Self {
    Self(
      getCurrentUser: getCurrentUser,
      updateProfile: updateProfile
    )
  }
}
```

### 7. Use Dependency Overrides

Override dependencies for specific tests:

```swift
@Test
func testGetCurrentUser_Success() async {
  let store = TestStore(initialState: Feature.State()) {
    Feature()
  } withDependencies: {
    $0.userClient.getCurrentUser = { User.mock }
  }

  await store.send(.getCurrentUserButtonTapped) {
    $0.isLoading = true
  }

  await store.receive(.userLoaded(User.mock)) {
    $0.isLoading = false
    $0.user = User.mock
  }
}

@Test
func testGetCurrentUser_Failure() async {
  let error = UserError.notAuthenticated

  let store = TestStore(initialState: Feature.State()) {
    Feature()
  } withDependencies: {
    $0.userClient.getCurrentUser = { throw error }
  }

  await store.send(.getCurrentUserButtonTapped) {
    $0.isLoading = true
  }

  await store.receive(.userLoadFailed(error)) {
    $0.isLoading = false
    $0.error = error
  }
}
```

### 8. Use @ObservationIgnored with @Dependency

When using `@Dependency` in an `@Observable` class, mark it with `@ObservationIgnored` to prevent unnecessary view updates:

```swift
@Observable
final class FeatureModel {
  var items: [Item] = []

  @ObservationIgnored
  @Dependency(\.continuousClock) var clock

  @ObservationIgnored
  @Dependency(\.date.now) var now

  @ObservationIgnored
  @Dependency(\.uuid) var uuid

  // Methods...
}
```

### 9. Use Shared State with @Shared

Use the `@Shared` property wrapper for state that needs to be shared across features:

```swift
@Reducer
struct ParentFeature {
  @ObservableState
  struct State {
    @Shared var count: Int = 0
    // Other properties
  }
  // Actions, body, etc.
}

@Reducer
struct ChildFeature {
  @ObservableState
  struct State {
    @Shared var count: Int
    // Other properties
  }
  // Actions, body, etc.
}
```

### 10. Use Preview Traits for Dependency Overrides

Use the `.dependencies` preview trait to override dependencies in SwiftUI previews:

```swift
#Preview(trait: .dependencies {
  $0.continuousClock = ImmediateClock()
  $0.userClient.getCurrentUser = { User.mock }
}) {
  FeatureView(model: FeatureModel())
}
```

## Conclusion

Dependency injection in TCA provides a powerful way to manage external dependencies in a testable and configurable manner. By following the principles and best practices outlined in this document, you can create dependencies that are easy to understand, modify, and test.

Modern TCA dependency management leverages Swift's latest features like property wrappers, macros, and structured concurrency to provide a clean, type-safe, and testable approach to managing dependencies. The `@DependencyClient` macro, `@Dependency` property wrapper, and `withDependencies` function make it easy to define, inject, and override dependencies throughout your application.
