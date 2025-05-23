import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation

// MARK: - gRPC Client

@DependencyClient
struct GRPCClient {
    var userService: UserServiceProtocol
    var contactService: ContactServiceProtocol
    var notificationService: NotificationServiceProtocol
}

// Service implementations are in separate files:
// - MockServices.swift for development/testing
// - LiveServices.swift for production

// MARK: - Dependency Implementation

extension GRPCClient: DependencyKey {
    static let liveValue = GRPCClient(
        userService: LiveUserService(),
        contactService: LiveContactService(),
        notificationService: LiveNotificationService()
    )
    
    static let testValue = GRPCClient(
        userService: MockUserService(),
        contactService: MockContactService(),
        notificationService: MockNotificationService()
    )
}

extension DependencyValues {
    var grpcClient: GRPCClient {
        get { self[GRPCClient.self] }
        set { self[GRPCClient.self] = newValue }
    }
}