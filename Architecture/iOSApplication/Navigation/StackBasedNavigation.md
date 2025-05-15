# Stack-Based Navigation

**Navigation:** [Back to iOS Architecture](../README.md) | [Navigation Patterns](./NavigationPatterns.md) | [Tree-Based Navigation](./TreeBasedNavigation.md)

---

> **Note:** As this is an MVP, the stack-based navigation approach may evolve as the project matures.

## Stack-Based Navigation Overview

Stack-based navigation in LifeSignal is used for navigation stacks. It follows these core principles:

1. **State-Driven**: Navigation is driven by state changes
2. **Type-Safe**: Navigation is type-safe
3. **Testable**: Navigation is testable
4. **Composable**: Navigation is composable
5. **Declarative**: Navigation is declarative

## State Definition

Stack-based navigation state is defined using `StackState`:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    var path = StackState<Path.State>()
    var items: [Item] = []
  }
  
  enum Action: Equatable, Sendable {
    case path(StackAction<Path.State, Path.Action>)
    case itemSelected(Item)
  }
  
  // Body, etc.
}
```

## Path Definition

Paths are defined using an enum:

```swift
@Reducer
struct Path {
  @ObservableState
  enum State: Equatable, Sendable {
    case detail(DetailFeature.State)
    case edit(EditFeature.State)
  }
  
  enum Action: Equatable, Sendable {
    case detail(DetailFeature.Action)
    case edit(EditFeature.Action)
  }
  
  var body: some ReducerOf<Self> {
    Scope(state: \.detail, action: \.detail) {
      DetailFeature()
    }
    Scope(state: \.edit, action: \.edit) {
      EditFeature()
    }
  }
}
```

## Reducer Implementation

The reducer handles navigation actions:

```swift
@Reducer
struct Feature {
  // State, Action, etc.
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .itemSelected(item):
        state.path.append(.detail(DetailFeature.State(item: item)))
        return .none
        
      case let .path(.element(id: _, action: .detail(.editButtonTapped))):
        guard case let .detail(detailState) = state.path[id: id] else {
          return .none
        }
        state.path.append(.edit(EditFeature.State(item: detailState.item)))
        return .none
        
      case let .path(.element(id: _, action: .edit(.saveButtonTapped))):
        // Handle save button tapped in edit feature
        return .none
        
      case .path(.popFrom(id: _)):
        // Handle pop action
        return .none
        
      case .path:
        return .none
      }
    }
    .forEach(\.path, action: \.path) {
      Path()
    }
  }
}
```

## SwiftUI Integration

Stack-based navigation is integrated with SwiftUI using `NavigationStack`:

```swift
struct FeatureView: View {
  @Bindable var store: StoreOf<Feature>
  
  var body: some View {
    NavigationStack(
      path: $store.scope(state: \.path, action: \.path)
    ) {
      List {
        ForEach(store.items) { item in
          Button {
            store.send(.itemSelected(item))
          } label: {
            Text(item.name)
          }
        }
      }
      .navigationTitle("Items")
    } destination: { store in
      switch store.case {
      case .detail(let store):
        DetailView(store: store)
      case .edit(let store):
        EditView(store: store)
      }
    }
  }
}
```

## Nested Navigation

Stack-based navigation can be combined with tree-based navigation:

```swift
@Reducer
struct DetailFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    let item: Item
    @Presents var destination: Destination.State?
  }
  
  enum Action: Equatable, Sendable {
    case editButtonTapped
    case shareButtonTapped
    case destination(PresentationAction<Destination.Action>)
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .editButtonTapped:
        // This will be handled by the parent feature
        return .none
        
      case .shareButtonTapped:
        state.destination = .share(ShareFeature.State(item: state.item))
        return .none
        
      case .destination:
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination) {
      Destination()
    }
  }
}
```

## Programmatic Navigation

Navigation can be performed programmatically:

```swift
@Reducer
struct Feature {
  // State, Action, etc.
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .navigateToDetailButtonTapped(let item):
        state.path.append(.detail(DetailFeature.State(item: item)))
        return .none
        
      case .navigateToEditButtonTapped(let item):
        state.path.append(.edit(EditFeature.State(item: item)))
        return .none
        
      case .navigateBackButtonTapped:
        _ = state.path.popLast()
        return .none
        
      case .navigateToRootButtonTapped:
        state.path.removeAll()
        return .none
        
      // Other cases...
      }
    }
    .forEach(\.path, action: \.path) {
      Path()
    }
  }
}
```

## Deep Linking

Deep linking is supported by setting the path state:

```swift
@Reducer
struct Feature {
  // State, Action, etc.
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .deepLink(url):
        // Parse the URL and set the path state
        if url.path.contains("/items/") {
          let itemId = url.lastPathComponent
          if let item = state.items.first(where: { $0.id == itemId }) {
            state.path.append(.detail(DetailFeature.State(item: item)))
          }
        }
        return .none
        
      // Other cases...
      }
    }
    .forEach(\.path, action: \.path) {
      Path()
    }
  }
}
```

## Testing

Stack-based navigation is tested using `TestStore`:

```swift
@Test
func testItemSelected() async {
  let item = Item(id: "1", name: "Test")
  let store = TestStore(initialState: Feature.State(items: [item])) {
    Feature()
  }
  
  await store.send(.itemSelected(item)) {
    $0.path.append(.detail(DetailFeature.State(item: item)))
  }
  
  await store.send(.path(.popFrom(id: 0))) {
    $0.path = []
  }
}

@Test
func testEditButtonTapped() async {
  let item = Item(id: "1", name: "Test")
  let store = TestStore(initialState: Feature.State()) {
    Feature()
  }
  
  await store.send(.itemSelected(item)) {
    $0.path.append(.detail(DetailFeature.State(item: item)))
  }
  
  await store.send(.path(.element(id: 0, action: .detail(.editButtonTapped)))) {
    $0.path.append(.edit(EditFeature.State(item: item)))
  }
  
  await store.send(.path(.popFrom(id: 1))) {
    $0.path = [
      .detail(DetailFeature.State(item: item))
    ]
  }
}
```

## Navigation with Multiple Stacks

Multiple navigation stacks can be used:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    var selectedTab: Tab = .home
    var homePath = StackState<HomePath.State>()
    var profilePath = StackState<ProfilePath.State>()
    var settingsPath = StackState<SettingsPath.State>()
  }
  
  enum Action: Equatable, Sendable {
    case selectedTabChanged(Tab)
    case homePath(StackAction<HomePath.State, HomePath.Action>)
    case profilePath(StackAction<ProfilePath.State, ProfilePath.Action>)
    case settingsPath(StackAction<SettingsPath.State, SettingsPath.Action>)
  }
  
  enum Tab: Equatable, Sendable {
    case home
    case profile
    case settings
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      // Reducer implementation...
    }
    
    .forEach(\.homePath, action: \.homePath) {
      HomePath()
    }
    
    .forEach(\.profilePath, action: \.profilePath) {
      ProfilePath()
    }
    
    .forEach(\.settingsPath, action: \.settingsPath) {
      SettingsPath()
    }
  }
}
```

## Best Practices

1. **Use StackState**: Use `StackState` for stack-based navigation
2. **Use StackAction**: Use `StackAction` for handling stack actions
3. **Handle Element Actions**: Handle element actions using the `.element(id:action:)` case
4. **Handle Pop Actions**: Handle pop actions using the `.popFrom(id:)` case
5. **Use forEach**: Use the `forEach` operator to integrate the path reducer
6. **Test Navigation**: Test navigation state changes
7. **Use Bindable**: Use `@Bindable` for SwiftUI integration
8. **Use $store.scope**: Use `$store.scope(state:action:)` for navigation binding
9. **Document Navigation**: Document the navigation flow
10. **Keep Navigation Simple**: Keep navigation as simple as possible
