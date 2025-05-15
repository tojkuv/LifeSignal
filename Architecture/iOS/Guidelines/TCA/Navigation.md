# Navigation in TCA

**Navigation:** [Back to TCA Overview](Overview.md) | [State Management](StateManagement.md) | [Action Design](ActionDesign.md) | [Effect Management](EffectManagement.md) | [Dependency Injection](DependencyInjection.md)

---

## Overview

Navigation in The Composable Architecture (TCA) is handled through state management and composition. TCA provides two main approaches to navigation:

1. **Tree-Based Navigation** - For presenting modals, sheets, and popovers
2. **Stack-Based Navigation** - For push/pop navigation in navigation stacks

Both approaches follow the same principles of state-driven navigation, where navigation is triggered by changes to state and handled by the reducer.

## Core Principles

### 1. State-Driven Navigation

Navigation is driven by state changes:

```swift
@Reducer
struct InventoryFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var items: [Item] = []
    @Presents var addItem: ItemFormFeature.State?
  }
  
  enum Action: Equatable, Sendable {
    case addButtonTapped
    case addItem(PresentationAction<ItemFormFeature.Action>)
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .addButtonTapped:
        state.addItem = ItemFormFeature.State()
        return .none
        
      // Other cases...
      }
    }
    .ifLet(\.$addItem, action: \.addItem) {
      ItemFormFeature()
    }
  }
}
```

This ensures:
- Navigation is predictable and testable
- Navigation state is part of the feature's state
- Navigation can be restored after app restarts

### 2. Composition

Navigation is handled through composition:

```swift
@Reducer
struct ParentFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var child: ChildFeature.State
    @Presents var modal: ModalFeature.State?
  }
  
  enum Action: Equatable, Sendable {
    case child(ChildFeature.Action)
    case modal(PresentationAction<ModalFeature.Action>)
    case modalButtonTapped
  }
  
  var body: some ReducerOf<Self> {
    Scope(state: \.child, action: \.child) {
      ChildFeature()
    }
    .ifLet(\.$modal, action: \.modal) {
      ModalFeature()
    }
  }
}
```

This ensures:
- Clear separation of concerns
- Reusable navigation patterns
- Testable navigation flows

### 3. Dismissal

Dismissal is handled by setting destination state to `nil`:

```swift
case .addItem(.presented(.cancelButtonTapped)):
  state.addItem = nil
  return .none
```

Or by using the `dismiss` dependency:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State { /* ... */ }
  enum Action { 
    case closeButtonTapped
    // ...
  }
  @Dependency(\.dismiss) var dismiss
  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .closeButtonTapped:
        return .run { _ in await self.dismiss() }
      }
    }
  }
}
```

This ensures:
- Consistent dismissal patterns
- Clean navigation state
- Testable dismissal flows

## Tree-Based Navigation

Tree-based navigation is used for presenting modals, sheets, and popovers:

### 1. Presentation State

Use `@Presents` for optional destination state:

```swift
@ObservableState
struct State: Equatable, Sendable {
  var items: [Item] = []
  @Presents var addItem: ItemFormFeature.State?
  @Presents var editItem: ItemFormFeature.State?
  @Presents var settings: SettingsFeature.State?
}
```

### 2. Presentation Actions

Use `PresentationAction` for handling child feature actions:

```swift
enum Action: Equatable, Sendable {
  case addButtonTapped
  case editButtonTapped(Item)
  case settingsButtonTapped
  case addItem(PresentationAction<ItemFormFeature.Action>)
  case editItem(PresentationAction<ItemFormFeature.Action>)
  case settings(PresentationAction<SettingsFeature.Action>)
}
```

### 3. Presentation Composition

Use `.ifLet` for composing presentation features:

```swift
var body: some ReducerOf<Self> {
  Reduce { state, action in
    switch action {
    case .addButtonTapped:
      state.addItem = ItemFormFeature.State()
      return .none
      
    case let .editButtonTapped(item):
      state.editItem = ItemFormFeature.State(item: item)
      return .none
      
    case .settingsButtonTapped:
      state.settings = SettingsFeature.State()
      return .none
      
    case .addItem(.presented(.saveButtonTapped)):
      // Handle save from add item
      state.addItem = nil
      return .none
      
    case .addItem(.presented(.cancelButtonTapped)):
      // Handle cancel from add item
      state.addItem = nil
      return .none
      
    case .addItem(.dismiss):
      // Handle dismiss from add item
      state.addItem = nil
      return .none
      
    // Handle other presentation actions...
      
    case .addItem, .editItem, .settings:
      return .none
    }
  }
  .ifLet(\.$addItem, action: \.addItem) {
    ItemFormFeature()
  }
  .ifLet(\.$editItem, action: \.editItem) {
    ItemFormFeature()
  }
  .ifLet(\.$settings, action: \.settings) {
    SettingsFeature()
  }
}
```

### 4. SwiftUI Integration

Use SwiftUI's presentation modifiers with scoped stores:

```swift
struct InventoryView: View {
  @Bindable var store: StoreOf<InventoryFeature>
  
  var body: some View {
    List {
      ForEach(store.items) { item in
        Button {
          store.send(.editButtonTapped(item))
        } label: {
          Text(item.name)
        }
      }
    }
    .toolbar {
      ToolbarItem {
        Button {
          store.send(.addButtonTapped)
        } label: {
          Image(systemName: "plus")
        }
      }
      ToolbarItem {
        Button {
          store.send(.settingsButtonTapped)
        } label: {
          Image(systemName: "gear")
        }
      }
    }
    .sheet(
      store: store.scope(state: \.$addItem, action: \.addItem)
    ) { store in
      ItemFormView(store: store)
    }
    .sheet(
      store: store.scope(state: \.$editItem, action: \.editItem)
    ) { store in
      ItemFormView(store: store)
    }
    .sheet(
      store: store.scope(state: \.$settings, action: \.settings)
    ) { store in
      SettingsView(store: store)
    }
  }
}
```

## Stack-Based Navigation

Stack-based navigation is used for push/pop navigation in navigation stacks:

### 1. Path State

Use `StackState` for navigation path:

```swift
@ObservableState
struct State: Equatable, Sendable {
  var items: [Item] = []
  var path = StackState<Path.State>()
}

@Reducer
enum Path {
  case detail(DetailFeature)
  case edit(EditFeature)
}
```

### 2. Path Actions

Use `StackAction` for handling path actions:

```swift
enum Action: Equatable, Sendable {
  case detailButtonTapped(Item)
  case path(StackAction<Path.State, Path.Action>)
}
```

### 3. Path Composition

Use `.forEach` for composing path features:

```swift
var body: some ReducerOf<Self> {
  Reduce { state, action in
    switch action {
    case let .detailButtonTapped(item):
      state.path.append(.detail(DetailFeature.State(item: item)))
      return .none
      
    case let .path(.element(id: id, action: .detail(.editButtonTapped))):
      guard let detailState = state.path[id: id]?.detail else { return .none }
      state.path.append(.edit(EditFeature.State(item: detailState.item)))
      return .none
      
    case let .path(.element(id: id, action: .edit(.saveButtonTapped))):
      guard let editState = state.path[id: id]?.edit else { return .none }
      state.path.pop(from: id)
      return .run { _ in
        await saveItem(editState.item)
      }
      
    case .path:
      return .none
    }
  }
  .forEach(\.path, action: \.path)
}
```

### 4. SwiftUI Integration

Use SwiftUI's `NavigationStack` with scoped stores:

```swift
struct RootView: View {
  @Bindable var store: StoreOf<RootFeature>
  
  var body: some View {
    NavigationStack(
      path: $store.scope(state: \.path, action: \.path)
    ) {
      List {
        ForEach(store.items) { item in
          Button {
            store.send(.detailButtonTapped(item))
          } label: {
            Text(item.name)
          }
        }
      }
      .navigationTitle("Items")
    } destination: { store in
      switch store.case {
      case let .detail(store):
        DetailView(store: store)
      case let .edit(store):
        EditView(store: store)
      }
    }
  }
}
```

## Advanced Navigation Patterns

### 1. Deep Linking

Implement deep linking by setting the navigation state directly:

```swift
@Reducer
struct AppFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var root = RootFeature.State()
  }
  
  enum Action: Equatable, Sendable {
    case root(RootFeature.Action)
    case deepLink(URL)
  }
  
  var body: some ReducerOf<Self> {
    Scope(state: \.root, action: \.root) {
      RootFeature()
    }
    
    Reduce { state, action in
      switch action {
      case let .deepLink(url):
        // Parse URL and set navigation state
        if url.path.contains("/items/") {
          let itemID = url.lastPathComponent
          if let item = getItem(id: itemID) {
            state.root.path.append(.detail(DetailFeature.State(item: item)))
          }
        }
        return .none
        
      case .root:
        return .none
      }
    }
  }
  
  private func getItem(id: String) -> Item? {
    // Fetch item by ID
    return nil
  }
}
```

### 2. Coordinator Pattern

Implement the coordinator pattern by handling navigation in a parent feature:

```swift
@Reducer
struct AppFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var auth = AuthFeature.State()
    var home: HomeFeature.State?
    var onboarding: OnboardingFeature.State?
  }
  
  enum Action: Equatable, Sendable {
    case auth(AuthFeature.Action)
    case home(HomeFeature.Action)
    case onboarding(OnboardingFeature.Action)
    case appDidLaunch
  }
  
  @Dependency(\.authClient) var authClient
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .appDidLaunch:
        return .run { send in
          for await user in await authClient.authStateStream() {
            if let user = user {
              if user.isOnboarded {
                await send(.auth(.authStateChanged(user)))
              } else {
                await send(.auth(.authStateChanged(user)))
                await send(.auth(.showOnboarding))
              }
            } else {
              await send(.auth(.authStateChanged(nil)))
            }
          }
        }
        .cancellable(id: CancelID.authStateStream)
        
      case .auth(.authStateChanged(let user)):
        if let user = user {
          state.home = HomeFeature.State(user: user)
          state.onboarding = nil
        } else {
          state.home = nil
          state.onboarding = nil
        }
        return .none
        
      case .auth(.showOnboarding):
        state.onboarding = OnboardingFeature.State()
        return .none
        
      case .onboarding(.finished):
        state.onboarding = nil
        return .none
        
      case .auth, .home, .onboarding:
        return .none
      }
    }
    .ifLet(\.home, action: \.home) {
      HomeFeature()
    }
    .ifLet(\.onboarding, action: \.onboarding) {
      OnboardingFeature()
    }
  }
}
```

### 3. Tab-Based Navigation

Implement tab-based navigation by managing tab selection in state:

```swift
@Reducer
struct MainTabFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var selectedTab: Tab = .home
    var home = HomeFeature.State()
    var profile = ProfileFeature.State()
    var settings = SettingsFeature.State()
  }
  
  enum Tab: Equatable, Sendable {
    case home
    case profile
    case settings
  }
  
  enum Action: Equatable, Sendable {
    case tabSelected(Tab)
    case home(HomeFeature.Action)
    case profile(ProfileFeature.Action)
    case settings(SettingsFeature.Action)
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .tabSelected(tab):
        state.selectedTab = tab
        return .none
        
      case .home, .profile, .settings:
        return .none
      }
    }
    .scope(state: \.home, action: \.home) {
      HomeFeature()
    }
    .scope(state: \.profile, action: \.profile) {
      ProfileFeature()
    }
    .scope(state: \.settings, action: \.settings) {
      SettingsFeature()
    }
  }
}
```

SwiftUI integration:

```swift
struct MainTabView: View {
  @Bindable var store: StoreOf<MainTabFeature>
  
  var body: some View {
    TabView(selection: $store.selectedTab) {
      HomeView(
        store: store.scope(state: \.home, action: \.home)
      )
      .tabItem {
        Label("Home", systemImage: "house")
      }
      .tag(MainTabFeature.Tab.home)
      
      ProfileView(
        store: store.scope(state: \.profile, action: \.profile)
      )
      .tabItem {
        Label("Profile", systemImage: "person")
      }
      .tag(MainTabFeature.Tab.profile)
      
      SettingsView(
        store: store.scope(state: \.settings, action: \.settings)
      )
      .tabItem {
        Label("Settings", systemImage: "gear")
      }
      .tag(MainTabFeature.Tab.settings)
    }
  }
}
```

## Best Practices

### 1. Keep Navigation State Minimal

Only include necessary navigation state:

```swift
// ❌ Too much navigation state
@ObservableState
struct State: Equatable, Sendable {
  var items: [Item] = []
  @Presents var addItem: ItemFormFeature.State?
  @Presents var editItem: ItemFormFeature.State?
  @Presents var viewItem: ItemDetailFeature.State?
  @Presents var deleteItem: DeleteConfirmationFeature.State?
  @Presents var shareItem: ShareFeature.State?
}

// ✅ Minimal navigation state
@ObservableState
struct State: Equatable, Sendable {
  var items: [Item] = []
  @Presents var destination: Destination.State?
}

@Reducer
enum Destination {
  case add(ItemFormFeature)
  case edit(ItemFormFeature)
  case detail(ItemDetailFeature)
  case delete(DeleteConfirmationFeature)
  case share(ShareFeature)
}
```

### 2. Use Enum-Based Destinations

Use enums for mutually exclusive destinations:

```swift
@ObservableState
struct State: Equatable, Sendable {
  var items: [Item] = []
  @Presents var destination: Destination.State?
}

@Reducer
enum Destination {
  case add(ItemFormFeature)
  case edit(ItemFormFeature)
  case detail(ItemDetailFeature)
}
```

### 3. Handle Dismissal Consistently

Handle dismissal consistently:

```swift
// ❌ Inconsistent dismissal
case .addItem(.presented(.saveButtonTapped)):
  state.addItem = nil
  return .none
  
case .editItem(.dismiss):
  state.editItem = nil
  return .none

// ✅ Consistent dismissal
case .destination(.presented(.add(.saveButtonTapped))):
  state.destination = nil
  return .none
  
case .destination(.presented(.edit(.saveButtonTapped))):
  state.destination = nil
  return .none
  
case .destination(.dismiss):
  state.destination = nil
  return .none
```

### 4. Extract Navigation Logic

Extract complex navigation logic into helper methods:

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
        return navigateToDetail(item: item, state: &state)
        
      case let .path(.element(id: id, action: .detail(.editButtonTapped))):
        return navigateToEdit(id: id, state: &state)
        
      case let .path(.element(id: id, action: .edit(.saveButtonTapped))):
        return handleEditSave(id: id, state: &state)
        
      case .path:
        return .none
      }
    }
    .forEach(\.path, action: \.path)
  }
  
  private func navigateToDetail(item: Item, state: inout State) -> Effect<Action> {
    state.path.append(.detail(DetailFeature.State(item: item)))
    return .none
  }
  
  private func navigateToEdit(id: StackElementID, state: inout State) -> Effect<Action> {
    guard let detailState = state.path[id: id]?.detail else { return .none }
    state.path.append(.edit(EditFeature.State(item: detailState.item)))
    return .none
  }
  
  private func handleEditSave(id: StackElementID, state: inout State) -> Effect<Action> {
    guard let editState = state.path[id: id]?.edit else { return .none }
    state.path.pop(from: id)
    return .run { _ in
      await saveItem(editState.item)
    }
  }
  
  private func saveItem(_ item: Item) async {
    // Save item logic
  }
}
```

### 5. Test Navigation Flows

Test navigation flows thoroughly:

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

## Conclusion

Navigation in TCA provides a powerful way to manage navigation flows in a predictable and testable manner. By following the principles and best practices outlined in this document, you can create navigation that is easy to understand, modify, and test.
