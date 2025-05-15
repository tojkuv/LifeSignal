# Feature Architecture

**Navigation:** [Back to iOS Architecture](../README.md) | [State Management](./StateManagement.md) | [Action Design](./ActionDesign.md) | [Effect Management](./EffectManagement.md)

---

> **Note:** As this is an MVP, the feature architecture may evolve as the project matures.

## Vertical Slice Architecture

LifeSignal organizes features using vertical slice architecture, where each feature contains all the necessary components:

### Feature Organization

```
Features/
  ├── Auth/                  # Authentication feature
  │   ├── AuthFeature.swift  # TCA reducer
  │   ├── AuthView.swift     # SwiftUI view
  │   ├── Models/            # Feature-specific models
  │   └── Views/             # Feature-specific views
  │
  ├── Profile/               # Profile feature
  │   ├── ProfileFeature.swift
  │   ├── ProfileView.swift
  │   ├── Models/
  │   └── Views/
  │
  ├── Contacts/              # Contacts feature
  │   ├── ContactsFeature.swift
  │   ├── ContactsView.swift
  │   ├── Models/
  │   └── Views/
  │
  └── ...                    # Other features
```

### Feature Components

1. **Feature Reducer** - The TCA reducer that defines the feature's state, actions, and behavior
2. **Feature View** - The SwiftUI view that renders the feature's UI
3. **Feature Models** - Feature-specific domain models
4. **Feature Views** - Reusable UI components specific to the feature
5. **Feature Tests** - Comprehensive tests for the feature's behavior

### Feature Design Principles

- Each feature is self-contained and independent
- Features communicate through well-defined interfaces
- Features depend on infrastructure clients, not directly on infrastructure
- Features are organized by domain functionality, not technical layers
- Features should be testable in isolation
- Features should handle their own error states
- Features should manage their own loading states
- Features should be composable with other features

## Feature Composition

Features can be composed in several ways:

### Parent-Child Composition

```swift
@Reducer
struct ParentFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var child: ChildFeature.State
    var otherChild: OtherChildFeature.State
    var localState: String
  }
  
  enum Action: Equatable, Sendable {
    case child(ChildFeature.Action)
    case otherChild(OtherChildFeature.Action)
    case localAction
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      // Handle local actions
      switch action {
      case .localAction:
        state.localState = "Updated"
        return .none
        
      case .child, .otherChild:
        return .none
      }
    }
    
    Scope(state: \.child, action: \.child) {
      ChildFeature()
    }
    
    Scope(state: \.otherChild, action: \.otherChild) {
      OtherChildFeature()
    }
  }
}
```

### Optional Child Composition

```swift
@Reducer
struct ParentFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var optionalChild: ChildFeature.State?
    var localState: String
  }
  
  enum Action: Equatable, Sendable {
    case optionalChild(ChildFeature.Action)
    case showChildButtonTapped
    case hideChildButtonTapped
    case localAction
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .showChildButtonTapped:
        state.optionalChild = ChildFeature.State()
        return .none
        
      case .hideChildButtonTapped:
        state.optionalChild = nil
        return .none
        
      case .localAction:
        state.localState = "Updated"
        return .none
        
      case .optionalChild:
        return .none
      }
    }
    
    .ifLet(\.optionalChild, action: \.optionalChild) {
      ChildFeature()
    }
  }
}
```

### Presentation Composition

```swift
@Reducer
struct ParentFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    @Presents var destination: Destination.State?
    var localState: String
  }
  
  enum Action: Equatable, Sendable {
    case destination(PresentationAction<Destination.Action>)
    case showDestinationButtonTapped
    case hideDestinationButtonTapped
    case localAction
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .showDestinationButtonTapped:
        state.destination = .child(ChildFeature.State())
        return .none
        
      case .hideDestinationButtonTapped:
        state.destination = nil
        return .none
        
      case .localAction:
        state.localState = "Updated"
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
    case child(ChildFeature.State)
    case otherChild(OtherChildFeature.State)
  }
  
  enum Action: Equatable, Sendable {
    case child(ChildFeature.Action)
    case otherChild(OtherChildFeature.Action)
  }
  
  var body: some ReducerOf<Self> {
    Scope(state: \.child, action: \.child) {
      ChildFeature()
    }
    
    Scope(state: \.otherChild, action: \.otherChild) {
      OtherChildFeature()
    }
  }
}
```

### Stack Composition

```swift
@Reducer
struct ParentFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var path = StackState<Path.State>()
    var localState: String
  }
  
  enum Action: Equatable, Sendable {
    case path(StackAction<Path.State, Path.Action>)
    case pushChildButtonTapped
    case pushOtherChildButtonTapped
    case popButtonTapped
    case localAction
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .pushChildButtonTapped:
        state.path.append(.child(ChildFeature.State()))
        return .none
        
      case .pushOtherChildButtonTapped:
        state.path.append(.otherChild(OtherChildFeature.State()))
        return .none
        
      case .popButtonTapped:
        _ = state.path.popLast()
        return .none
        
      case .localAction:
        state.localState = "Updated"
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
    case child(ChildFeature.State)
    case otherChild(OtherChildFeature.State)
  }
  
  enum Action: Equatable, Sendable {
    case child(ChildFeature.Action)
    case otherChild(OtherChildFeature.Action)
  }
  
  var body: some ReducerOf<Self> {
    Scope(state: \.child, action: \.child) {
      ChildFeature()
    }
    
    Scope(state: \.otherChild, action: \.otherChild) {
      OtherChildFeature()
    }
  }
}
```

## Feature Implementation

A complete feature implementation includes:

### Feature Reducer

```swift
@Reducer
struct ContactsFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var contacts: [Contact] = []
    var isLoading = false
    var error: Error?
    @Presents var destination: Destination.State?
    var path = StackState<Path.State>()
  }
  
  enum Action: Equatable, Sendable {
    case viewDidAppear
    case contactsResponse([Contact])
    case contactsFailure(Error)
    case addContactButtonTapped
    case contactSelected(Contact)
    case destination(PresentationAction<Destination.Action>)
    case path(StackAction<Path.State, Path.Action>)
  }
  
  @Dependency(\.contactsClient) var contactsClient
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .viewDidAppear:
        state.isLoading = true
        return .run { send in
          do {
            let contacts = try await contactsClient.getContacts()
            await send(.contactsResponse(contacts))
          } catch {
            await send(.contactsFailure(error))
          }
        }
        
      case let .contactsResponse(contacts):
        state.contacts = contacts
        state.isLoading = false
        return .none
        
      case let .contactsFailure(error):
        state.error = error
        state.isLoading = false
        return .none
        
      case .addContactButtonTapped:
        state.destination = .add(AddContactFeature.State())
        return .none
        
      case let .contactSelected(contact):
        state.path.append(.detail(ContactDetailFeature.State(contact: contact)))
        return .none
        
      case .destination(.presented(.add(.saveButtonTapped))):
        state.destination = nil
        return .run { send in
          await send(.viewDidAppear)
        }
        
      case .destination:
        return .none
        
      case .path:
        return .none
      }
    }
    
    .ifLet(\.$destination, action: \.destination) {
      Destination()
    }
    
    .forEach(\.path, action: \.path) {
      Path()
    }
  }
}
```

### Feature View

```swift
struct ContactsView: View {
  @Bindable var store: StoreOf<ContactsFeature>
  
  var body: some View {
    NavigationStack(
      path: $store.scope(state: \.path, action: \.path)
    ) {
      ZStack {
        List {
          ForEach(store.contacts) { contact in
            Button {
              store.send(.contactSelected(contact))
            } label: {
              ContactRow(contact: contact)
            }
          }
        }
        .navigationTitle("Contacts")
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            Button("Add") {
              store.send(.addContactButtonTapped)
            }
          }
        }
        
        if store.isLoading {
          ProgressView()
        }
        
        if let error = store.error {
          Text("Error: \(error.localizedDescription)")
            .foregroundColor(.red)
        }
      }
      .onAppear {
        store.send(.viewDidAppear)
      }
    } destination: { store in
      switch store.case {
      case .detail(let store):
        ContactDetailView(store: store)
      }
    }
    .sheet(item: $store.scope(state: \.destination?.add, action: \.destination.add)) { store in
      AddContactView(store: store)
    }
  }
}
```

### Feature Tests

```swift
@MainActor
final class ContactsFeatureTests: XCTestCase {
  @Test
  func testViewDidAppear() async {
    let contacts = [
      Contact(id: "1", name: "John Doe", phoneNumber: "555-1234"),
      Contact(id: "2", name: "Jane Smith", phoneNumber: "555-5678")
    ]
    
    let store = TestStore(initialState: ContactsFeature.State()) {
      ContactsFeature()
    } withDependencies: {
      $0.contactsClient.getContacts = { contacts }
    }
    
    await store.send(.viewDidAppear) {
      $0.isLoading = true
    }
    
    await store.receive(\.contactsResponse) {
      $0.contacts = contacts
      $0.isLoading = false
    }
  }
  
  @Test
  func testAddContactButtonTapped() async {
    let store = TestStore(initialState: ContactsFeature.State()) {
      ContactsFeature()
    }
    
    await store.send(.addContactButtonTapped) {
      $0.destination = .add(AddContactFeature.State())
    }
  }
  
  @Test
  func testContactSelected() async {
    let contact = Contact(id: "1", name: "John Doe", phoneNumber: "555-1234")
    
    let store = TestStore(initialState: ContactsFeature.State(contacts: [contact])) {
      ContactsFeature()
    }
    
    await store.send(.contactSelected(contact)) {
      $0.path.append(.detail(ContactDetailFeature.State(contact: contact)))
    }
  }
}
```

## Best Practices

1. **Keep Features Focused**: Each feature should have a single responsibility
2. **Use Vertical Slices**: Organize code by feature rather than by technical layer
3. **Compose Features**: Compose features using parent-child relationships
4. **Handle Loading States**: Features should manage their own loading states
5. **Handle Error States**: Features should handle their own error states
6. **Test Features**: Test features in isolation
7. **Document Features**: Document the purpose of each feature
8. **Use Dependency Injection**: Use TCA's dependency system for dependencies
9. **Use Presentation State**: Use `@Presents` for presentation state
10. **Use Stack State**: Use `StackState` for stack-based navigation
