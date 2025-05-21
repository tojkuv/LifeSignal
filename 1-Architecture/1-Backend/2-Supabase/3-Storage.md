# Supabase Storage

## Purpose

This document outlines the storage architecture, patterns, and best practices for implementing file storage with Supabase Storage.

## Core Principles

### Type Safety

- Define TypeScript interfaces for metadata
- Implement type-safe upload and download functions
- Use typed references for storage operations
- Create type-safe metadata validation

### Modularity/Composability

- Organize storage by bucket
- Implement repository pattern for storage access
- Create reusable storage utilities
- Design composable storage policies

### Testability

- Create mock storage repositories for unit testing
- Use local Supabase instance for integration testing
- Implement test utilities for file operations
- Design deterministic file paths for testing

## Content Structure

### Storage Organization

#### Bucket Structure

Our Supabase Storage is organized using the following buckets:

1. **Public Bucket**: For publicly accessible files
2. **Private Bucket**: For user-specific private files
3. **Shared Bucket**: For files shared between specific users
4. **Temporary Bucket**: For temporary file storage

#### Path Conventions

Storage paths follow these conventions:

1. **User-specific files**: `users/{userId}/{fileType}/{fileName}`
2. **Public files**: `public/{category}/{subcategory}/{fileName}`
3. **Shared files**: `shared/{groupId}/{fileName}`
4. **Temporary files**: `temp/{tempId}/{fileName}`

### Bucket Configuration

Configure buckets with appropriate policies:

```sql
-- Example: Create buckets
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('public', 'Public Files', true),
  ('private', 'Private Files', false),
  ('shared', 'Shared Files', false),
  ('temp', 'Temporary Files', false);

-- Example: Set bucket size limits
UPDATE storage.buckets
SET file_size_limit = 5242880 -- 5MB
WHERE id = 'public';

UPDATE storage.buckets
SET file_size_limit = 10485760 -- 10MB
WHERE id = 'private';

-- Example: Set allowed MIME types
UPDATE storage.buckets
SET allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/gif', 'application/pdf']
WHERE id = 'public';
```

### Storage Policies

#### Public Bucket Policies

```sql
-- Example: Public bucket policies
-- Anyone can read public files
CREATE POLICY "Public Access"
ON storage.objects
FOR SELECT
USING (bucket_id = 'public');

-- Only authenticated users can upload to public bucket
CREATE POLICY "Authenticated Users Can Upload"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'public'
  AND auth.role() = 'authenticated'
);

-- Users can update and delete their own uploads
CREATE POLICY "Users Can Update Own Files"
ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'public'
  AND auth.uid()::text = owner
);

CREATE POLICY "Users Can Delete Own Files"
ON storage.objects
FOR DELETE
USING (
  bucket_id = 'public'
  AND auth.uid()::text = owner
);
```

#### Private Bucket Policies

```sql
-- Example: Private bucket policies
-- Users can access only their own files
CREATE POLICY "Users Can Access Own Files"
ON storage.objects
FOR SELECT
USING (
  bucket_id = 'private'
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Users can upload only to their own folder
CREATE POLICY "Users Can Upload To Own Folder"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'private'
  AND auth.uid()::text = (storage.foldername(name))[1]
  AND auth.uid()::text = owner
);

-- Users can update and delete only their own files
CREATE POLICY "Users Can Update Own Private Files"
ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'private'
  AND auth.uid()::text = (storage.foldername(name))[1]
  AND auth.uid()::text = owner
);

CREATE POLICY "Users Can Delete Own Private Files"
ON storage.objects
FOR DELETE
USING (
  bucket_id = 'private'
  AND auth.uid()::text = (storage.foldername(name))[1]
  AND auth.uid()::text = owner
);
```

#### Shared Bucket Policies

```sql
-- Example: Shared bucket policies
-- Function to check if user has access to a shared folder
CREATE OR REPLACE FUNCTION storage.user_has_access_to_folder(folder_id text)
RETURNS boolean AS $$
DECLARE
  has_access boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM public.shared_folders sf
    JOIN public.folder_members fm ON sf.id = fm.folder_id
    WHERE sf.id = folder_id
    AND fm.user_id = auth.uid()
  ) INTO has_access;

  RETURN has_access;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Users can access files in shared folders they have access to
CREATE POLICY "Access Shared Files"
ON storage.objects
FOR SELECT
USING (
  bucket_id = 'shared'
  AND storage.user_has_access_to_folder((storage.foldername(name))[1])
);

-- Users can upload to shared folders they have access to
CREATE POLICY "Upload To Shared Folders"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'shared'
  AND storage.user_has_access_to_folder((storage.foldername(name))[1])
  AND auth.uid()::text = owner
);
```

### File Operations

#### Upload Operations

Implement secure and efficient uploads:

```typescript
// Example: Upload function
async function uploadUserAvatar(userId: string, file: File): Promise<string> {
  const filePath = `users/${userId}/profile/avatar.jpg`;

  const { data, error } = await supabase.storage
    .from('private')
    .upload(filePath, file, {
      cacheControl: '3600',
      upsert: true,
      contentType: file.type
    });

  if (error) {
    throw error;
  }

  // Get public URL
  const { data: urlData } = supabase.storage
    .from('private')
    .getPublicUrl(filePath);

  return urlData.publicUrl;
}
```

#### Download Operations

Implement efficient downloads:

```typescript
// Example: Download function
async function getUserAvatar(userId: string): Promise<string> {
  const filePath = `users/${userId}/profile/avatar.jpg`;

  // Get signed URL for private files
  const { data, error } = await supabase.storage
    .from('private')
    .createSignedUrl(filePath, 60); // 60 seconds expiry

  if (error) {
    // Return default avatar if file not found
    if (error.statusCode === 404) {
      return DEFAULT_AVATAR_URL;
    }
    throw error;
  }

  return data.signedUrl;
}
```

#### Delete Operations

Implement secure delete operations:

```typescript
// Example: Delete function
async function deleteUserAvatar(userId: string): Promise<void> {
  const filePath = `users/${userId}/profile/avatar.jpg`;

  const { error } = await supabase.storage
    .from('private')
    .remove([filePath]);

  if (error && error.statusCode !== 404) {
    throw error;
  }
}
```

#### List Operations

Implement file listing:

```typescript
// Example: List function
async function listUserFiles(userId: string, folder: string): Promise<string[]> {
  const path = `users/${userId}/${folder}`;

  const { data, error } = await supabase.storage
    .from('private')
    .list(path);

  if (error) {
    throw error;
  }

  return data.map(item => item.name);
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
async function setFileMetadata(
  bucket: string,
  path: string,
  metadata: FileMetadata
): Promise<void> {
  // Store metadata in a separate table
  const { error } = await supabase
    .from('file_metadata')
    .upsert({
      bucket,
      path,
      metadata
    });

  if (error) {
    throw error;
  }
}

// Example: Getting metadata
async function getFileMetadata(
  bucket: string,
  path: string
): Promise<FileMetadata | null> {
  const { data, error } = await supabase
    .from('file_metadata')
    .select('metadata')
    .eq('bucket', bucket)
    .eq('path', path)
    .single();

  if (error) {
    if (error.code === 'PGRST116') {
      return null; // Not found
    }
    throw error;
  }

  return data.metadata;
}
```

### File Processing

Implement file processing workflows:

1. **Client-side processing**: Resize/compress before upload
2. **Edge Functions**: Process files after upload
3. **Temporary to permanent**: Move from temporary to permanent storage

Example Edge Function:

```typescript
// Example: Process image after upload
import { serve } from 'https://deno.land/std@0.131.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.0.0';
import { processImage } from 'https://esm.sh/image-processing-library';

serve(async (req) => {
  // Create Supabase client
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  const supabase = createClient(supabaseUrl, supabaseKey);

  // Parse request
  const { bucket, filePath } = await req.json();

  try {
    // Download the file
    const { data, error } = await supabase.storage
      .from(bucket)
      .download(filePath);

    if (error) {
      throw error;
    }

    // Process the image
    const processedImageData = await processImage(data, {
      width: 200,
      height: 200,
      format: 'jpeg'
    });

    // Upload the thumbnail
    const thumbPath = filePath.replace(/\.[^/.]+$/, '_thumb.jpg');

    const { error: uploadError } = await supabase.storage
      .from(bucket)
      .upload(thumbPath, processedImageData, {
        contentType: 'image/jpeg',
        upsert: true
      });

    if (uploadError) {
      throw uploadError;
    }

    return new Response(
      JSON.stringify({ success: true, thumbPath }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
```

### Repository Pattern

Implement the repository pattern for storage access:

```typescript
// Example: Storage repository
interface StorageRepository {
  uploadFile(bucket: string, path: string, file: File): Promise<string>;
  downloadFile(bucket: string, path: string): Promise<Blob>;
  getFileUrl(bucket: string, path: string): Promise<string>;
  deleteFile(bucket: string, path: string): Promise<void>;
  listFiles(bucket: string, path: string): Promise<string[]>;
}

class SupabaseStorageRepository implements StorageRepository {
  private supabase: SupabaseClient;

  constructor(supabase: SupabaseClient) {
    this.supabase = supabase;
  }

  async uploadFile(bucket: string, path: string, file: File): Promise<string> {
    const { data, error } = await this.supabase.storage
      .from(bucket)
      .upload(path, file, {
        cacheControl: '3600',
        upsert: true,
        contentType: file.type
      });

    if (error) {
      throw error;
    }

    return this.getFileUrl(bucket, path);
  }

  async downloadFile(bucket: string, path: string): Promise<Blob> {
    const { data, error } = await this.supabase.storage
      .from(bucket)
      .download(path);

    if (error) {
      throw error;
    }

    return data;
  }

  async getFileUrl(bucket: string, path: string): Promise<string> {
    if (bucket === 'public') {
      const { data } = this.supabase.storage
        .from(bucket)
        .getPublicUrl(path);

      return data.publicUrl;
    } else {
      const { data, error } = await this.supabase.storage
        .from(bucket)
        .createSignedUrl(path, 60 * 60); // 1 hour expiry

      if (error) {
        throw error;
      }

      return data.signedUrl;
    }
  }

  async deleteFile(bucket: string, path: string): Promise<void> {
    const { error } = await this.supabase.storage
      .from(bucket)
      .remove([path]);

    if (error && error.statusCode !== 404) {
      throw error;
    }
  }

  async listFiles(bucket: string, path: string): Promise<string[]> {
    const { data, error } = await this.supabase.storage
      .from(bucket)
      .list(path);

    if (error) {
      throw error;
    }

    return data.map(item => item.name);
  }
}
```

## Error Handling

### Common Storage Errors

* **File Not Found**: Occurs when attempting to access a file that doesn't exist
* **Permission Denied**: Occurs when storage policies prevent access
* **Quota Exceeded**: Occurs when bucket size limits are exceeded
* **Invalid Operation**: Occurs when attempting an invalid operation
* **Network Errors**: Occurs during connectivity issues
* **Timeout Errors**: Occurs during large file operations

### Error Handling Strategies

```typescript
// Example: Comprehensive error handling
async function downloadFile(bucket: string, path: string): Promise<Blob | null> {
  try {
    const { data, error } = await supabase.storage
      .from(bucket)
      .download(path);

    if (error) {
      if (error.statusCode === 404) {
        console.log(`File not found: ${path}`);
        return null;
      }
      if (error.statusCode === 403) {
        throw new AuthorizationError('You do not have permission to access this file');
      }
      if (error.message?.includes('quota exceeded')) {
        throw new QuotaError('Storage quota exceeded');
      }
      throw error;
    }

    return data;
  } catch (error) {
    // Handle network errors
    if (error.message?.includes('network') || error.message?.includes('timeout')) {
      throw new RetryableError('Network error occurred, please try again');
    }
    throw error;
  }
}
```

### Client-Side Error Handling

* Implement user-friendly error messages
* Provide retry options for transient errors
* Fallback to default content when appropriate
* Implement offline support with local caching
* Handle upload progress and interruptions

### Server-Side Error Handling

* Log detailed error information for debugging
* Implement retry mechanisms with exponential backoff
* Monitor storage operations for error patterns
* Implement alerting for critical storage errors
* Use database transactions for operations that update both storage and database

## Testing

### Unit Testing

```typescript
// Example: Unit test for storage repository
describe('SupabaseStorageRepository', () => {
  let storageRepository: SupabaseStorageRepository;
  let mockSupabase: any;

  beforeEach(() => {
    // Create mock Supabase client
    mockSupabase = {
      storage: {
        from: jest.fn().mockReturnValue({
          upload: jest.fn(),
          download: jest.fn(),
          getPublicUrl: jest.fn(),
          createSignedUrl: jest.fn(),
          remove: jest.fn(),
          list: jest.fn()
        })
      }
    };
    storageRepository = new SupabaseStorageRepository(mockSupabase as any);
  });

  test('uploadFile should upload file and return URL', async () => {
    // Arrange
    const bucket = 'private';
    const path = 'users/123/profile/avatar.jpg';
    const file = new File(['test'], 'avatar.jpg', { type: 'image/jpeg' });
    const expectedUrl = 'https://example.com/avatar.jpg';

    mockSupabase.storage.from().upload.mockResolvedValue({ data: { path }, error: null });
    mockSupabase.storage.from().createSignedUrl.mockResolvedValue({
      data: { signedUrl: expectedUrl },
      error: null
    });

    // Act
    const result = await storageRepository.uploadFile(bucket, path, file);

    // Assert
    expect(result).toBe(expectedUrl);
    expect(mockSupabase.storage.from).toHaveBeenCalledWith(bucket);
    expect(mockSupabase.storage.from().upload).toHaveBeenCalledWith(
      path,
      file,
      expect.objectContaining({
        contentType: 'image/jpeg',
        upsert: true
      })
    );
  });

  test('downloadFile should handle file not found error', async () => {
    // Arrange
    const bucket = 'private';
    const path = 'users/123/profile/avatar.jpg';
    mockSupabase.storage.from().download.mockResolvedValue({
      data: null,
      error: { statusCode: 404, message: 'File not found' }
    });

    // Act & Assert
    await expect(storageRepository.downloadFile(bucket, path))
      .rejects
      .toThrow('File not found');
  });
});
```

### Integration Testing

* Use local Supabase instance for integration testing
* Test complete file operations workflows
* Verify storage policies in integration tests
* Test error handling scenarios

```typescript
// Example: Integration test with local Supabase
describe('Storage Integration', () => {
  let supabase: SupabaseClient;
  let storageRepository: SupabaseStorageRepository;

  beforeAll(async () => {
    // Connect to local Supabase instance
    supabase = createClient(
      'http://localhost:54321',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
    );

    // Sign in as test user
    await supabase.auth.signInWithPassword({
      email: 'test@example.com',
      password: 'password123'
    });

    storageRepository = new SupabaseStorageRepository(supabase);
  });

  afterAll(async () => {
    // Clean up test files
    await supabase.storage.from('private').remove(['users/test-user/profile/avatar.jpg']);
    await supabase.auth.signOut();
  });

  test('should upload and download user avatar', async () => {
    // Arrange
    const bucket = 'private';
    const path = 'users/test-user/profile/avatar.jpg';
    const file = new File(['test'], 'avatar.jpg', { type: 'image/jpeg' });

    // Act
    const uploadUrl = await storageRepository.uploadFile(bucket, path, file);
    const downloadedFile = await storageRepository.downloadFile(bucket, path);

    // Assert
    expect(uploadUrl).toContain('avatar.jpg');
    expect(downloadedFile).toBeDefined();
    expect(downloadedFile.size).toBe(4); // 'test'.length
    expect(downloadedFile.type).toBe('image/jpeg');
  });
});
```

### Policy Testing

* Test storage policies with different user scenarios
* Verify access control for different buckets and paths
* Test size and content type restrictions

```typescript
// Example: Policy test
describe('Storage Policies', () => {
  let adminSupabase: SupabaseClient;
  let userSupabase: SupabaseClient;
  let otherUserSupabase: SupabaseClient;

  beforeAll(async () => {
    // Admin client
    adminSupabase = createClient(
      'http://localhost:54321',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
    );

    // User client
    userSupabase = createClient(
      'http://localhost:54321',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
    );
    await userSupabase.auth.signInWithPassword({
      email: 'user@example.com',
      password: 'password123'
    });

    // Other user client
    otherUserSupabase = createClient(
      'http://localhost:54321',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
    );
    await otherUserSupabase.auth.signInWithPassword({
      email: 'other@example.com',
      password: 'password123'
    });
  });

  test('user can access their own private files', async () => {
    // Arrange
    const userId = (await userSupabase.auth.getUser()).data.user.id;
    const path = `users/${userId}/profile/avatar.jpg`;
    const file = new File(['test'], 'avatar.jpg', { type: 'image/jpeg' });

    // Upload file
    await userSupabase.storage.from('private').upload(path, file, { upsert: true });

    // Act & Assert - User can download their own file
    const { data, error } = await userSupabase.storage.from('private').download(path);
    expect(error).toBeNull();
    expect(data).toBeDefined();
  });

  test('user cannot access another user\'s private files', async () => {
    // Arrange
    const userId = (await userSupabase.auth.getUser()).data.user.id;
    const path = `users/${userId}/profile/avatar.jpg`;

    // Act - Other user tries to download file
    const { data, error } = await otherUserSupabase.storage.from('private').download(path);

    // Assert
    expect(error).not.toBeNull();
    expect(error.statusCode).toBe(403); // Forbidden
    expect(data).toBeNull();
  });
});
```

## Best Practices

* Use appropriate bucket organization
* Implement proper error handling
* Validate file types and sizes before upload
* Use signed URLs for temporary access
* Implement proper metadata
* Use Edge Functions for file processing
* Clean up temporary files
* Implement proper storage policies
* Use content-type headers
* Implement client-side validation
* Use progressive uploads for large files
* Implement proper caching strategies

## Anti-patterns

* Storing large files in the database instead of Storage
* Using inconsistent path naming
* Hardcoding file paths in multiple places
* Not validating file types and sizes
* Storing sensitive information in public buckets
* Not implementing proper error handling
* Using overly permissive storage policies
* Not cleaning up temporary files
* Using service role keys in client applications
* Not implementing proper access control
* Not handling file name collisions
* Storing files without proper metadata