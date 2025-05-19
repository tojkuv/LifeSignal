# LifeSignal iOS Domain Models

**Navigation:** [Back to Application Specification](../README.md) | [Models](Models.md) | [Infrastructure](../Infrastructure/README.md)

---

## Overview

This directory contains documentation for the domain models used in the LifeSignal iOS application. Domain models represent the core business entities and concepts in the application, independent of any infrastructure or UI concerns.

Domain models are the foundation of the application's business logic and are used by features to implement user-facing functionality. They are designed to be:

- **Pure**: Free from side effects and dependencies on external systems
- **Immutable**: Changed only through well-defined operations
- **Serializable**: Can be persisted and restored
- **Testable**: Easy to create and verify in tests

## Domain Model Types

The LifeSignal application uses the following core domain models:

1. **User** - Represents a user of the application
2. **Contact** - Represents a relationship between users
3. **CheckIn** - Represents a check-in record
4. **Alert** - Represents an alert triggered by a user
5. **Ping** - Represents a ping between users
6. **Notification** - Represents a notification to a user
7. **QRCode** - Represents a QR code for contact sharing

For detailed information about each domain model, see the [Models](Models.md) document.

## Domain Model Relationships

Domain models have relationships with each other that reflect the business rules of the application:

- A **User** has many **Contacts**
- A **Contact** has one **User** as the owner and one **User** as the contact
- A **User** has many **CheckIns**
- A **User** has many **Alerts**
- A **User** has many **Pings** (sent and received)
- A **User** has many **Notifications**
- A **User** has one **QRCode**

These relationships are implemented through references (IDs) rather than direct object references to maintain separation of concerns and enable serialization.

## Implementation Guidelines

When implementing domain models:

1. Use Swift structs with value semantics
2. Make properties immutable where possible
3. Implement validation logic within the model
4. Use enums for representing states and types
5. Keep models focused on business concepts, not technical details
6. Avoid dependencies on infrastructure or UI concerns
7. Implement Equatable, Hashable, and Identifiable where appropriate
8. Use Codable for serialization

## Migration from Mock Implementation

The domain models are being migrated from the mock implementation to a production implementation using The Composable Architecture (TCA). This migration involves:

1. Refining model properties and relationships
2. Adding validation logic
3. Implementing Codable for persistence
4. Creating DTOs for backend integration
5. Implementing mapping between domain models and DTOs

For more information on the migration process, see the [Mock to Production Migration Guide](../MockToProductionMigration.md).

## Related Documentation

- [Infrastructure Layer](../Infrastructure/README.md) - Documentation for the infrastructure layer that interacts with domain models
- [Client Interfaces](../Infrastructure/ClientInterfaces.md) - Specifications for client interfaces that operate on domain models
- [Data Persistence and Streaming](../Infrastructure/DataPersistenceStreaming.md) - Strategy for persisting and streaming domain models
