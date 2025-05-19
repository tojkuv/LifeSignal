# Security Rule Example

**Navigation:** [Back to Examples](README.md) | [Cloud Function Example](CloudFunctionExample.md) | [Database Query Example](DatabaseQueryExample.md)

---

## Overview

This document provides a comprehensive example of Firebase Security Rules implementation for the LifeSignal application. The example demonstrates best practices for security rule implementation, including authentication checks, authorization checks, data validation, and testing.

## Security Rules

### Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isCurrentUser(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    function isValidUserData(data) {
      return data.keys().hasAll(['name', 'phone', 'note', 'checkInInterval']) &&
             data.name is string && data.name.size() > 0 &&
             data.phone is string && data.phone.size() > 0 &&
             data.note is string &&
             data.checkInInterval is number && data.checkInInterval >= 3600;
    }
    
    function isValidContactData(data) {
      return data.keys().hasAll(['isResponder', 'isDependent', 'referencePath']) &&
             data.isResponder is bool &&
             data.isDependent is bool &&
             data.referencePath is string && data.referencePath.matches('users/[^/]+');
    }
    
    function existingData() {
      return resource.data;
    }
    
    function incomingData() {
      return request.resource.data;
    }
    
    function isContactRelationshipValid(userId, contactId) {
      let contactPath = /databases/$(database)/documents/users/$(contactId);
      return exists(contactPath) && 
             (
               // Check if contact relationship already exists
               exists(/databases/$(database)/documents/users/$(userId)/contacts/$(contactId)) ||
               // Or if this is a new contact relationship
               (
                 // Ensure the contact exists
                 exists(/databases/$(database)/documents/users/$(contactId)) &&
                 // Prevent adding yourself as a contact
                 userId != contactId
               )
             );
    }
    
    // Users collection
    match /users/{userId} {
      // Allow read if authenticated and current user
      allow read: if isCurrentUser(userId);
      
      // Allow create if authenticated, current user, and valid data
      allow create: if isCurrentUser(userId) && isValidUserData(incomingData());
      
      // Allow update if authenticated, current user, and valid data
      allow update: if isCurrentUser(userId) && isValidUserData(incomingData());
      
      // Allow delete if authenticated and current user
      allow delete: if isCurrentUser(userId);
      
      // Contacts subcollection
      match /contacts/{contactId} {
        // Allow read if authenticated and current user
        allow read: if isCurrentUser(userId);
        
        // Allow create if authenticated, current user, valid data, and valid contact relationship
        allow create: if isCurrentUser(userId) && 
                       isValidContactData(incomingData()) && 
                       isContactRelationshipValid(userId, contactId);
        
        // Allow update if authenticated, current user, and valid data
        allow update: if isCurrentUser(userId) && 
                       isValidContactData(incomingData());
        
        // Allow delete if authenticated and current user
        allow delete: if isCurrentUser(userId);
      }
    }
  }
}
```

### Storage Security Rules

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isCurrentUser(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    function isValidImage() {
      return request.resource.contentType.matches('image/.*') && 
             request.resource.size < 5 * 1024 * 1024; // 5MB
    }
    
    // User profile images
    match /users/{userId}/profile.jpg {
      // Allow read if authenticated
      allow read: if isAuthenticated();
      
      // Allow write if authenticated, current user, and valid image
      allow write: if isCurrentUser(userId) && isValidImage();
    }
    
    // QR code images
    match /users/{userId}/qrcode.png {
      // Allow read if authenticated
      allow read: if isAuthenticated();
      
      // Allow write if authenticated and current user
      allow write: if isCurrentUser(userId);
    }
  }
}
```

## Key Implementation Features

1. **Helper Functions**: Reusable functions for common checks
2. **Authentication Checks**: Ensuring users are authenticated
3. **Authorization Checks**: Ensuring users can only access their own data
4. **Data Validation**: Validating data structure and content
5. **Path Validation**: Validating document paths
6. **Relationship Validation**: Validating relationships between documents
7. **Content Type Validation**: Validating file content types
8. **Size Validation**: Validating file sizes

## Testing Security Rules

### Unit Testing with Firebase Rules Test Runner

```javascript
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const firebase = require('@firebase/rules-unit-testing');

describe('Firestore Security Rules', () => {
  let adminDb;
  let userDb;
  let otherUserDb;
  let unauthedDb;
  
  const userId = 'user123';
  const otherUserId = 'user456';
  const projectId = 'lifesignal-test';
  
  beforeAll(async () => {
    // Initialize test environment
    adminDb = firebase.initializeAdminApp({ projectId }).firestore();
    userDb = firebase.initializeTestApp({
      projectId,
      auth: { uid: userId, email: 'user@example.com' }
    }).firestore();
    otherUserDb = firebase.initializeTestApp({
      projectId,
      auth: { uid: otherUserId, email: 'other@example.com' }
    }).firestore();
    unauthedDb = firebase.initializeTestApp({
      projectId
    }).firestore();
    
    // Load security rules
    await firebase.loadFirestoreRules({
      projectId,
      rules: fs.readFileSync('firestore.rules', 'utf8')
    });
    
    // Seed test data
    await adminDb.doc(`users/${userId}`).set({
      name: 'Test User',
      phone: '+15551234567',
      note: 'Test note',
      checkInInterval: 86400
    });
    
    await adminDb.doc(`users/${otherUserId}`).set({
      name: 'Other User',
      phone: '+15557654321',
      note: 'Other note',
      checkInInterval: 86400
    });
  });
  
  afterAll(async () => {
    // Clean up test environment
    await firebase.clearFirestoreData({ projectId });
    await Promise.all(firebase.apps().map(app => app.delete()));
  });
  
  describe('User documents', () => {
    it('allows users to read their own data', async () => {
      const userDoc = userDb.doc(`users/${userId}`);
      await assertSucceeds(userDoc.get());
    });
    
    it('prevents users from reading other users data', async () => {
      const otherUserDoc = userDb.doc(`users/${otherUserId}`);
      await assertFails(otherUserDoc.get());
    });
    
    it('prevents unauthenticated users from reading any user data', async () => {
      const userDoc = unauthedDb.doc(`users/${userId}`);
      await assertFails(userDoc.get());
    });
    
    it('allows users to update their own data with valid data', async () => {
      const userDoc = userDb.doc(`users/${userId}`);
      await assertSucceeds(userDoc.update({
        name: 'Updated Name',
        phone: '+15551234567',
        note: 'Updated note',
        checkInInterval: 86400
      }));
    });
    
    it('prevents users from updating their own data with invalid data', async () => {
      const userDoc = userDb.doc(`users/${userId}`);
      await assertFails(userDoc.update({
        name: '',
        phone: '+15551234567',
        note: 'Updated note',
        checkInInterval: 86400
      }));
    });
    
    it('prevents users from updating other users data', async () => {
      const otherUserDoc = userDb.doc(`users/${otherUserId}`);
      await assertFails(otherUserDoc.update({
        name: 'Hacked Name',
        phone: '+15557654321',
        note: 'Hacked note',
        checkInInterval: 86400
      }));
    });
  });
  
  describe('Contact documents', () => {
    beforeAll(async () => {
      // Seed contact data
      await adminDb.doc(`users/${userId}/contacts/${otherUserId}`).set({
        isResponder: true,
        isDependent: false,
        referencePath: `users/${otherUserId}`
      });
    });
    
    it('allows users to read their own contacts', async () => {
      const contactDoc = userDb.doc(`users/${userId}/contacts/${otherUserId}`);
      await assertSucceeds(contactDoc.get());
    });
    
    it('prevents users from reading other users contacts', async () => {
      const otherContactDoc = otherUserDb.doc(`users/${userId}/contacts/${otherUserId}`);
      await assertFails(otherContactDoc.get());
    });
    
    it('allows users to create valid contacts', async () => {
      const newContactId = 'user789';
      
      // Create the user first
      await adminDb.doc(`users/${newContactId}`).set({
        name: 'New User',
        phone: '+15559876543',
        note: 'New note',
        checkInInterval: 86400
      });
      
      const newContactDoc = userDb.doc(`users/${userId}/contacts/${newContactId}`);
      await assertSucceeds(newContactDoc.set({
        isResponder: true,
        isDependent: false,
        referencePath: `users/${newContactId}`
      }));
    });
    
    it('prevents users from creating invalid contacts', async () => {
      const newContactId = 'user999';
      const newContactDoc = userDb.doc(`users/${userId}/contacts/${newContactId}`);
      
      // Missing required fields
      await assertFails(newContactDoc.set({
        isResponder: true
      }));
      
      // Invalid reference path
      await assertFails(newContactDoc.set({
        isResponder: true,
        isDependent: false,
        referencePath: 'invalid/path'
      }));
      
      // Non-existent user
      await assertFails(newContactDoc.set({
        isResponder: true,
        isDependent: false,
        referencePath: `users/${newContactId}`
      }));
      
      // Adding yourself as a contact
      const selfContactDoc = userDb.doc(`users/${userId}/contacts/${userId}`);
      await assertFails(selfContactDoc.set({
        isResponder: true,
        isDependent: false,
        referencePath: `users/${userId}`
      }));
    });
    
    it('allows users to update their own contacts', async () => {
      const contactDoc = userDb.doc(`users/${userId}/contacts/${otherUserId}`);
      await assertSucceeds(contactDoc.update({
        isResponder: false,
        isDependent: true,
        referencePath: `users/${otherUserId}`
      }));
    });
    
    it('prevents users from updating other users contacts', async () => {
      const otherContactDoc = otherUserDb.doc(`users/${userId}/contacts/${otherUserId}`);
      await assertFails(otherContactDoc.update({
        isResponder: false,
        isDependent: false,
        referencePath: `users/${otherUserId}`
      }));
    });
    
    it('allows users to delete their own contacts', async () => {
      const contactDoc = userDb.doc(`users/${userId}/contacts/${otherUserId}`);
      await assertSucceeds(contactDoc.delete());
    });
    
    it('prevents users from deleting other users contacts', async () => {
      // Recreate the contact
      await adminDb.doc(`users/${userId}/contacts/${otherUserId}`).set({
        isResponder: true,
        isDependent: false,
        referencePath: `users/${otherUserId}`
      });
      
      const otherContactDoc = otherUserDb.doc(`users/${userId}/contacts/${otherUserId}`);
      await assertFails(otherContactDoc.delete());
    });
  });
});
```

### Storage Rules Testing

```javascript
const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const firebase = require('@firebase/rules-unit-testing');

describe('Storage Security Rules', () => {
  let adminStorage;
  let userStorage;
  let otherUserStorage;
  let unauthedStorage;
  
  const userId = 'user123';
  const otherUserId = 'user456';
  const projectId = 'lifesignal-test';
  const bucket = 'lifesignal-test.appspot.com';
  
  beforeAll(async () => {
    // Initialize test environment
    adminStorage = firebase.initializeAdminApp({ projectId }).storage();
    userStorage = firebase.initializeTestApp({
      projectId,
      auth: { uid: userId, email: 'user@example.com' }
    }).storage();
    otherUserStorage = firebase.initializeTestApp({
      projectId,
      auth: { uid: otherUserId, email: 'other@example.com' }
    }).storage();
    unauthedStorage = firebase.initializeTestApp({
      projectId
    }).storage();
    
    // Load security rules
    await firebase.loadStorageRules({
      projectId,
      rules: fs.readFileSync('storage.rules', 'utf8')
    });
  });
  
  afterAll(async () => {
    // Clean up test environment
    await Promise.all(firebase.apps().map(app => app.delete()));
  });
  
  describe('Profile images', () => {
    it('allows users to upload their own profile image', async () => {
      const profileRef = userStorage.ref(`users/${userId}/profile.jpg`);
      const metadata = { contentType: 'image/jpeg' };
      const bytes = new Uint8Array([0x00, 0x01, 0x02, 0x03]);
      
      await assertSucceeds(profileRef.put(bytes, metadata));
    });
    
    it('prevents users from uploading other users profile image', async () => {
      const otherProfileRef = userStorage.ref(`users/${otherUserId}/profile.jpg`);
      const metadata = { contentType: 'image/jpeg' };
      const bytes = new Uint8Array([0x00, 0x01, 0x02, 0x03]);
      
      await assertFails(otherProfileRef.put(bytes, metadata));
    });
    
    it('prevents users from uploading invalid content types', async () => {
      const profileRef = userStorage.ref(`users/${userId}/profile.jpg`);
      const metadata = { contentType: 'application/javascript' };
      const bytes = new Uint8Array([0x00, 0x01, 0x02, 0x03]);
      
      await assertFails(profileRef.put(bytes, metadata));
    });
    
    it('allows authenticated users to read profile images', async () => {
      // Upload a profile image first
      const adminProfileRef = adminStorage.ref(`users/${userId}/profile.jpg`);
      const metadata = { contentType: 'image/jpeg' };
      const bytes = new Uint8Array([0x00, 0x01, 0x02, 0x03]);
      await adminProfileRef.put(bytes, metadata);
      
      // Test reading the image
      const profileRef = userStorage.ref(`users/${userId}/profile.jpg`);
      await assertSucceeds(profileRef.getDownloadURL());
      
      const otherUserProfileRef = otherUserStorage.ref(`users/${userId}/profile.jpg`);
      await assertSucceeds(otherUserProfileRef.getDownloadURL());
    });
    
    it('prevents unauthenticated users from reading profile images', async () => {
      const profileRef = unauthedStorage.ref(`users/${userId}/profile.jpg`);
      await assertFails(profileRef.getDownloadURL());
    });
  });
  
  describe('QR code images', () => {
    it('allows users to upload their own QR code', async () => {
      const qrCodeRef = userStorage.ref(`users/${userId}/qrcode.png`);
      const metadata = { contentType: 'image/png' };
      const bytes = new Uint8Array([0x00, 0x01, 0x02, 0x03]);
      
      await assertSucceeds(qrCodeRef.put(bytes, metadata));
    });
    
    it('prevents users from uploading other users QR code', async () => {
      const otherQrCodeRef = userStorage.ref(`users/${otherUserId}/qrcode.png`);
      const metadata = { contentType: 'image/png' };
      const bytes = new Uint8Array([0x00, 0x01, 0x02, 0x03]);
      
      await assertFails(otherQrCodeRef.put(bytes, metadata));
    });
    
    it('allows authenticated users to read QR codes', async () => {
      // Upload a QR code first
      const adminQrCodeRef = adminStorage.ref(`users/${userId}/qrcode.png`);
      const metadata = { contentType: 'image/png' };
      const bytes = new Uint8Array([0x00, 0x01, 0x02, 0x03]);
      await adminQrCodeRef.put(bytes, metadata);
      
      // Test reading the QR code
      const qrCodeRef = userStorage.ref(`users/${userId}/qrcode.png`);
      await assertSucceeds(qrCodeRef.getDownloadURL());
      
      const otherUserQrCodeRef = otherUserStorage.ref(`users/${userId}/qrcode.png`);
      await assertSucceeds(otherUserQrCodeRef.getDownloadURL());
    });
    
    it('prevents unauthenticated users from reading QR codes', async () => {
      const qrCodeRef = unauthedStorage.ref(`users/${userId}/qrcode.png`);
      await assertFails(qrCodeRef.getDownloadURL());
    });
  });
});
```

## Best Practices

1. **Least Privilege**: Grant the minimum access necessary
2. **Defense in Depth**: Implement multiple layers of security
3. **Helper Functions**: Use helper functions for common checks
4. **Data Validation**: Validate data structure and content
5. **Path Validation**: Validate document paths
6. **Relationship Validation**: Validate relationships between documents
7. **Testing**: Write comprehensive tests for security rules
8. **Documentation**: Document security rules and their purpose
9. **Version Control**: Version security rules alongside application code
10. **Regular Review**: Regularly review and update security rules

For detailed implementation guidelines, see the [Backend Guidelines](../../Guidelines/README.md) section.
