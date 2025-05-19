# iOS Architecture

**Navigation:** [Back to Main Architecture](../README.md) | [Guidelines](Guidelines/README.md) | [Specification](Specification/README.md) | [Backend Architecture](../Backend/README.md)

---

## Overview

The iOS application is built using Swift and SwiftUI, following The Composable Architecture (TCA) pattern. This modern architecture enables us to:

- Build features that are independent of specific backend technologies
- Test features in isolation with minimal mocking
- Maintain type safety and concurrency safety throughout the codebase
- Ensure a clean separation between business logic and infrastructure concerns
- Leverage Swift's latest features like structured concurrency, property wrappers, and macros

## Documentation Structure

The iOS documentation is organized into two main sections:

1. **[Guidelines](Guidelines/README.md)**: How to implement
   - [Production Guidelines](Guidelines/Production/README.md): Guidelines for the production application using TCA
   - [Mock Guidelines](Guidelines/Mock/README.md): Guidelines for the mock application using MVVM

2. **[Specification](Specification/README.md)**: What to implement
   - [Architecture Overview](Specification/ArchitectureOverview.md): Overview of the iOS architecture
   - [Project Structure](Specification/ProjectStructure.md): Structure of the iOS project
   - [Feature List](Specification/FeatureList.md): List of all features
   - [Domain Models](Specification/Domain/README.md): Core domain models
   - [Features](Specification/Features/README.md): Feature specifications
   - [Infrastructure](Specification/Infrastructure/README.md): Infrastructure specifications
   - [UI](Specification/UI/UIGuidelines.md): UI guidelines
   - [Examples](Specification/Examples/README.md): Example implementations

## Architectural Layers

The iOS application follows a layered architecture:

```
Feature Layer → Middleware Clients → Adapters → Platform Backend Clients → Backend
(UserFeature)    (UserClient)       (FirebaseUserAdapter)  (FirebaseClient)     (Firebase/Supabase)
```

### Key Components

1. **App Layer**: Root components that compose all features
2. **Feature Layer**: Individual features using modular features architecture
3. **Domain Layer**: Core domain models and business logic
4. **Middleware Layer**: Backend agnostic anti-corruption clients
5. **Adapter Layer**: Platform-specific adapters
6. **Platform Backend Layer**: Platform-specific clients (Firebase, Supabase)

## Implementation Strategy

The iOS implementation follows these principles:

1. **Separation of Concerns**: Each component has a single responsibility
2. **Dependency Inversion**: High-level modules do not depend on low-level modules
3. **Unidirectional Data Flow**: Data flows in one direction for predictable state management
4. **Testability**: All components are designed to be easily testable
5. **Modularity**: The application is divided into cohesive modules with clear boundaries
6. **Composition**: Complex features are composed from simpler components

For detailed implementation guidelines, see the [Guidelines](Guidelines/README.md) section.

For detailed specifications, see the [Specification](Specification/README.md) section.
