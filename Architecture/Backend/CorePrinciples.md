# Backend Core Principles

> **Note:** As this is an MVP, these principles may evolve as the project matures.

## Fundamental Principles

### 1. Vertical Slice Architecture

- Organize code by feature rather than by technical layer
- Each function should be self-contained and focused on a specific business operation
- Functions should be independent of each other
- Test files should be placed alongside the functions they test
- Group related functions into logical categories (e.g., data_management, notifications)

### 2. Type Safety

- Use TypeScript for all backend code
- Define interfaces for all data structures
- Use strict type checking
- Avoid using `any` type when possible
- Use enums for representing different states
- Use union types for representing different variants

### 3. Security First

- Implement proper authentication and authorization checks in all functions
- Validate all input data before processing
- Use Firestore security rules to enforce access control at the database level
- Implement proper error handling and logging
- Never expose sensitive data in logs or responses
- Follow the principle of least privilege

### 4. Testability

- Design all functions to be testable in isolation
- Use dependency injection for external services
- Provide mock implementations for testing
- Test both success and failure paths
- Use Firebase emulators for integration testing
- Aim for high test coverage

### 5. Idempotency

- Design functions to be idempotent when possible
- Handle duplicate requests gracefully
- Use transactions for operations that must be atomic
- Implement proper error handling and recovery
- Use unique identifiers for operations

### 6. Performance

- Keep functions focused and lightweight
- Minimize database operations
- Use batch operations for multiple updates
- Implement proper indexing for queries
- Use caching when appropriate
- Monitor function execution time and resource usage

## Design Patterns

### 1. Function Structure

- Each function should have a clear entry point
- Separate validation, business logic, and data access
- Use async/await for asynchronous operations
- Handle errors consistently
- Return standardized responses

```typescript
export const addContactRelation = functions.https.onCall(async (data, context) => {
  // Authentication check
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to add a contact'
    );
  }

  // Input validation
  if (!data.qrCodeId || typeof data.qrCodeId !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'QR code ID is required and must be a string'
    );
  }

  try {
    // Business logic
    const result = await addContactRelationLogic(context.auth.uid, data.qrCodeId);
    return result;
  } catch (error) {
    // Error handling
    console.error('Error adding contact relation:', error);
    throw new functions.https.HttpsError(
      'internal',
      'An error occurred while adding the contact'
    );
  }
});
```

### 2. Data Access

- Use Firestore transactions for operations that must be atomic
- Use batch operations for multiple updates
- Implement proper error handling and recovery
- Use references instead of duplicating data when possible
- Follow Firestore best practices for data modeling

```typescript
async function addContactRelationLogic(userId: string, qrCodeId: string) {
  const db = admin.firestore();
  
  // Use a transaction to ensure atomicity
  return db.runTransaction(async (transaction) => {
    // Get the QR code document
    const qrCodeRef = db.collection('qrCodes').doc(qrCodeId);
    const qrCodeDoc = await transaction.get(qrCodeRef);
    
    if (!qrCodeDoc.exists) {
      throw new Error('QR code not found');
    }
    
    const qrCodeData = qrCodeDoc.data();
    const targetUserId = qrCodeData.userId;
    
    // Check if the contact relation already exists
    const contactRef = db.collection('contacts').doc(userId).collection('userContacts').doc(targetUserId);
    const contactDoc = await transaction.get(contactRef);
    
    if (contactDoc.exists) {
      throw new Error('Contact relation already exists');
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
    
    return { success: true };
  });
}
```

### 3. Error Handling

- Use structured error handling
- Define custom error types
- Map internal errors to user-facing errors
- Log detailed error information for debugging
- Return appropriate HTTP status codes

```typescript
// Custom error types
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

// Error mapping
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
```

### 4. Validation

- Validate all input data before processing
- Use TypeScript interfaces for type checking
- Implement custom validation logic for complex rules
- Return clear validation error messages

```typescript
interface AddContactRequest {
  qrCodeId: string;
  roles?: string[];
}

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
```

### 5. Authentication and Authorization

- Implement proper authentication checks in all functions
- Use Firebase Authentication for user identity
- Implement role-based access control
- Validate user permissions before performing operations
- Use Firestore security rules for additional protection

```typescript
function verifyAuthentication(context: functions.https.CallableContext): string {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }
  
  return context.auth.uid;
}

async function verifyAuthorization(userId: string, targetUserId: string, operation: string): Promise<void> {
  const db = admin.firestore();
  
  // Check if the user has permission to perform the operation
  const userDoc = await db.collection('users').doc(userId).get();
  
  if (!userDoc.exists) {
    throw new functions.https.HttpsError(
      'not-found',
      'User not found'
    );
  }
  
  const userData = userDoc.data();
  
  // Check if the user has the required role
  if (operation === 'ping' && !userData.roles.includes('responder')) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'User does not have permission to ping dependents'
    );
  }
  
  // Check if the target user is a contact
  const contactRef = db.collection('contacts').doc(userId).collection('userContacts').doc(targetUserId);
  const contactDoc = await contactRef.get();
  
  if (!contactDoc.exists) {
    throw new functions.https.HttpsError(
      'not-found',
      'Contact relation not found'
    );
  }
}
```

## Implementation Guidelines

### 1. Function Organization

- Group related functions into logical categories
- Use descriptive names for functions
- Keep functions focused on a single responsibility
- Implement proper error handling and logging
- Use consistent naming conventions

### 2. Testing

- Write unit tests for all functions
- Use Firebase emulators for integration testing
- Test both success and failure paths
- Mock external dependencies
- Aim for high test coverage

### 3. Logging

- Use structured logging
- Log at appropriate levels (debug, info, warning, error)
- Include context in log messages
- Use correlation IDs for tracking requests
- Don't log sensitive information

### 4. Performance

- Keep functions lightweight
- Minimize database operations
- Use batch operations for multiple updates
- Implement proper indexing for queries
- Monitor function execution time and resource usage

### 5. Security

- Implement proper authentication and authorization
- Validate all input data
- Use Firestore security rules
- Follow the principle of least privilege
- Never expose sensitive data
