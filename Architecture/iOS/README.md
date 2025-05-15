# iOS Architecture

**Navigation:** [Back to Main Architecture](../README.md) | [General Architecture](../General/README.md) | [Backend Architecture](../Backend/README.md)

---

## Overview

The iOS application is built using Swift and SwiftUI, following The Composable Architecture (TCA) pattern. This modern architecture enables us to:

- Build features that are independent of specific backend technologies
- Test features in isolation with minimal mocking
- Maintain type safety and concurrency safety throughout the codebase
- Ensure a clean separation between business logic and infrastructure concerns
- Leverage Swift's latest features like structured concurrency, property wrappers, and macros

## Project Structure

```
LifeSignal/
├── App/ (App-wide components)
│   ├── LifeSignalApp.swift (App entry point with AppDelegate)
│   ├── AppFeature.swift (Root feature that composes all other features)
│   └── MainTabView.swift (Tab-based navigation)
│
├── Core/ (Shared core functionality)
│   ├── Domain/ (Domain models)
│   │   └── Models/ (Core domain models)
│   │
│   ├── Infrastructure/ (Infrastructure-agnostic interfaces)
│   │   ├── Protocols/ (Infrastructure-agnostic protocols)
│   │   ├── Clients/ (Core and domain-specific clients)
│   │   ├── DTOs/ (Data transfer objects)
│   │   └── Mapping/ (Mapping between domain models and DTOs)
│   │
│   └── HelperUtilities/ (Shared utilities)
│
├── Features/ (Feature modules using vertical slice architecture)
│   ├── Auth/ (Authentication feature)
│   ├── Profile/ (Profile feature)
│   ├── Contacts/ (Contacts feature)
│   ├── Home/ (Home feature)
│   ├── Responders/ (Responders feature)
│   ├── Dependents/ (Dependents feature)
│   ├── CheckIn/ (Check-in feature)
│   ├── Alert/ (Alert feature)
│   ├── Notification/ (Notification feature)
│   ├── Ping/ (Ping feature)
│   └── QRCodeSystem/ (QR code features)
│
└── Infrastructure/ (Backend-specific implementations)
    ├── Firebase/ (Firebase implementations)
    │   ├── Adapters/ (Firebase adapters)
    │   └── Clients/ (Firebase-specific clients)
    │
    └── Supabase/ (Supabase implementations - future)
        ├── Adapters/ (Supabase adapters)
        └── Clients/ (Supabase-specific clients)
```

## Architecture Components

### The Composable Architecture (TCA)

The application uses The Composable Architecture (TCA) for state management and UI coordination:

- **@Reducer** - Macro that defines a feature with state, actions, and reducer logic
- **@ObservableState** - Macro that makes state observable by SwiftUI
- **State** - The single source of truth for a feature, always `Equatable` and `Sendable`
- **Action** - Events that can change the state, always `Equatable` and `Sendable`
- **Reducer** - Pure functions that handle actions and update state
- **Effect** - Side effects that interact with the outside world using structured concurrency
- **Store** - Connects the reducer to the view
- **@Dependency** - Property wrapper for injecting dependencies into reducers
- **@Presents** - Property wrapper for managing presentation state
- **@Shared** - Property wrapper for sharing state across features

[Learn more about TCA →](Guidelines/TCA/Overview.md)

### Infrastructure Layers

LifeSignal follows a layered architecture for infrastructure:

```
Feature Layer → Domain-Specific Clients → Core Infrastructure Clients → Adapters → Backend
(UserFeature)    (UserClient)            (StorageClient)              (StorageAdapter)  (Firebase)
```

This layered architecture ensures:

1. **Type Safety**: All interfaces between layers use strongly-typed Swift types
2. **Concurrency Safety**: All async operations are properly handled with structured concurrency
3. **Infrastructure Agnosticism**: No backend-specific types leak into the application code
4. **Testability**: Each layer can be tested independently with appropriate mocks
5. **Maintainability**: Changes to one layer don't affect other layers

### Firebase Integration

LifeSignal integrates with Firebase services using a layered, infrastructure-agnostic approach:

- **Firebase Adapters**: Implement infrastructure-agnostic interfaces using Firebase
- **Firebase Clients**: Provide Firebase-specific functionality
- **Firebase Streaming**: Stream data from Firebase to the application
- **Firebase Error Handling**: Map Firebase errors to domain-specific errors

[Learn more about Firebase Integration →](Guidelines/Infrastructure/FirebaseInfrastructure/Overview.md)

## Documentation

### TCA Implementation

- [TCA Overview](Guidelines/TCA/Overview.md) - Overview of TCA implementation
- [State Management](Guidelines/TCA/StateManagement.md) - State management in TCA
- [Action Design](Guidelines/TCA/ActionDesign.md) - Action design in TCA
- [Effect Management](Guidelines/TCA/EffectManagement.md) - Effect management in TCA
- [Dependency Injection](Guidelines/TCA/DependencyInjection.md) - Dependency injection in TCA
- [Navigation](Guidelines/TCA/Navigation.md) - Navigation patterns in TCA
- [Testing](Guidelines/TCA/Testing.md) - Testing in TCA

### Firebase Integration

- [Firebase Overview](Guidelines/Infrastructure/FirebaseInfrastructure/Overview.md) - Overview of Firebase integration
- [Client Design](Guidelines/Infrastructure/FirebaseInfrastructure/ClientDesign.md) - Firebase client design
- [Adapter Pattern](Guidelines/Infrastructure/FirebaseInfrastructure/AdapterPattern.md) - Firebase adapter pattern
- [Streaming Data](Guidelines/Infrastructure/FirebaseInfrastructure/StreamingData.md) - Streaming data from Firebase

### Performance

- [Optimization](Guidelines/Performance/Optimization.md) - Performance optimization techniques

## Best Practices

### Feature Development

1. **Use @Reducer Macro**: Define features using the `@Reducer` macro
2. **Keep Features Focused**: Each feature should have a single responsibility
3. **Use Vertical Slices**: Organize code by feature rather than by technical layer
4. **Compose Features**: Compose features using parent-child relationships
5. **Handle Loading States**: Features should manage their own loading states
6. **Handle Error States**: Features should handle their own error states
7. **Test Features**: Test features in isolation
8. **Document Features**: Document the purpose of each feature
9. **Use Composition Over Inheritance**: Prefer composition over inheritance for feature organization

### State Management

1. **Use @ObservableState**: Mark state structs with `@ObservableState` for SwiftUI integration
2. **Single Source of Truth**: State is the single source of truth for a feature
3. **Immutable State**: State is only mutated within reducers
4. **Equatable State**: State is always `Equatable` for efficient diffing
5. **Sendable State**: State is always `Sendable` for concurrency safety
6. **Avoid Optionals**: Avoid storing optionals in state when a default value makes sense
7. **Use @Presents**: Use `@Presents` for presentation state instead of optionals
8. **Use @Shared**: Use `@Shared` for state that needs to be shared across features

### Action Design

1. **Use Enums**: Define actions as enums with associated values
2. **Equatable Actions**: Actions should be `Equatable` for testing
3. **Sendable Actions**: Actions should be `Sendable` for concurrency safety
4. **Avoid TaskResult**: Avoid using `TaskResult` in actions; handle errors in reducers
5. **Use PresentationAction**: Use `PresentationAction` for child feature actions
6. **Use BindableAction**: Use `BindableAction` for form fields and controls

### Effect Management

1. **Use .run**: Use `.run` for all asynchronous operations
2. **Handle Errors**: Handle errors within effects, not in actions or state
3. **Use Cancellation IDs**: Always specify cancellation IDs for long-running or repeating effects
4. **Use Task.yield()**: Use `Task.yield()` for CPU-intensive work in effects
5. **Return .none**: Return `.none` for synchronous state updates with no side effects
6. **Use Structured Concurrency**: Use structured concurrency (`async/await`) for all asynchronous code
7. **Avoid Raw Tasks**: Avoid using raw `Task` creation in reducers
8. **Use ContinuousClock**: Use `@Dependency(\.continuousClock)` instead of direct `Task.sleep`
9. **Ensure Cancellability**: Ensure all async code is properly cancellable

### Dependency Management

1. **Use @Dependency**: Use `@Dependency` property wrapper for all dependencies
2. **Use @DependencyClient**: Use `@DependencyClient` macro for client definitions
3. **Provide Default Values**: Provide default values for non-throwing closures in client definitions
4. **Remove Argument Labels**: Remove argument labels in function types for cleaner syntax
5. **Conform to DependencyKey**: Conform all dependencies to `DependencyKey`
6. **Provide Multiple Implementations**: Provide `liveValue`, `testValue`, and `previewValue` implementations
7. **Use Namespaced Access**: Use namespaced access for related dependencies (e.g., `$0.firebase.auth`)
8. **Use @ObservationIgnored**: Mark `@Dependency` properties with `@ObservationIgnored` in `@Observable` classes

### SwiftUI Integration

1. **Use @Bindable**: Use `@Bindable var store: StoreOf<Feature>` for view store binding
2. **Use $store.scope**: Use `$store.scope(state:action:)` for navigation stack binding
3. **Use $store Syntax**: Use `$store` syntax for form controls with `BindableAction`
4. **Use View Modifiers**: Use `.analyticsScreen()` or similar view modifiers for cross-cutting concerns
5. **Use Preview Traits**: Use `#Preview(trait: .dependencies { ... })` for dependency overrides in previews

### Performance Optimization

1. **Use onChange**: Use `onChange` reducer operator for selective effect execution
2. **Use TaskResult Caching**: Use `TaskResult` caching for expensive computations
3. **Yield Periodically**: Yield periodically during CPU-intensive work
4. **Use _printChanges()**: Use `._printChanges()` during development to identify unnecessary state updates
5. **Consider @Shared**: Consider using `@Shared` with appropriate persistence strategy for shared state

## Conclusion

The iOS architecture provides a solid foundation for building a scalable, maintainable, and testable application. By following The Composable Architecture (TCA) and infrastructure-agnostic design, we ensure that the application is flexible and can adapt to changing requirements.

Modern TCA leverages Swift's latest features like structured concurrency, property wrappers, and macros to provide a clean, type-safe, and testable approach to building iOS applications. The architecture's focus on composition, dependency injection, and infrastructure agnosticism makes it well-suited for complex applications that need to evolve over time.
