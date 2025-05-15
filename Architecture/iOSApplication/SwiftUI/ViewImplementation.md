# View Implementation

**Navigation:** [Back to iOS Architecture](../README.md) | [SwiftUI Integration](./SwiftUIIntegration.md)

---

> **Note:** As this is an MVP, the view implementation approach may evolve as the project matures.

## View Implementation Principles

View implementation in LifeSignal follows these core principles:

1. **Declarative UI**: Use SwiftUI's declarative approach
2. **Store-Driven**: Views are driven by the store
3. **Composition**: Views are composed of smaller views
4. **Reusability**: Views are designed for reuse
5. **Testability**: Views are designed for testability

## Basic View Structure

Views are structured using SwiftUI:

```swift
struct FeatureView: View {
  @Bindable var store: StoreOf<Feature>
  
  var body: some View {
    Form {
      Section {
        Text("\(store.count)")
        Button("Decrement") { store.send(.decrementButtonTapped) }
        Button("Increment") { store.send(.incrementButtonTapped) }
      }
      
      Section {
        Button("Number fact") { store.send(.numberFactButtonTapped) }
      }
      
      if let fact = store.numberFact {
        Text(fact)
      }
    }
  }
}
```

## View Composition

Views are composed of smaller views:

```swift
struct FeatureView: View {
  @Bindable var store: StoreOf<Feature>
  
  var body: some View {
    VStack {
      CounterView(
        count: store.count,
        onDecrement: { store.send(.decrementButtonTapped) },
        onIncrement: { store.send(.incrementButtonTapped) }
      )
      
      FactView(
        fact: store.numberFact,
        onFetchFact: { store.send(.numberFactButtonTapped) }
      )
    }
  }
}

struct CounterView: View {
  let count: Int
  let onDecrement: () -> Void
  let onIncrement: () -> Void
  
  var body: some View {
    HStack {
      Button("Decrement", action: onDecrement)
      Text("\(count)")
      Button("Increment", action: onIncrement)
    }
  }
}

struct FactView: View {
  let fact: String?
  let onFetchFact: () -> Void
  
  var body: some View {
    VStack {
      Button("Number fact", action: onFetchFact)
      
      if let fact = fact {
        Text(fact)
      }
    }
  }
}
```

## Child Store Views

Child store views are implemented using `store.scope`:

```swift
struct ParentView: View {
  @Bindable var store: StoreOf<ParentFeature>
  
  var body: some View {
    VStack {
      Text("Parent View")
      
      ChildView(
        store: store.scope(
          state: \.child,
          action: \.child
        )
      )
    }
  }
}

struct ChildView: View {
  @Bindable var store: StoreOf<ChildFeature>
  
  var body: some View {
    VStack {
      Text("Child View")
      Text("\(store.count)")
      Button("Increment") { store.send(.incrementButtonTapped) }
    }
  }
}
```

## Form Implementation

Forms are implemented using SwiftUI's `Form`:

```swift
struct SettingsView: View {
  @Bindable var store: StoreOf<Settings>
  
  var body: some View {
    Form {
      Section(header: Text("Profile")) {
        TextField("Display name", text: $store.displayName)
        TextField("Email", text: $store.email)
      }
      
      Section(header: Text("Preferences")) {
        Toggle("Notifications", isOn: $store.enableNotifications)
        Toggle("Dark mode", isOn: $store.darkMode)
        
        Picker("Theme", selection: $store.theme) {
          Text("System").tag(Theme.system)
          Text("Light").tag(Theme.light)
          Text("Dark").tag(Theme.dark)
        }
      }
      
      Section {
        Button("Save") {
          store.send(.saveButtonTapped)
        }
      }
    }
  }
}
```

## List Implementation

Lists are implemented using SwiftUI's `List`:

```swift
struct ContactsView: View {
  @Bindable var store: StoreOf<ContactsFeature>
  
  var body: some View {
    List {
      ForEach(store.contacts) { contact in
        ContactRow(
          contact: contact,
          onSelect: { store.send(.contactSelected(contact)) }
        )
      }
      
      Button("Add Contact") {
        store.send(.addContactButtonTapped)
      }
    }
    .navigationTitle("Contacts")
  }
}

struct ContactRow: View {
  let contact: Contact
  let onSelect: () -> Void
  
  var body: some View {
    Button(action: onSelect) {
      HStack {
        Text(contact.name)
        Spacer()
        Text(contact.phoneNumber)
      }
    }
  }
}
```

## Navigation Implementation

Navigation is implemented using SwiftUI's navigation views:

```swift
struct ContactsView: View {
  @Bindable var store: StoreOf<ContactsFeature>
  
  var body: some View {
    NavigationStack(
      path: $store.scope(state: \.path, action: \.path)
    ) {
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
    } destination: { store in
      switch store.case {
      case .detail(let store):
        ContactDetailView(store: store)
      case .edit(let store):
        ContactEditView(store: store)
      }
    }
    .sheet(item: $store.scope(state: \.destination?.add, action: \.destination.add)) { store in
      ContactAddView(store: store)
    }
  }
}
```

## Loading and Error States

Loading and error states are handled using SwiftUI views:

```swift
struct ContactsView: View {
  @Bindable var store: StoreOf<ContactsFeature>
  
  var body: some View {
    ZStack {
      List {
        ForEach(store.contacts) { contact in
          ContactRow(contact: contact)
        }
      }
      .navigationTitle("Contacts")
      
      if store.isLoading {
        ProgressView()
      }
      
      if let error = store.error {
        VStack {
          Text("Error")
            .font(.headline)
          
          Text(error.localizedDescription)
            .font(.subheadline)
          
          Button("Retry") {
            store.send(.retryButtonTapped)
          }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
      }
    }
  }
}
```

## Custom Views

Custom views are implemented for reuse:

```swift
struct PrimaryButton: View {
  let title: String
  let action: () -> Void
  
  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.headline)
        .foregroundColor(.white)
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.blue)
        .cornerRadius(10)
    }
  }
}

struct SecondaryButton: View {
  let title: String
  let action: () -> Void
  
  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.headline)
        .foregroundColor(.blue)
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
  }
}
```

## View Modifiers

Custom view modifiers are implemented for reuse:

```swift
struct CardStyle: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding()
      .background(Color.white)
      .cornerRadius(10)
      .shadow(radius: 2)
  }
}

extension View {
  func cardStyle() -> some View {
    modifier(CardStyle())
  }
}

struct ContactCard: View {
  let contact: Contact
  
  var body: some View {
    VStack(alignment: .leading) {
      Text(contact.name)
        .font(.headline)
      
      Text(contact.phoneNumber)
        .font(.subheadline)
    }
    .cardStyle()
  }
}
```

## Preview Implementation

Previews are implemented for development:

```swift
struct ContactsView_Previews: PreviewProvider {
  static var previews: some View {
    ContactsView(
      store: Store(initialState: ContactsFeature.State(
        contacts: [
          Contact(id: "1", name: "John Doe", phoneNumber: "555-1234"),
          Contact(id: "2", name: "Jane Smith", phoneNumber: "555-5678")
        ]
      )) {
        ContactsFeature()
      }
    )
  }
}
```

## Best Practices

1. **Keep Views Simple**: Keep views as simple as possible
2. **Compose Views**: Compose views from smaller views
3. **Use Store Binding**: Use `@Bindable var store: StoreOf<Feature>` for view store binding
4. **Use $store Syntax**: Use `$store` syntax for form controls
5. **Use Navigation Views**: Use SwiftUI's navigation views
6. **Handle Loading and Error States**: Handle loading and error states
7. **Create Custom Views**: Create custom views for reuse
8. **Create View Modifiers**: Create view modifiers for reuse
9. **Implement Previews**: Implement previews for development
10. **Document Views**: Document the purpose of each view
