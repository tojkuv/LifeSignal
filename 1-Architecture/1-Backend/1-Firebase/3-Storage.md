# Firebase Storage

## Purpose

This document outlines the storage architecture, patterns, and best practices for implementing file storage with Firebase Storage.

## Core Principles

### Type Safety

- Define TypeScript interfaces for metadata
- Implement type-safe upload and download functions
- Use typed references for storage operations
- Create type-safe metadata validation

### Modularity/Composability

- Organize storage by domain
- Implement repository pattern for storage access
- Create reusable storage utilities
- Design composable security rules

### Testability

- Create mock storage repositories for unit testing
- Use Firebase Emulator for integration testing
- Implement test utilities for file operations
- Design deterministic file paths for testing

## Content Structure

### Storage Organization

#### Folder Structure

Our Firebase Storage is organized using the following pattern:

```
/
├── users/
│   └── {userId}/
│       ├── profile/
│       │   └── avatar.jpg
│       └── documents/
│           └── {documentId}.pdf
├── public/
│   └── assets/
│       ├── images/
│       └── videos/
└── temporary/
    └── {tempId}/
        └── upload.jpg
```

#### Path Conventions

Storage paths follow these conventions:

1. **User-specific files**: `/users/{userId}/{fileType}/{fileName}`
2. **Public files**: `/public/{category}/{subcategory}/{fileName}`
3. **Temporary files**: `/temporary/{tempId}/{fileName}`

### File Operations

#### Upload Operations

Implement secure and efficient uploads:

```typescript
// Example: Upload function
async function uploadUserAvatar(userId: string, file: File): Promise<string> {
  const storageRef = ref(storage, `users/${userId}/profile/avatar.jpg`);
  const metadata = {
    contentType: file.type,
    customMetadata: {
      uploadedBy: userId,
      uploadedAt: new Date().toISOString()
    }
  };

  await uploadBytes(storageRef, file, metadata);
  return await getDownloadURL(storageRef);
}
```

#### Download Operations

Implement efficient downloads:

```typescript
// Example: Download function
async function getUserAvatar(userId: string): Promise<string> {
  const storageRef = ref(storage, `users/${userId}/profile/avatar.jpg`);
  try {
    return await getDownloadURL(storageRef);
  } catch (error) {
    if ((error as StorageError).code === 'storage/object-not-found') {
      return DEFAULT_AVATAR_URL;
    }
    throw error;
  }
}
```

#### Delete Operations

Implement secure delete operations:

```typescript
// Example: Delete function
async function deleteUserAvatar(userId: string): Promise<void> {
  const storageRef = ref(storage, `users/${userId}/profile/avatar.jpg`);
  try {
    await deleteObject(storageRef);
  } catch (error) {
    if ((error as StorageError).code !== 'storage/object-not-found') {
      throw error;
    }
  }
}
```

### Security Rules

#### User-Specific Rules

```javascript
// Example: User-specific file access
match /users/{userId}/{allPaths=**} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow write: if request.auth != null && request.auth.uid == userId
               && request.resource.size < 5 * 1024 * 1024
               && request.resource.contentType.matches('image/.*');
}
```

#### Public Access Rules

```javascript
// Example: Public file access
match /public/{allPaths=**} {
  allow read: if true;
  allow write: if request.auth != null && request.auth.token.admin == true;
}
```

#### Temporary File Rules

```javascript
// Example: Temporary file access
match /temporary/{tempId}/{allPaths=**} {
  allow read, write: if request.auth != null
                     && request.time < resource.metadata.expiry;
}
```

### Metadata Management

Implement consistent metadata:

```typescript
// Example: Metadata interface
interface FileMetadata {
  contentType: string;
  size: number;
  createdBy: string;
  createdAt: string;
  tags?: string[];
  description?: string;
}

// Example: Setting metadata
async function setFileMetadata(path: string, metadata: FileMetadata): Promise<void> {
  const storageRef = ref(storage, path);
  await updateMetadata(storageRef, {
    customMetadata: {
      ...metadata,
      createdAt: metadata.createdAt || new Date().toISOString(),
      createdBy: metadata.createdBy
    }
  });
}
```

### File Processing

Implement file processing workflows:

1. **Client-side processing**: Resize/compress before upload
2. **Cloud Functions triggers**: Process files after upload
3. **Temporary to permanent**: Move from temporary to permanent storage

Example Cloud Function trigger:

```typescript
// Example: Process image after upload
export const processUploadedImage = functions.storage
  .object()
  .onFinalize(async (object) => {
    const filePath = object.name;
    if (!filePath.startsWith('users/') || !filePath.endsWith('.jpg')) {
      return;
    }

    // Process the image
    const tempFilePath = `/tmp/${path.basename(filePath)}`;
    await bucket.file(filePath).download({ destination: tempFilePath });

    // Resize the image
    await sharp(tempFilePath)
      .resize(200, 200)
      .toFile(`${tempFilePath}_thumb`);

    // Upload the thumbnail
    const thumbFilePath = filePath.replace('.jpg', '_thumb.jpg');
    await bucket.upload(`${tempFilePath}_thumb`, {
      destination: thumbFilePath,
      metadata: object.metadata
    });

    // Clean up
    fs.unlinkSync(tempFilePath);
    fs.unlinkSync(`${tempFilePath}_thumb`);
  });
```

## Error Handling

### Common Storage Errors

* **File Not Found**: Occurs when attempting to access a file that doesn't exist
* **Permission Denied**: Occurs when security rules prevent access
* **Quota Exceeded**: Occurs when storage quota is exceeded
* **Invalid Operation**: Occurs when attempting an invalid operation
* **Network Errors**: Occurs during connectivity issues

### Error Handling Strategies

```typescript
// Example: Comprehensive error handling
async function downloadFile(path: string): Promise<string> {
  const storageRef = ref(storage, path);
  try {
    return await getDownloadURL(storageRef);
  } catch (error) {
    const storageError = error as StorageError;
    switch (storageError.code) {
      case 'storage/object-not-found':
        console.log(`File not found: ${path}`);
        return DEFAULT_FILE_URL;
      case 'storage/unauthorized':
        throw new AuthorizationError('You do not have permission to access this file');
      case 'storage/quota-exceeded':
        throw new QuotaError('Storage quota exceeded');
      case 'storage/canceled':
        // Allow retry
        throw new RetryableError('Download was canceled');
      case 'storage/unknown':
      default:
        // Log for monitoring
        console.error('Unknown storage error', storageError);
        throw new StorageError('An unknown error occurred');
    }
  }
}
```

### Client-Side Error Handling

* Implement user-friendly error messages
* Provide retry options for transient errors
* Fallback to default content when appropriate
* Implement offline support with local caching

### Server-Side Error Handling

* Log detailed error information for debugging
* Implement retry mechanisms with exponential backoff
* Monitor storage operations for error patterns
* Implement alerting for critical storage errors

## Testing

### Unit Testing

```typescript
// Example: Unit test for storage repository
describe('StorageRepository', () => {
  let storageRepository: StorageRepository;
  let mockStorage: jest.Mocked<FirebaseStorage>;

  beforeEach(() => {
    mockStorage = createMockStorage();
    storageRepository = new StorageRepository(mockStorage);
  });

  test('uploadFile should upload file and return download URL', async () => {
    // Arrange
    const file = new File(['test'], 'test.jpg', { type: 'image/jpeg' });
    const userId = 'user123';
    const expectedUrl = 'https://storage.example.com/test.jpg';
    mockUploadBytes.mockResolvedValue({ ref: {} as StorageReference });
    mockGetDownloadURL.mockResolvedValue(expectedUrl);

    // Act
    const result = await storageRepository.uploadUserAvatar(userId, file);

    // Assert
    expect(result).toBe(expectedUrl);
    expect(mockUploadBytes).toHaveBeenCalledWith(
      expect.any(Object),
      file,
      expect.objectContaining({
        contentType: 'image/jpeg',
        customMetadata: expect.objectContaining({
          uploadedBy: userId
        })
      })
    );
  });

  test('getUserAvatar should return default avatar when file not found', async () => {
    // Arrange
    const userId = 'user123';
    const error = new Error('File not found');
    (error as any).code = 'storage/object-not-found';
    mockGetDownloadURL.mockRejectedValue(error);

    // Act
    const result = await storageRepository.getUserAvatar(userId);

    // Assert
    expect(result).toBe(DEFAULT_AVATAR_URL);
  });
});
```

### Integration Testing

* Use Firebase Emulator Suite for integration testing
* Test complete file operations workflows
* Verify security rules in integration tests
* Test error handling scenarios

```typescript
// Example: Integration test with Firebase Emulator
describe('Storage Integration', () => {
  let app: firebase.app.App;
  let storage: firebase.storage.Storage;

  beforeAll(async () => {
    app = await initializeTestApp({
      projectId: 'demo-project',
      auth: { uid: 'test-user' }
    });
    storage = getStorage(app);
  });

  afterAll(async () => {
    await clearStorageData();
    await app.delete();
  });

  test('should upload and download user avatar', async () => {
    // Arrange
    const userId = 'test-user';
    const file = new File(['test'], 'avatar.jpg', { type: 'image/jpeg' });
    const storageRepository = new StorageRepository(storage);

    // Act
    const uploadUrl = await storageRepository.uploadUserAvatar(userId, file);
    const downloadUrl = await storageRepository.getUserAvatar(userId);

    // Assert
    expect(downloadUrl).toBe(uploadUrl);
  });
});
```

### Security Rules Testing

* Test security rules with different user scenarios
* Verify access control for different file paths
* Test size and content type restrictions

```javascript
// Example: Security rules test
describe('Storage security rules', () => {
  let storage: firebase.storage.Storage;
  let adminStorage: firebase.storage.Storage;

  beforeAll(async () => {
    const app = await initializeTestApp({
      projectId: 'demo-project',
      auth: { uid: 'test-user' }
    });
    storage = getStorage(app);

    const adminApp = await initializeAdminApp({
      projectId: 'demo-project'
    });
    adminStorage = getStorage(adminApp);
  });

  test('user can read their own avatar', async () => {
    const ref = ref(storage, 'users/test-user/profile/avatar.jpg');
    await expect(getDownloadURL(ref)).toResolve();
  });

  test('user cannot read another user\'s avatar', async () => {
    const ref = ref(storage, 'users/other-user/profile/avatar.jpg');
    await expect(getDownloadURL(ref)).toReject();
  });
});
```

## Best Practices

* Use consistent folder structure
* Implement proper error handling
* Validate file types and sizes before upload
* Use resumable uploads for large files
* Generate signed URLs for temporary access
* Implement proper metadata
* Use Cloud Functions for file processing
* Clean up temporary files
* Implement proper security rules
* Use content-type headers
* Implement client-side validation

## Anti-patterns

* Storing large files in Firestore instead of Storage
* Using inconsistent path naming
* Hardcoding file paths in multiple places
* Not validating file types and sizes
* Storing sensitive information in public files
* Not implementing proper error handling
* Using overly permissive security rules
* Not cleaning up temporary files
* Using service account credentials in client applications
* Not implementing proper access control