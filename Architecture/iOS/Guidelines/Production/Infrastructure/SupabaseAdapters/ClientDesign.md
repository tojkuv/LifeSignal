# Supabase Client Design Guidelines

**Navigation:** [Back to Supabase Overview](Overview.md) | [Cloud Functions](CloudFunctions.md) | [Backend Integration](../BackendIntegration.md)

---

## Overview

This document provides guidelines for designing client interfaces and adapters for interacting with Supabase cloud functions in the LifeSignal iOS application.

## Client Architecture

The client architecture follows a layered approach:

```
Feature Layer → Middleware Clients → Supabase Adapters → Supabase SDK
```

This layered approach provides:

1. **Abstraction**: Features depend on middleware clients, not concrete implementations
2. **Testability**: Middleware clients can be mocked for testing
3. **Flexibility**: Implementations can be changed without affecting features
4. **Separation of Concerns**: Each layer has a single responsibility

## Middleware Clients

Middleware clients define the contract between features and backend services:

### Design Principles

1. **Domain-Focused**: Interfaces should use domain types, not backend-specific types
2. **Feature-Aligned**: Organize interfaces by feature, not by backend service
3. **Minimal**: Include only the methods needed by features
4. **Async/Await**: Use Swift's async/await for asynchronous operations
5. **Error Handling**: Define clear error types and handling patterns

### Example Interfaces

#### Notification Client

```swift
enum NotificationError: Error {
    case unauthorized
    case userNotFound
    case invalidInput
    case sendFailed
    case unknown(Error)
}

struct NotificationRequest {
    let recipientId: String
    let title: String
    let body: String
    let data: [String: String]?
}

struct NotificationResult {
    let messageId: String
    let sentAt: Date
}

protocol NotificationClient {
    func sendPushNotification(_ notification: NotificationRequest) async throws -> NotificationResult
    func scheduleNotification(_ notification: NotificationRequest, deliveryTime: Date) async throws -> NotificationResult
    func cancelNotification(messageId: String) async throws
}
```

#### Check-In Client

```swift
enum CheckInError: Error {
    case unauthorized
    case userNotFound
    case invalidInterval
    case processingFailed
    case unknown(Error)
}

struct CheckInResult {
    let lastCheckInTime: Date
    let nextCheckInTime: Date
}

protocol CheckInClient {
    func processCheckIn(nextCheckInInterval: TimeInterval) async throws -> CheckInResult
    func getCheckInStatus() async throws -> CheckInStatus
}

struct CheckInStatus {
    let lastCheckInTime: Date?
    let nextCheckInTime: Date?
    let status: String
    let interval: TimeInterval
}
```

#### Alert Client

```swift
enum AlertError: Error {
    case unauthorized
    case userNotFound
    case alreadyActive
    case notActive
    case processingFailed
    case unknown(Error)
}

struct AlertResult {
    let alertId: String
    let activatedAt: Date
    let status: String
}

protocol AlertClient {
    func triggerAlert() async throws -> AlertResult
    func cancelAlert(alertId: String) async throws
    func getActiveAlert() async throws -> AlertResult?
}
```

## Supabase Adapters

Adapters implement client interfaces using the Supabase SDK:

### Design Principles

1. **Interface Conformance**: Adapters should fully implement client interfaces
2. **Error Mapping**: Map Supabase errors to domain-specific errors
3. **Type Conversion**: Convert between Supabase types and domain types
4. **Dependency Injection**: Accept dependencies in initializers
5. **Testability**: Design for testability with clear dependencies

### Base Adapter

Create a base adapter for common functionality:

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

enum SupabaseError: Error {
    case unauthorized
    case notFound
    case badRequest
    case serverError
    case invalidResponse
}
```

### Example Adapter Implementations

#### Notification Adapter

```swift
class SupabaseNotificationAdapter: SupabaseBaseAdapter, NotificationClient {
    func sendPushNotification(_ notification: NotificationRequest) async throws -> NotificationResult {
        do {
            let request = SendNotificationRequest(
                userId: notification.recipientId,
                title: notification.title,
                body: notification.body,
                data: notification.data
            )

            let response: SendNotificationResponse = try await callFunction(
                name: "send-push-notification",
                request: request
            )

            return NotificationResult(
                messageId: response.messageId,
                sentAt: ISO8601DateFormatter().date(from: response.sentAt) ?? Date()
            )
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

    func scheduleNotification(_ notification: NotificationRequest, deliveryTime: Date) async throws -> NotificationResult {
        do {
            let request = ScheduleNotificationRequest(
                userId: notification.recipientId,
                title: notification.title,
                body: notification.body,
                data: notification.data,
                deliveryTime: ISO8601DateFormatter().string(from: deliveryTime)
            )

            let response: ScheduleNotificationResponse = try await callFunction(
                name: "schedule-notification",
                request: request
            )

            return NotificationResult(
                messageId: response.messageId,
                sentAt: ISO8601DateFormatter().date(from: response.scheduledFor) ?? Date()
            )
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

    func cancelNotification(messageId: String) async throws {
        do {
            let request = CancelNotificationRequest(messageId: messageId)

            let _: EmptyResponse = try await callFunction(
                name: "cancel-notification",
                request: request
            )
        } catch let error as SupabaseError {
            switch error {
            case .unauthorized:
                throw NotificationError.unauthorized
            case .notFound:
                throw NotificationError.userNotFound
            default:
                throw NotificationError.sendFailed
            }
        } catch {
            throw NotificationError.unknown(error)
        }
    }
}

// Request/Response types
struct SendNotificationRequest: Encodable {
    let userId: String
    let title: String
    let body: String
    let data: [String: String]?
}

struct SendNotificationResponse: Decodable {
    let success: Bool
    let messageId: String
    let sentAt: String
}

struct ScheduleNotificationRequest: Encodable {
    let userId: String
    let title: String
    let body: String
    let data: [String: String]?
    let deliveryTime: String
}

struct ScheduleNotificationResponse: Decodable {
    let success: Bool
    let messageId: String
    let scheduledFor: String
}

struct CancelNotificationRequest: Encodable {
    let messageId: String
}

struct EmptyResponse: Decodable {}
```

#### Check-In Adapter

```swift
class SupabaseCheckInAdapter: SupabaseBaseAdapter, CheckInClient {
    func processCheckIn(nextCheckInInterval: TimeInterval) async throws -> CheckInResult {
        do {
            let request = ProcessCheckInRequest(nextCheckInInterval: nextCheckInInterval)

            let response: ProcessCheckInResponse = try await callFunction(
                name: "process-check-in",
                request: request
            )

            return CheckInResult(
                lastCheckInTime: ISO8601DateFormatter().date(from: response.lastCheckInTime) ?? Date(),
                nextCheckInTime: ISO8601DateFormatter().date(from: response.nextCheckInTime) ?? Date()
            )
        } catch let error as SupabaseError {
            switch error {
            case .unauthorized:
                throw CheckInError.unauthorized
            case .notFound:
                throw CheckInError.userNotFound
            case .badRequest:
                throw CheckInError.invalidInterval
            default:
                throw CheckInError.processingFailed
            }
        } catch {
            throw CheckInError.unknown(error)
        }
    }

    func getCheckInStatus() async throws -> CheckInStatus {
        do {
            let response: CheckInStatusResponse = try await callFunction(
                name: "get-check-in-status",
                request: EmptyRequest()
            )

            return CheckInStatus(
                lastCheckInTime: response.lastCheckInTime != nil ? ISO8601DateFormatter().date(from: response.lastCheckInTime!) : nil,
                nextCheckInTime: response.nextCheckInTime != nil ? ISO8601DateFormatter().date(from: response.nextCheckInTime!) : nil,
                status: response.status,
                interval: response.interval
            )
        } catch let error as SupabaseError {
            switch error {
            case .unauthorized:
                throw CheckInError.unauthorized
            case .notFound:
                throw CheckInError.userNotFound
            default:
                throw CheckInError.processingFailed
            }
        } catch {
            throw CheckInError.unknown(error)
        }
    }
}

// Request/Response types
struct ProcessCheckInRequest: Encodable {
    let nextCheckInInterval: TimeInterval
}

struct ProcessCheckInResponse: Decodable {
    let success: Bool
    let lastCheckInTime: String
    let nextCheckInTime: String
}

struct CheckInStatusResponse: Decodable {
    let lastCheckInTime: String?
    let nextCheckInTime: String?
    let status: String
    let interval: TimeInterval
}

struct EmptyRequest: Encodable {}
```

## Dependency Registration

Register adapters with the dependency injection system:

```swift
import ComposableArchitecture

extension NotificationClient: DependencyKey {
    static let liveValue: NotificationClient = {
        let supabaseClient = SupabaseClient(
            url: ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "",
            anonKey: ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
        )
        let authProvider = FirebaseAuthProvider()
        return SupabaseNotificationAdapter(supabaseClient: supabaseClient, authProvider: authProvider)
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

## Testing

### Mock Clients

Create mock clients for testing:

```swift
class MockNotificationClient: NotificationClient {
    var sendPushNotificationResult: Result<NotificationResult, NotificationError> = .success(
        NotificationResult(messageId: "mock-id", sentAt: Date())
    )

    var scheduleNotificationResult: Result<NotificationResult, NotificationError> = .success(
        NotificationResult(messageId: "mock-id", sentAt: Date())
    )

    var cancelNotificationResult: Result<Void, NotificationError> = .success(())

    func sendPushNotification(_ notification: NotificationRequest) async throws -> NotificationResult {
        try sendPushNotificationResult.get()
    }

    func scheduleNotification(_ notification: NotificationRequest, deliveryTime: Date) async throws -> NotificationResult {
        try scheduleNotificationResult.get()
    }

    func cancelNotification(messageId: String) async throws {
        try cancelNotificationResult.get()
    }
}
```

### Feature Tests

Test features with mock clients:

```swift
@MainActor
func testSendNotification() async {
    let store = TestStore(initialState: NotificationFeature.State()) {
        NotificationFeature()
    } withDependencies: {
        $0.notificationClient = MockNotificationClient()
    }

    await store.send(.sendNotification(to: "user-123", message: "Hello")) {
        $0.isSending = true
    }

    await store.receive(.notificationSent) {
        $0.isSending = false
        $0.lastSentMessageId = "mock-id"
    }
}
```

## Feature Integration

Use client interfaces in features:

```swift
@Reducer
struct NotificationFeature {
    struct State: Equatable {
        var isSending = false
        var lastSentMessageId: String?
        var error: String?
    }

    enum Action {
        case sendNotification(to: String, message: String)
        case notificationSent
        case notificationFailed(String)
    }

    @Dependency(\.notificationClient) var notificationClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .sendNotification(userId, message):
                state.isSending = true
                state.error = nil

                return .run { send in
                    do {
                        let notification = NotificationRequest(
                            recipientId: userId,
                            title: "LifeSignal",
                            body: message,
                            data: nil
                        )

                        let result = try await notificationClient.sendPushNotification(notification)
                        await send(.notificationSent)
                    } catch {
                        await send(.notificationFailed(error.localizedDescription))
                    }
                }

            case .notificationSent:
                state.isSending = false
                return .none

            case let .notificationFailed(error):
                state.isSending = false
                state.error = error
                return .none
            }
        }
    }
}
```

## Conclusion

By following these client design guidelines, you can create a clean, testable, and maintainable integration between the LifeSignal iOS application and Supabase cloud functions. Remember that all cloud functions should be implemented in Supabase, while authentication and data storage remain in Firebase.
