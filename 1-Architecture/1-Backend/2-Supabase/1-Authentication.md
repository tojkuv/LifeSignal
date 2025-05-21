# Supabase Authentication

## Purpose

This document outlines the authentication architecture, patterns, and best practices for implementing user authentication with Supabase Auth.

## Core Principles

### Type Safety

- Use TypeScript interfaces to define user profile structures
- Implement type-safe JWT handling
- Define type-safe authentication state in client applications

### Modularity/Composability

- Separate authentication logic from business logic
- Create reusable authentication components
- Implement composable RLS policies that can be combined

### Testability

- Mock Supabase Auth for unit tests
- Use local Supabase instance for integration tests
- Create test utilities for authentication state simulation

## Content Structure

### Authentication Methods

Our architecture supports the following authentication methods:

- Email/Password authentication
- Magic link authentication
- Phone number authentication
- OAuth providers (Google, Apple, etc.)

### User Management

#### User Profiles

User profiles are stored in two locations:

1. **Supabase Auth**: Basic identity information
   - UUID
   - Email
   - Phone number
   - Provider information

2. **Database**: Extended profile information
   - Display name
   - Profile picture
   - User preferences
   - Application-specific data

### JWT Claims

JWT claims are used to store role-based access control information:

- User roles
- Subscription status
- Account verification status

JWT claims are managed through Supabase Auth hooks or Edge Functions.

### Row-Level Security

#### Authentication-Based Policies

```sql
-- Example: Basic authentication check
CREATE POLICY "Authenticated users can read public data"
ON public.posts
FOR SELECT
USING (auth.role() = 'authenticated');
```

### Role-Based Policies

```sql
-- Example: Role-based access control
CREATE POLICY "Admins can manage all posts"
ON public.posts
FOR ALL
USING (
  auth.jwt() ->> 'role' = 'admin'
);
```

### User-Specific Policies

```sql
-- Example: User-specific data access
CREATE POLICY "Users can manage their own profiles"
ON public.profiles
FOR ALL
USING (auth.uid() = user_id);
```

### Implementation Patterns

#### Authentication Service

```typescript
// Example: Authentication service in TypeScript
import { createClient, SupabaseClient, User } from '@supabase/supabase-js';

export interface AuthUser {
  id: string;
  email: string | null;
  displayName: string | null;
  isAdmin: boolean;
}

export class AuthService {
  private supabase: SupabaseClient;

  constructor(supabaseUrl: string, supabaseKey: string) {
    this.supabase = createClient(supabaseUrl, supabaseKey);
  }

  async signIn(email: string, password: string): Promise<AuthUser> {
    const { data, error } = await this.supabase.auth.signInWithPassword({
      email,
      password
    });

    if (error) {
      throw error;
    }

    return this.mapToAuthUser(data.user);
  }

  async signUp(email: string, password: string): Promise<AuthUser> {
    const { data, error } = await this.supabase.auth.signUp({
      email,
      password
    });

    if (error) {
      throw error;
    }

    // Create profile in database
    await this.createUserProfile(data.user);

    return this.mapToAuthUser(data.user);
  }

  async signOut(): Promise<void> {
    const { error } = await this.supabase.auth.signOut();
    if (error) {
      throw error;
    }
  }

  async getCurrentUser(): Promise<AuthUser | null> {
    const { data } = await this.supabase.auth.getUser();

    if (!data.user) {
      return null;
    }

    return this.mapToAuthUser(data.user);
  }

  onAuthStateChange(callback: (user: AuthUser | null) => void): () => void {
    const { data } = this.supabase.auth.onAuthStateChange((event, session) => {
      if (event === 'SIGNED_IN' && session?.user) {
        callback(this.mapToAuthUser(session.user));
      } else if (event === 'SIGNED_OUT') {
        callback(null);
      }
    });

    return data.subscription.unsubscribe;
  }

  private async createUserProfile(user: User): Promise<void> {
    const { error } = await this.supabase
      .from('profiles')
      .insert({
        user_id: user.id,
        display_name: user.email?.split('@')[0] || 'User',
        email: user.email
      });

    if (error) {
      console.error('Error creating user profile:', error);
    }
  }

  private mapToAuthUser(user: User): AuthUser {
    return {
      id: user.id,
      email: user.email,
      displayName: user.user_metadata?.display_name || null,
      isAdmin: user.app_metadata?.role === 'admin'
    };
  }
}
```

### Custom Claims Management

```typescript
// Example: Edge function to set custom claims
import { serve } from 'https://deno.land/std@0.131.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.0.0';

serve(async (req) => {
  // Create Supabase client with admin privileges
  const supabaseAdmin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  );

  // Parse request
  const { userId, role } = await req.json();

  // Validate request
  if (!userId || !role) {
    return new Response(
      JSON.stringify({ error: 'User ID and role are required' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } }
    );
  }

  try {
    // Update user's app_metadata
    const { data, error } = await supabaseAdmin.auth.admin.updateUserById(
      userId,
      { app_metadata: { role } }
    );

    if (error) {
      throw error;
    }

    return new Response(
      JSON.stringify({ message: 'User role updated successfully', user: data.user }),
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

### Database Triggers for User Management

```sql
-- Example: Create profile on user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (user_id, display_name, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
    NEW.email
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger the function every time a user is created
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
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
async function signInWithEmail(email: string, password: string): Promise<User> {
  try {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    });

    if (error) {
      // Categorize and handle specific error types
      switch (error.message) {
        case 'Invalid login credentials':
          throw new AuthError('Invalid email or password.', 'INVALID_CREDENTIALS');
        case 'Email not confirmed':
          throw new AuthError('Please confirm your email before signing in.', 'EMAIL_NOT_CONFIRMED');
        default:
          // Log unexpected errors for monitoring
          logger.error('Authentication error:', error);
          throw new AuthError('An unexpected error occurred. Please try again.', 'UNKNOWN_ERROR');
      }
    }

    return data.user;
  } catch (error) {
    if (error instanceof AuthError) {
      throw error; // Re-throw our custom errors
    }
    // Handle unexpected errors
    logger.error('Unexpected authentication error:', error);
    throw new AuthError('An unexpected error occurred. Please try again.', 'UNKNOWN_ERROR');
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
- Implement proper error responses in Edge Functions

## Testing

### Unit Testing Authentication Logic

```typescript
// Example: Unit test for authentication logic
describe('Authentication Service', () => {
  let authService: AuthService;
  let mockSupabase: jest.Mocked<SupabaseClient>;

  beforeEach(() => {
    mockSupabase = {
      auth: {
        signInWithPassword: jest.fn(),
        signUp: jest.fn(),
        signOut: jest.fn(),
        getUser: jest.fn(),
        onAuthStateChange: jest.fn()
      }
    } as unknown as jest.Mocked<SupabaseClient>;

    authService = new AuthService(mockSupabase);
  });

  describe('signIn', () => {
    it('should sign in user with valid credentials', async () => {
      // Arrange
      const mockUser = { id: 'user123', email: 'test@example.com' };
      mockSupabase.auth.signInWithPassword.mockResolvedValue({
        data: { user: mockUser },
        error: null
      } as any);

      // Act
      const result = await authService.signIn('test@example.com', 'password123');

      // Assert
      expect(mockSupabase.auth.signInWithPassword).toHaveBeenCalledWith({
        email: 'test@example.com',
        password: 'password123'
      });
      expect(result.id).toEqual(mockUser.id);
    });

    it('should handle authentication errors properly', async () => {
      // Arrange
      const authError = { message: 'Invalid login credentials' };
      mockSupabase.auth.signInWithPassword.mockResolvedValue({
        data: { user: null },
        error: authError
      } as any);

      // Act & Assert
      await expect(authService.signIn('test@example.com', 'wrong-password'))
        .rejects
        .toThrow('Invalid email or password.');
    });
  });
});
```

### Integration Testing with Local Supabase

- Set up local Supabase instance for testing
- Create test users and authentication scenarios
- Test complete authentication flows
- Verify JWT generation and validation

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
  SET LOCAL request.jwt.claims TO '{"sub": "test-user-id", "role": "user"}';

  -- This should succeed (user accessing own profile)
  INSERT INTO public.profiles (user_id, display_name)
  VALUES ('test-user-id', 'Test User');

  -- This should fail (user accessing another profile)
  INSERT INTO public.profiles (user_id, display_name)
  VALUES ('test-admin-id', 'Test Admin');

  -- Test admin policy
  SET LOCAL request.jwt.claims TO '{"sub": "test-admin-id", "role": "admin"}';

  -- This should succeed (admin can access any profile)
  SELECT * FROM public.profiles;

  -- Cleanup
  RESET ROLE;
  RESET request.jwt.claims;
 ROLLBACK;
```

## Best Practices

* Always verify authentication state on both client and server
* Use JWT claims for role-based access control
* Implement proper token refresh handling
* Store minimal information in the authentication profile
* Use RLS policies to enforce access control at the data level
* Implement proper error handling for authentication failures
* Use multi-factor authentication for sensitive operations
* Implement email verification for new accounts
* Use secure password policies
* Implement rate limiting for authentication attempts
* Use passwordless authentication where appropriate
* Implement proper session management

## Anti-patterns

* Storing sensitive user data in JWT claims
* Relying solely on client-side authentication checks
* Hardcoding user roles or permissions in client code
* Using service role keys in client applications
* Storing authentication tokens insecurely
* Implementing custom authentication without proper security review
* Not validating email addresses
* Using weak password requirements
* Not implementing proper error messages
* Exposing sensitive user information
* Not implementing proper logout functionality
* Using the same JWT secret across environments