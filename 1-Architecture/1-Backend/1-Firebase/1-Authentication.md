# Firebase Authentication

## Purpose

This document outlines the authentication architecture, patterns, and best practices for implementing user authentication with Firebase Authentication.

## Core Principles

### Type Safety

- Use TypeScript interfaces to define user profile structures
- Implement type-safe custom claims management
- Define type-safe authentication state in client applications

### Modularity/Composability

- Separate authentication logic from business logic
- Create reusable authentication components
- Implement composable security rules that can be combined

### Testability

- Mock Firebase Authentication for unit tests
- Use Firebase Emulator for integration tests
- Create test utilities for authentication state simulation

## Content Structure

### Authentication Methods

Our architecture supports the following authentication methods:

- Email/Password authentication
- Phone number authentication
- OAuth providers (Google, Apple, etc.)
- Anonymous authentication (for guest access)

### User Management

### User Profiles

User profiles are stored in two locations:

1. **Firebase Authentication**: Basic identity information
   - UID
   - Email
   - Phone number
   - Provider information

2. **Firestore**: Extended profile information
   - Display name
   - Profile picture
   - User preferences
   - Application-specific data

### Custom Claims

Custom claims are used to store role-based access control information:

- Admin status
- User roles
- Subscription status
- Account verification status

Custom claims are managed through Firebase Cloud Functions to ensure security.

### Security Rules

### Authentication-Based Rules

```javascript
// Example: Basic authentication check
match /documents/{document=**} {
  allow read: if request.auth != null;
}
```

### Role-Based Rules

```javascript
// Example: Role-based access control
match /adminDocuments/{document=**} {
  allow read, write: if request.auth != null && request.auth.token.admin == true;
}
```

### User-Specific Rules

```javascript
// Example: User-specific data access
match /users/{userId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

## Error Handling

### Authentication Error Types

- **Validation Errors**: Issues with user input (invalid email, weak password)
- **Authentication Errors**: Failed sign-in attempts, invalid credentials
- **Network Errors**: Connection issues affecting authentication
- **Permission Errors**: Unauthorized access attempts
- **Token Errors**: Expired or invalid tokens

### Error Handling Strategy

```typescript
// Example: Structured error handling
async function signInWithEmailAndPassword(email: string, password: string): Promise<User> {
  try {
    const userCredential = await firebase.auth().signInWithEmailAndPassword(email, password);
    return userCredential.user;
  } catch (error) {
    // Categorize and handle specific error types
    switch (error.code) {
      case 'auth/invalid-email':
        throw new AuthError('The email address is not valid.', 'INVALID_EMAIL');
      case 'auth/user-disabled':
        throw new AuthError('This user account has been disabled.', 'ACCOUNT_DISABLED');
      case 'auth/user-not-found':
      case 'auth/wrong-password':
        // Security best practice: don't reveal which one is incorrect
        throw new AuthError('Invalid email or password.', 'INVALID_CREDENTIALS');
      default:
        // Log unexpected errors for monitoring
        logger.error('Authentication error:', error);
        throw new AuthError('An unexpected error occurred. Please try again.', 'UNKNOWN_ERROR');
    }
  }
}
```

### Client-Side Error Presentation

- Display user-friendly error messages
- Provide actionable recovery steps
- Maintain security by not revealing sensitive information
- Implement progressive retry mechanisms

### Server-Side Error Handling

- Log detailed error information for debugging
- Implement rate limiting for failed authentication attempts
- Monitor authentication errors for security threats
- Implement proper error responses in Cloud Functions

## Testing

### Unit Testing Authentication Logic

```typescript
// Example: Unit test for authentication logic
describe('Authentication Service', () => {
  let authService: AuthService;
  let mockAuth: jest.Mocked<Auth>;

  beforeEach(() => {
    mockAuth = {
      signInWithEmailAndPassword: jest.fn(),
      createUserWithEmailAndPassword: jest.fn(),
      signOut: jest.fn(),
      // Other methods...
    } as unknown as jest.Mocked<Auth>;

    authService = new AuthService(mockAuth);
  });

  describe('signIn', () => {
    it('should sign in user with valid credentials', async () => {
      // Arrange
      const mockUser = { uid: 'user123', email: 'test@example.com' };
      mockAuth.signInWithEmailAndPassword.mockResolvedValue({ user: mockUser } as any);

      // Act
      const result = await authService.signIn('test@example.com', 'password123');

      // Assert
      expect(mockAuth.signInWithEmailAndPassword).toHaveBeenCalledWith('test@example.com', 'password123');
      expect(result).toEqual(mockUser);
    });

    it('should handle authentication errors properly', async () => {
      // Arrange
      const authError = new Error('auth/wrong-password');
      authError.code = 'auth/wrong-password';
      mockAuth.signInWithEmailAndPassword.mockRejectedValue(authError);

      // Act & Assert
      await expect(authService.signIn('test@example.com', 'wrong-password'))
        .rejects
        .toThrow('Invalid email or password.');
    });
  });

  describe('createUser', () => {
    it('should create a new user with valid information', async () => {
      // Arrange
      const mockUser = { uid: 'newuser123', email: 'newuser@example.com' };
      mockAuth.createUserWithEmailAndPassword.mockResolvedValue({ user: mockUser } as any);

      // Act
      const result = await authService.createUser('newuser@example.com', 'securePassword123');

      // Assert
      expect(mockAuth.createUserWithEmailAndPassword).toHaveBeenCalledWith('newuser@example.com', 'securePassword123');
      expect(result).toEqual(mockUser);
    });

    it('should handle email-already-in-use error', async () => {
      // Arrange
      const authError = new Error('auth/email-already-in-use');
      authError.code = 'auth/email-already-in-use';
      mockAuth.createUserWithEmailAndPassword.mockRejectedValue(authError);

      // Act & Assert
      await expect(authService.createUser('existing@example.com', 'password123'))
        .rejects
        .toThrow('This email is already in use. Please use a different email or try signing in.');
    });
  });
});
```

### Integration Testing with Firebase Emulator

- Set up Firebase Emulator Suite for testing
- Create test users and authentication scenarios
- Test complete authentication flows
- Verify token generation and validation

```typescript
// Example: Integration test setup with Firebase Emulator
import * as firebase from '@firebase/testing';

const PROJECT_ID = 'test-auth-project';

describe('Authentication Integration Tests', () => {
  let app: firebase.app.App;

  beforeAll(async () => {
    // Clear Firebase emulator data
    await firebase.clearFirestoreData({ projectId: PROJECT_ID });
  });

  afterAll(async () => {
    await Promise.all(firebase.apps().map(app => app.delete()));
  });

  beforeEach(() => {
    app = firebase.initializeTestApp({
      projectId: PROJECT_ID,
      auth: { uid: 'test-user', email: 'test@example.com' }
    });
  });

  it('should allow authenticated users to read their profile', async () => {
    const db = app.firestore();
    const profileRef = db.collection('users').doc('test-user');
    await firebase.assertSucceeds(profileRef.get());
  });

  it('should deny unauthenticated access to user profiles', async () => {
    const unauthApp = firebase.initializeTestApp({
      projectId: PROJECT_ID,
      auth: null
    });
    const db = unauthApp.firestore();
    const profileRef = db.collection('users').doc('test-user');
    await firebase.assertFails(profileRef.get());
  });
});
```

### Security Rules Testing

- Test all security rule conditions
- Verify role-based access control
- Test edge cases and boundary conditions
- Ensure proper denial of unauthorized access

## Best Practices

* Always verify authentication state on both client and server
* Use custom claims for role-based access control
* Implement proper token refresh handling
* Store minimal information in the authentication profile
* Use security rules to enforce access control at the data level
* Implement proper error handling for authentication failures
* Use multi-factor authentication for sensitive operations
* Implement email verification for new accounts
* Use secure password policies

## Anti-patterns

* Storing sensitive user data in authentication custom claims
* Relying solely on client-side authentication checks
* Hardcoding user roles or permissions in client code
* Using Firebase Admin SDK in client applications
* Storing authentication tokens insecurely
* Implementing custom authentication without proper security review
* Not validating email addresses
* Using weak password requirements