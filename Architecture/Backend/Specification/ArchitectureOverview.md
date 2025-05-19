# LifeSignal Backend Architecture Overview

**Navigation:** [Back to Backend Specification](README.md) | [Data Model](DataModel.md) | [API Endpoints](APIEndpoints.md) | [Functions](Functions/README.md)

---

## Overview

The LifeSignal backend is built using a hybrid approach with Firebase and Supabase services. This document provides an overview of the backend architecture, including the services used, data model, and function organization.

## Backend Services

### Firebase

Firebase is used for authentication and data storage:

1. **Authentication**: Phone number authentication for user sign-up and sign-in
2. **Firestore**: NoSQL database for storing application data
   - User profiles
   - Contact relationships
   - Check-in data
   - Alert status
3. **Storage**: File storage for user-generated content
4. **Cloud Messaging**: Push notifications for real-time updates

### Supabase

Supabase is used for cloud functions and serverless computing:

1. **Cloud Functions**: Serverless functions for business logic
2. **Edge Functions**: Globally distributed functions for low-latency operations
3. **Scheduled Jobs**: Background tasks and periodic operations
4. **Webhooks**: Event-driven integrations with third-party services

## Data Model

The LifeSignal backend uses a document-based data model in Firestore:

1. **Users Collection**: Contains user profile documents
   - User ID (document ID)
   - Profile information (name, phone, etc.)
   - Check-in settings and status
   - FCM token for notifications

2. **Contacts Subcollection**: Each user document has a contacts subcollection
   - Contact ID (document ID, references another user)
   - Relationship type (responder, dependent)
   - Notification preferences
   - Ping status
   - Alert status

For detailed information on the data model, see the [Data Model](DataModel.md) document.

## Function Organization

The backend functions are organized by domain:

1. **Data Management**: Functions for managing application data
   - Contact relationship management
   - User profile management
   - QR code lookup

2. **Notifications**: Functions for managing notifications
   - Check-in reminders
   - Alert notifications
   - Ping notifications

3. **Safety Features**: Functions for safety features
   - Check-in processing
   - Alert processing
   - Ping processing

For detailed information on the functions, see the [Functions](Functions/README.md) document.

## Authentication Flow

The LifeSignal backend uses Firebase Authentication for phone number authentication:

1. **Phone Number Verification**: User enters phone number and receives a verification code
2. **Code Verification**: User enters verification code to authenticate
3. **User Creation**: If the user doesn't exist, a new user document is created
4. **Session Management**: Firebase handles session management and token refresh

For detailed information on the authentication flow, see the [Authentication Flow](AuthenticationFlow.md) document.

## Security Model

The LifeSignal backend uses Firebase Security Rules for access control:

1. **Authentication Rules**: Ensure users are authenticated
2. **User Data Rules**: Ensure users can only access their own data
3. **Contact Rules**: Ensure users can only access contacts they have a relationship with
4. **Function Rules**: Ensure functions can only be called by authenticated users

For detailed information on the security model, see the [Security Model](SecurityModel.md) document.

## Implementation Strategy

The backend implementation follows these principles:

1. **Separation of Concerns**: Each function has a specific responsibility
2. **Type Safety**: TypeScript is used for type safety
3. **Error Handling**: Comprehensive error handling and validation
4. **Logging**: Detailed logging for debugging and monitoring
5. **Testing**: Unit tests for all functions

For detailed implementation guidelines, see the [Backend Guidelines](../Guidelines/README.md) section.
