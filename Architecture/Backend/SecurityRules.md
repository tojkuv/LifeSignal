# Security Rules

> **Note:** As this is an MVP, the security rules may evolve as the project matures.

## Firestore Security Rules

Firestore security rules control access to the database. They are defined in a declarative language and are enforced on the server side.

### User Collection Rules

```javascript
match /users/{userId} {
  // Only authenticated users can read their own profile
  // Contacts can also read basic profile information
  function isContact(otherUserId) {
    return exists(/databases/$(database)/documents/contacts/$(request.auth.uid)/userContacts/$(otherUserId));
  }
  
  // Only allow reading specific fields for contacts
  function limitedUserData() {
    return {
      name: resource.data.name,
      profileImageURL: resource.data.profileImageURL,
      lastCheckedIn: resource.data.lastCheckedIn,
      checkInExpiration: resource.data.checkInExpiration
    };
  }
  
  // Users can read their own full profile
  allow read: if request.auth != null && request.auth.uid == userId;
  
  // Contacts can read limited profile information
  allow read: if request.auth != null && isContact(userId) && 
              request.resource.data.keys().hasOnly(limitedUserData().keys());
  
  // Users can create and update their own profile
  allow create: if request.auth != null && request.auth.uid == userId;
  allow update: if request.auth != null && request.auth.uid == userId;
  
  // No one can delete user profiles (handled by Cloud Functions)
  allow delete: if false;
}
```

### Contacts Collection Rules

```javascript
match /contacts/{userId}/userContacts/{contactId} {
  // Users can read their own contacts
  allow read: if request.auth != null && request.auth.uid == userId;
  
  // Users can create contacts for themselves
  // (but bidirectional creation should be handled by Cloud Functions)
  allow create: if request.auth != null && request.auth.uid == userId;
  
  // Users can update their own contacts
  allow update: if request.auth != null && request.auth.uid == userId;
  
  // Users can delete their own contacts
  // (but bidirectional deletion should be handled by Cloud Functions)
  allow delete: if request.auth != null && request.auth.uid == userId;
}
```

### QR Codes Collection Rules

```javascript
match /qrCodes/{qrCodeId} {
  // Only the creator can read their QR codes
  allow read: if request.auth != null && resource.data.userId == request.auth.uid;
  
  // Users can create QR codes for themselves
  allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
  
  // Only the creator can update their QR codes
  allow update: if request.auth != null && resource.data.userId == request.auth.uid;
  
  // Only the creator can delete their QR codes
  allow delete: if request.auth != null && resource.data.userId == request.auth.uid;
}
```

### Check-Ins Collection Rules

```javascript
match /checkIns/{userId}/history/{checkInId} {
  // Users can read their own check-in history
  // Contacts with responder role can also read check-in history
  function isResponder(userId) {
    return exists(/databases/$(database)/documents/contacts/$(request.auth.uid)/userContacts/$(userId)) &&
           get(/databases/$(database)/documents/contacts/$(request.auth.uid)/userContacts/$(userId)).data.roles.hasAny(['responder']);
  }
  
  // Users can read their own check-in history
  allow read: if request.auth != null && request.auth.uid == userId;
  
  // Responders can read check-in history
  allow read: if request.auth != null && isResponder(userId);
  
  // Users can create check-ins for themselves
  allow create: if request.auth != null && request.auth.uid == userId;
  
  // No one can update or delete check-ins (immutable history)
  allow update, delete: if false;
}
```

### Pings Collection Rules

```javascript
match /pings/{pingId} {
  // Only the sender and recipient can read pings
  allow read: if request.auth != null && 
              (resource.data.fromUserId == request.auth.uid || 
               resource.data.toUserId == request.auth.uid);
  
  // Only users with responder role can create pings
  function isResponderFor(userId) {
    return exists(/databases/$(database)/documents/contacts/$(request.auth.uid)/userContacts/$(userId)) &&
           get(/databases/$(database)/documents/contacts/$(request.auth.uid)/userContacts/$(userId)).data.roles.hasAny(['responder']);
  }
  
  // Users can create pings for their dependents
  allow create: if request.auth != null && 
                request.resource.data.fromUserId == request.auth.uid &&
                isResponderFor(request.resource.data.toUserId);
  
  // Only the recipient can update pings (to respond)
  allow update: if request.auth != null && 
                resource.data.toUserId == request.auth.uid &&
                request.resource.data.fromUserId == resource.data.fromUserId &&
                request.resource.data.toUserId == resource.data.toUserId;
  
  // No one can delete pings (handled by Cloud Functions for cleanup)
  allow delete: if false;
}
```

### Alerts Collection Rules

```javascript
match /alerts/{alertId} {
  // Users can read alerts they triggered or are a contact for
  function isContactOf(userId) {
    return exists(/databases/$(database)/documents/contacts/$(request.auth.uid)/userContacts/$(userId)) ||
           exists(/databases/$(database)/documents/contacts/$(userId)/userContacts/$(request.auth.uid));
  }
  
  // Users can read their own alerts or alerts for their contacts
  allow read: if request.auth != null && 
              (resource.data.userId == request.auth.uid || 
               isContactOf(resource.data.userId));
  
  // Users can create alerts for themselves
  allow create: if request.auth != null && 
                request.resource.data.userId == request.auth.uid;
  
  // Responders can update alerts to acknowledge or resolve them
  function isResponderFor(userId) {
    return exists(/databases/$(database)/documents/contacts/$(request.auth.uid)/userContacts/$(userId)) &&
           get(/databases/$(database)/documents/contacts/$(request.auth.uid)/userContacts/$(userId)).data.roles.hasAny(['responder']);
  }
  
  // Responders can update alerts
  allow update: if request.auth != null && 
                isResponderFor(resource.data.userId) &&
                request.resource.data.userId == resource.data.userId;
  
  // No one can delete alerts (handled by Cloud Functions for cleanup)
  allow delete: if false;
}
```

### Notifications Collection Rules

```javascript
match /notifications/{userId}/history/{notificationId} {
  // Users can only read their own notifications
  allow read: if request.auth != null && request.auth.uid == userId;
  
  // Only Cloud Functions can create notifications
  allow create: if false;
  
  // Users can update their own notifications (e.g., mark as read)
  allow update: if request.auth != null && 
                request.auth.uid == userId &&
                request.resource.data.diff(resource.data).affectedKeys().hasOnly(['read']);
  
  // Users can delete their own notifications
  allow delete: if request.auth != null && request.auth.uid == userId;
}
```

## Storage Security Rules

Firebase Storage security rules control access to files stored in Firebase Storage.

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Profile images
    match /profileImages/{userId}/{fileName} {
      // Users can read their own profile images
      // Anyone can read profile images (public)
      allow read: if true;
      
      // Users can only upload their own profile images
      allow write: if request.auth != null && 
                    request.auth.uid == userId &&
                    request.resource.size < 5 * 1024 * 1024 && // 5MB max
                    request.resource.contentType.matches('image/.*');
    }
    
    // QR code images
    match /qrCodes/{userId}/{fileName} {
      // Users can read their own QR code images
      allow read: if request.auth != null && request.auth.uid == userId;
      
      // Users can only upload their own QR code images
      allow write: if request.auth != null && 
                    request.auth.uid == userId &&
                    request.resource.size < 1 * 1024 * 1024 && // 1MB max
                    request.resource.contentType.matches('image/.*');
    }
    
    // Check-in attachments
    match /checkInAttachments/{userId}/{checkInId}/{fileName} {
      // Users can read their own check-in attachments
      // Responders can also read check-in attachments
      function isResponder(userId) {
        return request.auth != null &&
               exists(/databases/$(database)/documents/contacts/$(request.auth.uid)/userContacts/$(userId)) &&
               get(/databases/$(database)/documents/contacts/$(request.auth.uid)/userContacts/$(userId)).data.roles.hasAny(['responder']);
      }
      
      // Users can read their own check-in attachments
      allow read: if request.auth != null && request.auth.uid == userId;
      
      // Responders can read check-in attachments
      allow read: if isResponder(userId);
      
      // Users can only upload their own check-in attachments
      allow write: if request.auth != null && 
                    request.auth.uid == userId &&
                    request.resource.size < 10 * 1024 * 1024 && // 10MB max
                    (request.resource.contentType.matches('image/.*') ||
                     request.resource.contentType.matches('video/.*') ||
                     request.resource.contentType.matches('audio/.*'));
    }
  }
}
```

## Authentication Rules

Firebase Authentication rules control user authentication and account management.

### Email/Password Authentication

- Require email verification for sensitive operations
- Enforce password strength requirements
- Limit failed login attempts

```javascript
// In Firebase Console Authentication settings
{
  "passwordPolicy": {
    "minLength": 8,
    "requireUppercase": true,
    "requireLowercase": true,
    "requireNumeric": true,
    "requireNonAlphanumeric": true
  },
  "blockingFunctions": {
    "beforeSignIn": {
      "function": "beforeSignIn",
      "triggerType": "blocking"
    }
  }
}
```

### Phone Authentication

- Limit verification attempts
- Implement rate limiting for SMS verification

```javascript
// In Firebase Console Authentication settings
{
  "phoneVerification": {
    "autoRetrievalTimeout": 60,
    "recaptchaRequired": true
  }
}
```

## Cloud Functions Security

Secure Cloud Functions with proper authentication and authorization checks.

### HTTPS Callable Functions

```typescript
export const addContactRelation = functions.https.onCall(async (data, context) => {
  // Authentication check
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to add a contact'
    );
  }
  
  // Authorization check
  const userId = context.auth.uid;
  
  // Input validation
  if (!data.qrCodeId || typeof data.qrCodeId !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'QR code ID is required and must be a string'
    );
  }
  
  // Function implementation...
});
```

### Firestore Triggers

```typescript
export const onUserCheckIn = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const userId = context.params.userId;
    const beforeData = change.before.data();
    const afterData = change.after.data();
    
    // Check if this is a check-in update
    if (beforeData.lastCheckedIn === afterData.lastCheckedIn) {
      // Not a check-in update, exit early
      return null;
    }
    
    // Verify the data is valid
    if (!afterData.lastCheckedIn || !afterData.checkInInterval) {
      console.error('Invalid check-in data:', afterData);
      return null;
    }
    
    // Function implementation...
  });
```

## Security Best Practices

### 1. Principle of Least Privilege

- Grant the minimum permissions necessary
- Use role-based access control
- Regularly review and audit permissions

### 2. Data Validation

- Validate all input data on the server
- Use Firestore security rules for schema validation
- Implement additional validation in Cloud Functions

### 3. Authentication and Authorization

- Always check authentication in Cloud Functions
- Implement proper authorization checks
- Use custom claims for role-based access control

### 4. Error Handling

- Don't expose sensitive information in error messages
- Log errors securely
- Return appropriate error codes to clients

### 5. Rate Limiting

- Implement rate limiting for sensitive operations
- Protect against brute force attacks
- Use Firebase App Check to prevent abuse

### 6. Secure Communication

- Use HTTPS for all communication
- Implement proper CORS configuration
- Use Firebase App Check to verify client integrity

### 7. Secrets Management

- Store secrets in environment variables
- Use Firebase Secret Manager for sensitive data
- Never hardcode secrets in code

### 8. Regular Security Audits

- Regularly review security rules
- Monitor for suspicious activity
- Update dependencies to fix security vulnerabilities
