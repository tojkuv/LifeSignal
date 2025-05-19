# Backend Integration Guidelines

**Navigation:** [Back to Production Guidelines](../README.md) | [Infrastructure Agnosticism](AgnosticInfrastructure/InfrastructureAgnosticism.md) | [Firebase Adapters](FirebaseAdapters/Overview.md) | [Backend Integration Specification](../../../Specification/Infrastructure/BackendIntegration.md)

---

## Overview

This document provides guidelines for integrating the LifeSignal iOS application with backend services. The application uses a hybrid backend approach with specific responsibilities assigned to different services:

- **Supabase**: Cloud functions and serverless computing
- **Firebase**: Authentication and data storage

For detailed specifications on backend integration, see the [Backend Integration Specification](../../../Specification/Infrastructure/BackendIntegration.md).

## Backend Separation of Concerns

### Supabase Backend

All cloud functions should be implemented in the Supabase backend:

1. **API Endpoints**: REST endpoints for client-server communication
2. **Serverless Functions**: Business logic that runs on the server
3. **Scheduled Jobs**: Background tasks and periodic operations
4. **Webhooks**: Event-driven integrations with third-party services
5. **Edge Functions**: Globally distributed functions for low-latency operations

For detailed guidelines on implementing Supabase cloud functions, see:
- [Supabase Overview](SupabaseAdapters/Overview.md) - Overview of Supabase integration
- [Cloud Functions](SupabaseAdapters/CloudFunctions.md) - Guidelines for implementing cloud functions
- [Client Design](SupabaseAdapters/ClientDesign.md) - Guidelines for designing Supabase clients
- [Adapter Pattern](SupabaseAdapters/AdapterPattern.md) - Guidelines for implementing Supabase adapters

### Firebase Backend

Authentication and data storage should be handled by Firebase:

1. **Authentication**: User sign-up, sign-in, and account management
2. **Realtime Database/Firestore**: Application data storage
3. **Cloud Storage**: File storage (if needed)
4. **Cloud Messaging**: Push notifications

## Client Architecture

The iOS application should access these backend services through a layered architecture:

```
Feature Layer → Middleware Clients → Adapters → Platform Backend Clients → Backend
(UserFeature)    (UserClient)       (FirebaseUserAdapter)  (FirebaseClient)     (Firebase/Supabase)
```

### Middleware Clients

Define middleware clients that abstract the backend implementation details:

```swift
protocol UserClient {
    func getCurrentUser() async throws -> User
    func signIn(phoneNumber: String) async throws -> AuthResult
    func verifyCode(code: String) async throws -> User
    func signOut() async throws
    func observeAuthState() -> AsyncStream<AuthState>
}
```

### Adapters

Implement adapters that convert between backend-specific and domain models:

```swift
struct FirebaseUserAdapter: UserClient {
    private let auth = Auth.auth()

    func getCurrentUser() async throws -> User {
        guard let firebaseUser = auth.currentUser else {
            throw AuthError.notAuthenticated
        }
        return User(id: firebaseUser.uid, phoneNumber: firebaseUser.phoneNumber)
    }

    // Other methods...
}
```

### Feature Integration

Features should depend on client interfaces, not concrete implementations:

```swift
@Reducer
struct AuthFeature {
    @Dependency(\.userClient) var userClient

    // State, actions, and reducer...
}
```

## Implementation Guidelines

### 1. Cloud Functions in Supabase

When implementing cloud functions in Supabase:

- Use TypeScript for type safety
- Implement proper error handling and validation
- Document API endpoints with OpenAPI/Swagger
- Implement proper authentication and authorization
- Use environment variables for configuration
- Write tests for all functions

Example Supabase function:

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
  )

  // Function implementation...

  return new Response(
    JSON.stringify({ message: 'Success' }),
    { headers: { 'Content-Type': 'application/json' } },
  )
})
```

### 2. Authentication in Firebase

When implementing authentication in Firebase:

- Use phone number authentication for LifeSignal
- Implement proper error handling and user feedback
- Use Firebase Auth UI for a consistent authentication experience
- Implement proper session management
- Handle authentication state changes

Example Firebase authentication:

```swift
func signIn(phoneNumber: String) async throws -> AuthResult {
    try await withCheckedThrowingContinuation { continuation in
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { verificationID, error in
            if let error = error {
                continuation.resume(throwing: AuthError.from(error))
                return
            }

            guard let verificationID = verificationID else {
                continuation.resume(throwing: AuthError.unknown)
                return
            }

            continuation.resume(returning: AuthResult(verificationID: verificationID))
        }
    }
}
```

### 3. Data Storage in Firebase

When implementing data storage in Firebase:

- Use Firestore for structured data
- Use Realtime Database for real-time updates
- Implement proper data validation and security rules
- Use transactions for atomic operations
- Implement proper error handling and retry logic
- Use offline capabilities for a better user experience

Example Firestore data access:

```swift
func getContacts() async throws -> [Contact] {
    try await withCheckedThrowingContinuation { continuation in
        db.collection("contacts")
            .whereField("userId", isEqualTo: currentUserId)
            .getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: DatabaseError.from(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    continuation.resume(returning: [])
                    return
                }

                let contacts = documents.compactMap { document -> Contact? in
                    try? document.data(as: Contact.self)
                }

                continuation.resume(returning: contacts)
            }
    }
}
```

### 4. Streaming Data

When implementing streaming data from Firebase:

- Use AsyncStream to wrap Firebase listeners
- Implement proper error handling and retry logic
- Use proper cancellation to avoid memory leaks
- Implement proper state management for streaming data

Example streaming implementation:

```swift
func observeContacts() -> AsyncStream<[Contact]> {
    AsyncStream { continuation in
        let listener = db.collection("contacts")
            .whereField("userId", isEqualTo: currentUserId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    // Handle error, possibly emit an error state
                    return
                }

                guard let documents = snapshot?.documents else {
                    continuation.yield([])
                    return
                }

                let contacts = documents.compactMap { document -> Contact? in
                    try? document.data(as: Contact.self)
                }

                continuation.yield(contacts)
            }

        continuation.onTermination = { @Sendable _ in
            listener.remove()
        }
    }
}
```

## Testing

When testing backend integration:

1. **Mock Clients**: Use mock implementations of client interfaces for testing
2. **Test Real Integration**: Test with real backend services in integration tests
3. **Error Handling**: Test error cases and edge cases
4. **Offline Mode**: Test offline behavior
5. **Performance**: Test performance characteristics

Example mock client for testing:

```swift
struct MockUserClient: UserClient {
    var getCurrentUserResult: Result<User, Error> = .success(User.mock)
    var signInResult: Result<AuthResult, Error> = .success(AuthResult.mock)
    var verifyCodeResult: Result<User, Error> = .success(User.mock)
    var signOutResult: Result<Void, Error> = .success(())
    var authStateStream: AsyncStream<AuthState> = AsyncStream { continuation in
        continuation.yield(.authenticated(User.mock))
        continuation.finish()
    }

    func getCurrentUser() async throws -> User {
        try getCurrentUserResult.get()
    }

    // Other methods...
}
```

## Conclusion

By following these guidelines, the LifeSignal iOS application can integrate with backend services in a way that is:

1. **Maintainable**: Clear separation of concerns and abstraction layers
2. **Testable**: Client interfaces that can be mocked for testing
3. **Flexible**: Ability to change backend implementations without affecting features
4. **Performant**: Efficient use of backend services
5. **Secure**: Proper authentication and authorization
