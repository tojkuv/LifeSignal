# Action Design

**Navigation:** [Back to iOS Architecture](../README.md) | [Feature Architecture](./FeatureArchitecture.md) | [State Management](./StateManagement.md) | [Effect Management](./EffectManagement.md)

---

> **Note:** As this is an MVP, the action design approach may evolve as the project matures.

## Action Design Principles

Actions in LifeSignal follow these core principles:

1. **Enum Cases**: Actions are defined as enum cases
2. **Associated Values**: Actions can have associated values
3. **Equatable**: Actions are always `Equatable` for testing
4. **Sendable**: Actions are always `Sendable` for concurrency safety
5. **Intent-Based**: Actions describe user intent or system events
6. **Self-Contained**: Actions contain all data needed for the reducer

## Action Definition

Actions are defined using an enum:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable { /* ... */ }
  
  enum Action: Equatable, Sendable {
    // User actions
    case incrementButtonTapped
    case decrementButtonTapped
    case resetButtonTapped
    
    // System actions
    case dataLoaded([Item])
    case errorOccurred(Error)
    
    // Child feature actions
    case child(ChildFeature.Action)
    
    // Presentation actions
    case destination(PresentationAction<Destination.Action>)
  }
  
  // Body, etc.
}
```

## Action Categories

Actions typically fall into these categories:

### 1. User Actions

Actions triggered by user interaction:

```swift
case loginButtonTapped
case textFieldChanged(String)
case saveButtonTapped
case cancelButtonTapped
case itemSelected(Item)
```

### 2. System Actions

Actions triggered by the system or external events:

```swift
case appDidBecomeActive
case appDidEnterBackground
case timerTick
case dataLoaded([Item])
case errorOccurred(Error)
```

### 3. Effect Responses

Actions that represent responses from effects:

```swift
case userResponse(User)
case itemsResponse([Item])
case saveResponse(Result<Void, Error>)
```

### 4. Child Feature Actions

Actions that represent actions from child features:

```swift
case child(ChildFeature.Action)
case profile(ProfileFeature.Action)
case settings(SettingsFeature.Action)
```

### 5. Presentation Actions

Actions that represent actions from presented features:

```swift
case destination(PresentationAction<Destination.Action>)
```

## Bindable Actions

For form fields and controls, use `BindableAction`:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    var name = ""
    var email = ""
    var isEnabled = false
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

## View Actions

For separating view actions from internal actions, use `ViewAction`:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable { /* ... */ }
  
  enum Action: ViewAction, Equatable, Sendable {
    // View actions
    case view(View)
    
    // Internal actions
    case dataLoaded([Item])
    case errorOccurred(Error)
    
    enum View: Equatable, Sendable {
      case loginButtonTapped
      case textFieldChanged(String)
      case saveButtonTapped
      case cancelButtonTapped
    }
  }
  
  // Body, etc.
}
```

## Stack Actions

For stack-based navigation, use `StackAction`:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    var path = StackState<Path.State>()
    var items: [Item] = []
  }
  
  enum Action: Equatable, Sendable {
    case itemSelected(Item)
    case path(StackAction<Path.State, Path.Action>)
  }
  
  // Body, etc.
}
```

## Action Composition

Actions are composed using nested enums:

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
  
  // Body, etc.
}
```

## Error Handling in Actions

Errors are handled using `Result` or dedicated error actions:

```swift
enum Action: Equatable, Sendable {
  case saveButtonTapped
  case saveResponse(Result<Void, Error>)
  // or
  case saveSucceeded
  case saveFailed(Error)
}
```

## Best Practices

1. **Keep Actions Focused**: Each action should have a single purpose
2. **Use Descriptive Names**: Action names should clearly describe the intent
3. **Include Necessary Data**: Actions should include all data needed for the reducer
4. **Make Actions Equatable**: Always conform to `Equatable`
5. **Make Actions Sendable**: Always conform to `Sendable`
6. **Use BindableAction**: Use `BindableAction` for form fields and controls
7. **Use ViewAction**: Use `ViewAction` to separate view actions from internal actions
8. **Use PresentationAction**: Use `PresentationAction` for presented features
9. **Use StackAction**: Use `StackAction` for stack-based navigation
10. **Document Actions**: Document the purpose of each action
