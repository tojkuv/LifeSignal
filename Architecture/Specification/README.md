# LifeSignal iOS Application Specification

**Navigation:** [Back to iOS Architecture](../iOS/README_copy.md) | [Project Structure](ProjectStructure.md) | [Architecture Overview](ArchitectureOverview.md) | [Feature List](FeatureList.md) | [Mock to Production Migration](MockToProductionMigration.md) | [UI Guidelines](UI/UIGuidelines.md) | [Domain Models](Domain/README.md) | [Features](Features/README.md) | [Infrastructure](Infrastructure/README.md) | [Mock Application](../../iOSMockApplication/README.md)

---

## Overview

This section contains the specific implementation details for the LifeSignal iOS application. While the [Guidelines](../iOS/Guidelines) section covers general architectural principles, this section focuses on how those principles are applied to the LifeSignal application.

## Application Architecture

LifeSignal iOS is built using The Composable Architecture (TCA) with a layered approach:

```
Feature Layer → Middleware Clients → Adapters → Platform Backend Clients → Backend
(UserFeature)    (UserClient)       (FirebaseUserAdapter)  (FirebaseClient)     (Firebase/Supabase)
```

### Key Components

1. **App Layer** - Root components that compose all features
2. **Feature Layer** - Individual features using modular features architecture
3. **Domain Layer** - Core domain models and business logic
4. **Middleware Layer** - Backend agnostic anti-corruption clients
5. **Adapter Layer** - Platform-specific adapters
6. **Platform Backend Layer** - Platform-specific clients (Firebase, Supabase)

## Application Documentation

This directory contains detailed documentation about different aspects of the LifeSignal iOS application:

### Core Documentation

- [Project Structure](ProjectStructure.md) - Detailed project structure and organization
- [Architecture Overview](ArchitectureOverview.md) - Comprehensive architecture overview
- [Feature List](FeatureList.md) - List of all features and their responsibilities
- [Mock to Production Migration](MockToProductionMigration.md) - Guide for migrating from mock to production implementation
- [Testing Strategy](Testing.md) - Comprehensive testing strategy

### Domain Layer

- [Domain Models](Domain/README.md) - Core domain models and business logic
- [Domain Models Specification](Domain/Models.md) - Detailed specification of domain models

### Feature Layer

- [Features Overview](Features/README.md) - Overview of all features
- [Core Features](Features/CoreFeatures.md) - App, Auth, and User features
- [Contact Features](Features/ContactFeatures.md) - Contacts, Responders, and Dependents features
- [Safety Features](Features/SafetyFeatures.md) - CheckIn, Alert, and Ping features
- [Utility Features](Features/UtilityFeatures.md) - Notification, QRCode, and Settings features

### Infrastructure Layer

- [Infrastructure Overview](Infrastructure/README.md) - Infrastructure layer documentation
- [Client Interfaces](Infrastructure/ClientInterfaces.md) - Client interface specifications
- [Backend Integration](Infrastructure/BackendIntegration.md) - Backend integration specifications
- [Data Persistence and Streaming](Infrastructure/DataPersistenceStreaming.md) - Strategy for data persistence and streaming

### UI Layer

- [UI Guidelines](UI/UIGuidelines.md) - Comprehensive UI guidelines

### Examples

- [Examples](Examples) - Example implementations of features and views

### Mock Application

- [Mock Application](../../iOSMockApplication/README.md) - Mock version of the app for UI iteration

## Implementation Guidelines

When implementing features for the LifeSignal iOS application, follow these guidelines:

1. **Follow Modern TCA Rules** - Adhere to the [Modern TCA Rules](../iOS/Guidelines/Production/TCA/ModernTCARules.md)
2. **Use Modular Features** - Organize code by feature rather than by technical layer
3. **Use Middleware Clients** - Keep features independent of specific backend technologies through backend agnostic anti-corruption clients
4. **Ensure Type Safety** - Use strong typing throughout the codebase
5. **Ensure Concurrency Safety** - Handle asynchronous operations safely and efficiently
6. **Write Tests** - Write comprehensive tests for all features
7. **Document Code** - Document the purpose of each feature and component

## Mock Application

The [Mock Application](../../iOSMockApplication/README.md) is a simplified version of the LifeSignal iOS application that uses vanilla Swift (not TCA) with mock data instead of real business logic. It serves as a sandbox for UI development and iteration, allowing designers and developers to iterate on UI designs without affecting the production codebase.

Important guidelines for the mock application:

1. **No Client Implementations**: The mock application should not contain client implementations. All client interfaces and implementations should be in the TCA production application.
2. **No Testing Code**: Testing should only be done in the TCA production application, not in the mock application. The mock application is for UI development only.
3. **Use Mock Data**: The mock application should use hardcoded mock data instead of real backend services.

## Getting Started

To get started with the LifeSignal iOS application:

1. Review the [Architecture Overview](ArchitectureOverview.md) to understand the overall architecture
2. Explore the [Domain Models](Domain/README.md) to understand the core business entities
3. Study the [Features](Features/README.md) to understand the application's capabilities
4. Review the [Mock to Production Migration](MockToProductionMigration.md) to understand the migration process
5. Explore the [Infrastructure](Infrastructure/ClientInterfaces.md) documentation for backend integration
6. Review the [UI Guidelines](UI/UIGuidelines.md) for UI implementation
7. Study the [Examples](Examples) to see how features are implemented
8. Follow the [Modern TCA Rules](../iOS/Guidelines/Production/TCA/ModernTCARules.md) when implementing new features
9. Use the [Mock Application](../../iOSMockApplication/README.md) for UI iteration
