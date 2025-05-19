# Production Application Guidelines

**Navigation:** [Back to iOS Guidelines](../README.md) | [Mock Guidelines](../Mock/README.md)

---

## Overview

This directory contains guidelines for developing the LifeSignal production iOS application using The Composable Architecture (TCA). These guidelines provide a consistent approach to architecture, state management, and UI implementation across the production codebase.

> **Important:** All UI and UX for the production application should be derived from the mock application (`@Architecture/iOS/MockApplication/MockApplication`). The mock application serves as the source of truth for UI/UX design and is regularly updated to reflect the latest design requirements. The production application should implement these designs using TCA.

## Guidelines

### TCA Implementation

- [TCA Overview](TCA/Overview.md) - Overview of TCA implementation
- [State Management](TCA/StateManagement.md) - State management in TCA
- [Action Design](TCA/ActionDesign.md) - Action design in TCA
- [Effect Management](TCA/EffectManagement.md) - Effect management in TCA
- [Dependency Injection](TCA/DependencyInjection.md) - Dependency injection in TCA
- [Navigation](TCA/Navigation.md) - Navigation patterns in TCA
- [Testing](TCA/Testing.md) - Testing in TCA
- [Modern TCA Rules](TCA/ModernTCARules.md) - Modern TCA rules and best practices

### Infrastructure

- [Architectural Layers](Infrastructure/ArchitecturalLayers.md) - Detailed explanation of architectural layers and responsibilities
- [Backend Integration](Infrastructure/BackendIntegration.md) - Guidelines for integrating with Supabase and Firebase
- [Infrastructure Agnosticism](Infrastructure/AgnosticInfrastructure/InfrastructureAgnosticism.md) - Infrastructure-agnostic design
- [Middleware Clients](Infrastructure/MiddlewareClients/MiddlewareClients.md) - Guidelines for implementing middleware clients

#### Firebase Integration (Authentication & Data Storage)

- [Firebase Adapters](Infrastructure/FirebaseAdapters/Overview.md) - Firebase adapter implementation
- [Client Design](Infrastructure/FirebaseAdapters/ClientDesign.md) - Firebase client design
- [Adapter Pattern](Infrastructure/FirebaseAdapters/AdapterPattern.md) - Firebase adapter pattern
- [Streaming Data](Infrastructure/FirebaseAdapters/StreamingData.md) - Streaming data from Firebase

#### Supabase Integration (Cloud Functions)

- [Supabase Overview](Infrastructure/SupabaseAdapters/Overview.md) - Overview of Supabase integration
- [Cloud Functions](Infrastructure/SupabaseAdapters/CloudFunctions.md) - Guidelines for implementing cloud functions
- [Client Design](Infrastructure/SupabaseAdapters/ClientDesign.md) - Guidelines for designing Supabase clients
- [Adapter Pattern](Infrastructure/SupabaseAdapters/AdapterPattern.md) - Guidelines for implementing Supabase adapters

### Feature Architecture

- [Modular Features](ModularFeatures/ModularFeatures.md) - Modular feature architecture
- [Feature Composition](ModularFeatures/FeatureComposition.md) - Feature composition patterns

### Performance

- [Optimization](Performance/Optimization.md) - Performance optimization techniques

## Core Principles

The production application follows these core principles:

1. **UI/UX Consistency with Mock Application** - All UI and UX should match the mock application implementation
2. **Unidirectional Data Flow** - Data flows in one direction for predictable state management
3. **Composition** - Complex features are composed from simpler components
4. **Testability** - All components are designed to be easily testable
5. **Type Safety** - Strong typing throughout the codebase
6. **Concurrency Safety** - Safe handling of asynchronous operations
7. **Infrastructure Agnosticism** - Features are independent of specific backend technologies
8. **Modularity** - The application is divided into cohesive modules with clear boundaries
9. **Backend Separation of Concerns** - Cloud functions in Supabase, authentication and data storage in Firebase

## Testing Guidelines

Testing is a critical part of the production application development process:

1. **Unit Testing** - Test individual reducers and effects
2. **Integration Testing** - Test feature composition
3. **UI Testing** - Test UI interactions
4. **Snapshot Testing** - Test UI appearance
5. **Performance Testing** - Test performance characteristics

## UI and UX Implementation

When implementing UI and UX in the production application:

1. **Reference the Mock Application** - Always refer to the mock application implementation for UI/UX details
2. **Maintain Visual Consistency** - Ensure that the production application looks identical to the mock application
3. **Preserve Interaction Patterns** - Implement the same interaction patterns as the mock application
4. **Adapt for TCA** - Translate MVVM patterns from the mock application to TCA patterns
5. **Verify UI/UX Parity** - Regularly compare the production application with the mock application to ensure consistency

## Backend Integration

The LifeSignal production application follows these backend integration guidelines:

1. **Cloud Functions in Supabase** - All cloud functions should be implemented in our Supabase backend
2. **Authentication in Firebase** - User authentication should be handled by Firebase Authentication
3. **Data Storage in Firebase** - Application data should be stored in Firebase (Firestore/Realtime Database)
4. **Client Abstraction** - Backend services should be accessed through client interfaces that abstract the implementation details
5. **Adapter Pattern** - Use adapters to convert between backend-specific and domain models
6. **Infrastructure Agnosticism** - Features should not depend directly on Firebase or Supabase APIs
7. **Streaming Data** - Use AsyncStream to wrap Firebase listeners for type safety and testability

## Related Documentation

- [Architecture Overview](../../Specification/ArchitectureOverview.md) - Overview of the LifeSignal iOS architecture
- [Project Structure](../../Specification/ProjectStructure.md) - Structure of the LifeSignal iOS project
- [Mock to Production Migration](../../Specification/MockToProductionMigration.md) - Guide for migrating from mock to production
- [UI Guidelines](../../Specification/UI/UIGuidelines.md) - Comprehensive UI guidelines
- [Mock Application](../../../../iOSMockApplication/MockApplication) - Source of truth for UI/UX design
