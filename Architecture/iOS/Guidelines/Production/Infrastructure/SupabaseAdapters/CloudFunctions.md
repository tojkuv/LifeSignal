# Supabase Cloud Functions Guidelines

**Navigation:** [Back to Supabase Overview](Overview.md) | [Client Design](ClientDesign.md) | [Backend Integration](../BackendIntegration.md)

---

## Overview

This document provides guidelines for implementing cloud functions in Supabase for the LifeSignal application. All cloud functions should be implemented in Supabase, while authentication and data storage remain in Firebase.

## Function Types

Supabase offers several types of serverless functions:

1. **Edge Functions**: JavaScript/TypeScript functions that run on Deno at the edge
2. **Database Functions**: SQL functions that run inside the PostgreSQL database
3. **Webhooks**: HTTP endpoints that trigger on database changes
4. **Scheduled Functions**: Functions that run on a schedule

For LifeSignal, we primarily use Edge Functions for our cloud function needs.

## Edge Function Implementation

### Project Structure

Edge functions should be organized in a structured way:

```
supabase/
├── functions/
│   ├── send-push-notification/
│   │   ├── index.ts
│   │   └── README.md
│   ├── check-in-reminder/
│   │   ├── index.ts
│   │   └── README.md
│   └── _shared/
│       ├── cors.ts
│       ├── auth.ts
│       └── types.ts
└── config.toml
```

Each function should be in its own directory with a descriptive name.

### Function Template

Use this template for Edge Functions:

```typescript
// supabase/functions/function-name/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { verifyAuth } from '../_shared/auth.ts'

interface RequestPayload {
  // Define request payload type
}

interface ResponsePayload {
  // Define response payload type
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  
  try {
    // Verify authentication
    const userId = await verifyAuth(req)
    if (!userId) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    // Parse request body
    const payload: RequestPayload = await req.json()
    
    // Validate input
    if (!payload.requiredField) {
      return new Response(
        JSON.stringify({ error: 'Missing required field' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    // Function logic
    // ...
    
    // Return response
    const response: ResponsePayload = {
      // Response data
    }
    
    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    // Error handling
    console.error('Error:', error.message)
    
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
```

### Shared Utilities

Create shared utilities for common functionality:

#### CORS Handling

```typescript
// supabase/functions/_shared/cors.ts
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
}
```

#### Authentication

```typescript
// supabase/functions/_shared/auth.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

export async function verifyAuth(req: Request): Promise<string | null> {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return null
  
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: authHeader } } }
  )
  
  const { data: { user }, error } = await supabase.auth.getUser()
  if (error || !user) return null
  
  return user.id
}
```

#### Type Definitions

```typescript
// supabase/functions/_shared/types.ts
export interface User {
  id: string
  email?: string
  phone?: string
  // Other user properties
}

export interface Contact {
  id: string
  name: string
  phone: string
  roles: string[]
  // Other contact properties
}

// Other shared types
```

## Best Practices

### 1. Function Design

- **Single Responsibility**: Each function should do one thing well
- **Stateless**: Functions should be stateless and idempotent
- **Input Validation**: Validate all input parameters
- **Error Handling**: Implement proper error handling and return appropriate status codes
- **Logging**: Include appropriate logging for debugging and monitoring
- **Authentication**: Verify authentication for all functions that require it
- **Authorization**: Implement proper authorization checks

### 2. Performance Optimization

- **Minimize Cold Starts**: Keep functions small and focused
- **Optimize Dependencies**: Minimize external dependencies
- **Caching**: Use caching for expensive operations
- **Async/Await**: Use async/await for asynchronous operations
- **Streaming**: Use streaming for large responses
- **Timeout Handling**: Handle timeouts gracefully

### 3. Security

- **Input Sanitization**: Sanitize all user input
- **Authentication**: Verify authentication tokens
- **Authorization**: Check permissions before performing operations
- **Secrets Management**: Use environment variables for secrets
- **Rate Limiting**: Implement rate limiting for public endpoints
- **CORS**: Configure CORS headers appropriately
- **Content Security Policy**: Set appropriate security headers

### 4. Testing

- **Unit Testing**: Write unit tests for function logic
- **Integration Testing**: Test function integration with other services
- **End-to-End Testing**: Test the complete flow from client to function
- **Mocking**: Use mocks for external dependencies
- **Test Coverage**: Aim for high test coverage
- **Local Testing**: Test functions locally before deployment

### 5. Deployment

- **CI/CD**: Use CI/CD pipelines for deployment
- **Environment Variables**: Configure environment variables for each environment
- **Versioning**: Version your functions
- **Rollback Plan**: Have a plan for rolling back deployments
- **Monitoring**: Set up monitoring and alerting
- **Documentation**: Document function interfaces and behavior

## Function Categories

Organize functions by category:

### User Management

- `update-user-profile`: Update user profile information
- `delete-user-account`: Delete user account and associated data

### Notification System

- `send-push-notification`: Send push notifications to users
- `schedule-notification`: Schedule notifications for future delivery
- `cancel-notification`: Cancel scheduled notifications

### Check-In System

- `process-check-in`: Process user check-ins
- `send-check-in-reminder`: Send check-in reminders
- `process-missed-check-in`: Process missed check-ins

### Alert System

- `trigger-alert`: Trigger an alert for a user
- `cancel-alert`: Cancel an active alert
- `process-alert-response`: Process responses to alerts

### Contact Management

- `invite-contact`: Send invitation to a new contact
- `process-contact-acceptance`: Process contact acceptance
- `remove-contact`: Remove a contact relationship

## Example Functions

### Send Push Notification

```typescript
// supabase/functions/send-push-notification/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { verifyAuth } from '../_shared/auth.ts'
import { initializeFirebaseAdmin } from '../_shared/firebase.ts'

interface PushNotificationRequest {
  userId: string
  title: string
  body: string
  data?: Record<string, string>
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  
  try {
    // Verify authentication
    const senderId = await verifyAuth(req)
    if (!senderId) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    // Parse request body
    const { userId, title, body, data }: PushNotificationRequest = await req.json()
    
    // Validate input
    if (!userId || !title || !body) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    // Initialize Firebase Admin
    const admin = initializeFirebaseAdmin()
    
    // Get user's FCM token from Firebase
    const userDoc = await admin.firestore().collection('users').doc(userId).get()
    if (!userDoc.exists) {
      return new Response(
        JSON.stringify({ error: 'User not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    const fcmToken = userDoc.data()?.fcmToken
    if (!fcmToken) {
      return new Response(
        JSON.stringify({ error: 'User has no FCM token' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    // Send notification
    const message = {
      notification: {
        title,
        body,
      },
      data: data || {},
      token: fcmToken,
    }
    
    const response = await admin.messaging().send(message)
    
    // Log notification
    await admin.firestore().collection('notifications').add({
      senderId,
      recipientId: userId,
      title,
      body,
      data,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'sent',
    })
    
    return new Response(
      JSON.stringify({ success: true, messageId: response }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error sending notification:', error)
    
    return new Response(
      JSON.stringify({ error: 'Failed to send notification' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
```

### Process Check-In

```typescript
// supabase/functions/process-check-in/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { verifyAuth } from '../_shared/auth.ts'
import { initializeFirebaseAdmin } from '../_shared/firebase.ts'

interface CheckInRequest {
  nextCheckInInterval: number // in seconds
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  
  try {
    // Verify authentication
    const userId = await verifyAuth(req)
    if (!userId) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    // Parse request body
    const { nextCheckInInterval }: CheckInRequest = await req.json()
    
    // Validate input
    if (!nextCheckInInterval || nextCheckInInterval < 0) {
      return new Response(
        JSON.stringify({ error: 'Invalid check-in interval' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    // Initialize Firebase Admin
    const admin = initializeFirebaseAdmin()
    
    // Get user document
    const userDoc = await admin.firestore().collection('users').doc(userId).get()
    if (!userDoc.exists) {
      return new Response(
        JSON.stringify({ error: 'User not found' }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    // Calculate next check-in time
    const now = admin.firestore.Timestamp.now()
    const nextCheckInTime = new admin.firestore.Timestamp(
      now.seconds + nextCheckInInterval,
      now.nanoseconds
    )
    
    // Update user's check-in status
    await admin.firestore().collection('users').doc(userId).update({
      lastCheckInTime: now,
      nextCheckInTime: nextCheckInTime,
      checkInStatus: 'active',
    })
    
    // Log check-in
    await admin.firestore().collection('checkIns').add({
      userId,
      checkInTime: now,
      nextCheckInTime: nextCheckInTime,
      interval: nextCheckInInterval,
    })
    
    // Cancel any existing check-in reminders
    const existingReminders = await admin.firestore()
      .collection('scheduledTasks')
      .where('type', '==', 'checkInReminder')
      .where('userId', '==', userId)
      .where('status', '==', 'pending')
      .get()
    
    const batch = admin.firestore().batch()
    existingReminders.docs.forEach(doc => {
      batch.update(doc.ref, { status: 'cancelled' })
    })
    
    // Schedule new check-in reminder
    const reminderTime = new admin.firestore.Timestamp(
      nextCheckInTime.seconds - (30 * 60), // 30 minutes before next check-in
      nextCheckInTime.nanoseconds
    )
    
    batch.set(admin.firestore().collection('scheduledTasks').doc(), {
      type: 'checkInReminder',
      userId,
      scheduledTime: reminderTime,
      status: 'pending',
      createdAt: now,
    })
    
    await batch.commit()
    
    return new Response(
      JSON.stringify({
        success: true,
        lastCheckInTime: now.toDate().toISOString(),
        nextCheckInTime: nextCheckInTime.toDate().toISOString(),
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error processing check-in:', error)
    
    return new Response(
      JSON.stringify({ error: 'Failed to process check-in' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
```

## iOS Client Integration

### Client Interface

```swift
protocol CheckInClient {
    func processCheckIn(nextCheckInInterval: TimeInterval) async throws -> CheckInResult
}

struct CheckInResult {
    let lastCheckInTime: Date
    let nextCheckInTime: Date
}
```

### Supabase Adapter

```swift
struct SupabaseCheckInAdapter: CheckInClient {
    private let cloudFunctionClient: CloudFunctionClient
    
    init(cloudFunctionClient: CloudFunctionClient) {
        self.cloudFunctionClient = cloudFunctionClient
    }
    
    func processCheckIn(nextCheckInInterval: TimeInterval) async throws -> CheckInResult {
        let request = CheckInRequest(nextCheckInInterval: nextCheckInInterval)
        
        let response: CheckInResponse = try await cloudFunctionClient.callFunction(
            name: "process-check-in",
            request: request
        )
        
        let lastCheckInTime = ISO8601DateFormatter().date(from: response.lastCheckInTime)!
        let nextCheckInTime = ISO8601DateFormatter().date(from: response.nextCheckInTime)!
        
        return CheckInResult(
            lastCheckInTime: lastCheckInTime,
            nextCheckInTime: nextCheckInTime
        )
    }
}

struct CheckInRequest: Encodable {
    let nextCheckInInterval: TimeInterval
}

struct CheckInResponse: Decodable {
    let success: Bool
    let lastCheckInTime: String
    let nextCheckInTime: String
}
```

## Conclusion

By following these guidelines, you can implement robust, secure, and performant cloud functions in Supabase for the LifeSignal application. Remember that all cloud functions should be implemented in Supabase, while authentication and data storage remain in Firebase.
