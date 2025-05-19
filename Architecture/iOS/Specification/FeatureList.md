# LifeSignal iOS Feature List

**Navigation:** [Back to Application Specification](README.md) | [Project Structure](ProjectStructure.md) | [Module Graph](ModuleGraph.md) | [Dependency Graph](DependencyGraph.md) | [User Experience](UserExperience.md)

---

## Core Features

This document provides a comprehensive list of all features in the LifeSignal iOS application, along with their responsibilities and key components.

### App Features

#### AppFeature

**Responsibility:** Root feature that composes all other features and manages global application state.

**Key Components:**
- Global authentication state
- Global user session
- Feature composition
- Deep link handling
- Push notification handling

**Dependencies:**
- AuthClient
- UserClient
- NotificationClient

---

### Authentication Features

#### AuthFeature

**Responsibility:** Handles user authentication and session management.

**Key Components:**
- Phone number entry
- Verification code entry
- Sign out
- Session management

**Dependencies:**
- AuthClient

---

### User Features

#### ProfileFeature

**Responsibility:** Manages user profile information and settings.

**Key Components:**
- Profile information display and editing
- Emergency note management
- Profile picture management
- Account settings
- Notification preferences
- Check-in interval settings

**Dependencies:**
- UserClient
- StorageClient
- ImageClient

#### QRCodeFeature

**Responsibility:** Generates and manages QR codes for user identification.

**Key Components:**
- QR code generation
- QR code display
- QR code sharing

**Dependencies:**
- UserClient
- QRCodeClient

---

### Contact Features

#### ContactsFeature

**Responsibility:** Manages user contacts and relationships.

**Key Components:**
- Contact list display
- Contact addition via QR code
- Contact role management (responder, dependent)
- Contact removal
- Contact detail display

**Dependencies:**
- ContactClient
- QRCodeClient
- UserClient

#### RespondersFeature

**Responsibility:** Manages responder-specific functionality.

**Key Components:**
- Responder list display
- Responder status monitoring
- Ping response management

**Dependencies:**
- ContactClient
- PingClient
- UserClient

#### DependentsFeature

**Responsibility:** Manages dependent-specific functionality.

**Key Components:**
- Dependent list display
- Dependent status monitoring
- Dependent pinging

**Dependencies:**
- ContactClient
- PingClient
- UserClient

---

### Safety Features

#### CheckInFeature

**Responsibility:** Manages user check-in functionality.

**Key Components:**
- Check-in button
- Check-in status display
- Check-in history
- Check-in interval management
- Check-in reminder management

**Dependencies:**
- CheckInClient
- UserClient
- NotificationClient

#### AlertFeature

**Responsibility:** Manages alert functionality.

**Key Components:**
- Alert triggering
- Alert status display
- Alert history
- Alert notification management

**Dependencies:**
- AlertClient
- UserClient
- NotificationClient

#### PingFeature

**Responsibility:** Manages ping functionality between users.

**Key Components:**
- Ping sending
- Ping receiving
- Ping response
- Ping history

**Dependencies:**
- PingClient
- UserClient
- ContactClient

---

### Notification Features

#### NotificationFeature

**Responsibility:** Manages notifications and reminders.

**Key Components:**
- Notification list display
- Notification management
- Notification preferences
- Notification history

**Dependencies:**
- NotificationClient
- UserClient

---

## Feature Dependencies

Each feature depends on specific clients that provide the necessary functionality. These clients are injected using TCA's dependency injection system.

### Client Dependencies

- **AuthClient** - Authentication operations
- **UserClient** - User profile operations
- **ContactClient** - Contact relationship operations
- **CheckInClient** - Check-in operations
- **AlertClient** - Alert operations
- **PingClient** - Ping operations
- **NotificationClient** - Notification operations
- **StorageClient** - Data storage operations
- **ImageClient** - Image handling operations
- **QRCodeClient** - QR code operations

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
