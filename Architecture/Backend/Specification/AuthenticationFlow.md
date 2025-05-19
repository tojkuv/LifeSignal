# LifeSignal Authentication Flow

**Navigation:** [Back to Backend Specification](README.md) | [Architecture Overview](ArchitectureOverview.md) | [Security Model](SecurityModel.md)

---

## Overview

This document provides detailed specifications for the LifeSignal authentication flow. The LifeSignal application uses Firebase Authentication with phone number authentication as the primary authentication method.

## Authentication Process

### 1. Phone Number Verification

1. **User Input**: User enters their phone number in the application
2. **Validation**: Application validates the phone number format
3. **Request Verification Code**: Application calls Firebase Authentication to request a verification code
4. **SMS Delivery**: Firebase sends an SMS with a verification code to the user's phone
5. **Code Entry**: User enters the verification code in the application

### 2. Code Verification

1. **Verification**: Application submits the verification code to Firebase Authentication
2. **Token Generation**: Firebase verifies the code and generates an authentication token
3. **Token Storage**: Application stores the authentication token for future requests
4. **User Lookup**: Application checks if a user document exists for the authenticated phone number

### 3. User Creation

If no user document exists for the authenticated phone number:

1. **Profile Creation**: Application prompts the user to create a profile
2. **Data Submission**: User submits profile information (name, emergency note, etc.)
3. **Document Creation**: Application creates a new user document in Firestore
4. **Default Settings**: Application sets default check-in interval and notification settings

### 4. Session Management

1. **Token Refresh**: Firebase automatically refreshes the authentication token when needed
2. **Session Persistence**: Application maintains the session across app restarts
3. **Session Termination**: User can sign out to terminate the session

## Authentication Tokens

Firebase Authentication tokens are used for:

1. **API Access**: Authenticating requests to Firebase Cloud Functions
2. **Database Access**: Authenticating requests to Firestore
3. **Storage Access**: Authenticating requests to Firebase Storage

## Security Considerations

### Phone Number Verification

1. **Rate Limiting**: Firebase limits the number of verification codes that can be sent to a phone number
2. **Code Expiration**: Verification codes expire after a short period (typically 5 minutes)
3. **Attempt Limiting**: Firebase limits the number of verification attempts for a single code

### Token Security

1. **Token Expiration**: Authentication tokens expire after a period (typically 1 hour)
2. **Token Refresh**: Refresh tokens are used to obtain new authentication tokens
3. **Token Revocation**: Tokens can be revoked by the backend if needed

### Multi-Device Support

1. **Concurrent Sessions**: Firebase supports concurrent sessions on multiple devices
2. **Session Enumeration**: Backend can enumerate active sessions for a user
3. **Session Termination**: Backend can terminate specific sessions if needed

## Testing Authentication

For testing purposes, the LifeSignal application supports:

1. **Firebase Emulator**: Local testing using the Firebase Authentication Emulator
2. **Test Phone Numbers**: Special phone numbers that can be used for testing without SMS delivery
3. **Test Verification Codes**: Predefined verification codes for test phone numbers

## Implementation Guidelines

### Client-Side Implementation

1. **Firebase SDK**: Use the Firebase Authentication SDK for client-side implementation
2. **Error Handling**: Implement proper error handling for authentication failures
3. **Retry Logic**: Implement retry logic for transient failures
4. **Offline Support**: Handle authentication in offline scenarios

### Backend Implementation

1. **Security Rules**: Implement proper security rules for Firestore and Storage
2. **Function Authentication**: Verify authentication tokens in Cloud Functions
3. **Token Validation**: Validate token claims and expiration
4. **User Verification**: Verify that the authenticated user has permission to access the requested resource

For detailed implementation guidelines, see the [Backend Guidelines](../Guidelines/README.md) section.
