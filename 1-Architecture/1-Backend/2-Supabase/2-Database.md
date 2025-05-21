# Supabase Database

## Purpose

This document outlines the database architecture, patterns, and best practices for implementing data storage and retrieval with Supabase PostgreSQL.

## Core Principles

### Type Safety

- Define TypeScript interfaces for all table types
- Implement validation functions for data integrity
- Use generated types from Supabase CLI
- Create type-safe query builders

### Modularity/Composability

- Organize tables by domain
- Implement repository pattern for data access
- Create reusable query builders
- Design composable RLS policies

### Testability

- Create mock repositories for unit testing
- Use local Supabase instance for integration testing
- Implement test data factories
- Design deterministic query results for testing

## Content Structure

### Database Structure

#### Schema Organization

Our Supabase database is organized using the following patterns:

1. **Public Schema**: For application data
2. **Auth Schema**: Managed by Supabase Auth
3. **Storage Schema**: Managed by Supabase Storage
4. **Custom Schemas**: For domain-specific functionality

#### Table Design

Tables are designed with the following considerations:

1. **Relationships**: Proper foreign key constraints
2. **Indexing**: Strategic indexes for query performance
3. **Constraints**: Check constraints for data integrity
4. **Triggers**: For automated data management
5. **Views**: For complex query abstraction

Example schema:

```sql
-- Example: Users table
CREATE TABLE public.users (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    display_name TEXT NOT NULL,
    email TEXT NOT NULL,
    photo_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,

    CONSTRAINT proper_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Example: Posts table
CREATE TABLE public.posts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    author_id UUID REFERENCES public.users(id) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,

    CONSTRAINT title_length CHECK (char_length(title) >= 3 AND char_length(title) <= 100)
);

-- Example: Comments table
CREATE TABLE public.comments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    content TEXT NOT NULL,
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
    author_id UUID REFERENCES public.users(id) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Example: Updated at trigger function
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Example: Apply trigger to tables
CREATE TRIGGER handle_users_updated_at
BEFORE UPDATE ON public.users
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_posts_updated_at
BEFORE UPDATE ON public.posts
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_comments_updated_at
BEFORE UPDATE ON public.comments
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
```

### Data Access Patterns

#### Repository Pattern

We implement the repository pattern to abstract Supabase operations:

```typescript
// Example: User repository
export interface UserRepository {
  getUser(id: string): Promise<User | null>;
  createUser(user: NewUser): Promise<User>;
  updateUser(id: string, data: Partial<User>): Promise<User>;
  deleteUser(id: string): Promise<void>;
  queryUsers(criteria: UserQueryCriteria): Promise<User[]>;
}

export class SupabaseUserRepository implements UserRepository {
  private supabase: SupabaseClient;

  constructor(supabase: SupabaseClient) {
    this.supabase = supabase;
  }

  async getUser(id: string): Promise<User | null> {
    const { data, error } = await this.supabase
      .from('users')
      .select('*')
      .eq('id', id)
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        return null; // Not found
      }
      throw error;
    }

    return data;
  }

  async createUser(user: NewUser): Promise<User> {
    const { data, error } = await this.supabase
      .from('users')
      .insert(user)
      .select()
      .single();

    if (error) {
      throw error;
    }

    return data;
  }

  // Other methods...
}
```

#### Query Optimization

Optimize queries using:

1. **Indexes** for frequently queried columns
2. **Limit and offset** for pagination
3. **Select specific columns** to reduce data transfer
4. **Prepared statements** for repeated queries

```typescript
// Example: Optimized query
async function getPaginatedPosts(
  page: number,
  pageSize: number,
  authorId?: string
): Promise<{ posts: Post[], total: number }> {
  const query = supabase
    .from('posts')
    .select('id, title, created_at, author:users(display_name, photo_url)', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range((page - 1) * pageSize, page * pageSize - 1);

  if (authorId) {
    query.eq('author_id', authorId);
  }

  const { data, error, count } = await query;

  if (error) {
    throw error;
  }

  return {
    posts: data || [],
    total: count || 0
  };
}
```

### Row-Level Security

#### Policy Design

Design RLS policies for fine-grained access control:

```sql
-- Example: Enable RLS on tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;

-- Example: User policies
CREATE POLICY "Users can view all profiles"
ON public.users
FOR SELECT
USING (true);

CREATE POLICY "Users can update their own profile"
ON public.users
FOR UPDATE
USING (auth.uid() = id);

-- Example: Post policies
CREATE POLICY "Anyone can view published posts"
ON public.posts
FOR SELECT
USING (true);

CREATE POLICY "Users can create posts"
ON public.posts
FOR INSERT
WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Users can update their own posts"
ON public.posts
FOR UPDATE
USING (auth.uid() = author_id);

CREATE POLICY "Users can delete their own posts"
ON public.posts
FOR DELETE
USING (auth.uid() = author_id);

-- Example: Comment policies
CREATE POLICY "Anyone can view comments"
ON public.comments
FOR SELECT
USING (true);

CREATE POLICY "Users can create comments"
ON public.comments
FOR INSERT
WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Users can update their own comments"
ON public.comments
FOR UPDATE
USING (auth.uid() = author_id);

CREATE POLICY "Users can delete their own comments"
ON public.comments
FOR DELETE
USING (auth.uid() = author_id);
```

#### Function-Based Policies

Implement complex policies using functions:

```sql
-- Example: Function for checking if user is admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.users
    WHERE id = auth.uid()
    AND admin = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Example: Admin policy
CREATE POLICY "Admins can update any post"
ON public.posts
FOR UPDATE
USING (
  is_admin()
  OR auth.uid() = author_id
);
```

### Data Modeling

#### One-to-One Relationships

```sql
-- Example: User and Profile
CREATE TABLE public.users (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    email TEXT NOT NULL
);

CREATE TABLE public.profiles (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    bio TEXT,
    avatar_url TEXT
);
```

#### One-to-Many Relationships

```sql
-- Example: User and Posts
CREATE TABLE public.users (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    email TEXT NOT NULL
);

CREATE TABLE public.posts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    author_id UUID REFERENCES public.users(id) NOT NULL
);
```

#### Many-to-Many Relationships

```sql
-- Example: Users and Groups
CREATE TABLE public.users (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    email TEXT NOT NULL
);

CREATE TABLE public.groups (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT
);

CREATE TABLE public.group_members (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    group_id UUID REFERENCES public.groups(id) ON DELETE CASCADE NOT NULL,
    role TEXT NOT NULL DEFAULT 'member',
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,

    UNIQUE(user_id, group_id)
);
```

### Real-time Updates

Implement real-time updates using Supabase Realtime:

```typescript
// Example: Real-time subscription
function subscribeToUserPosts(userId: string, callback: (posts: Post[]) => void): () => void {
  const subscription = supabase
    .from(`posts:author_id=eq.${userId}`)
    .on('*', payload => {
      // Fetch updated posts
      supabase
        .from('posts')
        .select('*')
        .eq('author_id', userId)
        .order('created_at', { ascending: false })
        .then(({ data, error }) => {
          if (!error && data) {
            callback(data);
          }
        });
    })
    .subscribe();

  // Return unsubscribe function
  return () => {
    supabase.removeSubscription(subscription);
  };
}
```

### Database Migrations

Manage schema changes with migrations:

```sql
-- Example: Migration file (20230101000000_create_initial_schema.sql)
-- Up Migration
CREATE TABLE public.users (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    display_name TEXT NOT NULL,
    email TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Down Migration
DROP TABLE IF EXISTS public.users;
```

Use Supabase CLI for migration management:

```bash
# Generate a new migration
supabase migration new create_posts_table

# Apply migrations
supabase db push

# Reset database
supabase db reset
```

## Error Handling

### Database Error Types

- **Validation Errors**: Constraint violations and data type mismatches
- **Permission Errors**: RLS policy violations and insufficient privileges
- **Connection Errors**: Database connectivity issues
- **Query Errors**: Syntax errors and invalid operations
- **Constraint Errors**: Foreign key violations and unique constraint failures
- **Transaction Errors**: Deadlocks and serialization failures

### Error Handling Strategy

```typescript
// Example: Repository with structured error handling
export class SupabaseUserRepository implements UserRepository {
  private supabase: SupabaseClient;

  constructor(supabase: SupabaseClient) {
    this.supabase = supabase;
  }

  async getUser(id: string): Promise<User | null> {
    try {
      const { data, error } = await this.supabase
        .from('users')
        .select('*')
        .eq('id', id)
        .single();

      if (error) {
        if (error.code === 'PGRST116') {
          return null; // Not found
        }

        // Categorize and handle specific error types
        switch (error.code) {
          case '42501': // Insufficient privilege
            throw new DatabaseError('You do not have permission to access this user.', 'PERMISSION_DENIED', error);
          case '42P01': // Undefined table
            throw new DatabaseError('The requested resource does not exist.', 'RESOURCE_NOT_FOUND', error);
          case '23505': // Unique violation
            throw new DatabaseError('A resource with this identifier already exists.', 'RESOURCE_EXISTS', error);
          default:
            // Log unexpected errors for monitoring
            logger.error('Database error:', error);
            throw new DatabaseError('An unexpected database error occurred.', 'UNKNOWN_ERROR', error);
        }
      }

      return data;
    } catch (error) {
      if (error instanceof DatabaseError) {
        throw error; // Re-throw our custom errors
      }
      // Handle unexpected errors
      logger.error('Unexpected database error:', error);
      throw new DatabaseError('An unexpected error occurred. Please try again.', 'UNKNOWN_ERROR', error);
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
      if (error instanceof DatabaseError) {
        if (!['CONNECTION_ERROR', 'TIMEOUT_ERROR', 'RATE_LIMIT_ERROR'].includes(error.code)) {
          throw error; // Don't retry permanent errors
        }
      } else {
        throw error; // Don't retry non-database errors
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

### Client-Side Error Handling

- Display user-friendly error messages
- Provide actionable recovery steps
- Implement optimistic UI updates with rollback on error
- Handle offline scenarios gracefully

### Server-Side Error Handling

- Log detailed error information for debugging
- Implement structured error logging with context
- Set up monitoring alerts for critical error patterns
- Track error rates and types for proactive resolution

## Testing

### Unit Testing Repositories

```typescript
// Example: Unit test for user repository
describe('SupabaseUserRepository', () => {
  let repository: SupabaseUserRepository;
  let mockSupabase: jest.Mocked<SupabaseClient>;

  beforeEach(() => {
    // Mock Supabase client
    mockSupabase = {
      from: jest.fn().mockReturnThis(),
      select: jest.fn().mockReturnThis(),
      eq: jest.fn().mockReturnThis(),
      single: jest.fn(),
      insert: jest.fn().mockReturnThis(),
      update: jest.fn().mockReturnThis(),
      delete: jest.fn().mockReturnThis()
    } as unknown as jest.Mocked<SupabaseClient>;

    repository = new SupabaseUserRepository(mockSupabase);
  });

  describe('getUser', () => {
    it('should return user when document exists', async () => {
      // Arrange
      const mockUser = { id: 'user123', display_name: 'Test User', email: 'test@example.com' };
      mockSupabase.single.mockResolvedValue({ data: mockUser, error: null });

      // Act
      const result = await repository.getUser('user123');

      // Assert
      expect(mockSupabase.from).toHaveBeenCalledWith('users');
      expect(mockSupabase.select).toHaveBeenCalledWith('*');
      expect(mockSupabase.eq).toHaveBeenCalledWith('id', 'user123');
      expect(result).toEqual(mockUser);
    });

    it('should return null when document does not exist', async () => {
      // Arrange
      mockSupabase.single.mockResolvedValue({
        data: null,
        error: { code: 'PGRST116', message: 'Not found' }
      });

      // Act
      const result = await repository.getUser('nonexistent');

      // Assert
      expect(result).toBeNull();
    });

    it('should handle errors properly', async () => {
      // Arrange
      const mockError = { code: '42501', message: 'Insufficient privilege' };
      mockSupabase.single.mockResolvedValue({ data: null, error: mockError });

      // Act & Assert
      await expect(repository.getUser('user123'))
        .rejects
        .toThrow('You do not have permission to access this user.');
    });
  });
});
```

### Integration Testing with Local Supabase

```typescript
// Example: Integration test with local Supabase
describe('User Database Operations', () => {
  let supabase: SupabaseClient;
  let repository: SupabaseUserRepository;

  beforeAll(() => {
    // Connect to local Supabase instance
    supabase = createClient(
      'http://localhost:54321',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
    );
    repository = new SupabaseUserRepository(supabase);
  });

  beforeEach(async () => {
    // Clear test data
    await supabase.from('users').delete().neq('id', '00000000-0000-0000-0000-000000000000');
  });

  it('should create and retrieve a user', async () => {
    // Create test user
    const newUser = {
      id: '123e4567-e89b-12d3-a456-426614174000',
      display_name: 'Test User',
      email: 'test@example.com'
    };

    await repository.createUser(newUser);

    // Retrieve and verify
    const user = await repository.getUser(newUser.id);
    expect(user).not.toBeNull();
    expect(user?.display_name).toBe('Test User');
  });
});
```

### RLS Policy Testing

```sql
-- Example: Test RLS policies
BEGIN;
  -- Create test users
  INSERT INTO auth.users (id, email) VALUES
    ('test-user-id', 'user@example.com'),
    ('test-admin-id', 'admin@example.com');

  -- Set admin role for admin user
  UPDATE auth.users SET raw_app_meta_data = '{"role":"admin"}'::jsonb
  WHERE id = 'test-admin-id';

  -- Test user-specific policy
  SET LOCAL ROLE authenticated;
  SET LOCAL request.jwt.claims TO '{"sub": "test-user-id"}';

  -- This should succeed (user accessing own profile)
  INSERT INTO public.users (id, display_name, email)
  VALUES ('test-user-id', 'Test User', 'user@example.com');

  -- This should fail (user accessing another profile)
  INSERT INTO public.users (id, display_name, email)
  VALUES ('test-admin-id', 'Test Admin', 'admin@example.com');

  -- Cleanup
  RESET ROLE;
  RESET request.jwt.claims;
 ROLLBACK;
```

### Performance Testing

- Test query performance with realistic data volumes
- Measure and optimize read/write operations
- Verify index effectiveness for complex queries
- Test pagination strategies with large collections

## Best Practices

* Design the database schema based on domain models
* Use foreign key constraints for referential integrity
* Implement proper indexing for query performance
* Use RLS policies for security
* Implement database-level validation
* Use transactions for operations that require consistency
* Implement proper error handling for database operations
* Use migrations for schema changes
* Document database schema and relationships
* Use prepared statements for parameterized queries
* Implement proper database backups
* Use database functions for complex operations

## Anti-patterns

* Bypassing RLS with service roles unnecessarily
* Using text fields for structured data
* Not using foreign key constraints
* Implementing complex business logic in triggers
* Storing large binary data in tables
* Using excessive joins in queries
* Not using pagination for large result sets
* Hardcoding SQL queries in application code
* Not handling database errors properly
* Using too many indexes
* Not using database transactions for multi-step operations
* Implementing application-level constraints instead of database constraints