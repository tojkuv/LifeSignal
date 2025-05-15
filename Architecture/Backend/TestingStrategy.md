# Testing Strategy

> **Note:** As this is an MVP, the testing strategy may evolve as the project matures.

## Testing Approach

LifeSignal backend uses a comprehensive testing approach that covers all aspects of the system:

1. **Unit Tests** - Test individual functions and components in isolation
2. **Integration Tests** - Test interactions between components
3. **Emulator Tests** - Test with Firebase emulators
4. **End-to-End Tests** - Test complete workflows

## Testing Tools

- **Jest** - Testing framework
- **Firebase Functions Test SDK** - For testing Cloud Functions
- **Firebase Emulators** - For local testing with Firebase services
- **Supertest** - For HTTP endpoint testing
- **Sinon** - For mocking and stubbing

## Test Organization

Tests are organized following the vertical slice architecture, with test files placed alongside the functions they test:

```
src/
├── functions/
│   ├── data_management/
│   │   ├── addContactRelation.ts
│   │   ├── addContactRelation.test.ts
│   │   ├── updateContactRoles.ts
│   │   ├── updateContactRoles.test.ts
│   │   ├── deleteContactRelation.ts
│   │   ├── deleteContactRelation.test.ts
│   │   ├── respondToPing.ts
│   │   ├── respondToPing.test.ts
│   │   ├── respondToAllPings.ts
│   │   ├── respondToAllPings.test.ts
│   │   ├── pingDependent.ts
│   │   ├── pingDependent.test.ts
│   │   ├── clearPing.ts
│   │   └── clearPing.test.ts
│   └── notifications/
│       ├── sendCheckInReminders.ts
│       └── sendCheckInReminders.test.ts
├── models/
│   └── interfaces.ts
├── utils/
│   ├── handleNotifications.ts
│   └── handleNotifications.test.ts
└── index.ts
```

## Unit Testing

Unit tests focus on testing individual functions and components in isolation.

### Testing HTTPS Callable Functions

```typescript
// addContactRelation.test.ts
import * as admin from 'firebase-admin';
import * as test from 'firebase-functions-test';
import { addContactRelation } from '../src/functions/data_management/addContactRelation';

const testEnv = test();

describe('addContactRelation', () => {
  let adminInitStub;
  let firestoreStub;
  
  beforeAll(() => {
    // Mock Firebase Admin
    adminInitStub = jest.spyOn(admin, 'initializeApp').mockImplementation();
    
    // Mock Firestore
    firestoreStub = {
      collection: jest.fn().mockReturnThis(),
      doc: jest.fn().mockReturnThis(),
      get: jest.fn(),
      set: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
      runTransaction: jest.fn()
    };
    
    jest.spyOn(admin, 'firestore').mockReturnValue(firestoreStub);
  });
  
  afterAll(() => {
    testEnv.cleanup();
    jest.restoreAllMocks();
  });
  
  it('should throw an error if user is not authenticated', async () => {
    const wrapped = testEnv.wrap(addContactRelation);
    
    await expect(wrapped({ qrCodeId: 'test-qr-code' }, { auth: null }))
      .rejects
      .toThrow('User must be authenticated to add a contact');
  });
  
  it('should throw an error if qrCodeId is missing', async () => {
    const wrapped = testEnv.wrap(addContactRelation);
    
    await expect(wrapped({}, { auth: { uid: 'test-user-id' } }))
      .rejects
      .toThrow('QR code ID is required and must be a string');
  });
  
  it('should create a bidirectional contact relationship', async () => {
    // Mock transaction
    firestoreStub.runTransaction.mockImplementation(async (callback) => {
      const transaction = {
        get: jest.fn().mockResolvedValueOnce({
          exists: true,
          data: () => ({
            userId: 'target-user-id',
            status: 'active'
          })
        }).mockResolvedValueOnce({
          exists: false
        }),
        set: jest.fn()
      };
      
      return callback(transaction);
    });
    
    const wrapped = testEnv.wrap(addContactRelation);
    
    const result = await wrapped(
      { qrCodeId: 'test-qr-code' },
      { auth: { uid: 'test-user-id' } }
    );
    
    expect(result).toEqual({
      success: true,
      contactId: 'target-user-id'
    });
    
    // Verify transaction was called
    expect(firestoreStub.runTransaction).toHaveBeenCalled();
  });
  
  it('should throw an error if QR code does not exist', async () => {
    // Mock transaction
    firestoreStub.runTransaction.mockImplementation(async (callback) => {
      const transaction = {
        get: jest.fn().mockResolvedValueOnce({
          exists: false
        }),
        set: jest.fn()
      };
      
      return callback(transaction);
    });
    
    const wrapped = testEnv.wrap(addContactRelation);
    
    await expect(wrapped(
      { qrCodeId: 'non-existent-qr-code' },
      { auth: { uid: 'test-user-id' } }
    )).rejects.toThrow('QR code not found');
  });
  
  it('should throw an error if contact already exists', async () => {
    // Mock transaction
    firestoreStub.runTransaction.mockImplementation(async (callback) => {
      const transaction = {
        get: jest.fn()
          .mockResolvedValueOnce({
            exists: true,
            data: () => ({
              userId: 'target-user-id',
              status: 'active'
            })
          })
          .mockResolvedValueOnce({
            exists: true
          }),
        set: jest.fn()
      };
      
      return callback(transaction);
    });
    
    const wrapped = testEnv.wrap(addContactRelation);
    
    await expect(wrapped(
      { qrCodeId: 'test-qr-code' },
      { auth: { uid: 'test-user-id' } }
    )).rejects.toThrow('Contact relation already exists');
  });
});
```

### Testing Firestore Triggers

```typescript
// onUserCheckIn.test.ts
import * as admin from 'firebase-admin';
import * as test from 'firebase-functions-test';
import { onUserCheckIn } from '../src/functions/data_management/onUserCheckIn';

const testEnv = test();

describe('onUserCheckIn', () => {
  let adminInitStub;
  let firestoreStub;
  
  beforeAll(() => {
    // Mock Firebase Admin
    adminInitStub = jest.spyOn(admin, 'initializeApp').mockImplementation();
    
    // Mock Firestore
    firestoreStub = {
      collection: jest.fn().mockReturnThis(),
      doc: jest.fn().mockReturnThis(),
      get: jest.fn(),
      set: jest.fn(),
      update: jest.fn(),
      delete: jest.fn()
    };
    
    jest.spyOn(admin, 'firestore').mockReturnValue(firestoreStub);
  });
  
  afterAll(() => {
    testEnv.cleanup();
    jest.restoreAllMocks();
  });
  
  it('should process a check-in update', async () => {
    // Create a Firestore document change object
    const beforeSnapshot = {
      data: () => ({
        name: 'Test User',
        lastCheckedIn: admin.firestore.Timestamp.fromDate(new Date('2023-06-14T10:00:00Z')),
        checkInInterval: 86400, // 24 hours
        checkInExpiration: admin.firestore.Timestamp.fromDate(new Date('2023-06-15T10:00:00Z'))
      })
    };
    
    const afterSnapshot = {
      data: () => ({
        name: 'Test User',
        lastCheckedIn: admin.firestore.Timestamp.fromDate(new Date('2023-06-15T10:00:00Z')),
        checkInInterval: 86400, // 24 hours
        checkInExpiration: admin.firestore.Timestamp.fromDate(new Date('2023-06-16T10:00:00Z'))
      })
    };
    
    const change = {
      before: beforeSnapshot,
      after: afterSnapshot
    };
    
    const context = {
      params: {
        userId: 'test-user-id'
      }
    };
    
    // Mock Firestore query
    firestoreStub.get.mockResolvedValue({
      empty: false,
      docs: [
        {
          id: 'contact-1',
          data: () => ({
            userId: 'contact-1',
            roles: ['responder']
          })
        },
        {
          id: 'contact-2',
          data: () => ({
            userId: 'contact-2',
            roles: ['responder']
          })
        }
      ]
    });
    
    // Call the function
    await onUserCheckIn(change, context);
    
    // Verify Firestore operations
    expect(firestoreStub.collection).toHaveBeenCalledWith('checkIns');
    expect(firestoreStub.doc).toHaveBeenCalledWith('test-user-id');
    expect(firestoreStub.collection).toHaveBeenCalledWith('history');
    expect(firestoreStub.set).toHaveBeenCalled();
    
    // Verify notifications were sent to responders
    expect(firestoreStub.collection).toHaveBeenCalledWith('contacts');
    expect(firestoreStub.doc).toHaveBeenCalledWith('test-user-id');
    expect(firestoreStub.collection).toHaveBeenCalledWith('userContacts');
    expect(firestoreStub.get).toHaveBeenCalled();
  });
  
  it('should not process if lastCheckedIn did not change', async () => {
    // Create a Firestore document change object with no change to lastCheckedIn
    const timestamp = admin.firestore.Timestamp.fromDate(new Date('2023-06-15T10:00:00Z'));
    
    const beforeSnapshot = {
      data: () => ({
        name: 'Test User',
        lastCheckedIn: timestamp,
        checkInInterval: 86400, // 24 hours
        checkInExpiration: admin.firestore.Timestamp.fromDate(new Date('2023-06-16T10:00:00Z'))
      })
    };
    
    const afterSnapshot = {
      data: () => ({
        name: 'Updated User', // Name changed, but not lastCheckedIn
        lastCheckedIn: timestamp,
        checkInInterval: 86400, // 24 hours
        checkInExpiration: admin.firestore.Timestamp.fromDate(new Date('2023-06-16T10:00:00Z'))
      })
    };
    
    const change = {
      before: beforeSnapshot,
      after: afterSnapshot
    };
    
    const context = {
      params: {
        userId: 'test-user-id'
      }
    };
    
    // Call the function
    await onUserCheckIn(change, context);
    
    // Verify no Firestore operations were performed
    expect(firestoreStub.collection).not.toHaveBeenCalledWith('checkIns');
    expect(firestoreStub.set).not.toHaveBeenCalled();
  });
});
```

### Testing Utility Functions

```typescript
// handleNotifications.test.ts
import { sendNotification, sendBatchNotifications } from '../src/utils/handleNotifications';
import * as admin from 'firebase-admin';

jest.mock('firebase-admin', () => ({
  messaging: jest.fn().mockReturnValue({
    send: jest.fn().mockResolvedValue('message-id'),
    sendMulticast: jest.fn().mockResolvedValue({
      successCount: 2,
      failureCount: 0,
      responses: [
        { success: true, messageId: 'message-id-1' },
        { success: true, messageId: 'message-id-2' }
      ]
    })
  })
}));

describe('Notification Utilities', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });
  
  describe('sendNotification', () => {
    it('should send a notification to a single token', async () => {
      const token = 'fcm-token';
      const notification = {
        title: 'Test Notification',
        body: 'This is a test notification'
      };
      const data = {
        type: 'test',
        id: '123'
      };
      
      const result = await sendNotification(token, notification, data);
      
      expect(result).toBe('message-id');
      expect(admin.messaging().send).toHaveBeenCalledWith({
        token,
        notification,
        data,
        android: {
          priority: 'high'
        },
        apns: {
          payload: {
            aps: {
              contentAvailable: true
            }
          }
        }
      });
    });
    
    it('should handle errors when sending notifications', async () => {
      const token = 'invalid-token';
      const notification = {
        title: 'Test Notification',
        body: 'This is a test notification'
      };
      
      // Mock error
      admin.messaging().send.mockRejectedValueOnce(new Error('Invalid token'));
      
      await expect(sendNotification(token, notification)).rejects.toThrow('Invalid token');
    });
  });
  
  describe('sendBatchNotifications', () => {
    it('should send notifications to multiple tokens', async () => {
      const tokens = ['token-1', 'token-2'];
      const notification = {
        title: 'Test Notification',
        body: 'This is a test notification'
      };
      const data = {
        type: 'test',
        id: '123'
      };
      
      const result = await sendBatchNotifications(tokens, notification, data);
      
      expect(result.successCount).toBe(2);
      expect(result.failureCount).toBe(0);
      expect(admin.messaging().sendMulticast).toHaveBeenCalledWith({
        tokens,
        notification,
        data,
        android: {
          priority: 'high'
        },
        apns: {
          payload: {
            aps: {
              contentAvailable: true
            }
          }
        }
      });
    });
    
    it('should handle empty token arrays', async () => {
      const tokens = [];
      const notification = {
        title: 'Test Notification',
        body: 'This is a test notification'
      };
      
      const result = await sendBatchNotifications(tokens, notification);
      
      expect(result).toEqual({
        successCount: 0,
        failureCount: 0,
        responses: []
      });
      expect(admin.messaging().sendMulticast).not.toHaveBeenCalled();
    });
  });
});
```

## Integration Testing with Firebase Emulators

Integration tests use Firebase emulators to test interactions between components.

```typescript
// integration.test.ts
import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import * as test from 'firebase-functions-test';
import { addContactRelation } from '../src/functions/data_management/addContactRelation';

// Initialize the Firebase emulators
const testEnv = test({
  projectId: 'test-project',
  databaseURL: 'http://localhost:8080',
  storageBucket: 'test-project.appspot.com'
}, './service-account-key.json');

describe('Integration Tests', () => {
  let db;
  
  beforeAll(async () => {
    // Initialize Firestore
    db = admin.firestore();
    
    // Set up test data
    await db.collection('users').doc('user-1').set({
      name: 'User 1',
      email: 'user1@example.com',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    await db.collection('users').doc('user-2').set({
      name: 'User 2',
      email: 'user2@example.com',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    await db.collection('qrCodes').doc('qr-code-1').set({
      userId: 'user-2',
      status: 'active',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
  });
  
  afterAll(async () => {
    // Clean up test data
    await db.collection('users').doc('user-1').delete();
    await db.collection('users').doc('user-2').delete();
    await db.collection('qrCodes').doc('qr-code-1').delete();
    await db.collection('contacts').doc('user-1').collection('userContacts').doc('user-2').delete();
    await db.collection('contacts').doc('user-2').collection('userContacts').doc('user-1').delete();
    
    // Clean up Firebase test SDK
    testEnv.cleanup();
  });
  
  it('should create a bidirectional contact relationship', async () => {
    // Wrap the function
    const wrapped = testEnv.wrap(addContactRelation);
    
    // Call the function with test data
    const result = await wrapped(
      { qrCodeId: 'qr-code-1' },
      { auth: { uid: 'user-1' } }
    );
    
    // Verify the result
    expect(result).toEqual({
      success: true,
      contactId: 'user-2'
    });
    
    // Verify the contact was created for user-1
    const contact1Doc = await db.collection('contacts').doc('user-1').collection('userContacts').doc('user-2').get();
    expect(contact1Doc.exists).toBe(true);
    expect(contact1Doc.data().roles).toContain('responder');
    
    // Verify the contact was created for user-2
    const contact2Doc = await db.collection('contacts').doc('user-2').collection('userContacts').doc('user-1').get();
    expect(contact2Doc.exists).toBe(true);
    expect(contact2Doc.data().roles).toContain('dependent');
  });
  
  it('should throw an error if QR code does not exist', async () => {
    // Wrap the function
    const wrapped = testEnv.wrap(addContactRelation);
    
    // Call the function with non-existent QR code
    await expect(wrapped(
      { qrCodeId: 'non-existent-qr-code' },
      { auth: { uid: 'user-1' } }
    )).rejects.toThrow('QR code not found');
  });
});
```

## End-to-End Testing

End-to-end tests verify complete workflows from the client to the backend.

```typescript
// e2e.test.ts
import * as firebase from '@firebase/testing';
import * as admin from 'firebase-admin';

const projectId = 'test-project';
const adminApp = admin.initializeApp({
  projectId
});

describe('End-to-End Tests', () => {
  let db;
  let adminDb;
  
  beforeAll(async () => {
    // Initialize Firebase with authentication
    const app = firebase.initializeTestApp({
      projectId,
      auth: { uid: 'user-1', email: 'user1@example.com' }
    });
    
    db = app.firestore();
    adminDb = adminApp.firestore();
    
    // Set up test data
    await adminDb.collection('users').doc('user-1').set({
      name: 'User 1',
      email: 'user1@example.com',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    await adminDb.collection('users').doc('user-2').set({
      name: 'User 2',
      email: 'user2@example.com',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    await adminDb.collection('qrCodes').doc('qr-code-1').set({
      userId: 'user-2',
      status: 'active',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
  });
  
  afterAll(async () => {
    // Clean up test data
    await adminDb.collection('users').doc('user-1').delete();
    await adminDb.collection('users').doc('user-2').delete();
    await adminDb.collection('qrCodes').doc('qr-code-1').delete();
    await adminDb.collection('contacts').doc('user-1').collection('userContacts').doc('user-2').delete();
    await adminDb.collection('contacts').doc('user-2').collection('userContacts').doc('user-1').delete();
    
    // Clean up Firebase test app
    await Promise.all(firebase.apps().map(app => app.delete()));
  });
  
  it('should allow a user to check in', async () => {
    // Perform a check-in
    await db.collection('users').doc('user-1').update({
      lastCheckedIn: firebase.firestore.FieldValue.serverTimestamp(),
      checkInExpiration: firebase.firestore.Timestamp.fromMillis(Date.now() + 24 * 60 * 60 * 1000)
    });
    
    // Wait for Firestore triggers to execute
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Verify check-in was recorded
    const checkInSnapshot = await adminDb.collection('checkIns').doc('user-1').collection('history').orderBy('timestamp', 'desc').limit(1).get();
    expect(checkInSnapshot.empty).toBe(false);
    
    const checkInDoc = checkInSnapshot.docs[0];
    expect(checkInDoc.data().method).toBe('manual');
  });
  
  it('should allow a responder to ping a dependent', async () => {
    // Create contact relationship
    await adminDb.collection('contacts').doc('user-1').collection('userContacts').doc('user-2').set({
      userId: 'user-2',
      roles: ['responder'],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    await adminDb.collection('contacts').doc('user-2').collection('userContacts').doc('user-1').set({
      userId: 'user-1',
      roles: ['dependent'],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Send a ping
    const pingRef = await db.collection('pings').add({
      fromUserId: 'user-1',
      toUserId: 'user-2',
      status: 'pending',
      message: 'Are you okay?',
      expiresAt: firebase.firestore.Timestamp.fromMillis(Date.now() + 60 * 60 * 1000),
      createdAt: firebase.firestore.FieldValue.serverTimestamp()
    });
    
    // Wait for Firestore triggers to execute
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Verify ping was created
    const pingDoc = await adminDb.collection('pings').doc(pingRef.id).get();
    expect(pingDoc.exists).toBe(true);
    expect(pingDoc.data().status).toBe('pending');
    
    // Respond to the ping
    await adminDb.collection('pings').doc(pingRef.id).update({
      status: 'responded',
      responseMessage: 'I am fine',
      responseTime: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Wait for Firestore triggers to execute
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Verify ping was updated
    const updatedPingDoc = await adminDb.collection('pings').doc(pingRef.id).get();
    expect(updatedPingDoc.data().status).toBe('responded');
  });
});
```

## Test Coverage

Aim for high test coverage, especially for critical paths:

- Cloud Functions: 90%+
- Utility functions: 90%+
- Security rules: 80%+

Use Jest's coverage reporting to identify untested code:

```json
// package.json
{
  "scripts": {
    "test": "jest",
    "test:coverage": "jest --coverage"
  },
  "jest": {
    "collectCoverageFrom": [
      "src/**/*.ts",
      "!src/index.ts",
      "!src/**/*.d.ts"
    ],
    "coverageThreshold": {
      "global": {
        "branches": 80,
        "functions": 80,
        "lines": 80,
        "statements": 80
      }
    }
  }
}
```

## Continuous Integration

Set up continuous integration to run tests automatically:

```yaml
# .github/workflows/test.yml
name: Test

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Set up Node.js
      uses: actions/setup-node@v2
      with:
        node-version: '16'
    
    - name: Install dependencies
      run: npm ci
    
    - name: Start Firebase emulators
      run: npm run emulators:start &
      working-directory: ./functions
    
    - name: Wait for emulators
      run: sleep 10
    
    - name: Run tests
      run: npm test
      working-directory: ./functions
    
    - name: Upload coverage
      uses: codecov/codecov-action@v2
      with:
        directory: ./functions/coverage
```
