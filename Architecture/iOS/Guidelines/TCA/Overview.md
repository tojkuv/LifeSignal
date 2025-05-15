# The Composable Architecture (TCA) Overview

**Navigation:** [Back to iOS Architecture](../../README.md) | [State Management](StateManagement.md) | [Action Design](ActionDesign.md) | [Effect Management](EffectManagement.md) | [Dependency Injection](DependencyInjection.md)

---

## Introduction

The Composable Architecture (TCA) is a library for building applications in a consistent and understandable way, with composition, testing, and ergonomics in mind. It provides a way to structure applications using a unidirectional data flow pattern, where:

1. **State** describes the data your feature needs to render
2. **Actions** represent all the events that can occur in your feature
3. **Reducers** handle actions and update state
4. **Effects** perform side effects and feed data back into the system
5. **Store** connects the reducer to the view

## Core Components

### State

State is the single source of truth for a feature:

```swift
@Reducer
struct CounterFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var count = 0
    var isLoading = false
    var error: Error?
  }
  
  // Actions, body, etc.
}
```

Key characteristics:
- Must be `Equatable` and `Sendable`
- Should use value types (`struct`)
- Must use `@ObservableState` macro for SwiftUI integration
- Should use `@Presents` for presentation state
- Should use `@Shared` for shared state

[Learn more about State Management →](StateManagement.md)

### Action

Actions represent all the events that can occur in your feature:

```swift
@Reducer
struct CounterFeature {
  // State...
  
  enum Action: Equatable, Sendable {
    case incrementButtonTapped
    case decrementButtonTapped
    case numberFactButtonTapped
    case numberFactResponse(String)
    case numberFactFailed(Error)
  }
  
  // Body, etc.
}
```

Key characteristics:
- Must be `Equatable` and `Sendable`
- Should use `enum` cases with associated values
- Should use `BindableAction` for form fields
- Should use `PresentationAction` for child feature actions

[Learn more about Action Design →](ActionDesign.md)

### Reducer

Reducers handle actions and update state:

```swift
@Reducer
struct CounterFeature {
  // State, Action...
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .incrementButtonTapped:
        state.count += 1
        return .none
        
      case .decrementButtonTapped:
        state.count -= 1
        return .none
        
      case .numberFactButtonTapped:
        state.isLoading = true
        return .run { [count = state.count] send in
          do {
            let fact = try await numberFactClient.fetch(count)
            await send(.numberFactResponse(fact))
          } catch {
            await send(.numberFactFailed(error))
          }
        }
        
      case let .numberFactResponse(fact):
        state.isLoading = false
        state.numberFact = fact
        return .none
        
      case let .numberFactFailed(error):
        state.isLoading = false
        state.error = error
        return .none
      }
    }
  }
}
```

Key characteristics:
- Must use `@Reducer` macro for all feature definitions
- Should use `Reduce` for handling actions
- Should return `.none` for synchronous state updates
- Should use `.run` for asynchronous operations
- Should handle errors within effects

[Learn more about Effect Management →](EffectManagement.md)

### Dependencies

Dependencies are external services and clients injected into reducers:

```swift
@Reducer
struct CounterFeature {
  // State, Action...
  
  @Dependency(\.numberFactClient) var numberFactClient
  
  var body: some ReducerOf<Self> {
    // Reducer implementation...
  }
}
```

Key characteristics:
- Should use `@Dependency` property wrapper for all dependencies
- Should define dependencies as protocols or struct-based clients
- Should provide test implementations for all dependencies
- Should register dependencies with TCA's dependency system

[Learn more about Dependency Injection →](DependencyInjection.md)

### Store

Store connects the reducer to the view:

```swift
struct CounterView: View {
  @Bindable var store: StoreOf<CounterFeature>
  
  var body: some View {
    VStack {
      Text("Count: \(store.count)")
      
      HStack {
        Button("−") { store.send(.decrementButtonTapped) }
        Button("+") { store.send(.incrementButtonTapped) }
      }
      
      Button("Number Fact") { store.send(.numberFactButtonTapped) }
      
      if store.isLoading {
        ProgressView()
      }
      
      if let fact = store.numberFact {
        Text(fact)
      }
      
      if let error = store.error {
        Text("Error: \(error.localizedDescription)")
          .foregroundColor(.red)
      }
    }
  }
}
```

Key characteristics:
- Should use `@Bindable var store: StoreOf<Feature>` in views
- Should use `store.send(...)` to send actions
- Should use `$store.scope(state:action:)` for navigation
- Should use `$store` syntax for form controls

## Feature Composition

TCA enables composition of features through parent-child relationships:

```swift
@Reducer
struct ParentFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var counter: CounterFeature.State
    var settings: SettingsFeature.State?
  }
  
  enum Action: Equatable, Sendable {
    case counter(CounterFeature.Action)
    case settings(PresentationAction<SettingsFeature.Action>)
  }
  
  var body: some ReducerOf<Self> {
    Scope(state: \.counter, action: \.counter) {
      CounterFeature()
    }
    .ifLet(\.settings, action: \.settings) {
      SettingsFeature()
    }
  }
}
```

## Navigation

TCA supports both tree-based and stack-based navigation:

### Tree-Based Navigation

```swift
@Reducer
struct InventoryFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var items: [Item] = []
    @Presents var addItem: ItemFormFeature.State?
    @Presents var editItem: ItemFormFeature.State?
  }
  
  enum Action: Equatable, Sendable {
    case addButtonTapped
    case editButtonTapped(Item)
    case addItem(PresentationAction<ItemFormFeature.Action>)
    case editItem(PresentationAction<ItemFormFeature.Action>)
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .addButtonTapped:
        state.addItem = ItemFormFeature.State()
        return .none
        
      case let .editButtonTapped(item):
        state.editItem = ItemFormFeature.State(item: item)
        return .none
        
      // Handle child actions...
      }
    }
    .ifLet(\.$addItem, action: \.addItem) {
      ItemFormFeature()
    }
    .ifLet(\.$editItem, action: \.editItem) {
      ItemFormFeature()
    }
  }
}
```

### Stack-Based Navigation

```swift
@Reducer
struct RootFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var items: [Item] = []
    var path = StackState<Path.State>()
  }
  
  enum Action: Equatable, Sendable {
    case detailButtonTapped(Item)
    case path(StackAction<Path.State, Path.Action>)
  }
  
  @Reducer
  enum Path {
    case detail(DetailFeature)
    case edit(EditFeature)
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .detailButtonTapped(item):
        state.path.append(.detail(DetailFeature.State(item: item)))
        return .none
        
      // Handle path actions...
      }
    }
    .forEach(\.path, action: \.path)
  }
}
```

[Learn more about Navigation →](Navigation.md)

## Testing

TCA makes testing features straightforward using `TestStore`:

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

Key characteristics:
- Should create `TestStore` instances within individual tests
- Should override dependencies with `withDependencies`
- Should test both success and failure paths
- Should test cancellation of effects when appropriate

[Learn more about Testing →](Testing.md)

## Conclusion

The Composable Architecture (TCA) provides a consistent way to structure applications with a focus on composition, testing, and ergonomics. By following TCA's patterns and best practices, we can build applications that are easier to understand, modify, and test.
