# State Management in TCA

**Navigation:** [Back to TCA Overview](Overview.md) | [Action Design](ActionDesign.md) | [Effect Management](EffectManagement.md) | [Dependency Injection](DependencyInjection.md)

---

## Overview

State in The Composable Architecture (TCA) is the single source of truth for a feature. It describes all the data that a feature needs to render its UI and perform its logic. State is defined as a struct with the `@ObservableState` macro, making it compatible with SwiftUI's observation system.

## Core Principles

### 1. Value Types

State is always a value type (struct):

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    var count = 0
    var isLoading = false
    var error: Error?
    var user: User?
  }
  
  // Actions, body, etc.
}
```

This ensures:
- Immutability by default
- Thread safety
- Easy copying and comparison

### 2. Equatable

State is always `Equatable` for efficient diffing:

```swift
@ObservableState
struct State: Equatable, Sendable {
  var count = 0
  var isLoading = false
  var error: Error?
  var user: User?
  
  // Custom Equatable implementation for Error
  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.count == rhs.count &&
    lhs.isLoading == rhs.isLoading &&
    (lhs.error != nil) == (rhs.error != nil) &&
    lhs.user == rhs.user
  }
}
```

This enables:
- Efficient UI updates
- Precise testing
- Debugging state changes

### 3. Sendable

State is always `Sendable` for concurrency safety:

```swift
@ObservableState
struct State: Equatable, Sendable {
  var count = 0
  var isLoading = false
  var error: Error?
  var user: User?
}
```

This ensures:
- Thread safety when passing state between tasks
- Compatibility with Swift's concurrency system
- Prevention of data races

### 4. Observable

State uses `@ObservableState` for SwiftUI integration:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    var count = 0
    var isLoading = false
    var error: Error?
    var user: User?
  }
  
  // Actions, body, etc.
}
```

This enables:
- Automatic UI updates when state changes
- Fine-grained view updates
- Simplified view code

## State Types

### Basic State

Basic state contains simple properties:

```swift
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
```

### Presentation State

Presentation state uses `@Presents` for optional child features:

```swift
@ObservableState
struct State: Equatable, Sendable {
  var items: [Item] = []
  
  @Presents var addItem: ItemFormFeature.State?
  @Presents var editItem: ItemFormFeature.State?
  @Presents var settings: SettingsFeature.State?
}
```

This enables:
- Modal presentations
- Sheets and popovers
- Conditional UI

### Navigation State

Navigation state uses `StackState` for stack-based navigation:

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

This enables:
- Push/pop navigation
- Deep linking
- Navigation history

### Shared State

Shared state uses `@Shared` for state shared across features:

```swift
@ObservableState
struct State: Equatable, Sendable {
  @Shared var count: Int
  var localState: String
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

This enables:
- State sharing across features
- Persistence across app restarts
- Thread-safe state mutations

## State Design Patterns

### 1. Default Values

Provide default values for all state properties:

```swift
@ObservableState
struct State: Equatable, Sendable {
  var count = 0
  var isLoading = false
  var error: Error?
  var user: User?
  var items: [Item] = []
}
```

### 2. Custom Initializers

Use custom initializers for complex state initialization:

```swift
@ObservableState
struct State: Equatable, Sendable {
  var count: Int
  var isLoading: Bool
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
```

### 3. Computed Properties

Use computed properties for derived state:

```swift
@ObservableState
struct State: Equatable, Sendable {
  var user: User?
  var items: [Item] = []
  
  var isLoggedIn: Bool {
    user != nil
  }
  
  var itemCount: Int {
    items.count
  }
  
  var hasItems: Bool {
    !items.isEmpty
  }
}
```

### 4. Nested State

Use nested state for complex features:

```swift
@ObservableState
struct State: Equatable, Sendable {
  var authentication = AuthenticationState()
  var profile = ProfileState()
  var settings = SettingsState()
  
  @ObservableState
  struct AuthenticationState: Equatable, Sendable {
    var isLoggedIn = false
    var user: User?
    var error: Error?
  }
  
  @ObservableState
  struct ProfileState: Equatable, Sendable {
    var name = ""
    var email = ""
    var bio = ""
  }
  
  @ObservableState
  struct SettingsState: Equatable, Sendable {
    var notificationsEnabled = true
    var darkModeEnabled = false
    var autoSaveEnabled = true
  }
}
```

## State Mutation

State is only mutated within reducers:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    var count = 0
  }
  
  enum Action: Equatable, Sendable {
    case incrementButtonTapped
    case decrementButtonTapped
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .incrementButtonTapped:
        state.count += 1
        return .none
        
      case .decrementButtonTapped:
        state.count -= 1
        return .none
      }
    }
  }
}
```

### Mutating Shared State

Shared state is mutated using `withLock`:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    @Shared var count: Int
  }
  
  enum Action: Equatable, Sendable {
    case incrementButtonTapped
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .incrementButtonTapped:
        state.$count.withLock { $0 += 1 }
        return .none
      }
    }
  }
}
```

## Best Practices

### 1. Keep State Minimal

Only include state that is necessary for rendering and logic:

```swift
// ❌ Too much state
@ObservableState
struct State: Equatable, Sendable {
  var count = 0
  var incrementCount = 0  // Unnecessary tracking
  var decrementCount = 0  // Unnecessary tracking
  var lastAction: String?  // Unnecessary tracking
  var countHistory: [Int] = []  // Unnecessary tracking
}

// ✅ Minimal state
@ObservableState
struct State: Equatable, Sendable {
  var count = 0
}
```

### 2. Use Domain Models

Use domain models instead of primitive types:

```swift
// ❌ Primitive types
@ObservableState
struct State: Equatable, Sendable {
  var userId: String?
  var userName: String = ""
  var userEmail: String = ""
  var userIsVerified: Bool = false
}

// ✅ Domain models
@ObservableState
struct State: Equatable, Sendable {
  var user: User?
}

struct User: Equatable, Sendable {
  var id: String
  var name: String
  var email: String
  var isVerified: Bool
}
```

### 3. Avoid Optionals When Possible

Use default values instead of optionals when appropriate:

```swift
// ❌ Unnecessary optionals
@ObservableState
struct State: Equatable, Sendable {
  var count: Int?
  var name: String?
  var isEnabled: Bool?
}

// ✅ Default values
@ObservableState
struct State: Equatable, Sendable {
  var count = 0
  var name = ""
  var isEnabled = false
}
```

### 4. Use Enums for Exclusive States

Use enums for states that are mutually exclusive:

```swift
// ❌ Boolean flags
@ObservableState
struct State: Equatable, Sendable {
  var isLoading = false
  var isSuccess = false
  var isError = false
}

// ✅ Enum for exclusive states
@ObservableState
struct State: Equatable, Sendable {
  enum LoadingState: Equatable, Sendable {
    case idle
    case loading
    case success
    case error(Error)
  }
  
  var loadingState: LoadingState = .idle
}
```

### 5. Document Complex State

Add comments to explain complex state:

```swift
@ObservableState
struct State: Equatable, Sendable {
  /// The current user's profile information.
  /// This is nil when the user is not logged in.
  var user: User?
  
  /// The list of items in the user's inventory.
  /// This is empty when the user has no items.
  var items: [Item] = []
  
  /// The current error message to display.
  /// This is nil when there is no error.
  var error: Error?
  
  /// Whether the app is currently loading data.
  /// This is used to show a loading indicator.
  var isLoading = false
}
```

## Conclusion

State management in TCA provides a solid foundation for building applications with a clear and predictable data flow. By following the principles and best practices outlined in this document, you can create state that is easy to understand, modify, and test.
