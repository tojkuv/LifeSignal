# LifeSignal iOS Domain Models

**Navigation:** [Back to Domain](README.md) | [Back to Application Specification](../README.md)

---

## Overview

This document provides detailed specifications for the domain models used in the LifeSignal iOS application. Each model is described with its properties, methods, and relationships to other models.

## User Model

The User model represents a user of the LifeSignal application.

### Properties

```swift
struct User: Equatable, Identifiable, Codable, Sendable {
    let id: UUID
    var firstName: String
    var lastName: String
    var phoneNumber: String
    var profileImageURL: URL?
    var emergencyNote: String
    var checkInInterval: TimeInterval
    var reminderInterval: TimeInterval
    var lastCheckInTime: Date?
    var status: UserStatus
    var qrCodeID: UUID
}
```

### User Status

```swift
enum UserStatus: String, Equatable, Codable, Sendable {
    case active
    case nonResponsive
    case alertActive
}
```

### Responsibilities

- Stores user profile information
- Tracks user status (active, non-responsive, alert active)
- Manages check-in configuration (intervals, last check-in)
- Provides identity for contact relationships

## Contact Model

The Contact model represents a relationship between users.

### Properties

```swift
struct Contact: Equatable, Identifiable, Codable, Sendable {
    let id: UUID
    let userID: UUID
    let contactID: UUID
    var firstName: String
    var lastName: String
    var phoneNumber: String
    var profileImageURL: URL?
    var isResponder: Bool
    var isDependent: Bool
    var status: ContactStatus
    var lastCheckInTime: Date?
    var dateAdded: Date
}
```

### Contact Status

```swift
enum ContactStatus: String, Equatable, Codable, Sendable {
    case active
    case nonResponsive
    case alertActive
    case pendingPing
}
```

### Responsibilities

- Stores contact relationship information
- Tracks contact roles (responder, dependent)
- Tracks contact status (active, non-responsive, alert active, pending ping)
- Provides bidirectional relationship between users

## CheckIn Model

The CheckIn model represents a check-in record.

### Properties

```swift
struct CheckInRecord: Equatable, Identifiable, Codable, Sendable {
    let id: UUID
    let userID: UUID
    let timestamp: Date
    let source: CheckInSource
}
```

### Check-In Source

```swift
enum CheckInSource: String, Equatable, Codable, Sendable {
    case manual
    case automatic
    case responderInitiated
}
```

### Responsibilities

- Records check-in events
- Tracks check-in source (manual, automatic, responder-initiated)
- Provides history of user check-ins

## Alert Model

The Alert model represents an alert triggered by a user.

### Properties

```swift
struct Alert: Equatable, Identifiable, Codable, Sendable {
    let id: UUID
    let userID: UUID
    let timestamp: Date
    let status: AlertStatus
    var resolvedTimestamp: Date?
    var resolvedBy: UUID?
}
```

### Alert Status

```swift
enum AlertStatus: String, Equatable, Codable, Sendable {
    case active
    case resolved
}
```

### Responsibilities

- Records alert events
- Tracks alert status (active, resolved)
- Provides history of user alerts

## Ping Model

The Ping model represents a ping between users.

### Properties

```swift
struct Ping: Equatable, Identifiable, Codable, Sendable {
    let id: UUID
    let senderID: UUID
    let recipientID: UUID
    let timestamp: Date
    var status: PingStatus
    var responseTimestamp: Date?
}
```

### Ping Status

```swift
enum PingStatus: String, Equatable, Codable, Sendable {
    case pending
    case responded
    case expired
}
```

### Responsibilities

- Records ping events between users
- Tracks ping status (pending, responded, expired)
- Provides history of pings

## Notification Model

The Notification model represents a notification to a user.

### Properties

```swift
struct Notification: Equatable, Identifiable, Codable, Sendable {
    let id: UUID
    let userID: UUID
    let timestamp: Date
    let type: NotificationType
    let title: String
    let message: String
    var isRead: Bool
    var relatedUserID: UUID?
    var relatedContactID: UUID?
    var relatedAlertID: UUID?
    var relatedPingID: UUID?
    var relatedCheckInID: UUID?
}
```

### Notification Type

```swift
enum NotificationType: String, Equatable, Codable, Sendable {
    case alert
    case ping
    case checkIn
    case contactAdded
    case contactRemoved
    case roleChanged
    case system
}
```

### Responsibilities

- Records notification events
- Categorizes notifications by type
- Tracks notification read status
- Links notifications to related entities

## QRCode Model

The QRCode model represents a QR code for contact sharing.

### Properties

```swift
struct QRCode: Equatable, Identifiable, Codable, Sendable {
    let id: UUID
    let userID: UUID
    let createdAt: Date
}
```

### Responsibilities

- Provides unique identifier for contact sharing
- Tracks QR code creation time

## Model Relationships

The domain models have the following relationships:

1. **User to Contact**: One-to-many (a user has many contacts)
2. **Contact to User**: Many-to-one (many contacts belong to a user)
3. **User to CheckIn**: One-to-many (a user has many check-ins)
4. **User to Alert**: One-to-many (a user has many alerts)
5. **User to Ping**: One-to-many (a user has many sent and received pings)
6. **User to Notification**: One-to-many (a user has many notifications)
7. **User to QRCode**: One-to-one (a user has one QR code)

## Validation Rules

Domain models implement the following validation rules:

### User Validation

- First name and last name must not be empty
- Phone number must be in a valid format
- Check-in interval must be greater than zero
- Reminder interval must be less than check-in interval

### Contact Validation

- At least one role (responder or dependent) must be true
- First name and last name must not be empty
- Phone number must be in a valid format

### CheckIn Validation

- Timestamp must not be in the future

### Alert Validation

- Timestamp must not be in the future
- If status is resolved, resolvedTimestamp and resolvedBy must be present

### Ping Validation

- Timestamp must not be in the future
- If status is responded, responseTimestamp must be present

### Notification Validation

- Title and message must not be empty
- Related entity IDs must be present for specific notification types

## Migration from Mock Implementation

The domain models are being migrated from the mock implementation to a production implementation using The Composable Architecture (TCA). This migration involves:

1. Refining model properties and relationships
2. Adding validation logic
3. Implementing Codable for persistence
4. Creating DTOs for backend integration
5. Implementing mapping between domain models and DTOs

For more information on the migration process, see the [Mock to Production Migration Guide](../MockToProductionMigration.md).
