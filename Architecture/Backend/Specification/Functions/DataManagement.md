# Data Management Functions

**Navigation:** [Back to Functions](README.md) | [Notifications](Notifications.md) | [Scheduled](Scheduled.md)

---

## Overview

This document provides detailed specifications for the data management functions in the LifeSignal backend. These functions handle contact relationships, user profiles, and QR code lookup.

## Contact Management Functions

### addContactRelation

Creates a bidirectional contact relationship between two users.

**Function Signature:**
```typescript
export const addContactRelation = onCall(
  { cors: true },
  async (request) => {
    // Implementation
  }
);
```

**Input Parameters:**
```typescript
{
  userId: string;      // ID of the user who initiated the contact addition
  contactId: string;   // ID of the contact to add
  isResponder: boolean; // Whether the contact is a responder for the user
  isDependent: boolean; // Whether the contact is a dependent of the user
}
```

**Return Value:**
```typescript
{
  success: boolean;    // Whether the operation was successful
  contactId: string;   // ID of the added contact
}
```

**Implementation Details:**
1. Validate input parameters
2. Check authentication
3. Verify that both users exist
4. Check if the contact relationship already exists
5. Create bidirectional contact relationship
6. Return success status

**Error Handling:**
- `unauthenticated`: Authentication required
- `invalid-argument`: User ID and contact ID are required
- `invalid-argument`: Cannot add yourself as a contact
- `not-found`: One or both users not found
- `already-exists`: This user is already in your contacts

### updateContactRoles

Updates the roles of an existing contact relationship.

**Function Signature:**
```typescript
export const updateContactRoles = onCall(
  { cors: true },
  async (request) => {
    // Implementation
  }
);
```

**Input Parameters:**
```typescript
{
  userId: string;      // ID of the user who initiated the role update
  contactId: string;   // ID of the contact to update
  isResponder: boolean; // Whether the contact is a responder for the user
  isDependent: boolean; // Whether the contact is a dependent of the user
}
```

**Return Value:**
```typescript
{
  success: boolean;    // Whether the operation was successful
  contactId: string;   // ID of the updated contact
}
```

**Implementation Details:**
1. Validate input parameters
2. Check authentication
3. Verify that both users exist
4. Check if the contact relationship exists
5. Update bidirectional contact relationship
6. Return success status

**Error Handling:**
- `unauthenticated`: Authentication required
- `invalid-argument`: User ID and contact ID are required
- `not-found`: One or both users not found
- `not-found`: Contact relationship not found

### deleteContactRelation

Deletes a bidirectional contact relationship between two users.

**Function Signature:**
```typescript
export const deleteContactRelation = onCall(
  { cors: true },
  async (request) => {
    // Implementation
  }
);
```

**Input Parameters:**
```typescript
{
  userId: string;      // ID of the user who initiated the contact deletion
  contactId: string;   // ID of the contact to delete
}
```

**Return Value:**
```typescript
{
  success: boolean;    // Whether the operation was successful
}
```

**Implementation Details:**
1. Validate input parameters
2. Check authentication
3. Verify that both users exist
4. Check if the contact relationship exists
5. Delete bidirectional contact relationship
6. Return success status

**Error Handling:**
- `unauthenticated`: Authentication required
- `invalid-argument`: User ID and contact ID are required
- `not-found`: One or both users not found
- `not-found`: Contact relationship not found

### lookupUserByQRCode

Looks up a user by QR code ID.

**Function Signature:**
```typescript
export const lookupUserByQRCode = onCall(
  { cors: true },
  async (request) => {
    // Implementation
  }
);
```

**Input Parameters:**
```typescript
{
  qrCodeId: string;    // QR code ID to look up
}
```

**Return Value:**
```typescript
{
  success: boolean;    // Whether the operation was successful
  userId: string;      // ID of the user associated with the QR code
  name: string;        // Name of the user
}
```

**Implementation Details:**
1. Validate input parameters
2. Check authentication
3. Query users collection for the QR code ID
4. Return user information if found
5. Return error if not found

**Error Handling:**
- `unauthenticated`: Authentication required
- `invalid-argument`: QR code ID is required
- `not-found`: User not found for the given QR code ID

## Ping Management Functions

### pingDependent

Sends a ping to a dependent.

**Function Signature:**
```typescript
export const pingDependent = onCall(
  { cors: true },
  async (request) => {
    // Implementation
  }
);
```

**Input Parameters:**
```typescript
{
  userId: string;      // ID of the user sending the ping
  dependentId: string; // ID of the dependent to ping
}
```

**Return Value:**
```typescript
{
  success: boolean;    // Whether the operation was successful
  dependentId: string; // ID of the pinged dependent
}
```

**Implementation Details:**
1. Validate input parameters
2. Check authentication
3. Verify that both users exist
4. Check if the contact relationship exists
5. Update ping timestamps in both contact documents
6. Send notification to dependent
7. Return success status

**Error Handling:**
- `unauthenticated`: Authentication required
- `invalid-argument`: User ID and dependent ID are required
- `not-found`: One or both users not found
- `not-found`: Contact relationship not found
- `permission-denied`: User is not authorized to ping this dependent

### respondToPing

Responds to a ping from a responder.

**Function Signature:**
```typescript
export const respondToPing = onCall(
  { cors: true },
  async (request) => {
    // Implementation
  }
);
```

**Input Parameters:**
```typescript
{
  userId: string;      // ID of the user responding to the ping
  responderId: string; // ID of the responder who sent the ping
}
```

**Return Value:**
```typescript
{
  success: boolean;    // Whether the operation was successful
  responderId: string; // ID of the responder
}
```

**Implementation Details:**
1. Validate input parameters
2. Check authentication
3. Verify that both users exist
4. Check if the contact relationship exists
5. Check if there is an active ping
6. Clear ping timestamps in both contact documents
7. Send notification to responder
8. Return success status

**Error Handling:**
- `unauthenticated`: Authentication required
- `invalid-argument`: User ID and responder ID are required
- `not-found`: One or both users not found
- `not-found`: Contact relationship not found
- `not-found`: No active ping found from this responder

### respondToAllPings

Responds to all active pings for a user.

**Function Signature:**
```typescript
export const respondToAllPings = onCall(
  { cors: true },
  async (request) => {
    // Implementation
  }
);
```

**Input Parameters:**
```typescript
{
  userId: string;      // ID of the user responding to all pings
}
```

**Return Value:**
```typescript
{
  success: boolean;    // Whether the operation was successful
  respondedCount: number; // Number of pings responded to
}
```

**Implementation Details:**
1. Validate input parameters
2. Check authentication
3. Verify that the user exists
4. Query all contacts with active pings
5. Clear ping timestamps in all contact documents
6. Send notifications to all responders
7. Return success status and count

**Error Handling:**
- `unauthenticated`: Authentication required
- `invalid-argument`: User ID is required
- `not-found`: User not found

### clearPing

Clears a ping sent to a dependent.

**Function Signature:**
```typescript
export const clearPing = onCall(
  { cors: true },
  async (request) => {
    // Implementation
  }
);
```

**Input Parameters:**
```typescript
{
  userId: string;      // ID of the user clearing the ping
  dependentId: string; // ID of the dependent
}
```

**Return Value:**
```typescript
{
  success: boolean;    // Whether the operation was successful
  dependentId: string; // ID of the dependent
}
```

**Implementation Details:**
1. Validate input parameters
2. Check authentication
3. Verify that both users exist
4. Check if the contact relationship exists
5. Check if there is an active ping
6. Clear ping timestamps in both contact documents
7. Return success status

**Error Handling:**
- `unauthenticated`: Authentication required
- `invalid-argument`: User ID and dependent ID are required
- `not-found`: One or both users not found
- `not-found`: Contact relationship not found
- `not-found`: No active ping found for this dependent

## Implementation Guidelines

### Function Implementation

1. **Type Safety**: Use TypeScript for type safety
2. **Input Validation**: Validate all input parameters
3. **Authentication**: Check authentication in all functions
4. **Authorization**: Verify that the user has permission to perform the operation
5. **Error Handling**: Implement proper error handling
6. **Logging**: Log all function calls and errors
7. **Testing**: Write unit tests for all functions

For detailed implementation guidelines, see the [Backend Guidelines](../../Guidelines/README.md) section.

For implementation examples, see the [Cloud Function Example](../Examples/CloudFunctionExample.md).
