# LifeSignal iOS Module Graph

**Navigation:** [Back to Application Specification](README.md) | [Project Structure](ProjectStructure.md) | [Feature List](FeatureList.md) | [Dependency Graph](DependencyGraph.md) | [User Experience](UserExperience.md)

---

## Module Dependency Graph

This document provides a visual representation of the module dependencies in the LifeSignal iOS application. The module graph shows how different parts of the application depend on each other.

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                           App Module                                │
│                                                                     │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                         Feature Modules                             │
│                                                                     │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                          Domain Module                              │
│                                                                     │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                      Infrastructure Module                          │
│                                                                     │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│                        Adapter Modules                              │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Module Descriptions

### App Module

The App Module is the entry point for the application and composes all other features.

**Dependencies:**
- Feature Modules
- Domain Module
- Infrastructure Module

**Key Components:**
- LifeSignalApp.swift
- AppFeature.swift
- MainTabView.swift

### Feature Modules

Feature Modules contain the individual features of the application, organized using vertical slice architecture.

**Dependencies:**
- Domain Module
- Infrastructure Module

**Key Components:**
- Auth Feature
- Profile Feature
- Contacts Feature
- Home Feature
- Responders Feature
- Dependents Feature
- CheckIn Feature
- Alert Feature
- Notification Feature
- Ping Feature
- QRCode Feature

### Domain Module

The Domain Module contains the core domain models and business logic.

**Dependencies:**
- None

**Key Components:**
- User.swift
- Contact.swift
- CheckIn.swift
- Alert.swift
- Ping.swift
- Notification.swift

### Infrastructure Module

The Infrastructure Module contains infrastructure-agnostic interfaces and clients.

**Dependencies:**
- Domain Module

**Key Components:**
- AuthClient.swift
- StorageClient.swift
- UserClient.swift
- ContactClient.swift
- CheckInClient.swift
- AlertClient.swift
- PingClient.swift
- NotificationClient.swift
- ImageClient.swift
- QRCodeClient.swift

### Adapter Modules

Adapter Modules contain backend-specific implementations of infrastructure interfaces.

**Dependencies:**
- Infrastructure Module
- Domain Module
- Backend SDKs (Firebase, etc.)

**Key Components:**
- FirebaseAuthAdapter.swift
- FirebaseStorageAdapter.swift
- FirebaseUserAdapter.swift
- FirebaseContactAdapter.swift
- FirebaseCheckInAdapter.swift
- FirebaseAlertAdapter.swift
- FirebasePingAdapter.swift
- FirebaseNotificationAdapter.swift

## Detailed Module Dependencies

### Feature Module Dependencies

```
AuthFeature
└── AuthClient

ProfileFeature
├── UserClient
├── StorageClient
└── ImageClient

ContactsFeature
├── ContactClient
├── QRCodeClient
└── UserClient

RespondersFeature
├── ContactClient
├── PingClient
└── UserClient

DependentsFeature
├── ContactClient
├── PingClient
└── UserClient

CheckInFeature
├── CheckInClient
├── UserClient
└── NotificationClient

AlertFeature
├── AlertClient
├── UserClient
└── NotificationClient

PingFeature
├── PingClient
├── UserClient
└── ContactClient

NotificationFeature
├── NotificationClient
└── UserClient

QRCodeFeature
├── UserClient
└── QRCodeClient
```

### Infrastructure Client Dependencies

```
AuthClient
└── AuthAdapter

StorageClient
└── StorageAdapter

UserClient
├── StorageClient
└── AuthClient

ContactClient
└── StorageClient

CheckInClient
└── StorageClient

AlertClient
└── StorageClient

PingClient
└── StorageClient

NotificationClient
├── StorageClient
└── PushNotificationAdapter

ImageClient
├── StorageClient
└── ImageProcessingAdapter

QRCodeClient
└── QRCodeGenerationAdapter
```

## Module Boundaries

Each module has clear boundaries and responsibilities:

1. **App Module** - Composes features and manages global state
2. **Feature Modules** - Implement specific user-facing features
3. **Domain Module** - Defines core business entities and logic
4. **Infrastructure Module** - Defines infrastructure-agnostic interfaces
5. **Adapter Modules** - Implement infrastructure interfaces for specific backends

These boundaries ensure that:

1. Features depend only on infrastructure interfaces, not implementations
2. Domain models are independent of any infrastructure
3. Infrastructure implementations can be swapped without affecting features
4. Features can be developed and tested independently
