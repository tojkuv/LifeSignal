# Action Design in TCA

**Navigation:** [Back to TCA Overview](Overview.md) | [State Management](StateManagement.md) | [Effect Management](EffectManagement.md) | [Dependency Injection](DependencyInjection.md)

---

## Overview

Actions in The Composable Architecture (TCA) represent all the events that can occur in your feature. They are the entry points for state changes and side effects. Actions are defined as an enum with cases for each event that can occur in your feature.

## Core Principles

### 1. Enum-Based Design

Actions are defined as enums with cases for each event:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable { /* ... */ }
  
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

This ensures:
- Exhaustive handling of all possible actions
- Clear documentation of all events
- Type safety for action handling

### 2. Equatable

Actions are always `Equatable` for testing and debugging:

```swift
enum Action: Equatable, Sendable {
  case incrementButtonTapped
  case decrementButtonTapped
  case numberFactButtonTapped
  case numberFactResponse(String)
  case numberFactFailed(Error)
  
  // Custom Equatable implementation for Error
  static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case (.incrementButtonTapped, .incrementButtonTapped),
         (.decrementButtonTapped, .decrementButtonTapped),
         (.numberFactButtonTapped, .numberFactButtonTapped):
      return true
    case let (.numberFactResponse(lhsString), .numberFactResponse(rhsString)):
      return lhsString == rhsString
    case (.numberFactFailed, .numberFactFailed):
      // Compare error types or messages if needed
      return true
    default:
      return false
    }
  }
}
```

This enables:
- Precise testing of action sequences
- Debugging of action flow
- Comparison of actions

### 3. Sendable

Actions are always `Sendable` for concurrency safety:

```swift
enum Action: Equatable, Sendable {
  case incrementButtonTapped
  case decrementButtonTapped
  case numberFactButtonTapped
  case numberFactResponse(String)
  case numberFactFailed(Error)
}
```

This ensures:
- Thread safety when passing actions between tasks
- Compatibility with Swift's concurrency system
- Prevention of data races

## Action Types

### User Actions

User actions represent events triggered by user interaction:

```swift
enum Action: Equatable, Sendable {
  case incrementButtonTapped
  case decrementButtonTapped
  case refreshButtonTapped
  case saveButtonTapped
  case deleteButtonTapped
  case textFieldChanged(String)
  case toggleChanged(Bool)
}
```

### System Actions

System actions represent events triggered by the system:

```swift
enum Action: Equatable, Sendable {
  case appDidBecomeActive
  case appDidEnterBackground
  case timerTick
  case notificationReceived(Notification)
}
```

### Effect Actions

Effect actions represent events triggered by effects:

```swift
enum Action: Equatable, Sendable {
  case dataLoaded(Data)
  case dataLoadFailed(Error)
  case userAuthenticated(User)
  case userAuthenticationFailed(Error)
}
```

### Child Actions

Child actions represent events from child features:

```swift
enum Action: Equatable, Sendable {
  case child(ChildFeature.Action)
  case settings(PresentationAction<SettingsFeature.Action>)
  case path(StackAction<Path.State, Path.Action>)
}
```

### Binding Actions

Binding actions represent events from SwiftUI bindings:

```swift
enum Action: BindableAction, Equatable, Sendable {
  case binding(BindingAction<State>)
  case saveButtonTapped
  case cancelButtonTapped
}
```

## Action Design Patterns

### 1. Naming Conventions

Use consistent naming conventions for actions:

```swift
enum Action: Equatable, Sendable {
  // User interactions: verb + noun + past tense
  case incrementButtonTapped
  case decrementButtonTapped
  case refreshButtonTapped
  
  // Form field changes: noun + Changed
  case nameChanged(String)
  case emailChanged(String)
  case passwordChanged(String)
  
  // Toggle changes: noun + Changed
  case notificationsEnabledChanged(Bool)
  case darkModeEnabledChanged(Bool)
  
  // Effect responses: noun + past tense
  case userLoaded(User)
  case userLoadFailed(Error)
  case dataSaved
  case dataSaveFailed(Error)
}
```

### 2. Associated Values

Use associated values to carry data with actions:

```swift
enum Action: Equatable, Sendable {
  // Simple actions without data
  case refreshButtonTapped
  
  // Actions with primitive data
  case textFieldChanged(String)
  case toggleChanged(Bool)
  case sliderChanged(Double)
  
  // Actions with complex data
  case userSelected(User)
  case itemsLoaded([Item])
  case errorOccurred(Error)
}
```

### 3. Nested Actions

Use nested enums for complex action hierarchies:

```swift
enum Action: Equatable, Sendable {
  // Authentication actions
  enum Auth: Equatable, Sendable {
    case loginButtonTapped
    case signupButtonTapped
    case logoutButtonTapped
    case userAuthenticated(User)
    case authenticationFailed(Error)
  }
  
  // Profile actions
  enum Profile: Equatable, Sendable {
    case nameChanged(String)
    case emailChanged(String)
    case bioChanged(String)
    case saveButtonTapped
    case profileSaved
    case profileSaveFailed(Error)
  }
  
  // Settings actions
  enum Settings: Equatable, Sendable {
    case notificationsEnabledChanged(Bool)
    case darkModeEnabledChanged(Bool)
    case autoSaveEnabledChanged(Bool)
    case settingsSaved
    case settingsSaveFailed(Error)
  }
  
  // Top-level actions
  case auth(Auth)
  case profile(Profile)
  case settings(Settings)
}
```

### 4. BindableAction

Use `BindableAction` for form fields and controls:

```swift
@Reducer
struct SettingsFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var name = ""
    var email = ""
    var notificationsEnabled = false
    var darkModeEnabled = false
  }
  
  enum Action: BindableAction, Equatable, Sendable {
    case binding(BindingAction<State>)
    case saveButtonTapped
    case cancelButtonTapped
  }
  
  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        // BindingReducer handles this automatically
        return .none
        
      case .saveButtonTapped:
        // Handle save button tap
        return .none
        
      case .cancelButtonTapped:
        // Handle cancel button tap
        return .none
      }
    }
  }
}
```

### 5. PresentationAction

Use `PresentationAction` for child feature actions:

```swift
@Reducer
struct ParentFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    @Presents var child: ChildFeature.State?
  }
  
  enum Action: Equatable, Sendable {
    case addButtonTapped
    case child(PresentationAction<ChildFeature.Action>)
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .addButtonTapped:
        state.child = ChildFeature.State()
        return .none
        
      case .child(.presented(.saveButtonTapped)):
        // Handle child save button tap
        state.child = nil
        return .none
        
      case .child(.presented(.cancelButtonTapped)):
        // Handle child cancel button tap
        state.child = nil
        return .none
        
      case .child:
        return .none
      }
    }
    .ifLet(\.$child, action: \.child) {
      ChildFeature()
    }
  }
}
```

### 6. StackAction

Use `StackAction` for stack-based navigation:

```swift
@Reducer
struct RootFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var path = StackState<Path.State>()
  }
  
  enum Action: Equatable, Sendable {
    case detailButtonTapped
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
      case .detailButtonTapped:
        state.path.append(.detail(DetailFeature.State()))
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
}
```

## Best Practices

### 1. Keep Actions Focused

Each action should represent a single event:

```swift
// ❌ Too broad
enum Action: Equatable, Sendable {
  case handleFormSubmission(name: String, email: String, password: String)
}

// ✅ Focused
enum Action: Equatable, Sendable {
  case nameChanged(String)
  case emailChanged(String)
  case passwordChanged(String)
  case submitButtonTapped
}
```

### 2. Use Descriptive Names

Action names should clearly describe the event:

```swift
// ❌ Unclear
enum Action: Equatable, Sendable {
  case tap
  case change(String)
  case load
}

// ✅ Descriptive
enum Action: Equatable, Sendable {
  case saveButtonTapped
  case nameChanged(String)
  case userDataLoaded(User)
}
```

### 3. Avoid TaskResult in Actions

Handle errors in reducers, not in actions:

```swift
// ❌ Using TaskResult
enum Action: Equatable, Sendable {
  case loadUser
  case userResponse(TaskResult<User>)
}

// ✅ Separate success and failure
enum Action: Equatable, Sendable {
  case loadUser
  case userLoaded(User)
  case userLoadFailed(Error)
}
```

### 4. Group Related Actions

Group related actions together:

```swift
// ❌ Flat structure
enum Action: Equatable, Sendable {
  case loginButtonTapped
  case loginSucceeded(User)
  case loginFailed(Error)
  case signupButtonTapped
  case signupSucceeded(User)
  case signupFailed(Error)
  case logoutButtonTapped
  case logoutSucceeded
  case logoutFailed(Error)
}

// ✅ Grouped structure
enum Action: Equatable, Sendable {
  case login(LoginAction)
  case signup(SignupAction)
  case logout(LogoutAction)
}

enum LoginAction: Equatable, Sendable {
  case buttonTapped
  case succeeded(User)
  case failed(Error)
}

enum SignupAction: Equatable, Sendable {
  case buttonTapped
  case succeeded(User)
  case failed(Error)
}

enum LogoutAction: Equatable, Sendable {
  case buttonTapped
  case succeeded
  case failed(Error)
}
```

### 5. Document Complex Actions

Add comments to explain complex actions:

```swift
enum Action: Equatable, Sendable {
  /// Triggered when the user taps the refresh button.
  /// This will reload all data from the server.
  case refreshButtonTapped
  
  /// Triggered when the user data is successfully loaded.
  /// - Parameter user: The loaded user data.
  case userLoaded(User)
  
  /// Triggered when the user data fails to load.
  /// - Parameter error: The error that occurred.
  case userLoadFailed(Error)
  
  /// Triggered when the user changes their name.
  /// - Parameter name: The new name.
  case nameChanged(String)
}
```

## Conclusion

Action design in TCA provides a clear and type-safe way to represent all the events that can occur in your feature. By following the principles and best practices outlined in this document, you can create actions that are easy to understand, modify, and test.
