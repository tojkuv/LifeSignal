# Mock to Production Migration Guide

**Navigation:** [Back to Application Specification](README.md) | [Architecture Overview](ArchitectureOverview.md) | [Data Persistence and Streaming](Infrastructure/DataPersistenceStreaming.md) | [TCA Overview](../Guidelines/Production/TCA/Overview.md) | [Mock Guidelines](../Guidelines/Mock/README.md)

---

## Overview

This document provides a comprehensive guide for migrating the LifeSignal iOS application from the mock implementation to the production implementation using The Composable Architecture (TCA). It covers the migration strategy, implementation approach, and best practices.

## Current State: Mock Implementation

The MockApplication currently uses a traditional MVVM architecture with:

1. **View Models**: ObservableObject classes with @Published properties
2. **Views**: SwiftUI views that use @EnvironmentObject or @StateObject to reference view models
3. **Models**: Simple structs for data representation
4. **Mock Data**: Hardcoded data for UI development

The mock implementation serves as a sandbox for UI development and iteration, allowing designers and developers to iterate on UI designs without affecting the production codebase. The mock application should not contain client implementations or testing code, as these should only exist in the TCA production application.

## Target State: Production Implementation

The production implementation will use The Composable Architecture (TCA) with:

1. **State**: Immutable structs that represent feature state
2. **Action**: Enums that represent events in the feature
3. **Reducer**: Functions that handle actions and update state
4. **Effect**: Asynchronous operations triggered by actions
5. **View**: SwiftUI views that use TCA stores
6. **Client**: Protocol-based interfaces for external services
7. **Adapter**: Backend-specific implementations of client interfaces

## Migration Strategy

The migration will follow a phased approach:

### Phase 1: Infrastructure Layer (Weeks 1-4)

1. Define client interfaces (UserClient, ContactClient, etc.)
2. Implement platform-agnostic clients
3. Implement platform-specific adapters (Firebase, Supabase)
4. Implement mock clients for testing
5. Set up dependency injection

### Phase 2: Domain Layer (Weeks 5-6)

1. Define domain models (User, Contact, etc.)
2. Implement validation logic
3. Create DTOs for backend integration
4. Implement mapping between domain models and DTOs

### Phase 3: Feature Layer (Weeks 7-12)

1. Implement core features (AppFeature, UserFeature)
2. Implement authentication features (AuthFeature)
3. Implement contact features (ContactsFeature, RespondersFeature, DependentsFeature)
4. Implement safety features (CheckInFeature, AlertFeature)
5. Implement utility features (NotificationFeature, QRCodeFeature)

### Phase 4: Presentation Layer (Weeks 13-16)

1. Update views to use TCA stores
2. Implement WithPerceptionTracking for UI updates
3. Implement navigation and presentation
4. Implement error handling and loading states

### Phase 5: Testing and Refinement (Weeks 17-20)

1. Write unit tests for reducers in the TCA production application
2. Write integration tests for features in the TCA production application
3. Write UI tests for views in the TCA production application
4. Refine implementation based on testing
5. Optimize performance

Note: All testing should be done in the TCA production application, not in the mock application.

## Implementation Approach

### 1. Feature Implementation

Each feature will be implemented following the TCA pattern. For detailed information on TCA implementation, see the [TCA Overview](../Guidelines/Production/TCA/Overview.md) guidelines.

### 2. View Implementation

Views will be implemented using TCA's WithPerceptionTracking. For detailed information on view implementation in TCA, see the [TCA Overview](../Guidelines/Production/TCA/Overview.md) guidelines.

### 3. Client Implementation

Clients will be implemented using protocol-based interfaces. For detailed information on client implementation in TCA, see the [Infrastructure Layer](Infrastructure/README.md) documentation.

### 4. Adapter Implementation

Adapters will be implemented to bridge between client interfaces and backend services. For detailed information on adapter implementation, see the [Backend Integration](Infrastructure/BackendIntegration.md) documentation.

## Data Persistence and Streaming

The migration will implement a comprehensive strategy for data persistence and streaming, particularly for user data and contact collections. This strategy leverages TCA's @Shared property wrapper, AsyncStream, and platform-specific client capabilities to provide a responsive and reliable user experience.

For detailed information on implementing user data and contact collection persistence with streamed updates, see the [Data Persistence and Streaming](Infrastructure/DataPersistenceStreaming.md) document.

## Best Practices

### 1. State Management

- Use `@ObservableState` for all state structs
- Use `@Presents` for presentation state
- Use `@Shared` for state that needs to be shared across features
- Make state immutable where possible
- Use value types for state properties

### 2. Action Design

- Use descriptive action names
- Group related actions using nested enums
- Use `CasePathable` for action routing
- Include all necessary data in action payloads
- Use `TaskResult` for handling async results

### 3. Reducer Implementation

- Keep reducers focused on a single responsibility
- Use composition to build complex reducers
- Use `Scope` to delegate to child reducers
- Use `Reduce` for custom reducer logic
- Handle errors gracefully

### 4. Effect Management

- Use `.run` for asynchronous effects
- Use `.merge` to combine multiple effects
- Use `.cancel` to cancel ongoing effects
- Use cancellation IDs to identify effects
- Use `TaskResult` to handle success and failure

### 5. Dependency Injection

- Define clear interfaces for dependencies
- Provide live, test, and preview implementations
- Use `@Dependency` to inject dependencies
- Group related dependencies logically
- Override dependencies in tests

### 6. Testing

- Write tests for each reducer in the TCA production application
- Test success and failure paths
- Test edge cases and error conditions
- Use dependency overrides for testing
- Use TestStore for reducer testing
- Do not implement testing in the mock application

## Migration Challenges and Solutions

### 1. State Sharing

**Challenge**: The mock implementation uses shared view models for state sharing.

**Solution**: Use TCA's `@Shared` property wrapper for state that needs to be shared across features.

### 2. Navigation

**Challenge**: The mock implementation uses SwiftUI's navigation APIs directly.

**Solution**: Use TCA's navigation tools (`@Presents`, `NavigationStackStore`) for type-safe navigation.

### 3. Asynchronous Operations

**Challenge**: The mock implementation uses completion handlers and Combine for async operations.

**Solution**: Use Swift concurrency (async/await) and TCA's effect system for async operations.

### 4. Error Handling

**Challenge**: The mock implementation has inconsistent error handling.

**Solution**: Use TCA's `TaskResult` type and consistent error handling patterns.

### 5. Dependency Management

**Challenge**: The mock implementation has implicit dependencies.

**Solution**: Use TCA's dependency injection system for explicit dependencies.

## Conclusion

This migration guide provides a comprehensive approach to migrating the LifeSignal iOS application from the mock implementation to a production implementation using The Composable Architecture. By following this guide, the development team can ensure a smooth transition while maintaining code quality, testability, and developer productivity.

The migration will result in a more maintainable, testable, and scalable application that can evolve and grow over time. It will also provide a solid foundation for future feature development and backend integration.

## Related Documentation

- [TCA Overview](../Guidelines/Production/TCA/Overview.md) - Overview of The Composable Architecture
- [Mock Guidelines](../Guidelines/Mock/README.md) - Guidelines for the mock application
- [Infrastructure Layer](Infrastructure/README.md) - Documentation for the infrastructure layer
- [Data Persistence and Streaming](Infrastructure/DataPersistenceStreaming.md) - Strategy for data persistence and streaming
- [Architecture Overview](ArchitectureOverview.md) - Overview of the LifeSignal iOS architecture
