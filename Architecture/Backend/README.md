# LifeSignal Backend Architecture

**Navigation:** [Back to Main Architecture](../README.md) | [General Architecture](../General/README.md) | [iOS Architecture](../iOS/README.md)

---

> **Note:** As this is an MVP, the backend architecture and organization may evolve as the project matures.

## Overview

The LifeSignal backend is built using Firebase Cloud Functions with TypeScript, following a vertical slice architecture. This design enables us to:

1. Organize code by feature rather than by technical layer
2. Build functions that are independent and focused on specific business operations
3. Test functions in isolation with minimal mocking
4. Maintain type safety throughout the codebase
5. Ensure a clean separation between business logic and infrastructure concerns

## Backend Documentation

This directory contains detailed documentation about different aspects of the LifeSignal backend architecture:

- [Core Principles](CorePrinciples.md) - Fundamental backend architectural principles
- [Function Architecture](FunctionArchitecture.md) - Cloud function design and implementation
- [Data Model](DataModel.md) - Firestore data model and schema
- [Security Rules](SecurityRules.md) - Firestore and Storage security rules
- [Testing Strategy](TestingStrategy.md) - Backend testing approach and patterns
- [Deployment](Deployment.md) - Deployment process and environments

## Project Structure

```
functions/
├── src/
│   ├── functions/
│   │   ├── data_management/
│   │   │   ├── addContactRelation.ts
│   │   │   ├── addContactRelation.test.ts
│   │   │   ├── updateContactRoles.ts
│   │   │   ├── updateContactRoles.test.ts
│   │   │   ├── deleteContactRelation.ts
│   │   │   ├── deleteContactRelation.test.ts
│   │   │   ├── respondToPing.ts
│   │   │   ├── respondToPing.test.ts
│   │   │   ├── respondToAllPings.ts
│   │   │   ├── respondToAllPings.test.ts
│   │   │   ├── pingDependent.ts
│   │   │   ├── pingDependent.test.ts
│   │   │   ├── clearPing.ts
│   │   │   └── clearPing.test.ts
│   │   └── notifications/
│   │       ├── sendCheckInReminders.ts
│   │       └── sendCheckInReminders.test.ts
│   ├── models/
│   │   └── interfaces.ts
│   ├── utils/
│   │   ├── handleNotifications.ts
│   │   └── handleNotifications.test.ts
│   └── index.ts
│
├── test/
│   ├── utils/
│   │   ├── test-helpers.ts
│   │   └── mock-data.ts
│   ├── setup.ts
│   └── README.md
│
└── package.json
```

## Function Categories

The LifeSignal Firebase Functions are organized into the following categories:

### Data Management

- **addContactRelation**: Creates a bidirectional contact relationship between two users using a QR code
- **updateContactRoles**: Updates the roles of an existing contact relationship
- **deleteContactRelation**: Removes a bidirectional contact relationship between two users
- **respondToPing**: Responds to a ping from a contact
- **respondToAllPings**: Responds to all pending pings from contacts
- **pingDependent**: Sends a ping to a dependent contact
- **clearPing**: Clears a ping sent to a dependent contact

### Notifications

- **sendCheckInReminders**: Scheduled function that runs every 15 minutes to send check-in reminders and notifications to users and their responders

## Integration with iOS App

The iOS app interacts with the backend through:

1. **Firebase Authentication** - For user authentication and session management
2. **Firestore** - For real-time data storage and synchronization
3. **Cloud Functions** - For server-side business logic
4. **Firebase Cloud Messaging** - For push notifications

The backend follows the same domain model as the iOS app, ensuring consistency across the entire system.

## Conclusion

This backend architecture provides a solid foundation for building a scalable, maintainable, and testable backend. By using Firebase services and following a vertical slice architecture, we can ensure that our backend is flexible and can adapt to changing requirements.

> **Important:** This architecture document represents the current MVP state of the project. The folder structure, file organization, and specific implementation details are expected to evolve as the project matures. We will continuously refine this architecture based on real-world usage patterns and feedback.
