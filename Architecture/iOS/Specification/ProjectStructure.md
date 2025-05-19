# LifeSignal iOS Project Structure

**Navigation:** [Back to Application Specification](README.md) | [Module Graph](ModuleGraph.md) | [Feature List](FeatureList.md) | [Dependency Graph](DependencyGraph.md) | [User Experience](UserExperience.md)

---

## Directory Structure

The LifeSignal iOS application follows a structured organization that reflects our architectural principles:

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
├── Features/ (Feature modules using modular features architecture)
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

## File Naming Conventions

### Feature Files

Each feature should have the following files:

- **[FeatureName]Feature.swift** - TCA reducer with state, actions, and reducer logic
- **[FeatureName]View.swift** - SwiftUI view for the feature
- **[FeatureName]Models.swift** - Feature-specific models (if needed)
- **[FeatureName]Views/** - Directory for feature-specific subviews (if needed)

Example:
```
Features/
  ├── Auth/
  │   ├── AuthFeature.swift
  │   ├── AuthView.swift
  │   ├── AuthModels.swift
  │   └── AuthViews/
  │       ├── PhoneEntryView.swift
  │       └── VerificationView.swift
```

### Domain Models

Domain models should be named according to their business purpose:

- **[ModelName].swift** - Domain model

Example:
```
Core/Domain/Models/
  ├── User.swift
  ├── Contact.swift
  ├── CheckIn.swift
  └── Alert.swift
```

### Infrastructure Files

Infrastructure files should be named according to their purpose:

- **[ClientName]Client.swift** - Client interface
- **[ClientName]Adapter.swift** - Adapter implementation
- **[ModelName]DTO.swift** - Data transfer object
- **[ModelName]Mapping.swift** - Mapping between domain model and DTO

Example:
```
Core/Infrastructure/Clients/
  ├── AuthClient.swift
  ├── StorageClient.swift
  └── UserClient.swift

Infrastructure/Firebase/Adapters/
  ├── FirebaseAuthAdapter.swift
  ├── FirebaseStorageAdapter.swift
  └── FirebaseUserAdapter.swift
```

## Module Organization

The LifeSignal iOS application is organized into the following modules:

### App Module

The App module is the entry point for the application and composes all other features:

- **LifeSignalApp.swift** - App entry point with AppDelegate
- **AppFeature.swift** - Root feature that composes all other features
- **MainTabView.swift** - Tab-based navigation

### Core Module

The Core module contains shared functionality used across the application:

- **Domain Models** - Core business entities
- **Infrastructure Interfaces** - Infrastructure-agnostic interfaces
- **Helper Utilities** - Shared utilities

### Feature Modules

Each feature is organized as a modular feature with all necessary components:

- **State** - Feature-specific state
- **Actions** - Feature-specific actions
- **Reducer** - Feature-specific reducer
- **Views** - Feature-specific views
- **Models** - Feature-specific models

### Infrastructure Module

The Infrastructure module contains backend-specific implementations:

- **Adapters** - Backend-specific adapters
- **Clients** - Backend-specific clients

## Testing Structure

Tests follow the same structure as the application code:

```
Tests/
├── Core/
│   ├── Domain/
│   │   └── Models/
│   │       ├── UserTests.swift
│   │       └── ContactTests.swift
│   │
│   ├── Infrastructure/
│   │   ├── Clients/
│   │   │   ├── StorageClientTests.swift
│   │   │   └── UserClientTests.swift
│   │   │
│   │   ├── DTOs/
│   │   │   └── DocumentDataTests.swift
│   │   │
│   │   └── Mapping/
│   │       └── UserMappingTests.swift
│   │
│   └── HelperUtilities/
│       └── TimeFormatterTests.swift
│
├── Features/
│   ├── Auth/
│   │   └── AuthFeatureTests.swift
│   │
│   ├── Profile/
│   │   └── ProfileFeatureTests.swift
│   │
│   └── Contacts/
│       └── ContactsFeatureTests.swift
│
└── Infrastructure/
    └── Firebase/
        ├── Adapters/
        │   └── FirebaseStorageAdapterTests.swift
        │
        └── Clients/
            └── FirebaseUserClientTests.swift
```
