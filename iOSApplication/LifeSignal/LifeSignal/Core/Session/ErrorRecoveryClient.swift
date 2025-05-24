import ComposableArchitecture
import Dependencies
import Foundation

struct ErrorRecoveryClient {
    var categorizeError: @Sendable (Error) async -> String = { _ in "unknown" }
    var getRecoveryStrategy: @Sendable (Error, String) async -> String = { _, _ in "ignore" }
    var executeRecovery: @Sendable (@escaping () async throws -> Any, String, String) async -> Bool = { _, _, _ in true }
    var recoverFromNetworkError: @Sendable (Error) async -> Bool = { _ in true }
    var recoverFromAuthError: @Sendable (Error) async -> Bool = { _ in true }
    var recoverFromSyncError: @Sendable (Error) async -> Bool = { _ in true }
    var isCircuitOpen: @Sendable (String) -> Bool = { _ in false }
    var recordSuccess: @Sendable (String) -> Void = { _ in }
    var recordFailure: @Sendable (String, Error) -> Void = { _, _ in }
    var resetCircuit: @Sendable (String) -> Void = { _ in }
    var performHealthCheck: @Sendable () async -> Bool = { true }
    var waitForHealthy: @Sendable () async -> Void = { }
}

extension ErrorRecoveryClient: DependencyKey {
    static let liveValue = ErrorRecoveryClient()
    static let mockValue = ErrorRecoveryClient()
    static let testValue = ErrorRecoveryClient()
}

extension DependencyValues {
    var errorRecovery: ErrorRecoveryClient {
        get { self[ErrorRecoveryClient.self] }
        set { self[ErrorRecoveryClient.self] = newValue }
    }
}