# LifeSignal iOS Architecture Overview

**Navigation:** [Back to Application Specification](README.md) | [Project Structure](ProjectStructure.md) | [Feature List](FeatureList.md) | [Mock to Production Migration](MockToProductionMigration.md) | [TCA Overview](../Guidelines/Production/TCA/Overview.md)

---

## Overview

This document provides a comprehensive overview of the LifeSignal iOS application architecture. It combines information from the module dependency graph, dependency injection approach, layer boundaries, data flow, and state management strategy.

## Architectural Principles

The LifeSignal iOS application follows these core architectural principles:

1. **Separation of Concerns**: Each component has a single responsibility
2. **Dependency Inversion**: High-level modules do not depend on low-level modules
3. **Unidirectional Data Flow**: Data flows in one direction for predictable state management
4. **Testability**: All components are designed to be easily testable
5. **Modularity**: The application is divided into cohesive modules with clear boundaries
6. **Composition**: Complex features are composed from simpler components

## Architectural Layers

The application is organized into the following layers:

### 1. Presentation Layer

The presentation layer is responsible for displaying the user interface and handling user interactions. It consists of:

- **Views**: SwiftUI views that display the UI and handle user input
- **ViewStores**: TCA view stores that connect views to feature state
- **Bindings**: Connections between views and state

### 2. Feature Layer

The feature layer contains the application's business logic organized by feature. Each feature consists of:

- **State**: The feature's state data
- **Action**: Events that can occur in the feature
- **Reducer**: Logic that handles actions and updates state
- **Effect**: Asynchronous operations triggered by actions

### 3. Domain Layer

The domain layer contains the core business entities and logic. It consists of:

- **Models**: Core business entities
- **Validation**: Business rules and validation logic
- **Calculations**: Business calculations and transformations

### 4. Infrastructure Layer

The infrastructure layer provides access to external systems and services. It consists of:

- **Client Interfaces**: Protocol-based interfaces for external services
- **Client Implementations**: Concrete implementations of client interfaces
- **Adapters**: Bridges between client interfaces and backend services
- **DTOs**: Data transfer objects for serialization

## Layer Dependencies

The layers depend on each other in the following way:

```
Presentation Layer
       ↓
Feature Layer
       ↓
Domain Layer
       ↓
Infrastructure Layer (interfaces)
       ↓
Infrastructure Layer (implementations)
```

This dependency direction ensures that:

1. The domain layer is independent of infrastructure concerns
2. Features depend only on domain models and infrastructure interfaces
3. Presentation depends only on features
4. Infrastructure implementations depend on interfaces, not features

## Module Dependency Graph

The application is organized into the following modules:

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                          App Module                                 │
│                                                                     │
└───────────────────────────────────┬─────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                        Feature Modules                              │
│                                                                     │
└───────────────────────────────────┬─────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                         Domain Module                               │
│                                                                     │
└───────────────────────────────────┬─────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                     Infrastructure Module                           │
│                                                                     │
└───────────────────────────────────┬─────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                        Adapter Modules                              │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Module Responsibilities

1. **App Module**: Application entry point and global composition
2. **Feature Modules**: Feature-specific business logic and UI
3. **Domain Module**: Core business entities and logic
4. **Infrastructure Module**: Infrastructure-agnostic interfaces
5. **Adapter Modules**: Backend-specific implementations

## Dependency Injection

The application uses TCA's dependency injection system to provide dependencies to features. This approach allows for easy testing and flexibility in implementation.

For detailed information on dependency injection in TCA, see the [Dependency Injection](../Guidelines/Production/TCA/DependencyInjection.md) guidelines.

### Dependency Graph

The following diagram shows the dependencies between different clients:

```
AuthClient ◄─── UserClient ◄─── ProfileFeature
    │               │
    │               ▼
    │           ContactClient ◄─── ContactsFeature
    │               │
    │               ▼
    └───────► CheckInClient ◄─── CheckInFeature
                    │
                    ▼
                AlertClient ◄─── AlertFeature
                    │
                    ▼
                PingClient ◄─── PingFeature
                    │
                    ▼
            NotificationClient ◄─── NotificationFeature
```

## Data Flow

The application follows a unidirectional data flow pattern, which is a core principle of TCA:

1. **User Interaction**: User interacts with the view
2. **Action Dispatch**: View dispatches an action to the store
3. **Reducer Processing**: Reducer processes the action and updates state
4. **Effect Execution**: Effects perform asynchronous operations
5. **State Update**: State is updated based on effect results
6. **View Update**: View updates to reflect the new state

For detailed information on effect management in TCA, see the [Effect Management](../Guidelines/Production/TCA/EffectManagement.md) guidelines.

## State Management

The application uses TCA's state management approach, which includes:

1. **Feature State**: Each feature defines its state as a struct with `@ObservableState`
2. **Shared State**: State shared across features uses the `@Shared` property wrapper
3. **Presentation State**: Features that present other features use the `@Presents` property wrapper
4. **State Composition**: The application composes state hierarchically

For detailed information on state management in TCA, see the [State Management](../Guidelines/Production/TCA/StateManagement.md) guidelines.

## Persistence and Streaming

The application implements a comprehensive strategy for data persistence and streaming:

### 1. Server-Side Persistence

Firebase Firestore is used for primary storage of all user data and contacts.

### 2. Client-Side Persistence

Multiple layers of client-side persistence are used:

- **TCA @Shared State**: For state that needs to be shared across features
- **File Storage**: For larger data structures and complex objects
- **UserDefaults**: For simple preferences and settings
- **In-Memory Cache**: For temporary data and performance optimization

### 3. Streaming Updates

Real-time updates from the server to the client are implemented using:

- **AsyncStream**: To wrap Firebase listeners for type safety
- **TCA Effects**: To handle streaming in reducers
- **Cancellation**: To properly manage stream lifecycles

## Conclusion

The LifeSignal iOS application architecture provides a solid foundation for building a maintainable, testable, and scalable application. By following clear architectural principles, organizing code into well-defined layers and modules, and implementing a comprehensive dependency injection and state management strategy, the application can evolve and grow while maintaining code quality and developer productivity.
