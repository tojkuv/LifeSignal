# LifeSignal Backend Guidelines

**Navigation:** [Back to Backend Architecture](../README.md) | [Firebase Guidelines](Firebase/README.md) | [Supabase Guidelines](Supabase/README.md)

---

## Overview

This document provides guidelines for implementing the LifeSignal backend services. The backend is built using a combination of Firebase and Supabase services, with specific responsibilities assigned to each:

- **Firebase**: Authentication and data storage
- **Supabase**: Cloud functions and serverless computing

## Backend Separation of Concerns

### Firebase Backend

Authentication and data storage should be handled by Firebase:

1. **Authentication**: User sign-up, sign-in, and account management
2. **Firestore**: Application data storage
3. **Storage**: File storage
4. **Cloud Messaging**: Push notifications

For detailed guidelines on implementing Firebase services, see:
- [Firebase Overview](Firebase/README.md)
- [Authentication](Firebase/Authentication.md)
- [Firestore](Firebase/Firestore.md)
- [Security Rules](Firebase/Security.md)

### Supabase Backend

All cloud functions should be implemented in the Supabase backend:

1. **API Endpoints**: REST endpoints for client-server communication
2. **Serverless Functions**: Business logic that runs on the server
3. **Scheduled Jobs**: Background tasks and periodic operations
4. **Webhooks**: Event-driven integrations with third-party services
5. **Edge Functions**: Globally distributed functions for low-latency operations

For detailed guidelines on implementing Supabase services, see:
- [Supabase Overview](Supabase/README.md)
- [Functions](Supabase/Functions.md)
- [Database](Supabase/Database.md)
- [Authentication](Supabase/Authentication.md)
- [Security](Supabase/Security.md)

## Implementation Guidelines

### General Guidelines

1. **Type Safety**: Use TypeScript for all backend code
2. **Error Handling**: Implement proper error handling and validation
3. **Documentation**: Document all functions and endpoints
4. **Testing**: Write tests for all backend code
5. **Security**: Implement proper authentication and authorization
6. **Environment Variables**: Use environment variables for configuration
7. **Logging**: Implement proper logging for debugging and monitoring

### Firebase Guidelines

For detailed Firebase guidelines, see the [Firebase Guidelines](Firebase/README.md) section.

### Supabase Guidelines

For detailed Supabase guidelines, see the [Supabase Guidelines](Supabase/README.md) section.
