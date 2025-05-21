# Supabase Functions

## Purpose

This document outlines the architecture, patterns, and best practices for implementing Supabase Edge Functions.

## Core Principles

### Type Safety

- Use TypeScript for all Edge Functions
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
- Use local Supabase instance for integration testing
- Implement test fixtures and factories
- Design deterministic function behavior for testing

## Content Structure

### Function Organization

#### Project Structure

Our Edge Functions project follows a domain-driven structure:

```
supabase/
├── functions/
│   ├── auth/
│   │   ├── on-user-created.ts
│   │   ├── update-user-role.ts
│   │   └── _shared/
│   │       ├── auth-utils.ts
│   │       └── types.ts
│   ├── users/
│   │   ├── get-user-profile.ts
│   │   ├── update-user-profile.ts
│   │   └── _shared/
│   │       ├── user-utils.ts
│   │       └── types.ts
│   ├── notifications/
│   │   ├── send-notification.ts
│   │   ├── schedule-notification.ts
│   │   └── _shared/
│   │       ├── notification-utils.ts
│   │       └── types.ts
│   ├── _shared/
│   │   ├── db.ts
│   │   ├── validation.ts
│   │   ├── middleware.ts
│   │   └── error-handler.ts
│   └── _test/
│       ├── auth/
│       ├── users/
│       ├── notifications/
│       └── utils/
└── config.toml
```

#### Function Types

We implement the following types of functions:

1. **API Functions**: RESTful API endpoints
2. **Database Webhooks**: Functions triggered by database events
3. **Authentication Hooks**: Functions triggered by auth events
4. **Scheduled Functions**: Functions that run on a schedule
5. **Utility Functions**: Reusable utility functions

### Implementation Patterns

#### API Functions

```typescript
// Example: API function
import { serve } from 'https://deno.land/std@0.131.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.0.0';
import { corsHeaders } from '../_shared/cors.ts';
import { validateRequest } from '../_shared/validation.ts';
import { handleError } from '../_shared/error-handler.ts';

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Validate request
    if (req.method !== 'GET') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Parse URL and get user ID
    const url = new URL(req.url);
    const userId = url.searchParams.get('userId');

    if (!userId) {
      return new Response(
        JSON.stringify({ error: 'Missing userId parameter' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Create Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Get user profile
    const { data, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('user_id', userId)
      .single();

    if (error) {
      if (error.code === 'PGRST116') {
        return new Response(
          JSON.stringify({ error: 'User not found' }),
          { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      throw error;
    }

    // Return response
    return new Response(
      JSON.stringify(data),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    return handleError(error, corsHeaders);
  }
});
```

#### Database Webhook Functions

```typescript
// Example: Database webhook function
import { serve } from 'https://deno.land/std@0.131.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.0.0';
import { WebhookPayload } from '../_shared/types.ts';
import { handleError } from '../_shared/error-handler.ts';

serve(async (req) => {
  try {
    // Parse webhook payload
    const payload: WebhookPayload = await req.json();

    // Verify webhook signature
    const signature = req.headers.get('x-supabase-webhook-signature');
    if (!signature || !verifySignature(payload, signature)) {
      return new Response(
        JSON.stringify({ error: 'Invalid webhook signature' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Create Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Process the event
    if (payload.type === 'INSERT' && payload.table === 'posts') {
      const post = payload.record;

      // Get author information
      const { data: author, error } = await supabase
        .from('profiles')
        .select('display_name, email')
        .eq('user_id', post.author_id)
        .single();

      if (error) {
        throw error;
      }

      // Update post with author information
      await supabase
        .from('posts')
        .update({
          author_name: author.display_name
        })
        .eq('id', post.id);

      // Notify followers
      await notifyFollowers(supabase, post, author);
    }

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    return handleError(error);
  }
});

// Verify webhook signature
function verifySignature(payload: any, signature: string): boolean {
  const webhookSecret = Deno.env.get('WEBHOOK_SECRET') ?? '';
  const encoder = new TextEncoder();
  const data = encoder.encode(JSON.stringify(payload));

  // Implementation of signature verification
  // ...

  return true; // Placeholder
}

// Notify followers
async function notifyFollowers(supabase: any, post: any, author: any): Promise<void> {
  // Get followers
  const { data: followers, error } = await supabase
    .from('followers')
    .select('follower_id')
    .eq('user_id', post.author_id);

  if (error) {
    throw error;
  }

  // Create notifications
  const notifications = followers.map((follower: any) => ({
    user_id: follower.follower_id,
    type: 'new_post',
    content: `${author.display_name} published a new post: ${post.title}`,
    reference_id: post.id,
    reference_type: 'post',
    created_at: new Date().toISOString()
  }));

  if (notifications.length > 0) {
    await supabase
      .from('notifications')
      .insert(notifications);
  }
}
```

#### Authentication Hook Functions

```typescript
// Example: Authentication hook function
import { serve } from 'https://deno.land/std@0.131.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.0.0';
import { AuthWebhookPayload } from '../_shared/types.ts';
import { handleError } from '../_shared/error-handler.ts';

serve(async (req) => {
  try {
    // Parse webhook payload
    const payload: AuthWebhookPayload = await req.json();

    // Verify webhook signature
    const signature = req.headers.get('x-supabase-webhook-signature');
    if (!signature || !verifySignature(payload, signature)) {
      return new Response(
        JSON.stringify({ error: 'Invalid webhook signature' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Create Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Process the event
    if (payload.type === 'signup') {
      const user = payload.record;

      // Create user profile
      await supabase
        .from('profiles')
        .insert({
          user_id: user.id,
          display_name: user.email?.split('@')[0] || 'User',
          email: user.email,
          created_at: new Date().toISOString()
        });

      // Send welcome email
      await sendWelcomeEmail(user.email);
    }

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    return handleError(error);
  }
});

// Verify webhook signature
function verifySignature(payload: any, signature: string): boolean {
  // Implementation of signature verification
  // ...

  return true; // Placeholder
}

// Send welcome email
async function sendWelcomeEmail(email: string): Promise<void> {
  // Implementation of email sending
  // ...
}
```

### Middleware Pattern

Implement reusable middleware:

```typescript
// Example: Authentication middleware
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.0.0';

export interface AuthResult {
  success: boolean;
  userId?: string;
  error?: string;
  supabase?: SupabaseClient;
}

export async function authMiddleware(req: Request): Promise<AuthResult> {
  try {
    // Get authorization header
    const authHeader = req.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return { success: false, error: 'Missing or invalid authorization header' };
    }

    // Extract JWT token
    const token = authHeader.split('Bearer ')[1];

    // Create Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    const supabase = createClient(supabaseUrl, supabaseKey, {
      global: {
        headers: {
          Authorization: `Bearer ${token}`
        }
      }
    });

    // Verify token
    const { data, error } = await supabase.auth.getUser();

    if (error || !data.user) {
      return { success: false, error: 'Invalid authentication token' };
    }

    return {
      success: true,
      userId: data.user.id,
      supabase
    };
  } catch (error) {
    console.error('Auth middleware error:', error);
    return {
      success: false,
      error: 'Authentication error'
    };
  }
}
```

## Error Handling

### Error Classification

We classify Edge Function errors into the following categories:

- **Authentication Errors**: Issues with user authentication or authorization
- **Validation Errors**: Invalid input data or parameters
- **Database Errors**: Problems accessing or manipulating data
- **Business Logic Errors**: Errors in application-specific logic
- **External Service Errors**: Issues with third-party services
- **Infrastructure Errors**: Problems with the Edge Functions infrastructure

### Error Handling Implementation

```typescript
// Example: Error handling utility
export interface ErrorResponse {
  error: string;
  details?: any;
  status: number;
}

export function handleError(error: any, headers: HeadersInit = {}): Response {
  console.error('Function error:', error);

  const defaultHeaders = {
    'Content-Type': 'application/json',
    ...headers
  };

  // Handle known error types
  if (error.code) {
    switch (error.code) {
      case 'PGRST116':
        return new Response(
          JSON.stringify({ error: 'Resource not found' }),
          { status: 404, headers: defaultHeaders }
        );
      case '23505':
        return new Response(
          JSON.stringify({ error: 'Duplicate resource' }),
          { status: 409, headers: defaultHeaders }
        );
      case '42P01':
        return new Response(
          JSON.stringify({ error: 'Database error' }),
          { status: 500, headers: defaultHeaders }
        );
      default:
        // Handle other database errors
        if (error.code.startsWith('22') || error.code.startsWith('23')) {
          return new Response(
            JSON.stringify({ error: 'Invalid data', details: error.message }),
            { status: 400, headers: defaultHeaders }
          );
        }
    }
  }

  // Handle authentication errors
  if (error.message?.includes('JWT')) {
    return new Response(
      JSON.stringify({ error: 'Authentication error' }),
      { status: 401, headers: defaultHeaders }
    );
  }

  // Handle validation errors
  if (error.name === 'ValidationError') {
    return new Response(
      JSON.stringify({ error: 'Validation error', details: error.details }),
      { status: 400, headers: defaultHeaders }
    );
  }

  // Default error response
  return new Response(
    JSON.stringify({ error: 'Internal server error' }),
    { status: 500, headers: defaultHeaders }
  );
}
```

## Testing

### Unit Testing Strategy

We implement a comprehensive unit testing strategy for all Edge Functions:

1. **Isolated Testing**: Test each function in isolation with mocked dependencies
2. **Test Categories**: Test success cases, error cases, and edge cases
3. **Mocking Strategy**: Use dependency injection for easier mocking
4. **Coverage Goals**: Aim for >90% code coverage for all functions

### Unit Testing Implementation

```typescript
// Example: Function test
import { assertEquals, assertObjectMatch } from 'https://deno.land/std@0.131.0/testing/asserts.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.0.0';
import { MockRequest } from '../_test/utils/mock-request.ts';
import { MockResponse } from '../_test/utils/mock-response.ts';
import { getUserProfile } from './get-user-profile.ts';

Deno.test('getUserProfile - returns user profile for valid userId', async () => {
  // Mock Supabase client
  const mockSupabase = {
    from: (table: string) => ({
      select: (columns: string) => ({
        eq: (column: string, value: string) => ({
          single: async () => ({
            data: {
              user_id: 'user123',
              display_name: 'Test User',
              email: 'test@example.com'
            },
            error: null
          })
        })
      })
    })
  };

  // Mock createClient function
  globalThis.createClient = () => mockSupabase;

  // Create mock request
  const req = new MockRequest({
    method: 'GET',
    url: 'https://example.com/api/get-user-profile?userId=user123',
    headers: new Headers({
      'Authorization': 'Bearer valid-token'
    })
  });

  // Call function
  const response = await getUserProfile(req);

  // Assert response
  assertEquals(response.status, 200);

  const responseBody = await response.json();
  assertObjectMatch(responseBody, {
    user_id: 'user123',
    display_name: 'Test User',
    email: 'test@example.com'
  });
});

Deno.test('getUserProfile - returns 400 for missing userId', async () => {
  // Create mock request without userId
  const req = new MockRequest({
    method: 'GET',
    url: 'https://example.com/api/get-user-profile',
    headers: new Headers({
      'Authorization': 'Bearer valid-token'
    })
  });

  // Call function
  const response = await getUserProfile(req);

  // Assert response
  assertEquals(response.status, 400);

  const responseBody = await response.json();
  assertEquals(responseBody.error, 'Missing userId parameter');
});
```

### Integration Testing

```typescript
// Example: Integration test with local Supabase
import { assertEquals } from 'https://deno.land/std@0.131.0/testing/asserts.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.0.0';

Deno.test('Integration test - create and get user profile', async () => {
  // Connect to local Supabase instance
  const supabase = createClient(
    'http://localhost:54321',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
  );

  // Create test user
  const { data: user, error: authError } = await supabase.auth.signUp({
    email: `test-${Date.now()}@example.com`,
    password: 'password123'
  });

  assertEquals(authError, null);

  // Wait for auth webhook to create profile
  await new Promise(resolve => setTimeout(resolve, 1000));

  // Get user profile
  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('*')
    .eq('user_id', user.user.id)
    .single();

  assertEquals(profileError, null);
  assertEquals(profile.user_id, user.user.id);
});
```

### Performance Testing

```typescript
// Example: Performance test
import { assert } from 'https://deno.land/std@0.131.0/testing/asserts.ts';

Deno.test('Performance test - function completes in under 200ms', async () => {
  // Create mock request
  const req = new MockRequest({
    method: 'GET',
    url: 'https://example.com/api/get-user-profile?userId=user123',
    headers: new Headers({
      'Authorization': 'Bearer valid-token'
    })
  });

  // Measure execution time
  const startTime = performance.now();
  await getUserProfile(req);
  const endTime = performance.now();
  const executionTime = endTime - startTime;

  // Assert execution time is under threshold
  assert(executionTime < 200, `Function took ${executionTime}ms, which exceeds the 200ms threshold`);
});
```

### Deployment

Deploy functions using Supabase CLI:

```bash
# Example: Deploy all functions
supabase functions deploy

# Example: Deploy specific function
supabase functions deploy get-user-profile

# Example: Deploy with environment variables
supabase functions deploy get-user-profile --env-file .env.production
```

### Environment Variables

Manage environment variables:

```bash
# Example: Set environment variables
supabase secrets set EXTERNAL_API_KEY=your-api-key

# Example: List environment variables
supabase secrets list
```



## Best Practices

* Organize functions by domain
* Implement proper error handling
* Use TypeScript for type safety
* Create reusable middleware
* Implement comprehensive logging
* Optimize database queries
* Implement proper security checks
* Write comprehensive tests
* Use environment variables for configuration
* Implement proper CORS handling
* Keep functions small and focused
* Implement proper request validation

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
* Using service role keys unnecessarily
* Not implementing proper request validation