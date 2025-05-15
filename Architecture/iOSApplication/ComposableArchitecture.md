# Modern TCA Architecture Rules for iOS

**Navigation:** [Back to iOS Architecture](README.md) | [TCA Implementation](TCAImplementation.md) | [Feature Architecture](FeatureArchitecture.md) | [Core Principles](CorePrinciples.md)

---

## Core Architecture Principles

### Feature Definition
- Use `@Reducer` macro for all feature definitions
- Use `@ObservableState` for all state structs
- Prefer composition over inheritance for feature organization
- Keep features focused on a single responsibility

---

## State Management
- State should be fully `Equatable` and `Sendable`
- Use value types (`structs`) for all state
- Avoid storing optionals in state when a default value makes sense
- Use `@Presents` for presentation state instead of optionals
- Use `@Shared` for state that needs to be shared across features

---

## Action Design
- Actions should be fully `Equatable` and `Sendable`
- Use `enum` cases with associated values for all actions
- Avoid using `TaskResult` in actions; handle errors in reducers
- Use `PresentationAction` for child feature actions
- Use `BindableAction` for form fields and controls

---

## Effect Management

### Effect Handling
- Use `.run` for all asynchronous operations
- Handle errors within effects, not in actions or state
- Always specify cancellation IDs for long-running or repeating effects
- Use `Task.yield()` for CPU-intensive work in effects
- Return `.none` for synchronous state updates with no side effects

### Concurrency
- Use structured concurrency (`async/await`) for all asynchronous code
- Avoid using raw `Task` creation in reducers
- Use `@Dependency(\.continuousClock)` instead of direct `Task.sleep`
- Ensure all async code is properly cancellable

---

## Dependency Management

### Dependency Injection
- Use `@Dependency` property wrapper for all dependencies
- Define dependencies as protocols or struct-based clients with closure properties
- Use `@DependencyClient` macro for client definitions
- Provide default values for non-throwing closures in client definitions
- Remove argument labels in function types for cleaner syntax

### Dependency Registration
- Conform all dependencies to `DependencyKey`
- Provide `liveValue`, `testValue`, and `previewValue` implementations
- Register dependencies with `DependencyValues` extension
- Use namespaced access for related dependencies (e.g., `$0.firebase.auth`)

---

## Firebase Integration

### Firebase Client Design
- Create separate clients for each Firebase service (Auth, Firestore, Storage, etc.)
- Stream Firebase data at the top level (`AppFeature` or `SessionFeature`)
- Emit clean, `Equatable`/`Sendable` actions from Firebase streams
- Handle stream errors at the `AppFeature` level only
- Use domain-specific error types instead of raw Firebase errors

### Firebase Operations
- Encapsulate authentication checks in the dependency layer
- Implement generic update/patch methods for common Firestore operations
- Use atomic operations (like `FieldValue.increment()`) when appropriate
- Handle write errors locally in the initiating feature

---

## Navigation and Presentation

### Navigation Patterns
- Use `@Presents` for optional destination state
- Use `PresentationAction` for handling child feature actions
- Use `StackState` and `StackAction` for stack-based navigation
- Handle dismissal by setting destination state to `nil`
- Prefer composition with `Scope` and `ifLet` for complex navigation

---

## Testing

### TestStore Usage
- Create `TestStore` instances within individual tests, not as shared properties
- Override dependencies with `withDependencies` for controlled testing
- Use `ImmediateClock` for time-based tests
- Test both success and failure paths for all effects
- Use `.dependency` test trait for simple dependency overrides

### Assertion Patterns
- Use trailing closures with `store.send` to assert state changes
- Use `store.receive` to assert on actions received from effects
- Test shared state mutations in the send block for the triggering action
- Use `store.assert` for complex state assertions
- Verify cancellation of effects when appropriate

---

## SwiftUI Integration

### View Implementation
- Use `@Bindable var store: StoreOf<Feature>` for view store binding
- Use `$store.scope(state:action:)` for navigation stack binding
- Use `$store` syntax for form controls with `BindableAction`
- Use `.analyticsScreen()` or similar view modifiers for cross-cutting concerns
- Use `#Preview(trait: .dependencies { ... })` for dependency overrides in previews

---

## Performance Considerations

### Optimization Techniques
- Use `onChange` reducer operator for selective effect execution
- Use `TaskResult` caching for expensive computations
- Yield periodically during CPU-intensive work
- Use `._printChanges()` during development to identify unnecessary state updates
- Consider using `@Shared` with appropriate persistence strategy for shared state
