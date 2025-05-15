# LifeSignal iOS Application Specification

**Navigation:** [Back to iOS Architecture](../README.md) | [Project Structure](ProjectStructure.md) | [Module Graph](ModuleGraph.md) | [Feature List](FeatureList.md) | [Dependency Graph](DependencyGraph.md) | [User Experience](UserExperience.md) | [Mock Application](MockApplication/README.md)

---

## Overview

This section contains the specific implementation details for the LifeSignal iOS application. While the [Guidelines](../Guidelines) section covers general architectural principles, this section focuses on how those principles are applied to the LifeSignal application.

## Application Architecture

LifeSignal iOS is built using The Composable Architecture (TCA) with a layered approach:

```
Feature Layer → Domain-Specific Clients → Core Infrastructure Clients → Adapters → Backend
(UserFeature)    (UserClient)            (StorageClient)              (StorageAdapter)  (Firebase)
```

### Key Components

1. **App Layer** - Root components that compose all features
2. **Feature Layer** - Individual features using vertical slice architecture
3. **Domain Layer** - Core domain models and business logic
4. **Infrastructure Layer** - Infrastructure-agnostic interfaces and clients
5. **Adapter Layer** - Backend-specific implementations

## Application Documentation

This directory contains detailed documentation about different aspects of the LifeSignal iOS application:

- [Project Structure](ProjectStructure.md) - Detailed project structure and organization
- [Module Graph](ModuleGraph.md) - Module dependency graph
- [Feature List](FeatureList.md) - List of all features and their responsibilities
- [Dependency Graph](DependencyGraph.md) - Dependency injection graph
- [User Experience](UserExperience.md) - User flows and interactions
- [Examples](Examples) - Example implementations of features and views
- [Mock Application](MockApplication/README.md) - Mock version of the app for UI iteration

## Implementation Guidelines

When implementing features for the LifeSignal iOS application, follow these guidelines:

1. **Follow Modern TCA Rules** - Adhere to the [Modern TCA Rules](../Guidelines/TCA/ModernTCARules.md)
2. **Use Vertical Slice Architecture** - Organize code by feature rather than by technical layer
3. **Maintain Infrastructure Agnosticism** - Keep features independent of specific backend technologies
4. **Ensure Type Safety** - Use strong typing throughout the codebase
5. **Ensure Concurrency Safety** - Handle asynchronous operations safely and efficiently
6. **Write Tests** - Write comprehensive tests for all features
7. **Document Code** - Document the purpose of each feature and component

## Mock Application

The [Mock Application](MockApplication/README.md) is a simplified version of the LifeSignal iOS application that uses vanilla Swift (not TCA) with mock data instead of real business logic. It serves as a sandbox for UI development and iteration, allowing designers and developers to test UI components in isolation and iterate on UI designs without affecting the production codebase.

## Getting Started

To get started with the LifeSignal iOS application:

1. Review the [Project Structure](ProjectStructure.md) to understand the organization
2. Explore the [Feature List](FeatureList.md) to understand the application's capabilities
3. Study the [Examples](Examples) to see how features are implemented
4. Follow the [Modern TCA Rules](../Guidelines/TCA/ModernTCARules.md) when implementing new features
5. Use the [Mock Application](MockApplication/README.md) for UI iteration
