# Data Model

> **Note:** As this is an MVP, the data model and schema may evolve as the project matures.

## Firestore Collections

The LifeSignal backend uses the following Firestore collections:

### Users Collection

Stores user profiles and authentication information.

```
users/{userId}
```

**Fields:**
- `name`: string - User's display name
- `email`: string - User's email address
- `phoneNumber`: string - User's phone number
- `lastCheckedIn`: timestamp - When the user last checked in
- `checkInInterval`: number - Interval in seconds between check-ins
- `checkInExpiration`: timestamp - When the next check-in is due
- `profileImageURL`: string (optional) - URL to the user's profile image
- `isOnboarded`: boolean - Whether the user has completed onboarding
- `fcmTokens`: array - Firebase Cloud Messaging tokens for the user's devices
- `createdAt`: timestamp - When the user was created
- `updatedAt`: timestamp - When the user was last updated

### Contacts Collection

Stores contact relationships between users.

```
contacts/{userId}/userContacts/{contactId}
```

**Fields:**
- `userId`: string - ID of the contact user
- `roles`: array - Roles of the contact (e.g., "responder", "dependent")
- `nickname`: string (optional) - Custom nickname for the contact
- `lastPingTime`: timestamp (optional) - When the contact was last pinged
- `lastPingResponse`: timestamp (optional) - When the contact last responded to a ping
- `manualAlertActive`: boolean - Whether a manual alert is active for this contact
- `createdAt`: timestamp - When the contact relationship was created
- `updatedAt`: timestamp - When the contact relationship was last updated

### QR Codes Collection

Stores QR codes for contact sharing.

```
qrCodes/{qrCodeId}
```

**Fields:**
- `userId`: string - ID of the user who created the QR code
- `status`: string - Status of the QR code (e.g., "active", "used", "expired")
- `expiresAt`: timestamp (optional) - When the QR code expires
- `metadata`: map (optional) - Additional metadata for the QR code
- `createdAt`: timestamp - When the QR code was created

### Check-Ins Collection

Stores check-in history for users.

```
checkIns/{userId}/history/{checkInId}
```

**Fields:**
- `timestamp`: timestamp - When the check-in occurred
- `method`: string - How the check-in was performed (e.g., "manual", "automatic")
- `location`: geopoint (optional) - Where the check-in occurred
- `notes`: string (optional) - Additional notes for the check-in

### Pings Collection

Stores ping requests between contacts.

```
pings/{pingId}
```

**Fields:**
- `fromUserId`: string - ID of the user who sent the ping
- `toUserId`: string - ID of the user who received the ping
- `status`: string - Status of the ping (e.g., "pending", "responded", "expired")
- `message`: string (optional) - Message included with the ping
- `responseMessage`: string (optional) - Response message from the recipient
- `responseTime`: timestamp (optional) - When the ping was responded to
- `expiresAt`: timestamp - When the ping expires
- `createdAt`: timestamp - When the ping was created

### Alerts Collection

Stores alert notifications for missed check-ins and emergency situations.

```
alerts/{alertId}
```

**Fields:**
- `userId`: string - ID of the user who triggered the alert
- `type`: string - Type of alert (e.g., "missed_checkin", "manual", "emergency")
- `status`: string - Status of the alert (e.g., "active", "acknowledged", "resolved")
- `acknowledgedBy`: string (optional) - ID of the user who acknowledged the alert
- `acknowledgedAt`: timestamp (optional) - When the alert was acknowledged
- `resolvedBy`: string (optional) - ID of the user who resolved the alert
- `resolvedAt`: timestamp (optional) - When the alert was resolved
- `createdAt`: timestamp - When the alert was created

### Notifications Collection

Stores notification history for users.

```
notifications/{userId}/history/{notificationId}
```

**Fields:**
- `type`: string - Type of notification (e.g., "checkin_reminder", "ping", "alert")
- `title`: string - Title of the notification
- `body`: string - Body of the notification
- `data`: map - Additional data for the notification
- `read`: boolean - Whether the notification has been read
- `createdAt`: timestamp - When the notification was created

## Data Relationships

### User-Contact Relationship

- A user can have multiple contacts
- Each contact relationship is bidirectional
- Contacts can have different roles (responder, dependent)

```
users/{userId} <---> contacts/{userId}/userContacts/{contactId}
                     contacts/{contactId}/userContacts/{userId}
```

### User-QR Code Relationship

- A user can create multiple QR codes
- Each QR code belongs to one user

```
users/{userId} <---> qrCodes/{qrCodeId}
```

### User-Check-In Relationship

- A user has a check-in history
- Each check-in belongs to one user

```
users/{userId} <---> checkIns/{userId}/history/{checkInId}
```

### User-Ping Relationship

- A user can send and receive multiple pings
- Each ping has a sender and a recipient

```
users/{fromUserId} <---> pings/{pingId} <---> users/{toUserId}
```

### User-Alert Relationship

- A user can trigger multiple alerts
- Each alert belongs to one user
- Alerts can be acknowledged and resolved by contacts

```
users/{userId} <---> alerts/{alertId}
```

### User-Notification Relationship

- A user has a notification history
- Each notification belongs to one user

```
users/{userId} <---> notifications/{userId}/history/{notificationId}
```

## Data Modeling Principles

### 1. Denormalization for Read Efficiency

Denormalize data to optimize for read operations:

```typescript
// User document with denormalized check-in information
{
  "id": "user123",
  "name": "John Doe",
  "email": "john@example.com",
  "lastCheckedIn": "2023-06-15T10:30:00Z",
  "checkInInterval": 86400, // 24 hours in seconds
  "checkInExpiration": "2023-06-16T10:30:00Z"
}

// Contact document with denormalized user information
{
  "userId": "contact456",
  "name": "Jane Smith", // Denormalized from user document
  "roles": ["responder"],
  "lastPingTime": "2023-06-14T15:45:00Z"
}
```

### 2. References for Consistency

Use references for relationships that require consistency:

```typescript
// Ping document with references to users
{
  "id": "ping789",
  "fromUserId": "user123", // Reference to user
  "toUserId": "contact456", // Reference to user
  "status": "pending",
  "createdAt": "2023-06-15T14:20:00Z"
}
```

### 3. Subcollections for One-to-Many Relationships

Use subcollections for one-to-many relationships:

```
users/{userId}
contacts/{userId}/userContacts/{contactId}
checkIns/{userId}/history/{checkInId}
notifications/{userId}/history/{notificationId}
```

### 4. Atomic Updates with Transactions

Use transactions for operations that require atomicity:

```typescript
// Adding a contact relationship (bidirectional)
await db.runTransaction(async (transaction) => {
  // Add contact for current user
  transaction.set(
    db.collection('contacts').doc(userId).collection('userContacts').doc(contactId),
    {
      userId: contactId,
      roles: ['responder'],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }
  );
  
  // Add current user as contact for the other user
  transaction.set(
    db.collection('contacts').doc(contactId).collection('userContacts').doc(userId),
    {
      userId: userId,
      roles: ['dependent'],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }
  );
});
```

### 5. Batch Operations for Multiple Updates

Use batch operations for multiple updates:

```typescript
// Sending notifications to multiple users
const batch = db.batch();

for (const userId of userIds) {
  const notificationRef = db.collection('notifications')
    .doc(userId)
    .collection('history')
    .doc();
  
  batch.set(notificationRef, {
    type: 'alert',
    title: 'Emergency Alert',
    body: 'A contact has triggered an emergency alert.',
    data: { alertId: alertId },
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
}

await batch.commit();
```

## Schema Validation

Use Firestore security rules for schema validation:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // User document validation
    match /users/{userId} {
      allow create: if request.auth != null && request.auth.uid == userId &&
                     request.resource.data.name is string &&
                     request.resource.data.email is string &&
                     (request.resource.data.phoneNumber is string || !('phoneNumber' in request.resource.data)) &&
                     request.resource.data.isOnboarded is bool &&
                     request.resource.data.createdAt is timestamp &&
                     request.resource.data.updatedAt is timestamp;
      
      allow update: if request.auth != null && request.auth.uid == userId &&
                     (request.resource.data.name is string || !('name' in request.resource.data)) &&
                     (request.resource.data.email is string || !('email' in request.resource.data)) &&
                     (request.resource.data.phoneNumber is string || !('phoneNumber' in request.resource.data)) &&
                     (request.resource.data.lastCheckedIn is timestamp || !('lastCheckedIn' in request.resource.data)) &&
                     (request.resource.data.checkInInterval is number || !('checkInInterval' in request.resource.data)) &&
                     (request.resource.data.checkInExpiration is timestamp || !('checkInExpiration' in request.resource.data)) &&
                     (request.resource.data.profileImageURL is string || !('profileImageURL' in request.resource.data)) &&
                     (request.resource.data.isOnboarded is bool || !('isOnboarded' in request.resource.data)) &&
                     (request.resource.data.fcmTokens is list || !('fcmTokens' in request.resource.data)) &&
                     request.resource.data.updatedAt is timestamp;
    }
    
    // Contact document validation
    match /contacts/{userId}/userContacts/{contactId} {
      allow create, update: if request.auth != null && request.auth.uid == userId &&
                              request.resource.data.userId is string &&
                              request.resource.data.roles is list &&
                              (request.resource.data.nickname is string || !('nickname' in request.resource.data)) &&
                              (request.resource.data.lastPingTime is timestamp || !('lastPingTime' in request.resource.data)) &&
                              (request.resource.data.lastPingResponse is timestamp || !('lastPingResponse' in request.resource.data)) &&
                              (request.resource.data.manualAlertActive is bool || !('manualAlertActive' in request.resource.data)) &&
                              request.resource.data.createdAt is timestamp &&
                              request.resource.data.updatedAt is timestamp;
    }
    
    // QR code document validation
    match /qrCodes/{qrCodeId} {
      allow create: if request.auth != null &&
                     request.resource.data.userId == request.auth.uid &&
                     request.resource.data.status is string &&
                     (request.resource.data.expiresAt is timestamp || !('expiresAt' in request.resource.data)) &&
                     (request.resource.data.metadata is map || !('metadata' in request.resource.data)) &&
                     request.resource.data.createdAt is timestamp;
      
      allow update: if request.auth != null &&
                     (resource.data.userId == request.auth.uid || request.resource.data.userId == resource.data.userId) &&
                     request.resource.data.status is string;
    }
  }
}
```

## Data Migration

As the schema evolves, implement data migration strategies:

1. **Version Field** - Add a version field to documents to track schema versions
2. **Migration Functions** - Create Cloud Functions to migrate data to new schemas
3. **Backward Compatibility** - Maintain backward compatibility during migration

```typescript
// Migration function example
export const migrateUserSchema = functions.https.onRequest(async (req, res) => {
  const db = admin.firestore();
  const usersSnapshot = await db.collection('users').where('schemaVersion', '<', 2).get();
  
  const batch = db.batch();
  let migratedCount = 0;
  
  for (const userDoc of usersSnapshot.docs) {
    const userData = userDoc.data();
    
    // Migrate from schema version 1 to 2
    if (userData.schemaVersion === 1) {
      // Add new fields
      batch.update(userDoc.ref, {
        checkInExpiration: userData.lastCheckedIn ? 
          new admin.firestore.Timestamp(
            userData.lastCheckedIn.seconds + (userData.checkInInterval || 86400),
            userData.lastCheckedIn.nanoseconds
          ) : null,
        schemaVersion: 2
      });
      
      migratedCount++;
    }
    
    // Process in batches of 500
    if (migratedCount % 500 === 0) {
      await batch.commit();
      batch = db.batch();
    }
  }
  
  // Commit any remaining updates
  if (migratedCount % 500 !== 0) {
    await batch.commit();
  }
  
  res.json({ success: true, migratedCount });
});
```
