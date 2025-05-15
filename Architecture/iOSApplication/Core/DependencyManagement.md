# Dependency Management

**Navigation:** [Back to iOS Architecture](../README.md) | [Infrastructure Layers](./InfrastructureLayers.md) | [Client Architecture](./ClientArchitecture.md) | [Firebase Integration](./Firebase/FirebaseIntegration.md)

---

> **Note:** As this is an MVP, the dependency management approach may evolve as the project matures.

## Dependency Design Principles

Dependencies in LifeSignal follow these core principles:

1. **Protocol-Based**: Dependencies are defined as protocols or struct-based clients
2. **Dependency Injection**: Dependencies are injected via TCA's dependency system
3. **Testability**: Dependencies are designed to be testable
4. **Isolation**: Dependencies isolate implementation details
5. **Configurability**: Dependencies can be configured for different environments

## Dependency Definition

Dependencies are defined using the `@DependencyClient` macro:

```swift
@DependencyClient
struct NumberFactClient: Sendable {
  var fetch: @Sendable (Int) async throws -> String = { _ in
    throw DependencyError.unimplemented("NumberFactClient.fetch")
  }
}
```

## Dependency Registration

Dependencies are registered with TCA's dependency system:

```swift
extension NumberFactClient: DependencyKey {
  static let liveValue = Self(
    fetch: { number in
      let (data, _) = try await URLSession.shared
        .data(from: URL(string: "http://numbersapi.com/\(number)")!
      )
      return String(decoding: data, as: UTF8.self)
    }
  )
  
  static let testValue = Self(
    fetch: { number in
      "\(number) is a good number Brent"
    }
  )
  
  static let previewValue = Self(
    fetch: { number in
      "\(number) is a preview number"
    }
  )
}

extension DependencyValues {
  var numberFact: NumberFactClient {
    get { self[NumberFactClient.self] }
    set { self[NumberFactClient.self] = newValue }
  }
}
```

## Dependency Usage

Dependencies are used in reducers via the `@Dependency` property wrapper:

```swift
@Reducer
struct Feature {
  @Dependency(\.numberFactClient) var numberFactClient
  
  // State, Action, etc.
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .numberFactButtonTapped:
        return .run { [count = state.count] send in
          do {
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

## Dependency Types

LifeSignal uses several types of dependencies:

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
    throw UserError.notAuthenticated
  }
  
  var updateUser: @Sendable (User) async throws -> Void = { _ in
    throw UserError.updateFailed
  }
  
  // Other methods...
}
```

### 3. System Dependencies

Dependencies for system operations:

```swift
@Dependency(\.continuousClock) var clock
@Dependency(\.uuid) var uuid
@Dependency(\.date) var date
```

## Dependency Testing

Dependencies are tested using the `withDependencies` modifier:

```swift
@Test
func testNumberFact() async {
  let store = TestStore(initialState: Feature.State()) {
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

## Dependency Namespacing

Related dependencies are namespaced for cleaner access:

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

Usage:

```swift
@Reducer
struct Feature {
  @Dependency(\.firebase.auth) var authClient
  @Dependency(\.firebase.firestore) var firestoreClient
  
  // State, Action, etc.
}
```

## Dependency Configuration

Dependencies are configured for different environments:

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
          $0.firebase = .liveValue
          $0.continuousClock = ContinuousClock()
          $0.uuid = UUID.init
          $0.date = Date.init
        }
      )
    }
  }
}
```

## Dependency Overrides for Testing

Dependencies are overridden for testing:

```swift
@Test
func testFeature() async {
  let store = TestStore(initialState: Feature.State()) {
    Feature()
  } withDependencies: {
    $0.firebase.auth.currentUser = { User.mock }
    $0.firebase.firestore.getDocument = { _ in DocumentSnapshot.mock }
    $0.continuousClock = ImmediateClock()
    $0.uuid = { UUID(0) }
    $0.date = { Date(timeIntervalSince1970: 0) }
  }
  
  // Test the feature...
}
```

## Dependency Overrides for Previews

Dependencies are overridden for previews:

```swift
struct FeatureView_Previews: PreviewProvider {
  static var previews: some View {
    FeatureView(
      store: Store(initialState: Feature.State()) {
        Feature()
      } withDependencies: {
        $0.firebase.auth.currentUser = { User.mock }
        $0.firebase.firestore.getDocument = { _ in DocumentSnapshot.mock }
      }
    )
  }
}
```

## Best Practices

1. **Use @DependencyClient**: Use the `@DependencyClient` macro for client definitions
2. **Provide Default Values**: Provide default values for non-throwing closures
3. **Remove Argument Labels**: Remove argument labels in function types for cleaner syntax
4. **Provide Live, Test, and Preview Values**: Provide implementations for all environments
5. **Use Namespacing**: Use namespaced access for related dependencies
6. **Test with Overrides**: Test features with dependency overrides
7. **Document Dependencies**: Document the purpose of each dependency
8. **Keep Dependencies Focused**: Each dependency should have a single responsibility
9. **Use Structured Concurrency**: Use async/await for all asynchronous operations
10. **Handle Errors**: Handle errors within dependencies
