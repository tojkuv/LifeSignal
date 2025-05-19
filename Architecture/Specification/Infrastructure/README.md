# LifeSignal iOS Infrastructure Layer

**Navigation:** [Back to Application Specification](../README.md) | [Client Interfaces](ClientInterfaces.md) | [Middleware Clients](MiddlewareClients.md) | [Backend Integration](BackendIntegration.md) | [Data Persistence and Streaming](DataPersistenceStreaming.md)

---

## Overview

The Infrastructure layer in the LifeSignal iOS application is responsible for providing the implementation details for the client interfaces defined in the Domain layer. It serves as a bridge between the application's business logic and the external services it depends on, such as Firebase, Supabase, local storage, and other third-party services.

The infrastructure layer follows a layered approach where middleware clients (backend agnostic anti-corruption clients) use adapters of platform backend clients to create the backend implementation. This design allows for flexibility in switching between different backend technologies (such as Firebase and Supabase) without affecting the rest of the application.

## Layer Structure

The Infrastructure layer is organized into the following components:

1. **Client Interfaces** - Defined in the Domain layer, these interfaces specify the operations that can be performed on external services.
2. **Middleware Clients** - Backend agnostic anti-corruption clients that implement the client interfaces.
3. **Adapters** - Bridge between middleware clients and platform backend clients.
4. **Platform Backend Clients** - Implement the actual backend integration with specific technologies (Firebase, Supabase).
5. **DTOs** - Data Transfer Objects that map between domain models and backend data structures.
6. **Utilities** - Helper classes and functions for working with external services.

## Client Interfaces

Client interfaces are defined in the Domain layer and are implemented by adapters in the Infrastructure layer. Each client interface represents a specific domain of functionality, such as authentication, user management, or check-ins.

Example client interfaces include:
- `AuthClient` - Authentication operations
- `UserClient` - User profile operations
- `ContactClient` - Contact relationship operations
- `CheckInClient` - Check-in operations
- `AlertClient` - Alert operations
- `PingClient` - Ping operations
- `NotificationClient` - Notification operations
- `StorageClient` - Data storage operations
- `ImageClient` - Image handling operations
- `QRCodeClient` - QR code operations

## Middleware Clients

Middleware clients are backend agnostic anti-corruption clients that implement the client interfaces defined in the Domain layer. They use adapters of platform backend clients to interact with the actual backend services. This approach allows the application to switch between different backend technologies without changing the client interfaces or the features that use them.

Example middleware clients include:
- `AuthClient` - Authentication operations using adapters of platform backend clients
- `UserClient` - User profile operations using adapters of platform backend clients
- `ContactClient` - Contact relationship operations using adapters of platform backend clients
- `CheckInClient` - Check-in operations using adapters of platform backend clients
- `AlertClient` - Alert operations using adapters of platform backend clients
- `PingClient` - Ping operations using adapters of platform backend clients
- `NotificationClient` - Notification operations using adapters of platform backend clients

## Adapters and Platform Backend Clients

Adapters bridge between middleware clients and platform backend clients. Platform backend clients implement the actual integration with backend services. Adapters are responsible for translating between the domain models and the backend data structures, as well as handling backend-specific error conditions.

Example adapters and platform backend clients include:
- `FirebaseAuthAdapter` - Implements authentication using Firebase Authentication
- `FirebaseUserAdapter` - Implements user operations using Firebase Firestore
- `FirebaseContactAdapter` - Implements contact operations using Firebase Firestore
- `FirebaseCheckInAdapter` - Implements check-in operations using Firebase Firestore
- `FirebaseAlertAdapter` - Implements alert operations using Firebase Firestore
- `FirebasePingAdapter` - Implements ping operations using Firebase Firestore
- `FirebaseNotificationAdapter` - Implements notification operations using Firebase Cloud Messaging
- `SupabaseAuthAdapter` - Implements authentication using Supabase Auth (future)
- `SupabaseUserAdapter` - Implements user operations using Supabase Database (future)
- `UserDefaultsStorageAdapter` - Implements storage operations using UserDefaults
- `CoreDataStorageAdapter` - Implements storage operations using Core Data
- `UIImageAdapter` - Implements image operations using UIKit
- `CoreImageQRCodeAdapter` - Implements QR code operations using Core Image

## DTOs

Data Transfer Objects (DTOs) are used to map between domain models and backend data structures. They are responsible for serializing and deserializing data, as well as handling any data format conversions.

Example DTOs include:
- `UserDTO` - Maps between `User` domain model and Firebase user data
- `ContactDTO` - Maps between `Contact` domain model and Firebase contact data
- `CheckInDTO` - Maps between `CheckInRecord` domain model and Firebase check-in data
- `AlertDTO` - Maps between `Alert` domain model and Firebase alert data
- `PingDTO` - Maps between `Ping` domain model and Firebase ping data
- `NotificationDTO` - Maps between `Notification` domain model and Firebase notification data

## Utilities

Utilities are helper classes and functions that provide common functionality for working with external services. They are used by adapters to simplify common operations.

Example utilities include:
- `FirebaseUtilities` - Helper functions for working with Firebase
- `DateUtilities` - Helper functions for working with dates
- `ImageUtilities` - Helper functions for working with images
- `QRCodeUtilities` - Helper functions for working with QR codes
- `NetworkUtilities` - Helper functions for working with network operations

## Dependency Registration

Client implementations are registered with the dependency injection system using the `DependencyKey` protocol. This allows features to access the clients through the dependency injection system without knowing the specific implementation details. The platform-agnostic clients are registered with the dependency injection system, and they in turn use the appropriate platform-specific clients based on the current infrastructure provider.

Example dependency registration:

```swift
extension AuthClient: DependencyKey {
    static var liveValue: Self {
        // Get the current infrastructure provider
        let provider = Current.infrastructureProvider()

        // Create the appropriate auth adapter based on the provider
        let authAdapter = InfrastructureFactory.createAuthClient(provider: provider)

        return Self(
            signIn: {
                try await authAdapter.signIn()
            },
            signOut: {
                try await authAdapter.signOut()
            },
            // Other methods...
        )
    }

    static var testValue: Self {
        return Self(
            signIn: unimplemented("AuthClient.signIn"),
            signOut: unimplemented("AuthClient.signOut"),
            // Other methods...
        )
    }

    static var previewValue: Self {
        return Self(
            signIn: {
                // Return mock data for previews
                return "user123"
            },
            signOut: {
                // No-op for previews
            },
            // Other methods...
        )
    }
}

extension DependencyValues {
    var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}
```

## Error Handling

Adapters are responsible for handling backend-specific error conditions and mapping them to domain-specific errors. This allows features to handle errors in a consistent way without knowing the specific backend implementation details.

Example error handling:

```swift
enum AuthError: Error, LocalizedError {
    case notAuthenticated
    case invalidCredentials
    case networkError
    case serverError
    case unknownError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You are not signed in. Please sign in to continue."
        case .invalidCredentials:
            return "Invalid credentials. Please check your phone number and try again."
        case .networkError:
            return "A network error occurred. Please check your internet connection and try again."
        case .serverError:
            return "The server is currently unavailable. Please try again later."
        case let .unknownError(error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}
```

## Testing

The Infrastructure layer is tested using unit tests that verify the correct behavior of adapters and utilities. Mock implementations of backend services are used to simulate different scenarios, including success and failure cases.

For more information on testing the Infrastructure layer, see the [Testing Strategy](Testing/README.md) document.

## Client Interfaces

The LifeSignal iOS application uses client interfaces to interact with backend services. These interfaces provide a consistent contract for the application to interact with backend services, regardless of the specific backend technology being used. This approach allows the application to switch between different backend technologies (such as Firebase and Supabase) without affecting the rest of the application. For more information, see the [Client Interfaces](ClientInterfaces.md) document.

## Middleware Clients

Middleware clients are backend agnostic anti-corruption clients that implement the client interfaces. Features use middleware clients, and middleware clients use adapters of platform backend clients. This layered approach creates a clean separation of concerns and makes the application more flexible, testable, and maintainable. For more information, see the [Middleware Clients](MiddlewareClients.md) document.

## Backend Integration

Currently, the LifeSignal iOS application uses Firebase as its primary backend service. In the future, some functionality will be migrated to Supabase. For more information on backend integration, see the [Backend Integration](BackendIntegration.md) document.

## Data Persistence and Streaming

The LifeSignal iOS application implements a comprehensive strategy for data persistence and streaming, particularly for user data and contact collections. This strategy leverages TCA's @Shared property wrapper, AsyncStream, and platform-specific client capabilities to provide a responsive and reliable user experience. For more information, see the [Data Persistence and Streaming](DataPersistenceStreaming.md) document.

## Best Practices

When implementing adapters and utilities in the Infrastructure layer, follow these best practices:

1. **Keep adapters focused on a single responsibility** - Each adapter should implement a single client interface and be focused on a specific domain of functionality.

2. **Handle backend-specific error conditions** - Adapters should handle backend-specific error conditions and map them to domain-specific errors.

3. **Use DTOs to map between domain models and backend data structures** - DTOs should be used to serialize and deserialize data, as well as handle any data format conversions.

4. **Provide meaningful error messages** - Error messages should be clear and actionable, providing guidance on how to resolve the error.

5. **Test adapters thoroughly** - Adapters should be tested with unit tests that verify the correct behavior in different scenarios, including success and failure cases.

6. **Use dependency injection for testability** - Adapters should use dependency injection to allow for easy testing with mock implementations of backend services.

7. **Keep backend-specific code isolated** - Backend-specific code should be isolated in platform backend clients and adapters, keeping the rest of the application agnostic to the specific backend implementation. Middleware clients should use adapters of platform backend clients to interact with backend services.

8. **Document adapter behavior** - Adapters should be well-documented, including information on error handling, data mapping, and any backend-specific considerations.

9. **Provide live, test, and preview implementations** - Each client interface should have live, test, and preview implementations to support different environments.

10. **Use async/await for asynchronous operations** - Adapters should use async/await for asynchronous operations to provide a consistent and easy-to-use API.
