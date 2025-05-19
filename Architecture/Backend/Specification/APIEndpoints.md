# LifeSignal Backend API Endpoints

**Navigation:** [Back to Backend Specification](README.md) | [Architecture Overview](ArchitectureOverview.md) | [Functions](Functions/README.md)

---

## Overview

This document provides detailed specifications for the LifeSignal backend API endpoints. The LifeSignal backend uses Firebase Cloud Functions for API endpoints, which are implemented as callable functions.

## Authentication

All API endpoints require authentication using Firebase Authentication. The authentication token must be included in the request header.

## API Endpoint Categories

### Contact Management

#### addContactRelation

Creates a bidirectional contact relationship between two users.

**Request:**
```typescript
{
  userId: string;      // ID of the user who initiated the contact addition
  contactId: string;   // ID of the contact to add
  isResponder: boolean; // Whether the contact is a responder for the user
  isDependent: boolean; // Whether the contact is a dependent of the user
}
```

**Response:**
```typescript
{
  success: boolean;    // Whether the operation was successful
  contactId: string;   // ID of the added contact
}
```

**Errors:**
- `unauthenticated`: Authentication required
- `invalid-argument`: User ID and contact ID are required
- `not-found`: One or both users not found
- `already-exists`: This user is already in your contacts

#### updateContactRoles

Updates the roles of an existing contact relationship.

**Request:**
```typescript
{
  userId: string;      // ID of the user who initiated the role update
  contactId: string;   // ID of the contact to update
  isResponder: boolean; // Whether the contact is a responder for the user
  isDependent: boolean; // Whether the contact is a dependent of the user
}
```

**Response:**
```typescript
{
  success: boolean;    // Whether the operation was successful
  contactId: string;   // ID of the updated contact
}
```

**Errors:**
- `unauthenticated`: Authentication required
- `invalid-argument`: User ID and contact ID are required
- `not-found`: One or both users not found
- `not-found`: Contact relationship not found

#### deleteContactRelation

Deletes a bidirectional contact relationship between two users.

**Request:**
```typescript
{
  userId: string;      // ID of the user who initiated the contact deletion
  contactId: string;   // ID of the contact to delete
}
```

**Response:**
```typescript
{
  success: boolean;    // Whether the operation was successful
}
```

**Errors:**
- `unauthenticated`: Authentication required
- `invalid-argument`: User ID and contact ID are required
- `not-found`: One or both users not found
- `not-found`: Contact relationship not found

#### lookupUserByQRCode

Looks up a user by QR code ID.

**Request:**
```typescript
{
  qrCodeId: string;    // QR code ID to look up
}
```

**Response:**
```typescript
{
  success: boolean;    // Whether the operation was successful
  userId: string;      // ID of the user associated with the QR code
  name: string;        // Name of the user
}
```

**Errors:**
- `unauthenticated`: Authentication required
- `invalid-argument`: QR code ID is required
- `not-found`: User not found for the given QR code ID

### Ping Management

#### pingDependent

Sends a ping to a dependent.

**Request:**
```typescript
{
  userId: string;      // ID of the user sending the ping
  dependentId: string; // ID of the dependent to ping
}
```

**Response:**
```typescript
{
  success: boolean;    // Whether the operation was successful
  dependentId: string; // ID of the pinged dependent
}
```

**Errors:**
- `unauthenticated`: Authentication required
- `invalid-argument`: User ID and dependent ID are required
- `not-found`: One or both users not found
- `not-found`: Contact relationship not found
- `permission-denied`: User is not authorized to ping this dependent

#### respondToPing

Responds to a ping from a responder.

**Request:**
```typescript
{
  userId: string;      // ID of the user responding to the ping
  responderId: string; // ID of the responder who sent the ping
}
```

**Response:**
```typescript
{
  success: boolean;    // Whether the operation was successful
  responderId: string; // ID of the responder
}
```

**Errors:**
- `unauthenticated`: Authentication required
- `invalid-argument`: User ID and responder ID are required
- `not-found`: One or both users not found
- `not-found`: Contact relationship not found
- `not-found`: No active ping found from this responder

#### respondToAllPings

Responds to all active pings for a user.

**Request:**
```typescript
{
  userId: string;      // ID of the user responding to all pings
}
```

**Response:**
```typescript
{
  success: boolean;    // Whether the operation was successful
  respondedCount: number; // Number of pings responded to
}
```

**Errors:**
- `unauthenticated`: Authentication required
- `invalid-argument`: User ID is required
- `not-found`: User not found

#### clearPing

Clears a ping sent to a dependent.

**Request:**
```typescript
{
  userId: string;      // ID of the user clearing the ping
  dependentId: string; // ID of the dependent
}
```

**Response:**
```typescript
{
  success: boolean;    // Whether the operation was successful
  dependentId: string; // ID of the dependent
}
```

**Errors:**
- `unauthenticated`: Authentication required
- `invalid-argument`: User ID and dependent ID are required
- `not-found`: One or both users not found
- `not-found`: Contact relationship not found
- `not-found`: No active ping found for this dependent

### Notification Management

#### sendCheckInReminders

Scheduled function that sends check-in reminders to users.

**Trigger:** Scheduled (every 15 minutes)

**Function:**
- Queries users whose check-in is about to expire
- Sends push notifications to remind them to check in
- Sends notifications to responders if check-in has expired

## Error Handling

All API endpoints follow a consistent error handling pattern:

1. **Input Validation**: Validate all input parameters
2. **Authentication Check**: Ensure the user is authenticated
3. **Authorization Check**: Ensure the user has permission to perform the operation
4. **Error Response**: Return a standardized error response with code and message

## Rate Limiting

API endpoints are subject to rate limiting to prevent abuse:

1. **Default Limit**: 100 requests per minute per user
2. **Burst Limit**: 200 requests per minute per user for short periods
3. **IP-based Limiting**: Additional limits based on IP address

## Versioning

API endpoints follow a versioning strategy:

1. **Function Versioning**: Using Firebase Functions v2 API
2. **Backward Compatibility**: Maintaining backward compatibility for existing clients
3. **Deprecation Policy**: Providing a deprecation period before removing endpoints

For detailed implementation guidelines, see the [Backend Guidelines](../Guidelines/README.md) section.
