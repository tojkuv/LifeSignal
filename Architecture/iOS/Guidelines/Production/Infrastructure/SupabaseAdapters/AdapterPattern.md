# Supabase Adapter Pattern Guidelines

**Navigation:** [Back to Supabase Overview](Overview.md) | [Cloud Functions](CloudFunctions.md) | [Client Design](ClientDesign.md)

---

## Overview

This document provides guidelines for implementing the adapter pattern for Supabase cloud functions in the LifeSignal iOS application. The adapter pattern is used to convert between the Supabase API and the domain-specific client interfaces.

## Adapter Pattern

The adapter pattern is a structural design pattern that allows objects with incompatible interfaces to collaborate. In the context of the LifeSignal application, adapters convert between:

1. **Domain Models**: Models used by the application features
2. **Supabase Models**: Models used by the Supabase API

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │
│  Feature Layer  │◄────┤  Client Layer   │◄────┤  Adapter Layer  │◄────┐
│                 │     │                 │     │                 │     │
└─────────────────┘     └─────────────────┘     └─────────────────┘     │
                                                                         │
                                                                         │
┌─────────────────┐                                                      │
│                 │                                                      │
│  Supabase API   │──────────────────────────────────────────────────────┘
│                 │
└─────────────────┘
```

## Adapter Implementation

### Base Adapter

Create a base adapter class that handles common functionality:

```swift
class SupabaseBaseAdapter {
    private let supabaseClient: SupabaseClient
    private let authProvider: AuthProvider
    
    init(supabaseClient: SupabaseClient, authProvider: AuthProvider) {
        self.supabaseClient = supabaseClient
        self.authProvider = authProvider
    }
    
    func callFunction<Request: Encodable, Response: Decodable>(
        name: String,
        request: Request
    ) async throws -> Response {
        // Get authentication token
        guard let token = try? await authProvider.getIdToken() else {
            throw SupabaseError.unauthorized
        }
        
        // Prepare headers
        let headers = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        // Encode request
        let jsonData = try JSONEncoder().encode(request)
        
        // Call function
        let endpoint = "\(supabaseClient.functionsUrl)/\(name)"
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Handle response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return try JSONDecoder().decode(Response.self, from: data)
        case 401:
            throw SupabaseError.unauthorized
        case 404:
            throw SupabaseError.notFound
        case 400:
            throw SupabaseError.badRequest
        default:
            throw SupabaseError.serverError
        }
    }
}
```

### Feature-Specific Adapters

Create adapters for each feature that implement the client interfaces:

```swift
class SupabaseAlertAdapter: SupabaseBaseAdapter, AlertClient {
    func triggerAlert() async throws -> AlertResult {
        do {
            let response: TriggerAlertResponse = try await callFunction(
                name: "trigger-alert",
                request: EmptyRequest()
            )
            
            return AlertResult(
                alertId: response.alertId,
                activatedAt: ISO8601DateFormatter().date(from: response.activatedAt) ?? Date(),
                status: response.status
            )
        } catch let error as SupabaseError {
            switch error {
            case .unauthorized:
                throw AlertError.unauthorized
            case .notFound:
                throw AlertError.userNotFound
            case .badRequest:
                throw AlertError.alreadyActive
            default:
                throw AlertError.processingFailed
            }
        } catch {
            throw AlertError.unknown(error)
        }
    }
    
    func cancelAlert(alertId: String) async throws {
        do {
            let request = CancelAlertRequest(alertId: alertId)
            
            let _: EmptyResponse = try await callFunction(
                name: "cancel-alert",
                request: request
            )
        } catch let error as SupabaseError {
            switch error {
            case .unauthorized:
                throw AlertError.unauthorized
            case .notFound:
                throw AlertError.notActive
            default:
                throw AlertError.processingFailed
            }
        } catch {
            throw AlertError.unknown(error)
        }
    }
    
    func getActiveAlert() async throws -> AlertResult? {
        do {
            let response: GetActiveAlertResponse = try await callFunction(
                name: "get-active-alert",
                request: EmptyRequest()
            )
            
            if response.hasActiveAlert {
                return AlertResult(
                    alertId: response.alertId!,
                    activatedAt: ISO8601DateFormatter().date(from: response.activatedAt!) ?? Date(),
                    status: response.status!
                )
            } else {
                return nil
            }
        } catch let error as SupabaseError {
            switch error {
            case .unauthorized:
                throw AlertError.unauthorized
            case .notFound:
                throw AlertError.userNotFound
            default:
                throw AlertError.processingFailed
            }
        } catch {
            throw AlertError.unknown(error)
        }
    }
}
```

## Adapter Design Principles

### 1. Single Responsibility

Each adapter should be responsible for a single feature or domain area:

```swift
// Good: Single responsibility
class SupabaseNotificationAdapter: SupabaseBaseAdapter, NotificationClient {
    // Notification-specific methods
}

class SupabaseCheckInAdapter: SupabaseBaseAdapter, CheckInClient {
    // Check-in-specific methods
}

// Bad: Multiple responsibilities
class SupabaseAdapter: SupabaseBaseAdapter, NotificationClient, CheckInClient {
    // Mixed responsibilities
}
```

### 2. Error Mapping

Map backend-specific errors to domain-specific errors:

```swift
// Good: Specific error mapping
func sendPushNotification(_ notification: NotificationRequest) async throws -> NotificationResult {
    do {
        // Call function
    } catch let error as SupabaseError {
        switch error {
        case .unauthorized:
            throw NotificationError.unauthorized
        case .notFound:
            throw NotificationError.userNotFound
        case .badRequest:
            throw NotificationError.invalidInput
        default:
            throw NotificationError.sendFailed
        }
    } catch {
        throw NotificationError.unknown(error)
    }
}

// Bad: Generic error handling
func sendPushNotification(_ notification: NotificationRequest) async throws -> NotificationResult {
    do {
        // Call function
    } catch {
        throw error // Leaks implementation details
    }
}
```

### 3. Type Conversion

Convert between backend-specific types and domain types:

```swift
// Good: Explicit type conversion
let result = AlertResult(
    alertId: response.alertId,
    activatedAt: ISO8601DateFormatter().date(from: response.activatedAt) ?? Date(),
    status: response.status
)

// Bad: Leaking backend types
let result = response // Exposes backend-specific types
```

### 4. Dependency Injection

Accept dependencies in initializers:

```swift
// Good: Explicit dependencies
class SupabaseNotificationAdapter: SupabaseBaseAdapter, NotificationClient {
    init(supabaseClient: SupabaseClient, authProvider: AuthProvider) {
        super.init(supabaseClient: supabaseClient, authProvider: authProvider)
    }
}

// Bad: Hidden dependencies
class SupabaseNotificationAdapter: NotificationClient {
    private let supabaseClient = SupabaseClient.shared // Hidden dependency
}
```

### 5. Testability

Design adapters for testability:

```swift
// Good: Testable design
class SupabaseNotificationAdapter: SupabaseBaseAdapter, NotificationClient {
    func sendPushNotification(_ notification: NotificationRequest) async throws -> NotificationResult {
        // Implementation
    }
}

// For testing
class MockNotificationClient: NotificationClient {
    var sendPushNotificationResult: Result<NotificationResult, NotificationError> = .success(
        NotificationResult(messageId: "mock-id", sentAt: Date())
    )
    
    func sendPushNotification(_ notification: NotificationRequest) async throws -> NotificationResult {
        try sendPushNotificationResult.get()
    }
}
```

## Request/Response Models

Define clear request and response models for each function:

```swift
// Request models
struct TriggerAlertRequest: Encodable {
    // Empty for this function
}

struct CancelAlertRequest: Encodable {
    let alertId: String
}

// Response models
struct TriggerAlertResponse: Decodable {
    let success: Bool
    let alertId: String
    let activatedAt: String
    let status: String
}

struct GetActiveAlertResponse: Decodable {
    let hasActiveAlert: Bool
    let alertId: String?
    let activatedAt: String?
    let status: String?
}

struct EmptyResponse: Decodable {
    // Empty response
}

struct EmptyRequest: Encodable {
    // Empty request
}
```

## Error Handling

Define clear error types for each domain:

```swift
enum SupabaseError: Error {
    case unauthorized
    case notFound
    case badRequest
    case serverError
    case invalidResponse
}

enum AlertError: Error {
    case unauthorized
    case userNotFound
    case alreadyActive
    case notActive
    case processingFailed
    case unknown(Error)
}

enum NotificationError: Error {
    case unauthorized
    case userNotFound
    case invalidInput
    case sendFailed
    case unknown(Error)
}
```

## Adapter Factory

Create a factory for creating adapters:

```swift
class SupabaseAdapterFactory {
    private let supabaseClient: SupabaseClient
    private let authProvider: AuthProvider
    
    init(supabaseClient: SupabaseClient, authProvider: AuthProvider) {
        self.supabaseClient = supabaseClient
        self.authProvider = authProvider
    }
    
    func createNotificationAdapter() -> NotificationClient {
        return SupabaseNotificationAdapter(
            supabaseClient: supabaseClient,
            authProvider: authProvider
        )
    }
    
    func createCheckInAdapter() -> CheckInClient {
        return SupabaseCheckInAdapter(
            supabaseClient: supabaseClient,
            authProvider: authProvider
        )
    }
    
    func createAlertAdapter() -> AlertClient {
        return SupabaseAlertAdapter(
            supabaseClient: supabaseClient,
            authProvider: authProvider
        )
    }
}
```

## Dependency Registration

Register adapters with the dependency injection system:

```swift
import ComposableArchitecture

private enum SupabaseAdapterFactoryKey: DependencyKey {
    static let liveValue: SupabaseAdapterFactory = {
        let supabaseClient = SupabaseClient(
            url: ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "",
            anonKey: ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
        )
        let authProvider = FirebaseAuthProvider()
        return SupabaseAdapterFactory(
            supabaseClient: supabaseClient,
            authProvider: authProvider
        )
    }()
}

extension DependencyValues {
    var supabaseAdapterFactory: SupabaseAdapterFactory {
        get { self[SupabaseAdapterFactoryKey.self] }
        set { self[SupabaseAdapterFactoryKey.self] = newValue }
    }
}

extension NotificationClient: DependencyKey {
    static let liveValue: NotificationClient = {
        @Dependency(\.supabaseAdapterFactory) var factory
        return factory.createNotificationAdapter()
    }()
    
    static let testValue: NotificationClient = MockNotificationClient()
}

extension DependencyValues {
    var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}
```

## Complete Example

Here's a complete example of an adapter implementation:

```swift
// Client interface
protocol ContactClient {
    func inviteContact(phone: String, roles: [ContactRole]) async throws -> ContactInviteResult
    func acceptInvitation(invitationId: String) async throws -> Contact
    func removeContact(contactId: String) async throws
    func getContacts() async throws -> [Contact]
}

// Domain models
struct Contact: Equatable {
    let id: String
    let name: String
    let phone: String
    let roles: [ContactRole]
    let status: ContactStatus
}

enum ContactRole: String, Codable, Equatable {
    case dependent
    case responder
}

enum ContactStatus: String, Codable, Equatable {
    case pending
    case active
    case blocked
}

struct ContactInviteResult: Equatable {
    let invitationId: String
    let sentAt: Date
}

// Error types
enum ContactError: Error, Equatable {
    case unauthorized
    case userNotFound
    case invalidPhone
    case alreadyInvited
    case invitationNotFound
    case contactNotFound
    case processingFailed
    case unknown
    
    static func == (lhs: ContactError, rhs: ContactError) -> Bool {
        switch (lhs, rhs) {
        case (.unauthorized, .unauthorized),
             (.userNotFound, .userNotFound),
             (.invalidPhone, .invalidPhone),
             (.alreadyInvited, .alreadyInvited),
             (.invitationNotFound, .invitationNotFound),
             (.contactNotFound, .contactNotFound),
             (.processingFailed, .processingFailed),
             (.unknown, .unknown):
            return true
        default:
            return false
        }
    }
}

// Request/Response models
struct InviteContactRequest: Encodable {
    let phone: String
    let roles: [String]
}

struct InviteContactResponse: Decodable {
    let success: Bool
    let invitationId: String
    let sentAt: String
}

struct AcceptInvitationRequest: Encodable {
    let invitationId: String
}

struct AcceptInvitationResponse: Decodable {
    let success: Bool
    let contact: ContactResponse
}

struct ContactResponse: Decodable {
    let id: String
    let name: String
    let phone: String
    let roles: [String]
    let status: String
}

struct RemoveContactRequest: Encodable {
    let contactId: String
}

struct GetContactsResponse: Decodable {
    let contacts: [ContactResponse]
}

// Adapter implementation
class SupabaseContactAdapter: SupabaseBaseAdapter, ContactClient {
    func inviteContact(phone: String, roles: [ContactRole]) async throws -> ContactInviteResult {
        do {
            let request = InviteContactRequest(
                phone: phone,
                roles: roles.map { $0.rawValue }
            )
            
            let response: InviteContactResponse = try await callFunction(
                name: "invite-contact",
                request: request
            )
            
            return ContactInviteResult(
                invitationId: response.invitationId,
                sentAt: ISO8601DateFormatter().date(from: response.sentAt) ?? Date()
            )
        } catch let error as SupabaseError {
            switch error {
            case .unauthorized:
                throw ContactError.unauthorized
            case .notFound:
                throw ContactError.userNotFound
            case .badRequest:
                throw ContactError.invalidPhone
            default:
                throw ContactError.processingFailed
            }
        } catch {
            throw ContactError.unknown
        }
    }
    
    func acceptInvitation(invitationId: String) async throws -> Contact {
        do {
            let request = AcceptInvitationRequest(invitationId: invitationId)
            
            let response: AcceptInvitationResponse = try await callFunction(
                name: "accept-invitation",
                request: request
            )
            
            return Contact(
                id: response.contact.id,
                name: response.contact.name,
                phone: response.contact.phone,
                roles: response.contact.roles.compactMap { ContactRole(rawValue: $0) },
                status: ContactStatus(rawValue: response.contact.status) ?? .pending
            )
        } catch let error as SupabaseError {
            switch error {
            case .unauthorized:
                throw ContactError.unauthorized
            case .notFound:
                throw ContactError.invitationNotFound
            default:
                throw ContactError.processingFailed
            }
        } catch {
            throw ContactError.unknown
        }
    }
    
    func removeContact(contactId: String) async throws {
        do {
            let request = RemoveContactRequest(contactId: contactId)
            
            let _: EmptyResponse = try await callFunction(
                name: "remove-contact",
                request: request
            )
        } catch let error as SupabaseError {
            switch error {
            case .unauthorized:
                throw ContactError.unauthorized
            case .notFound:
                throw ContactError.contactNotFound
            default:
                throw ContactError.processingFailed
            }
        } catch {
            throw ContactError.unknown
        }
    }
    
    func getContacts() async throws -> [Contact] {
        do {
            let response: GetContactsResponse = try await callFunction(
                name: "get-contacts",
                request: EmptyRequest()
            )
            
            return response.contacts.map { contact in
                Contact(
                    id: contact.id,
                    name: contact.name,
                    phone: contact.phone,
                    roles: contact.roles.compactMap { ContactRole(rawValue: $0) },
                    status: ContactStatus(rawValue: contact.status) ?? .pending
                )
            }
        } catch let error as SupabaseError {
            switch error {
            case .unauthorized:
                throw ContactError.unauthorized
            case .notFound:
                throw ContactError.userNotFound
            default:
                throw ContactError.processingFailed
            }
        } catch {
            throw ContactError.unknown
        }
    }
}
```

## Conclusion

By following these adapter pattern guidelines, you can create a clean, testable, and maintainable integration between the LifeSignal iOS application and Supabase cloud functions. The adapter pattern provides a clear separation between the application's domain model and the backend implementation details, making it easier to change or extend the backend without affecting the application's core functionality.
