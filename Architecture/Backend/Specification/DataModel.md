# LifeSignal Backend Data Model

**Navigation:** [Back to Backend Specification](README.md) | [Architecture Overview](ArchitectureOverview.md) | [API Endpoints](APIEndpoints.md)

---

## Overview

This document provides detailed specifications for the LifeSignal backend data model. The data model is implemented using Firestore, a NoSQL document database provided by Firebase.

## Collections and Documents

### Users Collection

The `users` collection is the primary collection in the database. Each document in this collection represents a user of the LifeSignal application.

#### User Document

```typescript
interface UserProfile {
  name: string;                                  // User's full name
  phone: string;                                 // User's phone number in E.164 format
  note: string;                                  // User's emergency profile description/note
  checkInInterval: number;                       // User's check-in interval in seconds
  lastCheckedIn: FirebaseFirestore.Timestamp;    // Timestamp of user's last check-in
  expirationTimestamp: FirebaseFirestore.Timestamp; // Timestamp when the check-in expires
  fcmToken?: string;                             // Firebase Cloud Messaging token for push notifications
  notify30MinBefore?: boolean;                   // Whether to notify 30 minutes before check-in expiration
  notify2HoursBefore?: boolean;                  // Whether to notify 2 hours before check-in expiration
}
```

### Contacts Subcollection

Each user document has a `contacts` subcollection. Each document in this subcollection represents a contact relationship with another user.

#### Contact Document

```typescript
interface ContactReference {
  isResponder: boolean;                          // Whether this contact is a responder for the user
  isDependent: boolean;                          // Whether this contact is a dependent of the user
  referencePath: string;                         // Path to the contact's user document (format: "users/userId")
  sendPings?: boolean;                           // Whether to send pings to this contact
  receivePings?: boolean;                        // Whether to receive pings from this contact
  notifyOnCheckIn?: boolean;                     // Whether to notify this contact on check-in
  notifyOnExpiry?: boolean;                      // Whether to notify this contact on check-in expiry
  nickname?: string;                             // Optional nickname for this contact
  notes?: string;                                // Optional notes about this contact
  lastUpdated?: FirebaseFirestore.Timestamp;     // When this contact was last updated
  manualAlertActive?: boolean;                   // Whether this contact has an active manual alert
  manualAlertTimestamp?: FirebaseFirestore.Timestamp; // When the manual alert was activated
  incomingPingTimestamp?: FirebaseFirestore.Timestamp | null; // When an incoming ping was received
  outgoingPingTimestamp?: FirebaseFirestore.Timestamp | null; // When an outgoing ping was sent
}
```

## Relationships

The LifeSignal data model uses bidirectional relationships between users. When a contact relationship is established, two documents are created:

1. A document in User A's `contacts` subcollection referencing User B
2. A document in User B's `contacts` subcollection referencing User A

This bidirectional relationship ensures that both users have access to the relationship data and can interact with each other through the application.

## Contact Roles

Contact relationships in LifeSignal have two possible roles:

1. **Responder**: A contact who can respond to alerts and check-in expirations
2. **Dependent**: A contact who the user is responsible for monitoring

These roles are not mutually exclusive. A contact can be both a responder and a dependent, creating a mutual safety relationship.

## Ping System

The ping system allows users to check on their dependents:

1. **Outgoing Ping**: When a user pings a dependent, the `outgoingPingTimestamp` field is set in the user's contact document
2. **Incoming Ping**: When a user receives a ping, the `incomingPingTimestamp` field is set in the user's contact document
3. **Ping Response**: When a user responds to a ping, the `incomingPingTimestamp` field is cleared

## Alert System

The alert system allows users to notify their responders of an emergency:

1. **Manual Alert**: When a user activates a manual alert, the `manualAlertActive` field is set to `true` and the `manualAlertTimestamp` field is set
2. **Check-in Expiry Alert**: When a user's check-in expires, an automatic alert is sent to their responders

## Data Validation

The LifeSignal backend enforces data validation through:

1. **TypeScript Interfaces**: Ensuring type safety in the application code
2. **Firebase Security Rules**: Enforcing data structure and access control at the database level
3. **Function Validation**: Validating input data in cloud functions before processing

## Data Migration

As the application evolves, data migration strategies will be implemented to handle schema changes:

1. **Versioning**: Adding version fields to documents to track schema versions
2. **Migration Functions**: Implementing functions to migrate data from one schema version to another
3. **Backward Compatibility**: Ensuring backward compatibility with older schema versions during migration periods

For detailed implementation guidelines, see the [Backend Guidelines](../Guidelines/README.md) section.
