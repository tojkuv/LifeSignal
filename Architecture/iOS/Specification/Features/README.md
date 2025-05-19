# LifeSignal iOS Features

**Navigation:** [Back to Application Specification](../README.md) | [Core Features](CoreFeatures.md) | [Contact Features](ContactFeatures.md) | [Safety Features](SafetyFeatures.md) | [Utility Features](UtilityFeatures.md) | [TCA Overview](../../Guidelines/Production/TCA/Overview.md)

---

## Overview

This directory contains documentation for the features of the LifeSignal iOS application. Features are the building blocks of the application, each responsible for a specific piece of functionality. They are implemented using The Composable Architecture (TCA) and follow a consistent pattern.

## Feature Structure

Each feature consists of the following components:

1. **State**: Defines the feature's state data
2. **Action**: Defines the events that can occur in the feature
3. **Reducer**: Defines how the state changes in response to actions
4. **View**: Displays the feature's UI and handles user interaction
5. **Dependencies**: External services and resources used by the feature

## Feature Categories

The LifeSignal iOS application is organized into the following feature categories:

### [Core Features](CoreFeatures.md)

Core features provide the foundation for the application:

- **AppFeature**: Root feature that composes all other features
- **AuthFeature**: Handles user authentication and session management
- **UserFeature**: Manages user profile information

### [Contact Features](ContactFeatures.md)

Contact features manage user relationships:

- **ContactsFeature**: Manages the user's contacts
- **RespondersFeature**: Manages the user's responders
- **DependentsFeature**: Manages the user's dependents
- **ContactDetailsFeature**: Displays and manages contact details

### [Safety Features](SafetyFeatures.md)

Safety features provide the core safety functionality:

- **CheckInFeature**: Manages the user's check-in functionality
- **AlertFeature**: Manages the user's alert functionality
- **PingFeature**: Manages ping functionality between users

### [Utility Features](UtilityFeatures.md)

Utility features provide supporting functionality:

- **NotificationFeature**: Manages notifications and reminders
- **QRCodeFeature**: Manages QR code generation and scanning
- **SettingsFeature**: Manages application settings

## Feature Composition

Features are composed in a hierarchical structure:

```
AppFeature
├── AuthFeature
├── MainTabFeature
│   ├── HomeFeature
│   │   ├── CheckInFeature
│   │   └── AlertFeature
│   ├── ContactsFeature
│   │   ├── RespondersFeature
│   │   └── DependentsFeature
│   ├── NotificationFeature
│   └── ProfileFeature
│       └── QRCodeFeature
└── PingFeature (can be accessed from multiple places)
```

This composition allows for a modular application structure where features can be developed, tested, and maintained independently.

## Feature Implementation

Each feature is implemented following the TCA pattern. For detailed information on TCA implementation, see the [TCA Overview](../../Guidelines/Production/TCA/Overview.md) guidelines.

## Feature Dependencies

Each feature depends on specific clients that provide the necessary functionality. These clients are injected using TCA's dependency injection system.

### Client Dependencies

- **AuthClient**: Authentication operations
- **UserClient**: User profile operations
- **ContactClient**: Contact relationship operations
- **CheckInClient**: Check-in operations
- **AlertClient**: Alert operations
- **PingClient**: Ping operations
- **NotificationClient**: Notification operations
- **StorageClient**: Data storage operations
- **ImageClient**: Image handling operations
- **QRCodeClient**: QR code operations

## Feature Documentation

Each feature category has its own documentation file that provides detailed information about the features in that category:

- [Core Features](CoreFeatures.md): AppFeature, AuthFeature, UserFeature
  - [Auth Feature](Auth/README.md): Authentication feature
  - [Profile Feature](Profile/README.md): User profile feature
- [Contact Features](ContactFeatures.md): ContactsFeature, RespondersFeature, DependentsFeature, ContactDetailsFeature
  - [Responders Feature](Responders/README.md): Responders feature
  - [Dependents Feature](Dependents/README.md): Dependents feature
- [Safety Features](SafetyFeatures.md): CheckInFeature, AlertFeature, PingFeature
  - [CheckIn Feature](CheckIn/README.md): Check-in feature
  - [Alert Feature](Alert/README.md): Alert feature
  - [Ping Feature](Ping/README.md): Ping feature
- [Utility Features](UtilityFeatures.md): NotificationFeature, QRCodeFeature, SettingsFeature
  - [Notification Feature](Notification/README.md): Notification feature
  - [QRCode Feature](QRCode/README.md): QR code feature

## Related Documentation

- [TCA Overview](../../Guidelines/Production/TCA/Overview.md) - Overview of The Composable Architecture
- [Domain Models](../Domain/README.md) - Documentation for domain models used by features
- [Infrastructure Layer](../Infrastructure/README.md) - Documentation for the infrastructure layer that features interact with
- [Examples](../Examples/README.md) - Example implementations of features
- [Mock to Production Migration](../MockToProductionMigration.md) - Guide for migrating features from mock to production
