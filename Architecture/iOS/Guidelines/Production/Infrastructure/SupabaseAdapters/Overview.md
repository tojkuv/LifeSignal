# Supabase Integration Overview

**Navigation:** [Back to Production Guidelines](../../README.md) | [Backend Integration](../BackendIntegration.md) | [Cloud Functions](CloudFunctions.md) | [Client Design](ClientDesign.md) | [Architectural Layers](../ArchitecturalLayers.md)

---

## Introduction

This document provides an overview of how the LifeSignal iOS application integrates with Supabase for cloud functions. While Firebase handles authentication and data storage, Supabase is used for all cloud functions and serverless computing needs.

## Architecture Overview

The LifeSignal application uses a hybrid backend approach with clear separation of responsibilities:

```
                  ┌─────────────────┐
                  │                 │
                  │  iOS Application│
                  │                 │
                  └────────┬────────┘
                           │
                           ▼
           ┌─────────────────────────────┐
           │                             │
           │  Reducers (Business Logic)  │
           │                             │
           └───────────┬─────────────────┘
                       │
                       ▼
           ┌─────────────────────────────┐
           │                             │
           │  Middleware Clients         │
           │                             │
           └───────────┬─────────────────┘
                       │
          ┌────────────┴─────────────┐
          │                          │
┌─────────▼──────────┐    ┌──────────▼─────────┐
│                    │    │                     │
│  Firebase Adapters │    │  Supabase Adapters  │
│  (Auth & Storage)  │    │  (Cloud Functions)  │
│                    │    │                     │
└─────────┬──────────┘    └──────────┬─────────┘
          │                          │
┌─────────▼──────────┐    ┌──────────▼─────────┐
│                    │    │                     │
│  Firebase Backend  │    │  Supabase Backend   │
│                    │    │                     │
└────────────────────┘    └─────────────────────┘
```

## Key Components and Responsibilities

### 1. Reducers (Business Logic)

Reducers are responsible for all business logic in the application. They:

- Handle user actions and update application state
- Orchestrate complex workflows and business rules
- Interact with backend services exclusively through middleware clients
- Never directly access infrastructure adapters or backend SDKs

```swift
@Reducer
struct NotificationFeature {
    @Dependency(\.notificationClient) var notificationClient

    // State and actions...

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .sendNotification(userId, message):
                state.isSending = true
                return .run { send in
                    do {
                        try await notificationClient.sendPushNotification(to: userId, message: message)
                        await send(.notificationSent)
                    } catch {
                        await send(.notificationFailed(error))
                    }
                }

            // Other action handlers...
            }
        }
    }
}
```

### 2. Middleware Clients

Middleware clients are the only clients that reducers should use. They:

- Provide platform-agnostic interfaces for backend operations
- Abstract away infrastructure details from reducers
- Use infrastructure adapters to communicate with specific backends
- Handle domain-specific operations and transformations

```swift
@DependencyClient
struct NotificationClient: Sendable {
    var sendPushNotification: @Sendable (String, String) async throws -> Void
    var fetchNotifications: @Sendable (String) async throws -> [Notification]
    var streamNotifications: @Sendable (String) -> AsyncStream<[Notification]>
}

// Implementation using adapters
struct LiveNotificationClient: NotificationClient {
    private let cloudFunctionAdapter: CloudFunctionClient

    init(cloudFunctionAdapter: CloudFunctionClient) {
        self.cloudFunctionAdapter = cloudFunctionAdapter
    }

    func sendPushNotification(to userId: String, message: String) async throws {
        try await cloudFunctionAdapter.callFunction(
            name: "send-push-notification",
            request: PushNotificationRequest(userId: userId, message: message)
        )
    }

    // Other method implementations...
}
```

### 3. Infrastructure Adapters

Infrastructure adapters create a type-safe bridge for server clients. They:

- Implement platform-specific interfaces for Firebase and Supabase
- Handle the technical details of communicating with backend services
- Convert between domain models and backend-specific data formats
- Encapsulate error handling and retry logic

```swift
struct SupabaseCloudFunctionAdapter: CloudFunctionClient {
    private let supabaseClient: SupabaseClient

    init(supabaseClient: SupabaseClient) {
        self.supabaseClient = supabaseClient
    }

    func callFunction<Request: Encodable, Response: Decodable>(
        name: String,
        request: Request
    ) async throws -> Response {
        // Implementation that calls Supabase Edge Functions
        let response = try await supabaseClient.functions.invoke(name, body: request)
        return try JSONDecoder().decode(Response.self, from: response.data)
    }

    func callFunction<Response: Decodable>(
        name: String
    ) async throws -> Response {
        // Implementation for functions without parameters
        let response = try await supabaseClient.functions.invoke(name)
        return try JSONDecoder().decode(Response.self, from: response.data)
    }
}
```

## Benefits of Supabase for Cloud Functions

1. **Serverless Architecture**: No need to manage servers or infrastructure
2. **Edge Functions**: Deploy functions globally for low-latency responses
3. **TypeScript Support**: Write functions in TypeScript for type safety
4. **PostgreSQL Integration**: Direct access to PostgreSQL database if needed
5. **Open Source**: Built on open-source technologies
6. **Developer Experience**: Excellent developer tools and documentation

## Architectural Flow

1. **User Interaction**: User interacts with the UI, triggering an action
2. **Reducer Processing**: Reducer receives the action and processes business logic
3. **Middleware Client Call**: Reducer calls middleware client methods as needed
4. **Adapter Utilization**: Middleware client uses appropriate infrastructure adapter
5. **Backend Communication**: Adapter communicates with the specific backend (Firebase/Supabase)
6. **Response Handling**: Response flows back up through the layers to update the UI

## Implementation Guidelines

For detailed implementation guidelines, see:

- [Cloud Functions](CloudFunctions.md) - Guidelines for implementing Supabase cloud functions
- [Client Design](ClientDesign.md) - Guidelines for designing Supabase clients
- [Adapter Pattern](AdapterPattern.md) - Guidelines for implementing Supabase adapters
- [Architectural Layers](../ArchitecturalLayers.md) - Detailed explanation of architectural layers and responsibilities

## Related Documentation

- [Backend Integration](../BackendIntegration.md) - Overall backend integration strategy
- [Infrastructure Agnosticism](../AgnosticInfrastructure/InfrastructureAgnosticism.md) - Infrastructure-agnostic design principles
