# Mock Application Guidelines

**Navigation:** [Back to iOS Guidelines](../README.md) | [Production Guidelines](../Production/README.md)

---

## Overview

This directory contains guidelines for developing the LifeSignal mock application. The mock application serves as a sandbox for UI development and iteration, allowing designers and developers to iterate on UI designs without affecting the production codebase.

> **Important:** The mock application is the source of truth for UI and UX design in the LifeSignal project. All UI and UX implemented in the production application should be derived from the mock application. This ensures consistency across the application and allows for rapid iteration of designs.

## Guidelines

- [MVVM Architecture](MVVMArchitecture.md) - Comprehensive guidelines for implementing MVVM in the mock application

## Core Principles

The mock application follows these core principles:

1. **Strict MVVM Architecture** - Each view has its own dedicated view model
2. **Self-Contained Features** - No shared state or dependencies between features
3. **Mock Data Only** - No real data or networking
4. **UI-Focused Development** - Focus on UI implementation and iteration
5. **No Testing** - Testing is done in the production application only
6. **Comprehensive Previews** - All views include previews for both light and dark mode

## Purpose

The mock application is designed to:

1. **Serve as the source of truth for UI and UX design** in the LifeSignal project
2. Allow rapid UI iteration without affecting production code
3. Provide a sandbox for experimenting with UI designs
4. Enable designers and developers to collaborate on UI implementation
5. Serve as a reference for UI patterns and components
6. Facilitate UI reviews and feedback
7. Provide a visual reference for production application implementation

## Non-Goals

The mock application is **not** designed to:

1. Test business logic or complex interactions
2. Implement real data flows or networking
3. Serve as a production-ready application
4. Demonstrate architectural best practices beyond UI implementation

## Related Documentation

- [Mock to Production Migration](../../Specification/MockToProductionMigration.md) - Guide for migrating from mock to production
- [UI Guidelines](../../Specification/UI/UIGuidelines.md) - Comprehensive UI guidelines
- [Project Structure](../../Specification/ProjectStructure.md) - Overall project structure
