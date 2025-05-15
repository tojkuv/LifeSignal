# Dependency Testing

**Navigation:** [Back to iOS Architecture](../README.md) | [Testing Strategy](./TestingStrategy.md) | [TestStore Usage](./TestStoreUsage.md)

---

> **Note:** As this is an MVP, the dependency testing approach may evolve as the project matures.

## Dependency Testing Principles

Dependency testing in LifeSignal follows these core principles:

1. **Isolation**: Test features in isolation from real dependencies
2. **Controlled Behavior**: Control dependency behavior for predictable tests
3. **Comprehensive Testing**: Test both success and failure paths
4. **Realistic Scenarios**: Test realistic scenarios with realistic data
5. **Performance**: Use fast dependencies for efficient tests

## Dependency Overrides

Dependencies are overridden using `withDependencies`:

```swift
@Test
func testFeature() async {
  let store = TestStore(initialState: Feature.State()) {
    Feature()
  } withDependencies: {
    $0.numberFactClient.fetch = { "\($0) is a test number" }
    $0.continuousClock = ImmediateClock()
    $0.uuid = { UUID(0) }
    $0.date = { Date(timeIntervalSince1970: 0) }
  }
  
  // Test the feature...
}
```

## Testing Success Paths

Success paths are tested by overriding dependencies to return success values:

```swift
@Test
func testLoadUserSuccess() async {
  let user = User(id: "1", name: "Test User")
  
  let store = TestStore(initialState: Feature.State()) {
    Feature()
  } withDependencies: {
    $0.userClient.getCurrentUser = { user }
  }
  
  await store.send(.loadUserButtonTapped) {
    $0.isLoading = true
  }
  
  await store.receive(\.userResponse) {
    $0.isLoading = false
    $0.user = user
  }
}
```

## Testing Failure Paths

Failure paths are tested by overriding dependencies to throw errors:

```swift
@Test
func testLoadUserFailure() async {
  let error = NSError(domain: "test", code: 0)
  
  let store = TestStore(initialState: Feature.State()) {
    Feature()
  } withDependencies: {
    $0.userClient.getCurrentUser = { throw error }
  }
  
  await store.send(.loadUserButtonTapped) {
    $0.isLoading = true
  }
  
  await store.receive(\.userFailed) {
    $0.isLoading = false
    $0.error = error
  }
}
```

## Testing Time-Based Dependencies

Time-based dependencies are tested using `ImmediateClock`:

```swift
@Test
func testTimer() async {
  let store = TestStore(initialState: Feature.State(count: 0)) {
    Feature()
  } withDependencies: {
    $0.continuousClock = ImmediateClock()
  }
  
  await store.send(.startTimerButtonTapped)
  
  await store.receive(\.timerTick) {
    $0.count = 1
  }
  
  await store.receive(\.timerTick) {
    $0.count = 2
  }
  
  await store.receive(\.timerTick) {
    $0.count = 3
  }
  
  await store.receive(\.timerTick) {
    $0.count = 4
  }
  
  await store.receive(\.timerTick) {
    $0.count = 5
  }
}
```

## Testing Random Values

Random values are tested by overriding the UUID dependency:

```swift
@Test
func testRandomID() async {
  let store = TestStore(initialState: Feature.State()) {
    Feature()
  } withDependencies: {
    $0.uuid = { UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }
  }
  
  await store.send(.generateIDButtonTapped) {
    $0.id = "00000000-0000-0000-0000-000000000000"
  }
}
```

## Testing Date Dependencies

Date dependencies are tested by overriding the date dependency:

```swift
@Test
func testCurrentDate() async {
  let date = Date(timeIntervalSince1970: 0)
  
  let store = TestStore(initialState: Feature.State()) {
    Feature()
  } withDependencies: {
    $0.date = { date }
  }
  
  await store.send(.setCurrentDateButtonTapped) {
    $0.currentDate = date
  }
}
```

## Testing Firebase Dependencies

Firebase dependencies are tested by overriding the Firebase clients:

```swift
@Test
func testLoadUser() async {
  let user = User(id: "1", name: "Test User")
  
  let store = TestStore(initialState: Feature.State()) {
    Feature()
  } withDependencies: {
    $0.firebase.auth.currentUser = { user }
  }
  
  await store.send(.loadUserButtonTapped) {
    $0.isLoading = true
  }
  
  await store.receive(\.userResponse) {
    $0.isLoading = false
    $0.user = user
  }
}
```

## Testing Streaming Dependencies

Streaming dependencies are tested by overriding the stream methods:

```swift
@Test
func testUserStream() async {
  let user1 = User(id: "1", name: "Test User 1")
  let user2 = User(id: "1", name: "Test User 2")
  
  let store = TestStore(initialState: Feature.State()) {
    Feature()
  } withDependencies: {
    $0.userClient.observeCurrentUser = {
      AsyncStream { continuation in
        continuation.yield(user1)
        continuation.yield(user2)
        continuation.finish()
      }
    }
  }
  
  await store.send(.startUserStreamButtonTapped)
  
  await store.receive(\.userChanged) {
    $0.user = user1
  }
  
  await store.receive(\.userChanged) {
    $0.user = user2
  }
}
```

## Testing Multiple Dependencies

Multiple dependencies are tested by overriding all relevant dependencies:

```swift
@Test
func testComplexFeature() async {
  let user = User(id: "1", name: "Test User")
  let items = [Item(id: "1", name: "Item 1"), Item(id: "2", name: "Item 2")]
  
  let store = TestStore(initialState: Feature.State()) {
    Feature()
  } withDependencies: {
    $0.userClient.getCurrentUser = { user }
    $0.itemsClient.getItems = { items }
    $0.continuousClock = ImmediateClock()
    $0.uuid = { UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }
    $0.date = { Date(timeIntervalSince1970: 0) }
  }
  
  // Test the feature...
}
```

## Testing Dependency Traits

Dependency traits are used for common dependency overrides:

```swift
extension DependencyValues {
  var testTraits: TestTraits {
    get { self[TestTraits.self] }
    set { self[TestTraits.self] = newValue }
  }
}

struct TestTraits: DependencyKey {
  var user: User = .mock
  var items: [Item] = [.mock]
  var error: Error? = nil
  
  static let liveValue = Self()
  static let testValue = Self()
}

@Test
func testFeature() async {
  let store = TestStore(initialState: Feature.State()) {
    Feature()
  } withDependencies: {
    $0.testTraits.user = User(id: "1", name: "Test User")
    $0.testTraits.items = [Item(id: "1", name: "Item 1")]
    $0.userClient.getCurrentUser = { $0.testTraits.user }
    $0.itemsClient.getItems = { $0.testTraits.items }
  }
  
  // Test the feature...
}
```

## Best Practices

1. **Override Dependencies**: Override dependencies for controlled testing
2. **Test Both Success and Failure**: Test both success and failure paths
3. **Use ImmediateClock**: Use ImmediateClock for time-based tests
4. **Use Deterministic Values**: Use deterministic values for random dependencies
5. **Test Realistic Scenarios**: Test realistic scenarios with realistic data
6. **Test Edge Cases**: Test edge cases and error conditions
7. **Test Streaming Dependencies**: Test streaming dependencies with controlled streams
8. **Use Dependency Traits**: Use dependency traits for common dependency overrides
9. **Document Tests**: Document the purpose of each test
10. **Keep Tests Fast**: Keep tests fast by using efficient dependencies
