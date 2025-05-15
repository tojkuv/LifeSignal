# Function Architecture

> **Note:** As this is an MVP, the function architecture and implementation details may evolve as the project matures.

## Function Types

LifeSignal uses several types of Firebase Cloud Functions:

1. **HTTPS Callable Functions** - For direct invocation from the client app
2. **Firestore Triggers** - For responding to database changes
3. **Scheduled Functions** - For periodic tasks
4. **Authentication Triggers** - For responding to user authentication events

## Function Structure

Each function follows a consistent structure:

1. **Entry Point** - The function definition and export
2. **Authentication Check** - Verify the user is authenticated
3. **Input Validation** - Validate all input parameters
4. **Business Logic** - Implement the core functionality
5. **Error Handling** - Handle and map errors
6. **Response** - Return a standardized response

### HTTPS Callable Function Example

```typescript
// Entry Point
export const addContactRelation = functions.https.onCall(async (data, context) => {
  try {
    // Authentication Check
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to add a contact'
      );
    }
    
    // Input Validation
    if (!data.qrCodeId || typeof data.qrCodeId !== 'string') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'QR code ID is required and must be a string'
      );
    }
    
    // Business Logic
    const result = await addContactRelationLogic(context.auth.uid, data.qrCodeId);
    
    // Response
    return { success: true, contactId: result.contactId };
  } catch (error) {
    // Error Handling
    console.error('Error adding contact relation:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'An error occurred while adding the contact'
    );
  }
});

// Business Logic (separate function for testability)
async function addContactRelationLogic(userId: string, qrCodeId: string): Promise<{ contactId: string }> {
  const db = admin.firestore();
  
  // Implementation details...
  
  return { contactId: targetUserId };
}
```

### Firestore Trigger Example

```typescript
// Entry Point
export const onUserCheckIn = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    try {
      const userId = context.params.userId;
      const beforeData = change.before.data();
      const afterData = change.after.data();
      
      // Check if this is a check-in update
      if (beforeData.lastCheckedIn === afterData.lastCheckedIn) {
        // Not a check-in update, exit early
        return null;
      }
      
      // Business Logic
      await processCheckIn(userId, afterData.lastCheckedIn);
      
      return null;
    } catch (error) {
      // Error Handling
      console.error('Error processing check-in:', error);
      return null;
    }
  });

// Business Logic (separate function for testability)
async function processCheckIn(userId: string, checkInTime: FirebaseFirestore.Timestamp): Promise<void> {
  const db = admin.firestore();
  
  // Implementation details...
}
```

### Scheduled Function Example

```typescript
// Entry Point
export const sendCheckInReminders = functions.pubsub
  .schedule('every 15 minutes')
  .onRun(async (context) => {
    try {
      // Business Logic
      const result = await sendCheckInRemindersLogic();
      
      console.log(`Sent ${result.reminderCount} check-in reminders`);
      return null;
    } catch (error) {
      // Error Handling
      console.error('Error sending check-in reminders:', error);
      return null;
    }
  });

// Business Logic (separate function for testability)
async function sendCheckInRemindersLogic(): Promise<{ reminderCount: number }> {
  const db = admin.firestore();
  
  // Implementation details...
  
  return { reminderCount: remindersSent };
}
```

### Authentication Trigger Example

```typescript
// Entry Point
export const onUserCreated = functions.auth
  .user()
  .onCreate(async (user) => {
    try {
      // Business Logic
      await setupNewUser(user);
      
      return null;
    } catch (error) {
      // Error Handling
      console.error('Error setting up new user:', error);
      return null;
    }
  });

// Business Logic (separate function for testability)
async function setupNewUser(user: admin.auth.UserRecord): Promise<void> {
  const db = admin.firestore();
  
  // Implementation details...
}
```

## Function Categories

### Data Management Functions

These functions handle data operations like creating, updating, and deleting records:

1. **addContactRelation** - Creates a bidirectional contact relationship using a QR code
2. **updateContactRoles** - Updates the roles of an existing contact relationship
3. **deleteContactRelation** - Removes a bidirectional contact relationship
4. **respondToPing** - Responds to a ping from a contact
5. **respondToAllPings** - Responds to all pending pings from contacts
6. **pingDependent** - Sends a ping to a dependent contact
7. **clearPing** - Clears a ping sent to a dependent contact

### Notification Functions

These functions handle sending notifications to users:

1. **sendCheckInReminders** - Sends reminders to users who are approaching their check-in deadline
2. **sendEmergencyAlerts** - Sends alerts to responders when a dependent misses a check-in
3. **sendPingNotifications** - Sends notifications when a user is pinged by a contact

### User Management Functions

These functions handle user account operations:

1. **onUserCreated** - Sets up a new user account with default settings
2. **updateUserProfile** - Updates a user's profile information
3. **deleteUserAccount** - Deletes a user's account and all associated data

## Implementation Patterns

### Transactions

Use transactions for operations that must be atomic:

```typescript
async function addContactRelationLogic(userId: string, qrCodeId: string): Promise<{ contactId: string }> {
  const db = admin.firestore();
  
  return db.runTransaction(async (transaction) => {
    // Get the QR code document
    const qrCodeRef = db.collection('qrCodes').doc(qrCodeId);
    const qrCodeDoc = await transaction.get(qrCodeRef);
    
    if (!qrCodeDoc.exists) {
      throw new QRCodeNotFoundError();
    }
    
    const qrCodeData = qrCodeDoc.data();
    const targetUserId = qrCodeData.userId;
    
    // Check if the contact relation already exists
    const contactRef = db.collection('contacts').doc(userId).collection('userContacts').doc(targetUserId);
    const contactDoc = await transaction.get(contactRef);
    
    if (contactDoc.exists) {
      throw new ContactAlreadyExistsError();
    }
    
    // Create bidirectional contact relation
    const timestamp = admin.firestore.FieldValue.serverTimestamp();
    
    // Add target user as contact for current user
    transaction.set(contactRef, {
      userId: targetUserId,
      roles: ['responder'],
      createdAt: timestamp,
      updatedAt: timestamp
    });
    
    // Add current user as contact for target user
    const reverseContactRef = db.collection('contacts').doc(targetUserId).collection('userContacts').doc(userId);
    transaction.set(reverseContactRef, {
      userId: userId,
      roles: ['dependent'],
      createdAt: timestamp,
      updatedAt: timestamp
    });
    
    return { contactId: targetUserId };
  });
}
```

### Batch Operations

Use batch operations for multiple updates that don't need to be atomic:

```typescript
async function sendCheckInRemindersLogic(): Promise<{ reminderCount: number }> {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  const thirtyMinutesFromNow = new admin.firestore.Timestamp(
    now.seconds + 30 * 60,
    now.nanoseconds
  );
  
  // Find users who need reminders
  const usersSnapshot = await db.collection('users')
    .where('checkInExpiration', '<=', thirtyMinutesFromNow)
    .where('checkInExpiration', '>', now)
    .where('lastReminderSent', '<', now.toMillis() - 15 * 60 * 1000) // No reminder in last 15 minutes
    .get();
  
  if (usersSnapshot.empty) {
    return { reminderCount: 0 };
  }
  
  const batch = db.batch();
  let reminderCount = 0;
  
  // Process each user
  for (const userDoc of usersSnapshot.docs) {
    const userData = userDoc.data();
    
    // Update the lastReminderSent field
    batch.update(userDoc.ref, {
      lastReminderSent: now.toMillis()
    });
    
    // Send the notification (in a real implementation, this would use FCM)
    await sendNotification(userData.fcmToken, {
      title: 'Check-In Reminder',
      body: 'Your check-in deadline is approaching. Please check in soon.',
      data: {
        type: 'checkInReminder',
        userId: userDoc.id
      }
    });
    
    reminderCount++;
  }
  
  // Commit the batch
  await batch.commit();
  
  return { reminderCount };
}
```

### Error Handling

Use custom error classes and map them to HTTP errors:

```typescript
// Custom error classes
class QRCodeNotFoundError extends Error {
  constructor() {
    super('QR code not found');
    this.name = 'QRCodeNotFoundError';
  }
}

class ContactAlreadyExistsError extends Error {
  constructor() {
    super('Contact relation already exists');
    this.name = 'ContactAlreadyExistsError';
  }
}

// Error mapping function
function mapErrorToHttpsError(error: Error): functions.https.HttpsError {
  if (error instanceof QRCodeNotFoundError) {
    return new functions.https.HttpsError('not-found', error.message);
  } else if (error instanceof ContactAlreadyExistsError) {
    return new functions.https.HttpsError('already-exists', error.message);
  } else {
    console.error('Unhandled error:', error);
    return new functions.https.HttpsError('internal', 'An unexpected error occurred');
  }
}

// Usage in function
export const addContactRelation = functions.https.onCall(async (data, context) => {
  try {
    // Function implementation...
  } catch (error) {
    if (error instanceof QRCodeNotFoundError || error instanceof ContactAlreadyExistsError) {
      throw mapErrorToHttpsError(error);
    }
    
    console.error('Error adding contact relation:', error);
    throw new functions.https.HttpsError('internal', 'An unexpected error occurred');
  }
});
```

### Validation

Use TypeScript interfaces and validation functions:

```typescript
// Interface for request data
interface AddContactRequest {
  qrCodeId: string;
  roles?: string[];
}

// Validation function
function validateAddContactRequest(data: any): AddContactRequest {
  if (!data) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Request data is required'
    );
  }
  
  if (!data.qrCodeId || typeof data.qrCodeId !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'QR code ID is required and must be a string'
    );
  }
  
  if (data.roles && !Array.isArray(data.roles)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Roles must be an array of strings'
    );
  }
  
  return {
    qrCodeId: data.qrCodeId,
    roles: data.roles || []
  };
}

// Usage in function
export const addContactRelation = functions.https.onCall(async (data, context) => {
  try {
    // Authentication check
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to add a contact'
      );
    }
    
    // Validate request data
    const request = validateAddContactRequest(data);
    
    // Function implementation...
  } catch (error) {
    // Error handling...
  }
});
```

## Testing Functions

Each function should have corresponding test files:

```typescript
// addContactRelation.test.ts
import * as admin from 'firebase-admin';
import * as test from 'firebase-functions-test';
import { addContactRelation } from '../src/functions/data_management/addContactRelation';

const testEnv = test();
const db = admin.firestore();

describe('addContactRelation', () => {
  beforeEach(async () => {
    // Set up test data
    await db.collection('qrCodes').doc('test-qr-code').set({
      userId: 'target-user-id',
      status: 'active',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
  });
  
  afterEach(async () => {
    // Clean up test data
    await db.collection('qrCodes').doc('test-qr-code').delete();
    await db.collection('contacts').doc('test-user-id').collection('userContacts').doc('target-user-id').delete();
    await db.collection('contacts').doc('target-user-id').collection('userContacts').doc('test-user-id').delete();
  });
  
  it('should create a bidirectional contact relationship', async () => {
    // Mock authenticated user
    const wrapped = testEnv.wrap(addContactRelation);
    const context = {
      auth: {
        uid: 'test-user-id'
      }
    };
    
    // Call the function
    const result = await wrapped({ qrCodeId: 'test-qr-code' }, context);
    
    // Verify the result
    expect(result).toEqual({
      success: true,
      contactId: 'target-user-id'
    });
    
    // Verify the contact was created for the current user
    const contactDoc = await db.collection('contacts').doc('test-user-id').collection('userContacts').doc('target-user-id').get();
    expect(contactDoc.exists).toBe(true);
    expect(contactDoc.data().roles).toContain('responder');
    
    // Verify the contact was created for the target user
    const reverseContactDoc = await db.collection('contacts').doc('target-user-id').collection('userContacts').doc('test-user-id').get();
    expect(reverseContactDoc.exists).toBe(true);
    expect(reverseContactDoc.data().roles).toContain('dependent');
  });
  
  it('should throw an error if the QR code does not exist', async () => {
    // Mock authenticated user
    const wrapped = testEnv.wrap(addContactRelation);
    const context = {
      auth: {
        uid: 'test-user-id'
      }
    };
    
    // Call the function with a non-existent QR code
    await expect(wrapped({ qrCodeId: 'non-existent-qr-code' }, context))
      .rejects
      .toThrow('QR code not found');
  });
  
  it('should throw an error if the contact already exists', async () => {
    // Create the contact relationship first
    await db.collection('contacts').doc('test-user-id').collection('userContacts').doc('target-user-id').set({
      userId: 'target-user-id',
      roles: ['responder'],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Mock authenticated user
    const wrapped = testEnv.wrap(addContactRelation);
    const context = {
      auth: {
        uid: 'test-user-id'
      }
    };
    
    // Call the function
    await expect(wrapped({ qrCodeId: 'test-qr-code' }, context))
      .rejects
      .toThrow('Contact relation already exists');
  });
});
```
