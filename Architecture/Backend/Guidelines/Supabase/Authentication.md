# Supabase Authentication Guidelines

**Navigation:** [Back to Supabase Guidelines](README.md) | [Functions](Functions.md) | [Database](Database.md) | [Security](Security.md)

---

## Overview

This document provides guidelines for implementing authentication in Supabase for the LifeSignal application. While the primary authentication is handled by Firebase Authentication, Supabase functions need to verify Firebase authentication tokens.

## Authentication Flow

The authentication flow in the LifeSignal application is as follows:

1. **Client Authentication**: The client authenticates with Firebase Authentication
2. **Token Generation**: Firebase Authentication generates a JWT token
3. **Token Verification**: Supabase functions verify the Firebase JWT token
4. **Authorization**: Supabase functions check the user's permissions

## Implementation Guidelines

### Token Verification

Supabase functions should verify Firebase JWT tokens:

```typescript
import { serve } from '@supabase/functions-js'
import { createClient } from '@supabase/supabase-js'
import { auth } from 'firebase-admin'

// Initialize Firebase Admin
const firebaseApp = auth.initializeApp({
  credential: auth.cert({
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n')
  })
})

// Implement function
export const myFunction = serve(async (req) => {
  try {
    // Extract token from Authorization header
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
    
    const token = authHeader.replace('Bearer ', '')
    
    // Verify token
    const decodedToken = await firebaseApp.auth().verifyIdToken(token)
    
    // Get user ID from token
    const userId = decodedToken.uid
    
    // Implement function logic
    // ...
    
    // Return success response
    return new Response(
      JSON.stringify({
        success: true,
        data: { /* result data */ }
      }),
      { status: 200 }
    )
  } catch (error) {
    // Handle authentication errors
    if (error.code === 'auth/id-token-expired') {
      return new Response(
        JSON.stringify({
          code: 'unauthenticated',
          message: 'Authentication token expired'
        }),
        { status: 401 }
      )
    }
    
    if (error.code === 'auth/id-token-revoked') {
      return new Response(
        JSON.stringify({
          code: 'unauthenticated',
          message: 'Authentication token revoked'
        }),
        { status: 401 }
      )
    }
    
    if (error.code === 'auth/invalid-id-token') {
      return new Response(
        JSON.stringify({
          code: 'unauthenticated',
          message: 'Invalid authentication token'
        }),
        { status: 401 }
      )
    }
    
    // Log error
    console.error('Authentication error:', error)
    
    // Return error response
    return new Response(
      JSON.stringify({
        code: 'internal',
        message: 'Internal server error'
      }),
      { status: 500 }
    )
  }
})
```

### Authorization

After verifying the token, functions should check the user's permissions:

```typescript
// Verify token
const decodedToken = await firebaseApp.auth().verifyIdToken(token)

// Get user ID from token
const userId = decodedToken.uid

// Check if user exists in Firestore
const userDoc = await firebaseApp.firestore().collection('users').doc(userId).get()
if (!userDoc.exists) {
  return new Response(
    JSON.stringify({
      code: 'not-found',
      message: 'User not found'
    }),
    { status: 404 }
  )
}

// Check user permissions
const userData = userDoc.data()
if (!userData.isAdmin) {
  return new Response(
    JSON.stringify({
      code: 'permission-denied',
      message: 'You do not have permission to perform this action'
    }),
    { status: 403 }
  )
}
```

### Error Handling

Handle authentication errors appropriately:

```typescript
try {
  // Verify token
  const decodedToken = await firebaseApp.auth().verifyIdToken(token)
  
  // Get user ID from token
  const userId = decodedToken.uid
  
  // Implement function logic
  // ...
} catch (error) {
  // Handle authentication errors
  if (error.code === 'auth/id-token-expired') {
    return new Response(
      JSON.stringify({
        code: 'unauthenticated',
        message: 'Authentication token expired'
      }),
      { status: 401 }
    )
  }
  
  if (error.code === 'auth/id-token-revoked') {
    return new Response(
      JSON.stringify({
        code: 'unauthenticated',
        message: 'Authentication token revoked'
      }),
      { status: 401 }
    )
  }
  
  if (error.code === 'auth/invalid-id-token') {
    return new Response(
      JSON.stringify({
        code: 'unauthenticated',
        message: 'Invalid authentication token'
      }),
      { status: 401 }
    )
  }
  
  // Log error
  console.error('Authentication error:', error)
  
  // Return error response
  return new Response(
    JSON.stringify({
      code: 'internal',
      message: 'Internal server error'
    }),
    { status: 500 }
  )
}
```

## Best Practices

1. **Verify Tokens**: Always verify authentication tokens
2. **Check Permissions**: Always check user permissions
3. **Handle Errors**: Handle authentication errors appropriately
4. **Use HTTPS**: Always use HTTPS for API requests
5. **Secure Secrets**: Store authentication secrets securely
6. **Log Authentication Events**: Log authentication events for auditing
7. **Implement Rate Limiting**: Implement rate limiting to prevent brute force attacks
8. **Use Short-Lived Tokens**: Use short-lived tokens to reduce the risk of token theft
9. **Implement Token Refresh**: Implement token refresh for long-lived sessions
10. **Monitor Authentication Events**: Monitor authentication events for suspicious activity

## Related Documentation

- [Supabase Overview](README.md) - Overview of Supabase integration
- [Functions](Functions.md) - Guidelines for implementing Supabase functions
- [Database](Database.md) - Guidelines for implementing Supabase database
- [Security](Security.md) - Guidelines for implementing Supabase security
