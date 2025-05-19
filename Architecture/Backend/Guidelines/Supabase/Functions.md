# Supabase Cloud Functions Guidelines

**Navigation:** [Back to Supabase Guidelines](README.md) | [Database](Database.md) | [Authentication](Authentication.md) | [Security](Security.md)

---

## Overview

This document provides guidelines for implementing cloud functions in Supabase for the LifeSignal application. All cloud functions should be implemented in Supabase, while authentication and data storage remain in Firebase.

## Function Types

Supabase offers several types of serverless functions:

1. **REST API Functions**: HTTP endpoints that can be called from the client
2. **Edge Functions**: Globally distributed functions for low-latency operations
3. **Scheduled Functions**: Functions that run on a schedule
4. **Webhook Functions**: Functions that are triggered by external events

## Implementation Guidelines

### General Guidelines

1. **TypeScript**: Use TypeScript for all functions
2. **Input Validation**: Validate all input parameters
3. **Error Handling**: Implement proper error handling
4. **Authentication**: Check authentication in all functions
5. **Authorization**: Verify that the user has permission to perform the operation
6. **Logging**: Log all function calls and errors
7. **Testing**: Write unit tests for all functions

### Function Structure

Each function should follow this structure:

```typescript
import { serve } from '@supabase/functions-js'
import { createClient } from '@supabase/supabase-js'

// Define input type
interface FunctionInput {
  // Input parameters
}

// Define output type
interface FunctionOutput {
  // Output parameters
}

// Define error type
interface FunctionError {
  code: string
  message: string
}

// Implement function
export const myFunction = serve(async (req) => {
  try {
    // Parse input
    const input: FunctionInput = await req.json()
    
    // Validate input
    if (!input.requiredParam) {
      return new Response(
        JSON.stringify({
          code: 'invalid-argument',
          message: 'Required parameter is missing'
        } as FunctionError),
        { status: 400 }
      )
    }
    
    // Check authentication
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({
          code: 'unauthenticated',
          message: 'Authentication required'
        } as FunctionError),
        { status: 401 }
      )
    }
    
    // Create Supabase client
    const supabase = createClient(
      process.env.SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    )
    
    // Implement function logic
    // ...
    
    // Return success response
    return new Response(
      JSON.stringify({
        success: true,
        data: { /* result data */ }
      } as FunctionOutput),
      { status: 200 }
    )
  } catch (error) {
    // Log error
    console.error('Function error:', error)
    
    // Return error response
    return new Response(
      JSON.stringify({
        code: 'internal',
        message: 'Internal server error'
      } as FunctionError),
      { status: 500 }
    )
  }
})
```

### Error Handling

Functions should return standardized error responses:

```typescript
{
  code: string,    // Error code (e.g., 'invalid-argument', 'not-found')
  message: string  // User-friendly error message
}
```

Common error codes:

- `unauthenticated`: Authentication required
- `invalid-argument`: Invalid input parameters
- `not-found`: Resource not found
- `permission-denied`: User does not have permission
- `already-exists`: Resource already exists
- `internal`: Internal server error

### Authentication and Authorization

Functions should verify authentication and authorization:

1. **Authentication**: Check that the request includes a valid authentication token
2. **Authorization**: Verify that the authenticated user has permission to perform the operation

Example:

```typescript
// Check authentication
const authHeader = req.headers.get('Authorization')
if (!authHeader) {
  return new Response(
    JSON.stringify({
      code: 'unauthenticated',
      message: 'Authentication required'
    }),
    { status: 401 }
  )
}

// Extract token
const token = authHeader.replace('Bearer ', '')

// Verify token
const { data: user, error } = await supabase.auth.getUser(token)
if (error || !user) {
  return new Response(
    JSON.stringify({
      code: 'unauthenticated',
      message: 'Invalid authentication token'
    }),
    { status: 401 }
  )
}

// Check authorization
const { data: permissions } = await supabase
  .from('permissions')
  .select('*')
  .eq('user_id', user.id)
  .single()

if (!permissions || !permissions.can_perform_action) {
  return new Response(
    JSON.stringify({
      code: 'permission-denied',
      message: 'You do not have permission to perform this action'
    }),
    { status: 403 }
  )
}
```

### Testing

Functions should be tested using unit tests:

```typescript
import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import { createClient } from '@supabase/supabase-js'
import { myFunction } from './myFunction'

describe('myFunction', () => {
  let supabase
  
  beforeEach(() => {
    // Set up test environment
    supabase = createClient('http://localhost:54321', 'test-key')
  })
  
  afterEach(() => {
    // Clean up test environment
  })
  
  it('should return success for valid input', async () => {
    // Arrange
    const input = {
      requiredParam: 'value'
    }
    
    // Act
    const response = await myFunction({
      method: 'POST',
      headers: {
        'Authorization': 'Bearer test-token',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(input)
    })
    
    // Assert
    const result = await response.json()
    expect(response.status).toBe(200)
    expect(result.success).toBe(true)
  })
  
  it('should return error for invalid input', async () => {
    // Arrange
    const input = {
      // Missing required parameter
    }
    
    // Act
    const response = await myFunction({
      method: 'POST',
      headers: {
        'Authorization': 'Bearer test-token',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(input)
    })
    
    // Assert
    const result = await response.json()
    expect(response.status).toBe(400)
    expect(result.code).toBe('invalid-argument')
  })
})
```

## Function Categories

The LifeSignal application uses the following function categories:

1. **Data Management Functions**: Functions for managing application data
   - `addContactRelation`: Add a contact relation between two users
   - `updateContactRoles`: Update the roles of a contact relation
   - `deleteContactRelation`: Delete a contact relation
   - `lookupUserByQRCode`: Look up a user by QR code
   - `respondToPing`: Respond to a ping
   - `respondToAllPings`: Respond to all pings
   - `pingDependent`: Ping a dependent
   - `clearPing`: Clear a ping

2. **Notification Functions**: Functions for managing notifications
   - `sendCheckInReminders`: Send check-in reminders
   - `sendAlertNotifications`: Send alert notifications
   - `sendPingNotifications`: Send ping notifications
   - `sendRoleChangeNotifications`: Send role change notifications
   - `sendContactAddedNotifications`: Send contact added notifications
   - `sendContactRemovedNotifications`: Send contact removed notifications

3. **Scheduled Functions**: Scheduled functions for background tasks
   - `processCheckIns`: Process check-ins
   - `processAlerts`: Process alerts
   - `processNotifications`: Process notifications
   - `cleanupExpiredData`: Clean up expired data

For detailed function specifications, see the [Functions](../../../Specification/Functions/README.md) section.

## Deployment

Functions should be deployed using the Supabase CLI:

```bash
# Install Supabase CLI
npm install -g supabase

# Login to Supabase
supabase login

# Deploy functions
supabase functions deploy myFunction
```

## Monitoring

Functions should be monitored using Supabase's built-in monitoring tools:

1. **Logs**: View function logs in the Supabase dashboard
2. **Metrics**: Monitor function performance and usage
3. **Alerts**: Set up alerts for function errors and performance issues

## Best Practices

1. **Keep Functions Small**: Each function should have a single responsibility
2. **Use Environment Variables**: Store configuration in environment variables
3. **Implement Proper Error Handling**: Return standardized error responses
4. **Log All Function Calls**: Log function calls for debugging and monitoring
5. **Write Unit Tests**: Test all functions with both success and failure cases
6. **Document All Functions**: Document function inputs, outputs, and behavior
7. **Use TypeScript**: Use TypeScript for type safety
8. **Validate Input**: Validate all input parameters
9. **Check Authentication**: Verify authentication in all functions
10. **Check Authorization**: Verify authorization in all functions

## Related Documentation

- [Supabase Overview](README.md) - Overview of Supabase integration
- [Database](Database.md) - Guidelines for implementing Supabase database
- [Authentication](Authentication.md) - Guidelines for implementing Supabase authentication
- [Security](Security.md) - Guidelines for implementing Supabase security
- [Function Specifications](../../../Specification/Functions/README.md) - Detailed specifications for backend functions
