# Firebase Database

## Purpose

This document outlines the database architecture, patterns, and best practices for implementing data storage and retrieval with Firebase Firestore.

## Core Principles

### Type Safety

- Define TypeScript interfaces for all document types
- Implement validation functions for data integrity
- Use typed references and queries
- Implement converters for type-safe document access

### Modularity/Composability

- Organize collections by domain
- Implement repository pattern for data access
- Create reusable query builders
- Design composable security rules

### Testability

- Create mock repositories for unit testing
- Use Firebase Emulator for integration testing
- Implement test data factories
- Design deterministic query results for testing

## Content Structure

### Database Organization

#### Collection Organization

Our Firestore database is organized using the following patterns:

1. **Root-level collections** for primary entities
2. **Subcollections** for related data that belongs to a specific document
3. **Collection groups** for querying across subcollections

#### Document Design

Documents are designed with the following considerations:

1. **Size limitations**: Keep documents under 1MB
2. **Access patterns**: Structure documents based on how they will be accessed
3. **Update frequency**: Separate frequently updated fields
4. **Denormalization**: Strategic duplication for query efficiency

### Data Access Patterns

#### Repository Pattern

We implement the repository pattern to abstract Firestore operations:

```typescript
// Example: User repository
export interface UserRepository {
  getUser(id: string): Promise<User | null>;
  createUser(user: User): Promise<string>;
  updateUser(id: string, data: Partial<User>): Promise<void>;
  deleteUser(id: string): Promise<void>;
  queryUsers(criteria: UserQueryCriteria): Promise<User[]>;
}

export class FirestoreUserRepository implements UserRepository {
  private collection = collection(firestore, 'users');

  async getUser(id: string): Promise<User | null> {
    const docRef = doc(this.collection, id);
    const docSnap = await getDoc(docRef);
    return docSnap.exists() ? docSnap.data() as User : null;
  }

  // Other methods...
}
```

#### Query Optimization

Optimize queries using:

1. **Compound indexes** for complex queries
2. **Limit operations** to reduce document reads
3. **Cursor pagination** for large result sets
4. **Denormalization** to avoid joins

### Security Rules

#### Collection-Level Rules

```javascript
// Example: Collection-level security
match /users/{userId} {
  allow read: if request.auth != null;
  allow write: if request.auth != null && request.auth.uid == userId;
}
```

#### Field-Level Security

```javascript
// Example: Field-level security
match /users/{userId} {
  allow read: if request.auth != null;
  allow update: if request.auth != null && request.auth.uid == userId
                && request.resource.data.diff(resource.data).affectedKeys()
                   .hasOnly(['displayName', 'photoURL', 'settings']);
}
```

#### Function-Based Rules

```javascript
// Example: Function-based validation
match /posts/{postId} {
  allow create: if request.auth != null
                && request.resource.data.authorId == request.auth.uid
                && isValidPost(request.resource.data);
}

function isValidPost(post) {
  return post.title is string && post.title.size() <= 100
      && post.content is string
      && post.createdAt is timestamp;
}
```

### Data Modeling

#### One-to-One Relationships

```
users/{userId}
userProfiles/{userId}
```

#### One-to-Many Relationships

```
users/{userId}
users/{userId}/posts/{postId}
```

#### Many-to-Many Relationships

```
users/{userId}
groups/{groupId}
groupMembers/{membershipId} // Contains userId and groupId
```

### Real-time Updates

Implement real-time updates using:

1. **Document listeners** for single document updates
2. **Collection listeners** for list updates
3. **Query listeners** for filtered data

## Error Handling

### Database Error Categories

- **Permission Errors**: Security rule violations
- **Validation Errors**: Data that doesn't meet schema requirements
- **Availability Errors**: Service disruptions or quota limits
- **Network Errors**: Connection issues affecting database operations
- **Consistency Errors**: Transaction failures or conflicts

### Structured Error Handling

```typescript
// Example: Repository with structured error handling
export class FirestoreUserRepository implements UserRepository {
  private collection = collection(firestore, 'users');

  async getUser(id: string): Promise<User | null> {
    try {
      const docRef = doc(this.collection, id);
      const docSnap = await getDoc(docRef);
      return docSnap.exists() ? docSnap.data() as User : null;
    } catch (error) {
      if (error instanceof FirebaseError) {
        switch (error.code) {
          case 'permission-denied':
            throw new DatabaseError('You do not have permission to access this user.', 'PERMISSION_DENIED', error);
          case 'unavailable':
          case 'resource-exhausted':
            // Implement exponential backoff retry
            throw new DatabaseError('Database service temporarily unavailable.', 'SERVICE_UNAVAILABLE', error);
          default:
            // Log unexpected errors
            logger.error('Database error:', error);
            throw new DatabaseError('An unexpected database error occurred.', 'UNKNOWN_ERROR', error);
        }
      }
      throw error; // Re-throw non-Firebase errors
    }
  }
}
```

### Retry Mechanisms

```typescript
// Example: Retry utility with exponential backoff
async function withRetry<T>(
  operation: () => Promise<T>,
  maxRetries = 3,
  initialDelay = 300
): Promise<T> {
  let lastError: Error;
  let retryCount = 0;

  while (retryCount <= maxRetries) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;

      // Only retry on specific error types that are likely transient
      if (error instanceof FirebaseError) {
        if (!['unavailable', 'resource-exhausted', 'deadline-exceeded'].includes(error.code)) {
          throw error; // Don't retry permanent errors
        }
      } else {
        throw error; // Don't retry non-Firebase errors
      }

      // Exponential backoff with jitter
      const delay = initialDelay * Math.pow(2, retryCount) * (0.5 + Math.random() * 0.5);
      await new Promise(resolve => setTimeout(resolve, delay));
      retryCount++;
    }
  }

  throw lastError;
}
```

### Offline Handling

- Enable offline persistence for critical applications
- Implement optimistic UI updates with pending operation tracking
- Provide clear offline indicators to users
- Synchronize data when connection is restored

### Error Logging and Monitoring

- Log detailed error information for debugging
- Implement structured error logging with context
- Set up monitoring alerts for critical error patterns
- Track error rates and types for proactive resolution

## Testing

### Unit Testing Repositories

```typescript
// Example: Unit test for user repository
describe('FirestoreUserRepository', () => {
  let repository: FirestoreUserRepository;
  let mockFirestore: jest.Mocked<Firestore>;

  beforeEach(() => {
    // Mock Firestore and its methods
    mockFirestore = {
      collection: jest.fn(),
      doc: jest.fn(),
      getDoc: jest.fn(),
      setDoc: jest.fn(),
      updateDoc: jest.fn(),
      deleteDoc: jest.fn(),
      // Other methods...
    } as unknown as jest.Mocked<Firestore>;

    repository = new FirestoreUserRepository(mockFirestore);
  });

  describe('getUser', () => {
    it('should return user when document exists', async () => {
      // Arrange
      const mockUser = { id: 'user123', name: 'Test User', email: 'test@example.com' };
      const mockDocSnap = {
        exists: () => true,
        data: () => mockUser
      };
      mockFirestore.getDoc.mockResolvedValue(mockDocSnap as any);

      // Act
      const result = await repository.getUser('user123');

      // Assert
      expect(mockFirestore.doc).toHaveBeenCalledWith(expect.anything(), 'user123');
      expect(mockFirestore.getDoc).toHaveBeenCalled();
      expect(result).toEqual(mockUser);
    });

    it('should return null when document does not exist', async () => {
      // Arrange
      const mockDocSnap = {
        exists: () => false,
        data: () => null
      };
      mockFirestore.getDoc.mockResolvedValue(mockDocSnap as any);

      // Act
      const result = await repository.getUser('nonexistent');

      // Assert
      expect(result).toBeNull();
    });

    it('should handle errors properly', async () => {
      // Arrange
      const mockError = new Error('Database error');
      mockError.code = 'permission-denied';
      mockFirestore.getDoc.mockRejectedValue(mockError);

      // Act & Assert
      await expect(repository.getUser('user123'))
        .rejects
        .toThrow('You do not have permission to access this user.');
    });
  });
});
```

### Integration Testing with Emulator

```typescript
// Example: Integration test with Firebase Emulator
import * as firebase from '@firebase/testing';

const PROJECT_ID = 'test-db-project';

describe('User Database Operations', () => {
  let app: firebase.app.App;
  let db: firebase.firestore.Firestore;

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
    db = app.firestore();
  });

  it('should create and retrieve a user document', async () => {
    // Create test user
    const userRef = db.collection('users').doc('test-user');
    await userRef.set({
      name: 'Test User',
      email: 'test@example.com',
      createdAt: firebase.firestore.FieldValue.serverTimestamp()
    });

    // Retrieve and verify
    const docSnap = await userRef.get();
    expect(docSnap.exists).toBe(true);
    expect(docSnap.data().name).toBe('Test User');
  });
});
```

### Security Rules Testing

```typescript
// Example: Security rules test
describe('Firestore Security Rules', () => {
  let adminApp: firebase.app.App;
  let userApp: firebase.app.App;
  let unauthApp: firebase.app.App;

  beforeAll(async () => {
    // Load security rules
    await firebase.loadFirestoreRules({
      projectId: PROJECT_ID,
      rules: fs.readFileSync('firestore.rules', 'utf8')
    });
  });

  beforeEach(() => {
    // Initialize test apps with different auth states
    adminApp = firebase.initializeTestApp({
      projectId: PROJECT_ID,
      auth: { uid: 'admin', email: 'admin@example.com', admin: true }
    });

    userApp = firebase.initializeTestApp({
      projectId: PROJECT_ID,
      auth: { uid: 'user123', email: 'user@example.com' }
    });

    unauthApp = firebase.initializeTestApp({
      projectId: PROJECT_ID,
      auth: null
    });
  });

  describe('User collection rules', () => {
    it('should allow users to read their own document', async () => {
      const db = userApp.firestore();
      const userRef = db.collection('users').doc('user123');
      await firebase.assertSucceeds(userRef.get());
    });

    it('should deny users from reading other user documents', async () => {
      const db = userApp.firestore();
      const otherUserRef = db.collection('users').doc('other-user');
      await firebase.assertFails(otherUserRef.get());
    });

    it('should allow admins to read any user document', async () => {
      const db = adminApp.firestore();
      const anyUserRef = db.collection('users').doc('any-user');
      await firebase.assertSucceeds(anyUserRef.get());
    });
  });
});
```

### Performance Testing

- Test query performance with realistic data volumes
- Measure and optimize read/write operations
- Verify index effectiveness for complex queries
- Test pagination strategies with large collections

## Best Practices

* Design the database structure based on query patterns
* Use batch operations for atomic updates across documents
* Implement pagination for large collections
* Use transactions for operations that require consistency
* Cache frequently accessed data on the client
* Implement proper error handling for database operations
* Use security rules to enforce data validation
* Implement proper indexing for all queries
* Use server timestamps for time-based operations

## Anti-patterns

* Deeply nested subcollections (more than 2-3 levels)
* Storing large binary data in documents (use Storage instead)
* Creating collection references in loops
* Querying without indexes
* Updating documents in tight loops
* Relying on client-side filtering instead of proper queries
* Using arrays for many-to-many relationships
* Storing sensitive data without proper security rules
* Creating monolithic documents with all related data