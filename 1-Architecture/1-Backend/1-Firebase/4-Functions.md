# Firebase Functions

## Purpose

This document outlines the architecture, patterns, and best practices for implementing Firebase Cloud Functions.

## Core Principles

### Type Safety

- Use TypeScript for all Cloud Functions
- Define interfaces for request and response data
- Implement type-safe database operations
- Create typed utility functions

### Modularity/Composability

- Organize functions by domain
- Implement middleware pattern for common operations
- Create reusable utility functions
- Design composable function chains

### Testability

- Write unit tests for all functions
- Use Firebase Emulator for integration testing
- Implement test fixtures and factories
- Design deterministic function behavior for testing

## Content Structure

### Function Organization

#### Project Structure

Our Cloud Functions project follows a domain-driven structure:

```
functions/
├── src/
│   ├── auth/
│   │   ├── onUserCreate.ts
│   │   ├── onUserDelete.ts
│   │   └── index.ts
│   ├── users/
│   │   ├── getUserProfile.ts
│   │   ├── updateUserProfile.ts
│   │   └── index.ts
│   ├── notifications/
│   │   ├── sendPushNotification.ts
│   │   ├── scheduleNotification.ts
│   │   └── index.ts
│   ├── utils/
│   │   ├── database.ts
│   │   ├── validation.ts
│   │   └── logger.ts
│   ├── middleware/
│   │   ├── auth.ts
│   │   ├── validation.ts
│   │   └── errorHandler.ts
│   └── index.ts
├── test/
│   ├── auth/
│   ├── users/
│   ├── notifications/
│   └── utils/
└── package.json
```

#### Function Types

We implement the following types of functions:

1. **HTTP Functions**: RESTful API endpoints
2. **Firestore Triggers**: Functions triggered by database events
3. **Authentication Triggers**: Functions triggered by auth events
4. **Storage Triggers**: Functions triggered by storage events
5. **Scheduled Functions**: Functions that run on a schedule
6. **Callable Functions**: Functions that can be called directly from client apps

### Implementation Patterns

#### HTTP Functions

```typescript
// Example: HTTP function
export const getUserProfile = functions.https.onRequest(async (req, res) => {
  try {
    // Apply middleware
    const authResult = await authMiddleware(req);
    if (!authResult.success) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    // Validate request
    const userId = req.query.userId as string;
    if (!userId) {
      return res.status(400).json({ error: 'Missing userId parameter' });
    }

    // Get user profile
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Return response
    return res.status(200).json({
      userId: userDoc.id,
      ...userDoc.data()
    });
  } catch (error) {
    console.error('Error getting user profile:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});
```

#### Firestore Triggers

```typescript
// Example: Firestore trigger
export const onUserUpdate = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    try {
      const userId = context.params.userId;
      const beforeData = change.before.data();
      const afterData = change.after.data();

      // Check if relevant fields changed
      if (beforeData.displayName === afterData.displayName &&
          beforeData.photoURL === afterData.photoURL) {
        return null; // No relevant changes
      }

      // Update related documents
      const batch = admin.firestore().batch();

      // Get all posts by this user
      const postsSnapshot = await admin.firestore()
        .collection('posts')
        .where('authorId', '==', userId)
        .get();

      // Update author info in each post
      postsSnapshot.docs.forEach(doc => {
        batch.update(doc.ref, {
          authorName: afterData.displayName,
          authorPhotoURL: afterData.photoURL
        });
      });

      // Commit the batch
      return batch.commit();
    } catch (error) {
      console.error('Error in onUserUpdate:', error);
      return null;
    }
  });
```

#### Authentication Triggers

```typescript
// Example: Authentication trigger
export const onUserCreate = functions.auth.user().onCreate(async (user) => {
  try {
    // Create user profile in Firestore
    await admin.firestore().collection('users').doc(user.uid).set({
      uid: user.uid,
      email: user.email,
      displayName: user.displayName || '',
      photoURL: user.photoURL || '',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Set custom claims
    await admin.auth().setCustomUserClaims(user.uid, {
      role: 'user',
      premiumUser: false
    });

    // Send welcome email
    await sendWelcomeEmail(user.email);

    return null;
  } catch (error) {
    console.error('Error in onUserCreate:', error);
    return null;
  }
});
```

#### Callable Functions

```typescript
// Example: Callable function
interface UpdateProfileData {
  displayName?: string;
  photoURL?: string;
  bio?: string;
}

export const updateProfile = functions.https.onCall(async (data: UpdateProfileData, context) => {
  // Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.'
    );
  }

  // Validate data
  if (!data.displayName && !data.photoURL && !data.bio) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'At least one field must be provided.'
    );
  }

  try {
    // Update profile
    const userId = context.auth.uid;
    const updateData: Record<string, any> = {};

    if (data.displayName) updateData.displayName = data.displayName;
    if (data.photoURL) updateData.photoURL = data.photoURL;
    if (data.bio) updateData.bio = data.bio;

    await admin.firestore().collection('users').doc(userId).update(updateData);

    return { success: true };
  } catch (error) {
    console.error('Error updating profile:', error);
    throw new functions.https.HttpsError(
      'internal',
      'An error occurred while updating the profile.'
    );
  }
});
```

### Middleware Pattern

Implement reusable middleware:

```typescript
// Example: Authentication middleware
export interface AuthResult {
  success: boolean;
  uid?: string;
  error?: string;
}

export async function authMiddleware(req: functions.https.Request): Promise<AuthResult> {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return { success: false, error: 'Missing or invalid authorization header' };
    }

    const idToken = authHeader.split('Bearer ')[1];
    const decodedToken = await admin.auth().verifyIdToken(idToken);

    return {
      success: true,
      uid: decodedToken.uid
    };
  } catch (error) {
    console.error('Auth middleware error:', error);
    return {
      success: false,
      error: 'Invalid authentication token'
    };
  }
}
```

## Error Handling

### Error Classification

We classify Cloud Function errors into the following categories:

- **Authentication Errors**: Issues with user authentication or authorization
- **Validation Errors**: Invalid input data or parameters
- **Resource Errors**: Problems accessing required resources (Firestore, Storage, etc.)
- **Business Logic Errors**: Errors in application-specific logic
- **External Service Errors**: Issues with third-party services
- **Infrastructure Errors**: Problems with the Cloud Functions infrastructure

### Structured Error Handling

```typescript
// Example: Structured error handling with custom error classes

// Base error class for all function errors
export class FunctionError extends Error {
  constructor(
    public readonly code: string,
    message: string,
    public readonly details?: any,
    public readonly httpStatus: number = 500
  ) {
    super(message);
    this.name = this.constructor.name;
  }

  // Convert to HttpsError for callable functions
  toHttpsError(): functions.https.HttpsError {
    return new functions.https.HttpsError(
      this.code as any,
      this.message,
      this.details
    );
  }

  // Convert to HTTP response for HTTP functions
  toHttpResponse(): { status: number; body: ErrorResponse } {
    return {
      status: this.httpStatus,
      body: {
        code: this.code,
        message: this.message,
        details: this.details
      }
    };
  }
}

// Specific error types
export class AuthenticationError extends FunctionError {
  constructor(message: string, details?: any) {
    super('unauthenticated', message, details, 401);
  }
}

export class AuthorizationError extends FunctionError {
  constructor(message: string, details?: any) {
    super('permission-denied', message, details, 403);
  }
}

export class ValidationError extends FunctionError {
  constructor(message: string, details?: any) {
    super('invalid-argument', message, details, 400);
  }
}

export class NotFoundError extends FunctionError {
  constructor(message: string, details?: any) {
    super('not-found', message, details, 404);
  }
}

export class ConflictError extends FunctionError {
  constructor(message: string, details?: any) {
    super('already-exists', message, details, 409);
  }
}

export class InternalError extends FunctionError {
  constructor(message: string, details?: any) {
    super('internal', message, details, 500);
  }
}

// Error handler utility
export function handleError(error: any): ErrorResponse {
  // Log the error with stack trace for debugging
  console.error('Function error:', error);

  // If it's already our custom error, use it directly
  if (error instanceof FunctionError) {
    return {
      code: error.code,
      message: error.message,
      details: error.details
    };
  }

  // Handle Firebase errors
  if (error instanceof functions.https.HttpsError) {
    return {
      code: error.code,
      message: error.message,
      details: error.details
    };
  }

  // Handle Firestore errors
  if (error.code && error.name === 'FirebaseError') {
    // Map Firebase error codes to our error codes
    const codeMap: Record<string, string> = {
      'permission-denied': 'permission-denied',
      'not-found': 'not-found',
      'already-exists': 'already-exists',
      'resource-exhausted': 'resource-exhausted',
      'failed-precondition': 'failed-precondition',
      'aborted': 'aborted',
      'out-of-range': 'out-of-range',
      'unimplemented': 'unimplemented',
      'unavailable': 'unavailable',
      'data-loss': 'data-loss',
      'unauthenticated': 'unauthenticated'
    };

    return {
      code: codeMap[error.code] || 'internal',
      message: error.message,
      details: error
    };
  }

  // For unknown errors, return a generic internal error
  return {
    code: 'internal',
    message: 'An unexpected error occurred',
    details: process.env.NODE_ENV === 'development' ? error : undefined
  };
}
```

## Testing

### Unit Testing Strategy

We implement a comprehensive unit testing strategy for all Cloud Functions:

1. **Isolated Testing**: Test each function in isolation with mocked dependencies
2. **Test Categories**: Test success cases, error cases, and edge cases
3. **Mocking Strategy**: Use dependency injection for easier mocking
4. **Coverage Goals**: Aim for >90% code coverage for all functions

### Unit Testing with Jest

```typescript
// Example: Unit test for HTTP function using Jest and TypeScript
import * as admin from 'firebase-admin';
import { Request, Response } from 'firebase-functions';
import { getUserProfile } from '../src/users/getUserProfile';
import { authMiddleware } from '../src/middleware/auth';

// Mock Firebase Admin SDK
jest.mock('firebase-admin', () => ({
  firestore: jest.fn().mockReturnValue({
    collection: jest.fn().mockReturnThis(),
    doc: jest.fn().mockReturnThis(),
    get: jest.fn()
  })
}));

// Mock auth middleware
jest.mock('../src/middleware/auth', () => ({
  authMiddleware: jest.fn()
}));

describe('getUserProfile', () => {
  let req: Partial<Request>;
  let res: Partial<Response>;

  beforeEach(() => {
    // Reset mocks
    jest.clearAllMocks();

    // Setup request and response objects
    req = {
      query: { userId: 'user123' },
      headers: { authorization: 'Bearer valid-token' }
    };

    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis()
    };

    // Mock successful authentication
    (authMiddleware as jest.Mock).mockResolvedValue({
      success: true,
      uid: 'user123'
    });
  });

  test('should return user profile for valid userId', async () => {
    // Mock Firestore response
    const mockUserDoc = {
      exists: true,
      id: 'user123',
      data: () => ({
        displayName: 'Test User',
        email: 'test@example.com'
      })
    };

    admin.firestore().collection().doc().get.mockResolvedValue(mockUserDoc);

    // Call the function
    await getUserProfile(req as Request, res as Response);

    // Verify Firestore was called correctly
    expect(admin.firestore().collection).toHaveBeenCalledWith('users');
    expect(admin.firestore().collection().doc).toHaveBeenCalledWith('user123');

    // Verify response
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      userId: 'user123',
      displayName: 'Test User',
      email: 'test@example.com'
    });
  });

  test('should return 401 when authentication fails', async () => {
    // Mock failed authentication
    (authMiddleware as jest.Mock).mockResolvedValue({
      success: false,
      error: 'Invalid token'
    });

    // Call the function
    await getUserProfile(req as Request, res as Response);

    // Verify response
    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({ error: 'Unauthorized' });

    // Verify Firestore was not called
    expect(admin.firestore().collection().doc().get).not.toHaveBeenCalled();
  });

  test('should return 404 when user not found', async () => {
    // Mock user not found
    const mockUserDoc = {
      exists: false
    };

    admin.firestore().collection().doc().get.mockResolvedValue(mockUserDoc);

    // Call the function
    await getUserProfile(req as Request, res as Response);

    // Verify response
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith({ error: 'User not found' });
  });

  test('should handle database errors properly', async () => {
    // Mock database error
    admin.firestore().collection().doc().get.mockRejectedValue(
      new Error('Database connection failed')
    );

    // Call the function
    await getUserProfile(req as Request, res as Response);

    // Verify response
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      error: 'Internal server error'
    });
  });
});
```

### Integration Testing with Firebase Emulator

```typescript
// Example: Integration test with Firebase Emulator
import * as firebase from '@firebase/testing';
import * as functions from 'firebase-functions-test';
import * as admin from 'firebase-admin';
import { getUserProfile } from '../src/users/getUserProfile';

const projectId = 'test-project';
const test = functions.default();

describe('getUserProfile Integration', () => {
  let adminApp: admin.app.App;
  let db: admin.firestore.Firestore;

  beforeAll(async () => {
    // Initialize the Firebase emulator
    adminApp = admin.initializeApp({
      projectId
    });

    db = adminApp.firestore();

    // Clear the database between tests
    await firebase.clearFirestoreData({ projectId });
  });

  afterAll(async () => {
    await adminApp.delete();
    test.cleanup();
  });

  beforeEach(async () => {
    // Seed the database with test data
    await db.collection('users').doc('test-user').set({
      displayName: 'Test User',
      email: 'test@example.com',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
  });

  test('should return user profile from real Firestore', async () => {
    // Create wrapped function
    const wrappedFunction = test.wrap(getUserProfile);

    // Mock request and context
    const req = {
      query: { userId: 'test-user' },
      headers: { authorization: 'Bearer valid-token' }
    };

    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };

    // Mock auth middleware (in a real test, you might use the actual middleware)
    jest.mock('../src/middleware/auth', () => ({
      authMiddleware: jest.fn().mockResolvedValue({
        success: true,
        uid: 'test-user'
      })
    }));

    // Call the function
    await wrappedFunction(req, res);

    // Verify response
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      userId: 'test-user',
      displayName: 'Test User',
      email: 'test@example.com'
    }));
  });
});
```

### Performance Testing

```typescript
// Example: Performance test for a function
describe('Function Performance', () => {
  test('should process 100 documents in under 2 seconds', async () => {
    // Setup test data
    const documents = Array.from({ length: 100 }).map((_, i) => ({
      id: `doc-${i}`,
      data: { value: `test-${i}` }
    }));

    // Mock Firestore batch
    const batchCommitMock = jest.fn().mockResolvedValue(null);
    const batchUpdateMock = jest.fn().mockReturnThis();
    const batchMock = {
      update: batchUpdateMock,
      commit: batchCommitMock
    };

    admin.firestore().batch.mockReturnValue(batchMock);

    // Measure execution time
    const startTime = Date.now();

    await processBatch(documents);

    const endTime = Date.now();
    const executionTime = endTime - startTime;

    // Verify performance
    expect(executionTime).toBeLessThan(2000); // Less than 2 seconds
    expect(batchUpdateMock).toHaveBeenCalledTimes(100);
    expect(batchCommitMock).toHaveBeenCalledTimes(1);
  });
});
```

### Test Coverage and Reporting

We use Jest's built-in coverage reporting to ensure comprehensive test coverage:

```json
// Example: Jest configuration in package.json
{
  "jest": {
    "preset": "ts-jest",
    "testEnvironment": "node",
    "collectCoverage": true,
    "coverageReporters": ["text", "lcov"],
    "coverageThreshold": {
      "global": {
        "branches": 80,
        "functions": 90,
        "lines": 90,
        "statements": 90
      }
    }
  }
}
```
```

## Best Practices

* Organize functions by domain
* Implement proper error handling
* Use TypeScript for type safety
* Create reusable middleware
* Implement comprehensive logging
* Use batched writes for multiple document updates
* Optimize database queries
* Implement proper security checks
* Write comprehensive tests
* Use environment variables for configuration

## Anti-patterns

* Monolithic functions that do too much
* Insufficient error handling
* Missing authentication checks
* Inefficient database queries
* Hardcoded configuration values
* Lack of logging
* Missing type definitions
* Insufficient testing
* Directly exposing internal errors to clients
* Ignoring function timeout limits