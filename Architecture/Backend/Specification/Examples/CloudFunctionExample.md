# Cloud Function Example

**Navigation:** [Back to Examples](README.md) | [Security Rule Example](SecurityRuleExample.md) | [Database Query Example](DatabaseQueryExample.md)

---

## Overview

This document provides a comprehensive example of a Supabase Cloud Function implementation for the LifeSignal application. The example demonstrates best practices for function implementation, including input validation, error handling, authentication, authorization, database operations, and response formatting.

## Function: addContactRelation

This function creates a bidirectional contact relationship between two users.

### Function Definition

```typescript
import { serve } from '@supabase/functions-js'
import { createClient } from '@supabase/supabase-js'

// Initialize Supabase client
const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const supabase = createClient(supabaseUrl, supabaseKey)

// Define request and response types
interface AddContactRequest {
  userId: string
  contactId: string
  isResponder: boolean
  isDependent: boolean
}

interface AddContactResponse {
  success: boolean
  contactId?: string
  error?: string
}

// Define error types
enum ErrorCode {
  UNAUTHORIZED = 'unauthorized',
  INVALID_REQUEST = 'invalid_request',
  USER_NOT_FOUND = 'user_not_found',
  CONTACT_NOT_FOUND = 'contact_not_found',
  CONTACT_EXISTS = 'contact_exists',
  INTERNAL_ERROR = 'internal_error'
}

// Main function handler
serve(async (req) => {
  try {
    // Parse request body
    const { userId, contactId, isResponder, isDependent } = await req.json() as AddContactRequest

    // Validate request
    if (!userId || !contactId) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'User ID and contact ID are required'
        } as AddContactResponse),
        { 
          status: 400,
          headers: { 'Content-Type': 'application/json' }
        }
      )
    }

    // Prevent adding yourself as a contact
    if (userId === contactId) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Cannot add yourself as a contact'
        } as AddContactResponse),
        { 
          status: 400,
          headers: { 'Content-Type': 'application/json' }
        }
      )
    }

    // Get JWT from request
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Authentication required'
        } as AddContactResponse),
        { 
          status: 401,
          headers: { 'Content-Type': 'application/json' }
        }
      )
    }

    // Verify JWT and get user
    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    
    if (authError || !user) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Authentication failed'
        } as AddContactResponse),
        { 
          status: 401,
          headers: { 'Content-Type': 'application/json' }
        }
      )
    }

    // Verify that the authenticated user is the one making the request
    if (user.id !== userId) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'You can only add contacts for yourself'
        } as AddContactResponse),
        { 
          status: 403,
          headers: { 'Content-Type': 'application/json' }
        }
      )
    }

    // Get user and contact profiles
    const { data: userProfile, error: userError } = await supabase
      .from('user_profiles')
      .select('*')
      .eq('user_id', userId)
      .single()

    const { data: contactProfile, error: contactError } = await supabase
      .from('user_profiles')
      .select('*')
      .eq('user_id', contactId)
      .single()

    if (userError || !userProfile) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'User not found'
        } as AddContactResponse),
        { 
          status: 404,
          headers: { 'Content-Type': 'application/json' }
        }
      )
    }

    if (contactError || !contactProfile) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Contact not found'
        } as AddContactResponse),
        { 
          status: 404,
          headers: { 'Content-Type': 'application/json' }
        }
      )
    }

    // Check if contact already exists
    const { data: existingContact, error: existingContactError } = await supabase
      .from('contacts')
      .select('*')
      .eq('user_id', userId)
      .eq('contact_id', contactId)
      .single()

    if (existingContact) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'This user is already in your contacts'
        } as AddContactResponse),
        { 
          status: 409,
          headers: { 'Content-Type': 'application/json' }
        }
      )
    }

    // Create timestamp
    const now = new Date().toISOString()

    // Create bidirectional contact relationship
    const { error: insertUserContactError } = await supabase
      .from('contacts')
      .insert({
        user_id: userId,
        contact_id: contactId,
        is_responder: isResponder,
        is_dependent: isDependent,
        send_pings: true,
        receive_pings: true,
        notify_on_check_in: isResponder,
        notify_on_expiry: isResponder,
        added_at: now,
        last_updated: now
      })

    const { error: insertContactUserError } = await supabase
      .from('contacts')
      .insert({
        user_id: contactId,
        contact_id: userId,
        is_responder: isDependent, // Reciprocal role
        is_dependent: isResponder, // Reciprocal role
        send_pings: true,
        receive_pings: true,
        notify_on_check_in: isDependent,
        notify_on_expiry: isDependent,
        added_at: now,
        last_updated: now
      })

    if (insertUserContactError || insertContactUserError) {
      // Rollback if one insert succeeded but the other failed
      if (!insertUserContactError) {
        await supabase
          .from('contacts')
          .delete()
          .eq('user_id', userId)
          .eq('contact_id', contactId)
      }

      if (!insertContactUserError) {
        await supabase
          .from('contacts')
          .delete()
          .eq('user_id', contactId)
          .eq('contact_id', userId)
      }

      return new Response(
        JSON.stringify({
          success: false,
          error: 'Failed to create contact relationship'
        } as AddContactResponse),
        { 
          status: 500,
          headers: { 'Content-Type': 'application/json' }
        }
      )
    }

    // Return success response
    return new Response(
      JSON.stringify({
        success: true,
        contactId: contactId
      } as AddContactResponse),
      { 
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      }
    )
  } catch (error) {
    // Log error
    console.error('Error adding contact relation:', error)

    // Return error response
    return new Response(
      JSON.stringify({
        success: false,
        error: 'Internal server error'
      } as AddContactResponse),
      { 
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      }
    )
  }
})
```

### Key Implementation Features

1. **Type Safety**: Using TypeScript interfaces for request and response types
2. **Input Validation**: Validating all input parameters
3. **Authentication**: Verifying JWT token and user identity
4. **Authorization**: Ensuring the user can only add contacts for themselves
5. **Error Handling**: Comprehensive error handling with appropriate status codes
6. **Transaction Management**: Rolling back changes if one part of the transaction fails
7. **Response Formatting**: Consistent response format with success status and error messages

## Testing the Function

### Unit Testing

```typescript
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { createClient } from '@supabase/supabase-js'

// Mock Supabase client
vi.mock('@supabase/supabase-js', () => {
  return {
    createClient: vi.fn(() => ({
      auth: {
        getUser: vi.fn()
      },
      from: vi.fn(() => ({
        select: vi.fn(() => ({
          eq: vi.fn(() => ({
            single: vi.fn()
          }))
        })),
        insert: vi.fn(() => ({
          select: vi.fn()
        })),
        delete: vi.fn(() => ({
          eq: vi.fn(() => ({
            eq: vi.fn()
          }))
        }))
      }))
    }))
  }
})

// Import function handler
import { handler } from './addContactRelation'

describe('addContactRelation', () => {
  let mockRequest
  let mockSupabase

  beforeEach(() => {
    // Setup mock request
    mockRequest = {
      json: vi.fn().mockResolvedValue({
        userId: 'user123',
        contactId: 'contact456',
        isResponder: true,
        isDependent: false
      }),
      headers: {
        get: vi.fn().mockReturnValue('Bearer fake-token')
      }
    }

    // Setup mock Supabase responses
    mockSupabase = createClient('', '')
    mockSupabase.auth.getUser.mockResolvedValue({
      data: { user: { id: 'user123' } },
      error: null
    })

    const mockFrom = mockSupabase.from
    mockFrom.mockImplementation((table) => {
      const mockSelect = vi.fn().mockReturnValue({
        eq: vi.fn().mockReturnValue({
          single: vi.fn().mockResolvedValue({
            data: table === 'user_profiles' ? { id: 1 } : null,
            error: null
          })
        })
      })

      const mockInsert = vi.fn().mockResolvedValue({
        error: null
      })

      return {
        select: mockSelect,
        insert: mockInsert,
        delete: vi.fn().mockReturnValue({
          eq: vi.fn().mockReturnValue({
            eq: vi.fn()
          })
        })
      }
    })
  })

  afterEach(() => {
    vi.clearAllMocks()
  })

  it('should create a contact relationship successfully', async () => {
    const response = await handler(mockRequest)
    const body = await response.json()

    expect(response.status).toBe(200)
    expect(body).toEqual({
      success: true,
      contactId: 'contact456'
    })
  })

  it('should return 400 if userId or contactId is missing', async () => {
    mockRequest.json.mockResolvedValue({
      userId: '',
      contactId: 'contact456',
      isResponder: true,
      isDependent: false
    })

    const response = await handler(mockRequest)
    const body = await response.json()

    expect(response.status).toBe(400)
    expect(body).toEqual({
      success: false,
      error: 'User ID and contact ID are required'
    })
  })

  it('should return 401 if authentication is missing', async () => {
    mockRequest.headers.get.mockReturnValue(null)

    const response = await handler(mockRequest)
    const body = await response.json()

    expect(response.status).toBe(401)
    expect(body).toEqual({
      success: false,
      error: 'Authentication required'
    })
  })

  // Additional test cases...
})
```

### Integration Testing

```typescript
import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { createClient } from '@supabase/supabase-js'

// Create Supabase client for testing
const supabaseUrl = process.env.SUPABASE_URL
const supabaseKey = process.env.SUPABASE_ANON_KEY
const supabase = createClient(supabaseUrl, supabaseKey)

describe('addContactRelation Integration', () => {
  let testUserId
  let testContactId
  let authToken

  beforeAll(async () => {
    // Create test users
    const { data: user1 } = await supabase.auth.signUp({
      email: 'test1@example.com',
      password: 'password123'
    })

    const { data: user2 } = await supabase.auth.signUp({
      email: 'test2@example.com',
      password: 'password123'
    })

    testUserId = user1.user.id
    testContactId = user2.user.id

    // Get auth token
    const { data } = await supabase.auth.signInWithPassword({
      email: 'test1@example.com',
      password: 'password123'
    })

    authToken = data.session.access_token

    // Create user profiles
    await supabase.from('user_profiles').insert([
      {
        user_id: testUserId,
        name: 'Test User 1',
        phone: '+15551234567',
        note: 'Test note',
        check_in_interval: 86400
      },
      {
        user_id: testContactId,
        name: 'Test User 2',
        phone: '+15557654321',
        note: 'Test note',
        check_in_interval: 86400
      }
    ])
  })

  afterAll(async () => {
    // Clean up test data
    await supabase.from('contacts').delete().eq('user_id', testUserId)
    await supabase.from('contacts').delete().eq('user_id', testContactId)
    await supabase.from('user_profiles').delete().eq('user_id', testUserId)
    await supabase.from('user_profiles').delete().eq('user_id', testContactId)
    await supabase.auth.admin.deleteUser(testUserId)
    await supabase.auth.admin.deleteUser(testContactId)
  })

  it('should create a contact relationship', async () => {
    const response = await fetch(`${supabaseUrl}/functions/v1/addContactRelation`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${authToken}`
      },
      body: JSON.stringify({
        userId: testUserId,
        contactId: testContactId,
        isResponder: true,
        isDependent: false
      })
    })

    const data = await response.json()

    expect(response.status).toBe(200)
    expect(data).toEqual({
      success: true,
      contactId: testContactId
    })

    // Verify contact relationships were created
    const { data: userContact } = await supabase
      .from('contacts')
      .select('*')
      .eq('user_id', testUserId)
      .eq('contact_id', testContactId)
      .single()

    const { data: contactUser } = await supabase
      .from('contacts')
      .select('*')
      .eq('user_id', testContactId)
      .eq('contact_id', testUserId)
      .single()

    expect(userContact).toBeTruthy()
    expect(userContact.is_responder).toBe(true)
    expect(userContact.is_dependent).toBe(false)

    expect(contactUser).toBeTruthy()
    expect(contactUser.is_responder).toBe(false)
    expect(contactUser.is_dependent).toBe(true)
  })
})
```

## Deployment

### Supabase Edge Function Deployment

```bash
# Deploy the function
supabase functions deploy addContactRelation --project-ref your-project-ref

# Set environment variables
supabase secrets set SUPABASE_URL=https://your-project.supabase.co SUPABASE_SERVICE_ROLE_KEY=your-service-role-key --project-ref your-project-ref

# Test the deployed function
curl -X POST https://your-project.supabase.co/functions/v1/addContactRelation \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-auth-token" \
  -d '{"userId":"user123","contactId":"contact456","isResponder":true,"isDependent":false}'
```

## Best Practices

1. **Type Safety**: Use TypeScript for type safety
2. **Input Validation**: Validate all input parameters
3. **Authentication**: Verify JWT token and user identity
4. **Authorization**: Ensure users can only access their own data
5. **Error Handling**: Implement comprehensive error handling
6. **Transaction Management**: Use transactions for atomic operations
7. **Response Formatting**: Use consistent response formats
8. **Logging**: Log function calls and errors
9. **Testing**: Write unit and integration tests
10. **Documentation**: Document function behavior and parameters

For detailed implementation guidelines, see the [Backend Guidelines](../../Guidelines/README.md) section.
