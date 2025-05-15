# Testing Strategy

**Navigation:** [Back to iOS Architecture](../README.md) | [TestStore Usage](./TestStoreUsage.md) | [Dependency Testing](./DependencyTesting.md)

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

Infrastructure components are tested in isolation:

- **Client Tests** - Test infrastructure-agnostic clients
- **Adapter Tests** - Test backend-specific adapters
- **Mapping Tests** - Test mapping between domain models and DTOs

### Domain Testing

Domain models and logic are tested in isolation:

- **Model Tests** - Test domain model behavior
- **Validation Tests** - Test validation logic
- **Business Logic Tests** - Test business logic

### Feature Testing

Features are tested using TCA's `TestStore`:

- **State Tests** - Test state changes
- **Effect Tests** - Test effects
- **Navigation Tests** - Test navigation
- **Error Handling Tests** - Test error handling

### UI Testing

UI components are tested using SwiftUI's testing tools:

- **View Tests** - Test view rendering
- **Interaction Tests** - Test user interactions
- **Accessibility Tests** - Test accessibility

## Testing Tools

LifeSignal uses the following testing tools:

- **XCTest** - Apple's testing framework
- **TestStore** - TCA's testing tool for features
- **withDependencies** - TCA's dependency override tool
- **ImmediateClock** - TCA's clock for testing time-based effects
- **ViewInspector** - Tool for testing SwiftUI views

## Test Structure

Tests are structured using XCTest:

```swift
import XCTest
import ComposableArchitecture
@testable import LifeSignal

@MainActor
final class FeatureTests: XCTestCase {
  @Test
  func testIncrementButtonTapped() async {
    let store = TestStore(initialState: Feature.State(count: 0)) {
      Feature()
    }
    
    await store.send(.incrementButtonTapped) {
      $0.count = 1
    }
  }
  
  @Test
  func testDecrementButtonTapped() async {
    let store = TestStore(initialState: Feature.State(count: 1)) {
      Feature()
    }
    
    await store.send(.decrementButtonTapped) {
      $0.count = 0
    }
  }
  
  @Test
  func testNumberFactButtonTapped() async {
    let store = TestStore(initialState: Feature.State(count: 0)) {
      Feature()
    } withDependencies: {
      $0.numberFactClient.fetch = { "\($0) is a test number" }
    }
    
    await store.send(.numberFactButtonTapped)
    
    await store.receive(\.numberFactResponse) {
      $0.numberFact = "0 is a test number"
    }
  }
}
```

## Test Organization

Tests are organized by feature and layer:

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
            └── FirebaseAuthClientTests.swift
```

## Test Doubles

LifeSignal uses the following test doubles:

- **Mocks** - Objects with predefined behavior
- **Stubs** - Objects that return predefined values
- **Spies** - Objects that record interactions
- **Fakes** - Simplified implementations of real objects

## Dependency Testing

Dependencies are tested using TCA's dependency system:

```swift
@Test
func testNumberFactButtonTapped() async {
  let store = TestStore(initialState: Feature.State(count: 0)) {
    Feature()
  } withDependencies: {
    $0.numberFactClient.fetch = { "\($0) is a test number" }
  }
  
  await store.send(.numberFactButtonTapped)
  
  await store.receive(\.numberFactResponse) {
    $0.numberFact = "0 is a test number"
  }
}
```

## Firebase Testing

Firebase is tested using test doubles:

```swift
@Test
func testGetUser() async {
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

## UI Testing

UI is tested using ViewInspector:

```swift
@Test
func testFeatureView() throws {
  let view = FeatureView(
    store: Store(initialState: Feature.State(count: 0)) {
      Feature()
    }
  )
  
  let text = try view.inspect().find(text: "0")
  XCTAssertNotNil(text)
  
  let incrementButton = try view.inspect().find(button: "Increment")
  XCTAssertNotNil(incrementButton)
  
  let decrementButton = try view.inspect().find(button: "Decrement")
  XCTAssertNotNil(decrementButton)
}
```

## Test Coverage

LifeSignal aims for high test coverage:

- **Core Domain Models** - 100% coverage
- **Infrastructure Clients** - 100% coverage
- **Feature Reducers** - 100% coverage
- **UI Components** - 80% coverage

## Continuous Integration

Tests are run on CI for every pull request:

- **Unit Tests** - Run on every PR
- **Integration Tests** - Run on every PR
- **UI Tests** - Run on every PR
- **Performance Tests** - Run on scheduled basis

## Best Practices

1. **Test in Isolation**: Test components in isolation
2. **Use TestStore**: Use `TestStore` for feature tests
3. **Override Dependencies**: Override dependencies for controlled testing
4. **Test Both Success and Failure**: Test both success and failure paths
5. **Test Navigation**: Test navigation state changes
6. **Test Error Handling**: Test error handling
7. **Test Edge Cases**: Test edge cases
8. **Keep Tests Fast**: Keep tests fast for quick feedback
9. **Use Test Doubles**: Use test doubles for dependencies
10. **Document Tests**: Document the purpose of each test
