# Navigation Patterns

**Navigation:** [Back to iOS Architecture](../README.md) | [Tree-Based Navigation](./TreeBasedNavigation.md) | [Stack-Based Navigation](./StackBasedNavigation.md)

---

> **Note:** As this is an MVP, the navigation patterns may evolve as the project matures.

## Navigation Design Principles

Navigation in LifeSignal follows these core principles:

1. **State-Driven**: Navigation is driven by state changes
2. **Type-Safe**: Navigation is type-safe
3. **Testable**: Navigation is testable
4. **Composable**: Navigation is composable
5. **Declarative**: Navigation is declarative

## Navigation Types

LifeSignal uses several types of navigation:

### 1. Tree-Based Navigation

For modal presentations, sheets, popovers, and alerts:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    @Presents var destination: Destination.State?
    var items: [Item] = []
  }
  
  enum Action: Equatable, Sendable {
    case destination(PresentationAction<Destination.Action>)
    case addButtonTapped
    case dismissButtonTapped
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .addButtonTapped:
        state.destination = .add(AddFeature.State())
        return .none
        
      case .dismissButtonTapped:
        state.destination = nil
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

@Reducer
struct Destination {
  @ObservableState
  enum State: Equatable, Sendable {
    case add(AddFeature.State)
    case edit(EditFeature.State)
    case detail(DetailFeature.State)
  }
  
  enum Action: Equatable, Sendable {
    case add(AddFeature.Action)
    case edit(EditFeature.Action)
    case detail(DetailFeature.Action)
  }
  
  var body: some ReducerOf<Self> {
    Scope(state: \.add, action: \.add) {
      AddFeature()
    }
    Scope(state: \.edit, action: \.edit) {
      EditFeature()
    }
    Scope(state: \.detail, action: \.detail) {
      DetailFeature()
    }
  }
}
```

### 2. Stack-Based Navigation

For navigation stacks:

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
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .itemSelected(item):
        state.path.append(.detail(DetailFeature.State(item: item)))
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

### 3. Tab-Based Navigation

For tab bars:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    var selectedTab: Tab = .home
    var home: HomeFeature.State = .init()
    var profile: ProfileFeature.State = .init()
    var settings: SettingsFeature.State = .init()
  }
  
  enum Action: Equatable, Sendable {
    case selectedTabChanged(Tab)
    case home(HomeFeature.Action)
    case profile(ProfileFeature.Action)
    case settings(SettingsFeature.Action)
  }
  
  enum Tab: Equatable, Sendable {
    case home
    case profile
    case settings
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .selectedTabChanged(tab):
        state.selectedTab = tab
        return .none
        
      case .home, .profile, .settings:
        return .none
      }
    }
    
    Scope(state: \.home, action: \.home) {
      HomeFeature()
    }
    
    Scope(state: \.profile, action: \.profile) {
      ProfileFeature()
    }
    
    Scope(state: \.settings, action: \.settings) {
      SettingsFeature()
    }
  }
}
```

### 4. Nested Navigation

For combining navigation types:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    var selectedTab: Tab = .home
    var home: HomeFeature.State = .init()
    var profile: ProfileFeature.State = .init()
    var settings: SettingsFeature.State = .init()
    @Presents var destination: Destination.State?
  }
  
  enum Action: Equatable, Sendable {
    case selectedTabChanged(Tab)
    case home(HomeFeature.Action)
    case profile(ProfileFeature.Action)
    case settings(SettingsFeature.Action)
    case destination(PresentationAction<Destination.Action>)
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
    
    Scope(state: \.home, action: \.home) {
      HomeFeature()
    }
    
    Scope(state: \.profile, action: \.profile) {
      ProfileFeature()
    }
    
    Scope(state: \.settings, action: \.settings) {
      SettingsFeature()
    }
    
    .ifLet(\.$destination, action: \.destination) {
      Destination()
    }
  }
}
```

## SwiftUI Integration

### Tree-Based Navigation

```swift
struct FeatureView: View {
  @Bindable var store: StoreOf<Feature>
  
  var body: some View {
    List {
      ForEach(store.items) { item in
        Text(item.name)
      }
      
      Button("Add") {
        store.send(.addButtonTapped)
      }
    }
    .sheet(item: $store.scope(state: \.destination?.add, action: \.destination.add)) { store in
      AddView(store: store)
    }
    .sheet(item: $store.scope(state: \.destination?.edit, action: \.destination.edit)) { store in
      EditView(store: store)
    }
    .sheet(item: $store.scope(state: \.destination?.detail, action: \.destination.detail)) { store in
      DetailView(store: store)
    }
  }
}
```

### Stack-Based Navigation

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

### Tab-Based Navigation

```swift
struct FeatureView: View {
  @Bindable var store: StoreOf<Feature>
  
  var body: some View {
    TabView(selection: $store.selectedTab) {
      HomeView(store: store.scope(state: \.home, action: \.home))
        .tabItem {
          Label("Home", systemImage: "house")
        }
        .tag(Feature.Tab.home)
      
      ProfileView(store: store.scope(state: \.profile, action: \.profile))
        .tabItem {
          Label("Profile", systemImage: "person")
        }
        .tag(Feature.Tab.profile)
      
      SettingsView(store: store.scope(state: \.settings, action: \.settings))
        .tabItem {
          Label("Settings", systemImage: "gear")
        }
        .tag(Feature.Tab.settings)
    }
  }
}
```

## Navigation Testing

### Tree-Based Navigation Testing

```swift
@Test
func testAddButtonTapped() async {
  let store = TestStore(initialState: Feature.State()) {
    Feature()
  }
  
  await store.send(.addButtonTapped) {
    $0.destination = .add(AddFeature.State())
  }
  
  await store.send(.dismissButtonTapped) {
    $0.destination = nil
  }
}
```

### Stack-Based Navigation Testing

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
```

## Best Practices

1. **Use @Presents**: Use `@Presents` for optional destination state
2. **Use PresentationAction**: Use `PresentationAction` for handling child feature actions
3. **Use StackState**: Use `StackState` for stack-based navigation
4. **Handle Dismissal**: Handle dismissal by setting destination state to `nil`
5. **Prefer Composition**: Prefer composition with `Scope` and `ifLet` for complex navigation
6. **Test Navigation**: Test navigation state changes
7. **Use Bindable**: Use `@Bindable` for SwiftUI integration
8. **Use $store.scope**: Use `$store.scope(state:action:)` for navigation binding
9. **Document Navigation**: Document the navigation flow
10. **Keep Navigation Simple**: Keep navigation as simple as possible
