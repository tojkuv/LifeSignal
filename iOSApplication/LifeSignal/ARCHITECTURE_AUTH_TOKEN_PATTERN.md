# Auth Token Passing Pattern

## Problem
Clients in `/Clients/PersistentSharedState/` were accessing other clients' shared state (e.g., UserClient accessing AuthenticationClient state), violating client isolation.

## Solution
Features must obtain auth tokens from AuthenticationClient and pass them to other clients when requesting state updates.

## Updated Client Interfaces

### UserClient
```swift
struct UserClient {
    // All state-modifying operations require auth token from Features
    var getUser: @Sendable (String) async throws -> User? // authToken
    var createUser: @Sendable (String, String, String, String, String) async throws -> Void // uid, name, phone, region, authToken
    var updateUser: @Sendable (User, String) async throws -> Void // user, authToken
    var deleteUser: @Sendable (UUID, String) async throws -> Void // userID, authToken
    var resetQRCode: @Sendable (String) async throws -> Void // authToken
    var updateAvatarData: @Sendable (UUID, Data, String) async throws -> Void // userID, imageData, authToken
    var deleteAvatarData: @Sendable (UUID, String) async throws -> Void // userID, authToken
}
```

### ContactsClient
```swift
struct ContactsClient {
    var addContact: @Sendable (String, String, Bool, Bool, String) async throws -> Contact // name, phone, isResponder, isDependent, authToken
    var updateContact: @Sendable (Contact, String) async throws -> Void // contact, authToken
    var deleteContact: @Sendable (UUID, String) async throws -> Void // contactID, authToken
    var getContactByQRCode: @Sendable (String, String) async throws -> Contact // qrCodeId, authToken
}
```

### NotificationClient
```swift
struct NotificationClient {
    var sendPingNotification: @Sendable (NotificationType, String, String, UUID, String) async throws -> Void // type, title, body, contactID, authToken
    var notifyEmergencyAlertToggled: @Sendable (UUID, Bool, String) async throws -> Void // userID, isActive, authToken
}
```

## Feature Implementation Pattern

### 1. Get Auth Token Helper
```swift
// In Features, create helper to get auth token from AuthenticationClient
private func getAuthToken() throws -> String {
    @Shared(.authenticationInternalState) var authState
    guard let token = authState.authenticationToken else {
        throw AuthenticationError.notAuthenticated
    }
    return token
}
```

### 2. Pass Token to Clients
```swift
// Before:
try await userClient.updateUser(user)

// After:
let authToken = try getAuthToken()
try await userClient.updateUser(user, authToken)
```

### 3. Handle Authentication Errors
```swift
return .run { [user] send in
    do {
        let authToken = try getAuthToken()
        try await userClient.updateUser(user, authToken)
        await send(.updateSuccess)
    } catch let error as AuthenticationError {
        await send(.authenticationFailed(error))
    } catch {
        await send(.updateFailed(error))
    }
}
```

## Benefits

1. **Client Isolation**: Each client only accesses its own shared state
2. **Explicit Authentication**: Features explicitly handle authentication
3. **Clear Dependencies**: Token passing makes authentication requirements explicit  
4. **Testability**: Easier to test with mock auth tokens
5. **Security**: Authentication validation happens at Feature level

## Implementation Status

✅ **Client Interfaces Updated**: UserClient interface updated to require auth tokens
⏳ **Feature Updates Needed**: All Features using UserClient need to pass auth tokens
⏳ **Other Clients**: ContactsClient, NotificationClient need similar updates
⏳ **Error Handling**: Features need proper authentication error handling

## Next Steps

1. Update all UserClient method calls in Features to pass auth tokens
2. Update ContactsClient and NotificationClient interfaces 
3. Update Features using ContactsClient and NotificationClient
4. Add proper authentication error handling in Features
5. Remove deprecated `getAuthenticatedUserInfo()` helper methods from clients