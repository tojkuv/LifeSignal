# TestStore Usage

**Navigation:** [Back to iOS Architecture](../README.md) | [Testing Strategy](./TestingStrategy.md) | [Dependency Testing](./DependencyTesting.md)

---

> **Note:** As this is an MVP, the TestStore usage patterns may evolve as the project matures.

## TestStore Design Principles

TestStore usage in LifeSignal follows these core principles:

1. **Individual Test Instances**: Create TestStore instances within individual tests
2. **Dependency Overrides**: Override dependencies with `withDependencies`
3. **Controlled Time**: Use `ImmediateClock` for time-based tests
4. **Comprehensive Testing**: Test both success and failure paths
5. **Explicit Assertions**: Use explicit assertions for state changes

## TestStore Initialization

TestStore is initialized within individual tests:

```swift
@Test
func testFeature() async {
  let store = TestStore(initialState: Feature.State()) {
    Feature()
  }
  
  // Test the feature...
}
```

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

## Sending Actions

Actions are sent using `store.send`:

```swift
@Test
func testIncrementButtonTapped() async {
  let store = TestStore(initialState: Feature.State(count: 0)) {
    Feature()
  }
  
  await store.send(.incrementButtonTapped) {
    $0.count = 1
  }
}
```

## Asserting State Changes

State changes are asserted using trailing closures:

```swift
await store.send(.incrementButtonTapped) {
  $0.count = 1
}

await store.send(.decrementButtonTapped) {
  $0.count = 0
}
```

## Receiving Actions

Actions from effects are received using `store.receive`:

```swift
await store.send(.numberFactButtonTapped)

await store.receive(\.numberFactResponse) {
  $0.numberFact = "0 is a test number"
}
```

## Testing Effects with Timeouts

Effects with timeouts are tested using the `timeout` parameter:

```swift
await store.receive(\.timerTick, timeout: .seconds(2)) {
  $0.count = 1
}
```

## Testing Multiple Actions

Multiple actions are tested in sequence:

```swift
await store.send(.incrementButtonTapped) {
  $0.count = 1
}

await store.send(.incrementButtonTapped) {
  $0.count = 2
}

await store.send(.decrementButtonTapped) {
  $0.count = 1
}
```

## Testing Cancellation

Cancellation is tested by sending the cancellation action:

```swift
await store.send(.startTimerButtonTapped)

await store.receive(\.timerTick) {
  $0.count = 1
}

await store.send(.stopTimerButtonTapped)

// No more timerTick actions should be received
```

## Testing Navigation

Navigation is tested by asserting state changes:

```swift
await store.send(.addButtonTapped) {
  $0.destination = .add(AddFeature.State())
}

await store.send(.dismissButtonTapped) {
  $0.destination = nil
}
```

## Testing Stack Navigation

Stack navigation is tested by asserting path changes:

```swift
await store.send(.itemSelected(item)) {
  $0.path.append(.detail(DetailFeature.State(item: item)))
}

await store.send(.path(.popFrom(id: 0))) {
  $0.path = []
}
```

## Testing Binding Actions

Binding actions are tested using the `binding` case:

```swift
await store.send(\.binding.name, "Test") {
  $0.name = "Test"
}

await store.send(\.binding.isEnabled, true) {
  $0.isEnabled = true
}
```

## Testing Shared State

Shared state is tested using the `withLock` method:

```swift
@Test
func testSharedState() async {
  let store = TestStore(initialState: Feature.State(count: Shared(0))) {
    Feature()
  }
  
  await store.send(.incrementButtonTapped)
  
  store.assert {
    $0.$count.withLock { $0 = 1 }
  }
}
```

## Testing Error Handling

Error handling is tested by overriding dependencies to throw errors:

```swift
@Test
func testErrorHandling() async {
  let store = TestStore(initialState: Feature.State()) {
    Feature()
  } withDependencies: {
    $0.numberFactClient.fetch = { _ in
      throw NSError(domain: "test", code: 0)
    }
  }
  
  await store.send(.numberFactButtonTapped)
  
  await store.receive(\.numberFactFailed) {
    $0.error = NSError(domain: "test", code: 0)
  }
}
```

## Testing Complex State

Complex state is tested using multiple assertions:

```swift
await store.send(.loadButtonTapped) {
  $0.isLoading = true
  $0.error = nil
}

await store.receive(\.dataLoaded) {
  $0.isLoading = false
  $0.items = [item1, item2, item3]
}
```

## Best Practices

1. **Create TestStore Instances Within Tests**: Don't share TestStore instances between tests
2. **Override Dependencies**: Override dependencies for controlled testing
3. **Use ImmediateClock**: Use ImmediateClock for time-based tests
4. **Test Both Success and Failure**: Test both success and failure paths
5. **Use Explicit Assertions**: Use explicit assertions for state changes
6. **Test Cancellation**: Test cancellation of effects when appropriate
7. **Test Navigation**: Test navigation state changes
8. **Test Binding Actions**: Test binding actions for form fields
9. **Test Shared State**: Test shared state mutations
10. **Document Tests**: Document the purpose of each test
