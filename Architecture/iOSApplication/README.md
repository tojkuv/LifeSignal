# LifeSignal iOS Architecture

**Navigation:** [Back to Main Architecture](../README.md) | [Backend Architecture](../Backend/README.md)

---

> **Note:** This architecture is still an MVP and the folder structure and files are likely to change as the project evolves. The current implementation is a starting point that will be refined based on real-world usage and feedback.

## Overview

LifeSignal uses a combination of vertical slice architecture for features and a layered, infrastructure-agnostic architecture for the core infrastructure. This design enables us to:

1. Organize code by feature rather than by technical layer
2. Build features that are independent of specific backend technologies
3. Switch between different backends (Firebase, Supabase, etc.) without changing application code
4. Test features without real infrastructure dependencies
5. Maintain type safety and concurrency safety throughout the codebase
6. Ensure a clean separation between domain logic and infrastructure concerns
7. Support multiple platforms with shared business logic

## Architecture Documentation

This directory contains detailed documentation about different aspects of the LifeSignal iOS architecture:

### Core Architecture

- [Core Principles](CorePrinciples.md) - Fundamental architectural principles
- [Infrastructure Layers](Core/InfrastructureLayers.md) - Infrastructure-agnostic layer design
- [Client Architecture](Core/ClientArchitecture.md) - Client architecture and types
- [Dependency Management](Core/DependencyManagement.md) - TCA dependency system

### Firebase Integration

- [Firebase Integration](Core/Firebase/FirebaseIntegration.md) - Overview of Firebase integration
- [Firebase Clients](Core/Firebase/FirebaseClients.md) - Firebase client design
- [Firebase Adapters](Core/Firebase/FirebaseAdapters.md) - Adapter implementation
- [Firebase Streaming](Core/Firebase/FirebaseStreaming.md) - Streaming data from Firebase

### Feature Architecture

- [Feature Architecture](Features/FeatureArchitecture.md) - Vertical slice feature architecture
- [State Management](Features/StateManagement.md) - State design principles
- [Action Design](Features/ActionDesign.md) - Action design principles
- [Effect Management](Features/EffectManagement.md) - Effect design principles

### Navigation

- [Navigation Patterns](Navigation/NavigationPatterns.md) - Overview of navigation approaches
- [Tree-Based Navigation](Navigation/TreeBasedNavigation.md) - Tree-based navigation
- [Stack-Based Navigation](Navigation/StackBasedNavigation.md) - Stack-based navigation

### Testing

- [Testing Strategy](Testing/TestingStrategy.md) - Testing approach and patterns
- [TestStore Usage](Testing/TestStoreUsage.md) - TestStore best practices
- [Dependency Testing](Testing/DependencyTesting.md) - Testing with dependencies

### SwiftUI Integration

- [SwiftUI Integration](SwiftUI/SwiftUIIntegration.md) - SwiftUI with TCA
- [View Implementation](SwiftUI/ViewImplementation.md) - View implementation patterns

### Performance

- [Performance Considerations](Performance/PerformanceConsiderations.md) - Performance optimization

### TCA Implementation

- [TCA Implementation](TCAImplementation.md) - TCA implementation details
- [Modern TCA Architecture](ComposableArchitecture.md) - Modern TCA architecture rules

## High-Level Architecture

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

## Conclusion

This architecture provides a solid foundation for building a scalable, maintainable, and testable application. By separating concerns and using a layered approach, we can ensure that our application is flexible and can adapt to changing requirements. The use of TCA and vertical slice architecture allows us to build features that are independent and can be developed and tested in isolation.

> **Important:** This architecture document represents the current MVP state of the project. The folder structure, file organization, and specific implementation details are expected to evolve as the project matures. We will continuously refine this architecture based on real-world usage patterns and feedback.
