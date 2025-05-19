# iOS Architecture Guidelines

**Navigation:** [Back to iOS Architecture](../README.md) | [Application Specification](../Specification/README.md)

---

## Overview

This directory contains guidelines for developing the LifeSignal iOS application. These guidelines are divided into two main categories:

1. **[Production Guidelines](Production/README.md)** - Guidelines for the production application using The Composable Architecture (TCA)
2. **[Mock Guidelines](Mock/README.md)** - Guidelines for the mock application using MVVM

## Production Guidelines

The production guidelines cover:

- [TCA Overview](Production/TCA/Overview.md) - Overview of TCA implementation
- [State Management](Production/TCA/StateManagement.md) - State management in TCA
- [Action Design](Production/TCA/ActionDesign.md) - Action design in TCA
- [Effect Management](Production/TCA/EffectManagement.md) - Effect management in TCA
- [Dependency Injection](Production/TCA/DependencyInjection.md) - Dependency injection in TCA
- [Navigation](Production/TCA/Navigation.md) - Navigation patterns in TCA
- [Testing](Production/TCA/Testing.md) - Testing in TCA
- [Modern TCA Rules](Production/TCA/ModernTCARules.md) - Modern TCA rules and best practices

## Mock Guidelines

The mock guidelines cover:

- [MVVM Architecture](Mock/MVVMArchitecture.md) - Comprehensive guidelines for implementing MVVM in the mock application

## Purpose

These guidelines serve as a reference for developers working on the LifeSignal iOS application. They provide a consistent approach to architecture, state management, and UI implementation across the codebase.

## Implementation Approach

The LifeSignal iOS application follows a dual-track approach:

1. **Mock Application** - A simplified version of the app using MVVM for UI development and iteration
2. **Production Application** - The full application using TCA for production-ready features

> **Important:** The mock application is the source of truth for UI and UX design. All UI and UX implemented in the production application must be derived from the mock application. The production application implements the same UI/UX using TCA instead of MVVM.

This approach allows for:

- Rapid UI iteration without affecting production code
- Clear separation of concerns between UI and business logic
- Comprehensive testing of business logic in the production codebase
- Consistent UI/UX across the application
- Gradual migration from mock to production

## Related Documentation

- [Architecture Overview](../Specification/ArchitectureOverview.md) - Overview of the LifeSignal iOS architecture
- [Project Structure](../Specification/ProjectStructure.md) - Structure of the LifeSignal iOS project
- [Mock to Production Migration](../Specification/MockToProductionMigration.md) - Guide for migrating from mock to production
- [UI Guidelines](../Specification/UI/UIGuidelines.md) - Comprehensive UI guidelines
