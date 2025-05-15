# SwiftUI Integration

**Navigation:** [Back to iOS Architecture](../README.md) | [View Implementation](./ViewImplementation.md)

---

> **Note:** As this is an MVP, the SwiftUI integration approach may evolve as the project matures.

## SwiftUI Integration Principles

SwiftUI integration in LifeSignal follows these core principles:

1. **Bindable Store**: Use `@Bindable var store: StoreOf<Feature>` for view store binding
2. **Scope for Navigation**: Use `$store.scope(state:action:)` for navigation binding
3. **Bindable Actions**: Use `$store` syntax for form controls with `BindableAction`
4. **View Modifiers**: Use view modifiers for cross-cutting concerns
5. **Preview Dependencies**: Override dependencies in previews

## View Implementation

Views are implemented using SwiftUI:

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

## Navigation Integration

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

## Form Controls

Form controls are implemented using `$store` syntax:

```swift
struct SettingsView: View {
  @Bindable var store: StoreOf<Settings>
  
  var body: some View {
    Form {
      TextField("Display name", text: $store.displayName)
      Toggle("Notifications", isOn: $store.enableNotifications)
      Toggle("Dark mode", isOn: $store.darkMode)
      
      Picker("Theme", selection: $store.theme) {
        Text("System").tag(Theme.system)
        Text("Light").tag(Theme.light)
        Text("Dark").tag(Theme.dark)
      }
      
      Button("Save") {
        store.send(.saveButtonTapped)
      }
    }
  }
}
```

## Alerts and Dialogs

Alerts and dialogs are implemented using `$store` syntax:

```swift
struct FeatureView: View {
  @Bindable var store: StoreOf<Feature>
  
  var body: some View {
    List {
      ForEach(store.items) { item in
        Text(item.name)
        
        Button("Delete") {
          store.send(.deleteButtonTapped(item))
        }
      }
    }
    .alert($store.scope(state: \.alert, action: \.alert))
  }
}
```

## Loading and Error States

Loading and error states are handled using SwiftUI views:

```swift
struct FeatureView: View {
  @Bindable var store: StoreOf<Feature>
  
  var body: some View {
    ZStack {
      List {
        ForEach(store.items) { item in
          Text(item.name)
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
  }
}
```

## Custom View Modifiers

Custom view modifiers are used for cross-cutting concerns:

```swift
extension View {
  func analyticsScreen(name: String, class screenClass: String? = nil, extraParameters: [String: Any]? = nil) -> some View {
    onAppear {
      var params: [String: Any] = [AnalyticsParameterScreenName: name]
      if let screenClass {
        params[AnalyticsParameterScreenClass] = screenClass
      }
      if let extraParameters {
        params.merge(extraParameters) { _, new in new }
      }
      Analytics.logEvent(AnalyticsEventScreenView, parameters: params)
    }
  }
}

struct ContentView: View {
  var body: some View {
    Text("Hello, world!")
      .analyticsScreen(name: "main_content", class: "ContentView")
  }
}
```

## Preview Dependencies

Dependencies are overridden in previews:

```swift
struct FeatureView_Previews: PreviewProvider {
  static var previews: some View {
    FeatureView(
      store: Store(initialState: Feature.State()) {
        Feature()
      } withDependencies: {
        $0.numberFactClient.fetch = { "\($0) is a preview number" }
      }
    )
  }
}
```

## Store Initialization

Store is initialized using `@StateObject`:

```swift
struct FeatureView: View {
  @StateObject var store: StoreOf<Feature>
  
  init() {
    _store = StateObject(
      wrappedValue: Store(initialState: Feature.State()) {
        Feature()
      }
    )
  }
  
  var body: some View {
    // View implementation...
  }
}
```

## Performance Optimization

Performance is optimized using `._printChanges()`:

```swift
struct FeatureView: View {
  @Bindable var store: StoreOf<Feature>
  
  var body: some View {
    Form {
      // View implementation...
    }
    ._printChanges()
  }
}
```

## Best Practices

1. **Use @Bindable**: Use `@Bindable var store: StoreOf<Feature>` for view store binding
2. **Use $store.scope**: Use `$store.scope(state:action:)` for navigation binding
3. **Use $store Syntax**: Use `$store` syntax for form controls with `BindableAction`
4. **Use View Modifiers**: Use view modifiers for cross-cutting concerns
5. **Override Dependencies in Previews**: Override dependencies in previews
6. **Use @StateObject**: Use `@StateObject` for store initialization
7. **Use ._printChanges()**: Use `._printChanges()` during development
8. **Keep Views Simple**: Keep views as simple as possible
9. **Use SwiftUI Patterns**: Use standard SwiftUI patterns
10. **Document Views**: Document the purpose of each view
