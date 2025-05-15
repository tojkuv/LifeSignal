# Tree-Based Navigation

**Navigation:** [Back to iOS Architecture](../README.md) | [Navigation Patterns](./NavigationPatterns.md) | [Stack-Based Navigation](./StackBasedNavigation.md)

---

> **Note:** As this is an MVP, the tree-based navigation approach may evolve as the project matures.

## Tree-Based Navigation Overview

Tree-based navigation in LifeSignal is used for modal presentations, sheets, popovers, and alerts. It follows these core principles:

1. **State-Driven**: Navigation is driven by state changes
2. **Type-Safe**: Navigation is type-safe
3. **Testable**: Navigation is testable
4. **Composable**: Navigation is composable
5. **Declarative**: Navigation is declarative

## State Definition

Tree-based navigation state is defined using the `@Presents` property wrapper:

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
  
  // Body, etc.
}
```

## Destination Definition

Destinations are defined using an enum:

```swift
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

## Reducer Implementation

The reducer handles navigation actions:

```swift
@Reducer
struct Feature {
  // State, Action, etc.
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .addButtonTapped:
        state.destination = .add(AddFeature.State())
        return .none
        
      case .editButtonTapped(let item):
        state.destination = .edit(EditFeature.State(item: item))
        return .none
        
      case .itemSelected(let item):
        state.destination = .detail(DetailFeature.State(item: item))
        return .none
        
      case .dismissButtonTapped:
        state.destination = nil
        return .none
        
      case .destination(.presented(.add(.saveButtonTapped))):
        // Handle save button tapped in add feature
        state.destination = nil
        return .none
        
      case .destination(.presented(.edit(.saveButtonTapped))):
        // Handle save button tapped in edit feature
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
```

## SwiftUI Integration

Tree-based navigation is integrated with SwiftUI using the `sheet`, `fullScreenCover`, `popover`, and `alert` modifiers:

```swift
struct FeatureView: View {
  @Bindable var store: StoreOf<Feature>
  
  var body: some View {
    List {
      ForEach(store.items) { item in
        HStack {
          Text(item.name)
          
          Spacer()
          
          Button("Edit") {
            store.send(.editButtonTapped(item))
          }
        }
        .contentShape(Rectangle())
        .onTapGesture {
          store.send(.itemSelected(item))
        }
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

## Nested Destinations

Destinations can be nested:

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
    case destination(PresentationAction<Destination.Action>)
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .editButtonTapped:
        state.destination = .edit(EditFeature.State(item: state.item))
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
    case edit(EditFeature.State)
  }
  
  enum Action: Equatable, Sendable {
    case edit(EditFeature.Action)
  }
  
  var body: some ReducerOf<Self> {
    Scope(state: \.edit, action: \.edit) {
      EditFeature()
    }
  }
}
```

## Alerts

Alerts are handled using the `@Presents` property wrapper:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    @Presents var alert: AlertState<Action.Alert>?
    var items: [Item] = []
  }
  
  enum Action: Equatable, Sendable {
    case deleteButtonTapped(Item)
    case alert(PresentationAction<Alert>)
    
    enum Alert: Equatable, Sendable {
      case confirmDeletion
      case cancelDeletion
    }
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .deleteButtonTapped(item):
        state.alert = AlertState {
          TextState("Delete Item")
        } actions: {
          ButtonState(role: .destructive, action: .confirmDeletion) {
            TextState("Delete")
          }
          ButtonState(role: .cancel, action: .cancelDeletion) {
            TextState("Cancel")
          }
        } message: {
          TextState("Are you sure you want to delete this item?")
        }
        return .none
        
      case .alert(.presented(.confirmDeletion)):
        // Handle confirmation
        state.alert = nil
        return .none
        
      case .alert(.presented(.cancelDeletion)), .alert(.dismiss):
        state.alert = nil
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}
```

## Confirmation Dialogs

Confirmation dialogs are handled similarly to alerts:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    @Presents var confirmationDialog: ConfirmationDialogState<Action.Dialog>?
    var items: [Item] = []
  }
  
  enum Action: Equatable, Sendable {
    case moreButtonTapped(Item)
    case confirmationDialog(PresentationAction<Dialog>)
    
    enum Dialog: Equatable, Sendable {
      case edit
      case delete
      case share
    }
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .moreButtonTapped(item):
        state.confirmationDialog = ConfirmationDialogState {
          TextState("Options")
        } actions: {
          ButtonState(action: .edit) {
            TextState("Edit")
          }
          ButtonState(role: .destructive, action: .delete) {
            TextState("Delete")
          }
          ButtonState(action: .share) {
            TextState("Share")
          }
        } message: {
          TextState("Choose an action for this item.")
        }
        return .none
        
      case .confirmationDialog(.presented(.edit)):
        // Handle edit
        state.confirmationDialog = nil
        return .none
        
      case .confirmationDialog(.presented(.delete)):
        // Handle delete
        state.confirmationDialog = nil
        return .none
        
      case .confirmationDialog(.presented(.share)):
        // Handle share
        state.confirmationDialog = nil
        return .none
        
      case .confirmationDialog(.dismiss):
        state.confirmationDialog = nil
        return .none
      }
    }
    .ifLet(\.$confirmationDialog, action: \.confirmationDialog)
  }
}
```

## Testing

Tree-based navigation is tested using `TestStore`:

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

@Test
func testEditButtonTapped() async {
  let item = Item(id: "1", name: "Test")
  let store = TestStore(initialState: Feature.State(items: [item])) {
    Feature()
  }
  
  await store.send(.editButtonTapped(item)) {
    $0.destination = .edit(EditFeature.State(item: item))
  }
  
  await store.send(.destination(.presented(.edit(.saveButtonTapped)))) {
    $0.destination = nil
  }
}
```

## Best Practices

1. **Use @Presents**: Use `@Presents` for optional destination state
2. **Use PresentationAction**: Use `PresentationAction` for handling child feature actions
3. **Handle Dismissal**: Handle dismissal by setting destination state to `nil`
4. **Use Enum for Destinations**: Use an enum for multiple destination types
5. **Test Navigation**: Test navigation state changes
6. **Use Bindable**: Use `@Bindable` for SwiftUI integration
7. **Use $store.scope**: Use `$store.scope(state:action:)` for navigation binding
8. **Document Navigation**: Document the navigation flow
9. **Keep Navigation Simple**: Keep navigation as simple as possible
10. **Handle Child Actions**: Handle child actions in the parent reducer when appropriate
