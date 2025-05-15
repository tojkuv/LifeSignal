# State Management

**Navigation:** [Back to iOS Architecture](../README.md) | [Feature Architecture](./FeatureArchitecture.md) | [Action Design](./ActionDesign.md) | [Effect Management](./EffectManagement.md)

---

> **Note:** As this is an MVP, the state management approach may evolve as the project matures.

## State Design Principles

State in LifeSignal follows these core principles:

1. **Value Types**: State is always a value type (struct)
2. **Equatable**: State is always `Equatable` for efficient diffing
3. **Sendable**: State is always `Sendable` for concurrency safety
4. **Observable**: State uses `@ObservableState` for SwiftUI integration
5. **Single Source of Truth**: State is the single source of truth for a feature
6. **Immutability**: State is only mutated within reducers

## State Definition

State is defined using a struct with the `@ObservableState` macro:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    var count = 0
    var isLoading = false
    var error: Error?
    var user: User?
    
    // Computed properties
    var isLoggedIn: Bool {
      user != nil
    }
  }
  
  // Actions, body, etc.
}
```

## State Composition

State is composed using properties:

```swift
@Reducer
struct ParentFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var child: ChildFeature.State
    var otherChild: OtherChildFeature.State
    var localState: String
  }
  
  // Actions, body, etc.
}
```

## Presentation State

Presentation state is managed using the `@Presents` property wrapper:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    @Presents var destination: Destination.State?
    var items: [Item] = []
  }
  
  // Actions, body, etc.
}
```

## Shared State

Shared state is managed using the `@Shared` property wrapper:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    @Shared var count: Int
    var localState: String
  }
  
  // Actions, body, etc.
}
```

Different persistence strategies can be used:

```swift
// In-memory persistence (resets on app restart)
@Shared(.inMemory("count")) var count = 0

// UserDefaults persistence
@Shared(.appStorage("count")) var count = 0

// Document-based persistence
@Shared(.document("count")) var count = 0
```

## Optional State

Optional state is used for conditional features:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    var optionalChild: ChildFeature.State?
    var items: [Item] = []
  }
  
  // Actions, body, etc.
}
```

## Collection State

Collection state is managed using `IdentifiedArray`:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    var items: IdentifiedArrayOf<Item> = []
  }
  
  // Actions, body, etc.
}
```

## Loading State

Loading state is managed using boolean flags:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    var isLoading = false
    var items: [Item] = []
  }
  
  // Actions, body, etc.
}
```

## Error State

Error state is managed using optional error properties:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    var error: Error?
    var items: [Item] = []
  }
  
  // Actions, body, etc.
}
```

## Form State

Form state is managed using properties with the `@BindableState` property wrapper:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    var name = ""
    var email = ""
    var isValid: Bool {
      !name.isEmpty && !email.isEmpty
    }
  }
  
  // Actions, body, etc.
}
```

## Navigation State

Navigation state is managed using optional state or `StackState`:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    var path = StackState<Path.State>()
    var items: [Item] = []
  }
  
  // Actions, body, etc.
}
```

## State Initialization

State is initialized with default values:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    var count = 0
    var isLoading = false
    var error: Error?
    var user: User?
    
    init(
      count: Int = 0,
      isLoading: Bool = false,
      error: Error? = nil,
      user: User? = nil
    ) {
      self.count = count
      self.isLoading = isLoading
      self.error = error
      self.user = user
    }
  }
  
  // Actions, body, etc.
}
```

## Best Practices

1. **Keep State Minimal**: Only include what's needed for the feature
2. **Use Value Types**: Always use structs for state
3. **Make State Equatable**: Always conform to `Equatable`
4. **Make State Sendable**: Always conform to `Sendable`
5. **Use @ObservableState**: Always use `@ObservableState` for SwiftUI integration
6. **Use @Presents**: Use `@Presents` for presentation state
7. **Use @Shared**: Use `@Shared` for shared state
8. **Avoid Optionals**: Avoid optionals when a default value makes sense
9. **Use IdentifiedArray**: Use `IdentifiedArrayOf` for collections of identifiable items
10. **Document State**: Document the purpose of each state property
