# Testing in TCA

**Navigation:** [Back to TCA Overview](Overview.md) | [State Management](StateManagement.md) | [Action Design](ActionDesign.md) | [Effect Management](EffectManagement.md) | [Dependency Injection](DependencyInjection.md)

---

## Overview

Testing in The Composable Architecture (TCA) is straightforward and comprehensive. TCA provides a `TestStore` that allows you to test your reducers, effects, and navigation flows in a predictable and deterministic way. This document outlines the principles and patterns for testing TCA features.

## Core Principles

### 1. TestStore

`TestStore` is the primary tool for testing TCA features:

```swift
@Test
func testCounter() async {
  let store = TestStore(initialState: CounterFeature.State()) {
    CounterFeature()
  } withDependencies: {
    $0.numberFactClient.fetch = { _ in "Test fact" }
  }
  
  await store.send(.incrementButtonTapped) {
    $0.count = 1
  }
  
  await store.send(.numberFactButtonTapped) {
    $0.isLoading = true
  }
  
  await store.receive(.numberFactResponse("Test fact")) {
    $0.isLoading = false
    $0.numberFact = "Test fact"
  }
}
```

This ensures:
- Predictable testing of state changes
- Verification of action sequences
- Controlled testing of effects

### 2. Dependency Overrides

Dependencies are overridden for testing:

```swift
let store = TestStore(initialState: CounterFeature.State()) {
  CounterFeature()
} withDependencies: {
  $0.numberFactClient.fetch = { _ in "Test fact" }
  $0.continuousClock = ImmediateClock()
}
```

This ensures:
- Tests run without real dependencies
- Predictable test behavior
- Fast test execution

### 3. Action Assertions

Actions are asserted using `send` and `receive`:

```swift
// Assert state changes when sending an action
await store.send(.incrementButtonTapped) {
  $0.count = 1
}

// Assert receiving an action from an effect
await store.receive(.numberFactResponse("Test fact")) {
  $0.isLoading = false
  $0.numberFact = "Test fact"
}
```

This ensures:
- Verification of state changes
- Verification of effect outputs
- Clear test failures

## TestStore Usage

### Creating TestStore

Create `TestStore` instances within individual tests:

```swift
@Test
func testCounter() async {
  let store = TestStore(initialState: CounterFeature.State()) {
    CounterFeature()
  }
  
  // Test assertions...
}
```

### Overriding Dependencies

Override dependencies for controlled testing:

```swift
@Test
func testNumberFact() async {
  let store = TestStore(initialState: CounterFeature.State()) {
    CounterFeature()
  } withDependencies: {
    $0.numberFactClient.fetch = { _ in "Test fact" }
    $0.continuousClock = ImmediateClock()
  }
  
  // Test assertions...
}
```

### Using Test Traits

Use test traits for common dependency overrides:

```swift
@Test
func testNumberFact() async {
  let store = TestStore(initialState: CounterFeature.State()) {
    CounterFeature()
  }
  .dependency(\.numberFactClient.fetch, { _ in "Test fact" })
  .dependency(\.continuousClock, ImmediateClock())
  
  // Test assertions...
}
```

### Testing State Changes

Test state changes using trailing closures with `store.send`:

```swift
await store.send(.incrementButtonTapped) {
  $0.count = 1
}

await store.send(.decrementButtonTapped) {
  $0.count = 0
}
```

### Testing Effects

Test effects using `store.receive`:

```swift
await store.send(.numberFactButtonTapped) {
  $0.isLoading = true
}

await store.receive(.numberFactResponse("Test fact")) {
  $0.isLoading = false
  $0.numberFact = "Test fact"
}
```

### Testing Cancellation

Test cancellation of effects:

```swift
await store.send(.startTimerButtonTapped) {
  $0.isTimerRunning = true
}

await store.send(.stopTimerButtonTapped) {
  $0.isTimerRunning = false
}

// No actions should be received after cancellation
```

### Testing Navigation

Test navigation flows:

```swift
await store.send(.detailButtonTapped(item)) {
  $0.path.append(.detail(DetailFeature.State(item: item)))
}

await store.send(.path(.element(id: 0, action: .detail(.editButtonTapped)))) {
  $0.path.append(.edit(EditFeature.State(item: item)))
}
```

### Testing Presentation

Test presentation flows:

```swift
await store.send(.addButtonTapped) {
  $0.addItem = ItemFormFeature.State()
}

await store.send(.addItem(.presented(.cancelButtonTapped))) {
  $0.addItem = nil
}
```

## Testing Patterns

### 1. Testing Success Paths

Test the happy path of your feature:

```swift
@Test
func testSaveProfile_Success() async {
  let store = TestStore(initialState: ProfileFeature.State(user: User.mock)) {
    ProfileFeature()
  } withDependencies: {
    $0.userClient.updateProfile = { _ in }
  }
  
  await store.send(.nameChanged("New Name")) {
    $0.user.name = "New Name"
  }
  
  await store.send(.saveButtonTapped) {
    $0.isSaving = true
  }
  
  await store.receive(.profileSaved) {
    $0.isSaving = false
    $0.isEditing = false
  }
}
```

### 2. Testing Failure Paths

Test error handling:

```swift
@Test
func testSaveProfile_Failure() async {
  let error = UserError.updateFailed
  
  let store = TestStore(initialState: ProfileFeature.State(user: User.mock)) {
    ProfileFeature()
  } withDependencies: {
    $0.userClient.updateProfile = { _ in throw error }
  }
  
  await store.send(.nameChanged("New Name")) {
    $0.user.name = "New Name"
  }
  
  await store.send(.saveButtonTapped) {
    $0.isSaving = true
  }
  
  await store.receive(.profileSaveFailed(error)) {
    $0.isSaving = false
    $0.error = error
  }
}
```

### 3. Testing Time-Based Effects

Test time-based effects using `ImmediateClock` or `TestClock`:

```swift
@Test
func testDebounce() async {
  let clock = TestClock()
  
  let store = TestStore(initialState: SearchFeature.State()) {
    SearchFeature()
  } withDependencies: {
    $0.continuousClock = clock
    $0.searchClient.search = { _ in ["Result"] }
  }
  
  await store.send(.searchQueryChanged("Test")) {
    $0.query = "Test"
  }
  
  // Advance clock to trigger debounced effect
  await clock.advance(by: .milliseconds(300))
  
  await store.receive(.searchResultsLoaded(["Result"])) {
    $0.results = ["Result"]
  }
}
```

### 4. Testing Long-Running Effects

Test long-running effects:

```swift
@Test
func testLongRunningEffect() async {
  let store = TestStore(initialState: FeatureState()) {
    Feature()
  } withDependencies: {
    $0.client.stream = { AsyncStream { continuation in
      continuation.yield("First")
      continuation.yield("Second")
      continuation.yield("Third")
      continuation.finish()
    }}
  }
  
  await store.send(.startStream) {
    $0.isStreaming = true
  }
  
  await store.receive(.streamOutput("First")) {
    $0.outputs.append("First")
  }
  
  await store.receive(.streamOutput("Second")) {
    $0.outputs.append("Second")
  }
  
  await store.receive(.streamOutput("Third")) {
    $0.outputs.append("Third")
  }
  
  await store.receive(.streamCompleted) {
    $0.isStreaming = false
  }
}
```

### 5. Testing Child Features

Test parent-child feature interactions:

```swift
@Test
func testParentChildInteraction() async {
  let store = TestStore(initialState: ParentFeature.State()) {
    ParentFeature()
  }
  
  await store.send(.addButtonTapped) {
    $0.child = ChildFeature.State()
  }
  
  await store.send(.child(.presented(.nameChanged("New Name")))) {
    $0.child?.name = "New Name"
  }
  
  await store.send(.child(.presented(.saveButtonTapped)))
  
  await store.receive(.child(.dismiss)) {
    $0.child = nil
  }
}
```

### 6. Testing Navigation Flows

Test complex navigation flows:

```swift
@Test
func testNavigationFlow() async {
  let store = TestStore(initialState: RootFeature.State()) {
    RootFeature()
  }
  
  let item = Item(id: "1", name: "Test Item")
  
  // Navigate to detail
  await store.send(.detailButtonTapped(item)) {
    $0.path.append(.detail(DetailFeature.State(item: item)))
  }
  
  // Navigate to edit
  await store.send(.path(.element(id: 0, action: .detail(.editButtonTapped)))) {
    $0.path.append(.edit(EditFeature.State(item: item)))
  }
  
  // Save and pop
  await store.send(.path(.element(id: 1, action: .edit(.saveButtonTapped)))) {
    $0.path.pop(from: 1)
  }
}
```

### 7. Testing Binding Actions

Test binding actions:

```swift
@Test
func testBindingActions() async {
  let store = TestStore(initialState: SettingsFeature.State()) {
    SettingsFeature()
  }
  
  await store.send(.binding(.set(\.name, "New Name"))) {
    $0.name = "New Name"
  }
  
  await store.send(.binding(.set(\.notificationsEnabled, true))) {
    $0.notificationsEnabled = true
  }
}
```

## Advanced Testing Patterns

### 1. Testing Complex State Assertions

Use `store.assert` for complex state assertions:

```swift
@Test
func testComplexStateAssertions() async {
  let store = TestStore(initialState: FeatureState()) {
    Feature()
  }
  
  await store.send(.action)
  
  await store.assert {
    $0.property1 = "New Value"
    $0.property2 = 42
    $0.complexProperty.nestedProperty = true
    $0.array = [1, 2, 3]
    $0.dictionary = ["key": "value"]
  }
}
```

### 2. Testing Shared State

Test shared state mutations:

```swift
@Test
func testSharedState() async {
  let store = TestStore(initialState: FeatureState()) {
    Feature()
  } withDependencies: {
    $0.sharedState.withLock { $0 = SharedState() }
  }
  
  await store.send(.incrementSharedCounter) {
    $0.$count.withLock { $0 += 1 }
  }
  
  await store.send(.readSharedCounter) {
    $0.localCount = $0.$count.withLock { $0 }
  }
}
```

### 3. Testing Concurrency

Test concurrent operations:

```swift
@Test
func testConcurrentOperations() async {
  let store = TestStore(initialState: FeatureState()) {
    Feature()
  } withDependencies: {
    $0.client.operation1 = { "Result 1" }
    $0.client.operation2 = { "Result 2" }
    $0.client.operation3 = { "Result 3" }
  }
  
  await store.send(.performConcurrentOperations) {
    $0.isLoading = true
  }
  
  await store.receive(.concurrentOperationsCompleted(
    result1: "Result 1",
    result2: "Result 2",
    result3: "Result 3"
  )) {
    $0.isLoading = false
    $0.result1 = "Result 1"
    $0.result2 = "Result 2"
    $0.result3 = "Result 3"
  }
}
```

### 4. Testing Cancellation on State Change

Test cancellation of effects when state changes:

```swift
@Test
func testCancellationOnStateChange() async {
  let store = TestStore(initialState: FeatureState()) {
    Feature()
  } withDependencies: {
    $0.client.longRunningOperation = { _ in
      try await Task.sleep(for: .seconds(10))
      return "Result"
    }
  }
  
  await store.send(.startOperation("Input")) {
    $0.isLoading = true
    $0.input = "Input"
  }
  
  // Change input, which should cancel the previous operation
  await store.send(.startOperation("New Input")) {
    $0.isLoading = true
    $0.input = "New Input"
  }
  
  // Only the result from the second operation should be received
  await store.receive(.operationCompleted("Result")) {
    $0.isLoading = false
    $0.result = "Result"
  }
}
```

### 5. Testing Side Effects

Test side effects using dependency overrides:

```swift
@Test
func testSideEffects() async {
  var analyticsEvents: [String] = []
  
  let store = TestStore(initialState: FeatureState()) {
    Feature()
  } withDependencies: {
    $0.analytics.trackEvent = { event in
      analyticsEvents.append(event)
    }
  }
  
  await store.send(.buttonTapped)
  
  XCTAssertEqual(analyticsEvents, ["button_tapped"])
}
```

## Best Practices

### 1. Create TestStore Instances Within Tests

Create `TestStore` instances within individual tests:

```swift
// ❌ Shared TestStore
class FeatureTests: XCTestCase {
  let store = TestStore(initialState: FeatureState()) {
    Feature()
  }
  
  func testFeature1() async {
    // Tests using shared store
  }
  
  func testFeature2() async {
    // Tests using shared store
  }
}

// ✅ Individual TestStore instances
class FeatureTests: XCTestCase {
  func testFeature1() async {
    let store = TestStore(initialState: FeatureState()) {
      Feature()
    }
    
    // Tests using this store
  }
  
  func testFeature2() async {
    let store = TestStore(initialState: FeatureState()) {
      Feature()
    }
    
    // Tests using this store
  }
}
```

### 2. Override Dependencies for Controlled Testing

Override dependencies for controlled testing:

```swift
// ❌ Real dependencies
let store = TestStore(initialState: FeatureState()) {
  Feature()
}

// ✅ Overridden dependencies
let store = TestStore(initialState: FeatureState()) {
  Feature()
} withDependencies: {
  $0.client.fetch = { _ in "Test result" }
  $0.continuousClock = ImmediateClock()
  $0.date = { Date(timeIntervalSince1970: 0) }
  $0.uuid = { UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }
}
```

### 3. Use ImmediateClock for Time-Based Tests

Use `ImmediateClock` for time-based tests:

```swift
// ❌ Real clock
let store = TestStore(initialState: FeatureState()) {
  Feature()
}

// ✅ ImmediateClock
let store = TestStore(initialState: FeatureState()) {
  Feature()
} withDependencies: {
  $0.continuousClock = ImmediateClock()
}
```

### 4. Test Both Success and Failure Paths

Test both success and failure paths for all effects:

```swift
// ❌ Only testing success path
@Test
func testFeature() async {
  let store = TestStore(initialState: FeatureState()) {
    Feature()
  } withDependencies: {
    $0.client.fetch = { _ in "Success" }
  }
  
  // Test success path
}

// ✅ Testing both success and failure paths
@Test
func testFeature_Success() async {
  let store = TestStore(initialState: FeatureState()) {
    Feature()
  } withDependencies: {
    $0.client.fetch = { _ in "Success" }
  }
  
  // Test success path
}

@Test
func testFeature_Failure() async {
  let error = NSError(domain: "test", code: 1)
  
  let store = TestStore(initialState: FeatureState()) {
    Feature()
  } withDependencies: {
    $0.client.fetch = { _ in throw error }
  }
  
  // Test failure path
}
```

### 5. Verify Cancellation of Effects

Verify cancellation of effects when appropriate:

```swift
@Test
func testCancellation() async {
  let store = TestStore(initialState: FeatureState()) {
    Feature()
  }
  
  await store.send(.startOperation) {
    $0.isLoading = true
  }
  
  await store.send(.cancelOperation) {
    $0.isLoading = false
  }
  
  // No actions should be received after cancellation
}
```

### 6. Use Descriptive Test Names

Use descriptive test names:

```swift
// ❌ Unclear test name
@Test
func testFeature() async {
  // Test implementation
}

// ✅ Descriptive test name
@Test
func testSaveProfile_WithValidInput_ShouldUpdateProfileAndDismissScreen() async {
  // Test implementation
}
```

### 7. Test One Thing at a Time

Test one thing at a time:

```swift
// ❌ Testing multiple things
@Test
func testFeature() async {
  // Test login
  // Test profile update
  // Test logout
}

// ✅ Testing one thing at a time
@Test
func testLogin_WithValidCredentials_ShouldSucceed() async {
  // Test login
}

@Test
func testProfileUpdate_WithValidInput_ShouldSucceed() async {
  // Test profile update
}

@Test
func testLogout_ShouldClearUserData() async {
  // Test logout
}
```

## Conclusion

Testing in TCA provides a powerful way to verify the behavior of your features in a predictable and deterministic way. By following the principles and best practices outlined in this document, you can create tests that are easy to understand, modify, and maintain.
