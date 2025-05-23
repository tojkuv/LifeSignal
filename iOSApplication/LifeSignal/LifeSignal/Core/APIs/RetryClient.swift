import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
struct RetryClient {
    var withRetry: @Sendable (
        @escaping () async throws -> Any,
        _ maxAttempts: Int,
        _ baseDelay: Duration
    ) async throws -> Any = { _, _, _ in throw RetryError.notImplemented }
}

enum RetryError: Error {
    case notImplemented
    case maxAttemptsReached
}

extension RetryClient: DependencyKey {
    static let liveValue = RetryClient(
        withRetry: { operation, maxAttempts, baseDelay in
            var attempt = 0
            while attempt < maxAttempts {
                do {
                    return try await operation()
                } catch {
                    attempt += 1
                    if attempt >= maxAttempts { throw error }
                    
                    let delay = baseDelay * pow(2.0, Double(attempt - 1))
                    try await Task.sleep(for: delay)
                }
            }
            throw RetryError.maxAttemptsReached
        }
    )
    
    static let testValue = RetryClient(
        withRetry: { operation, _, _ in
            try await operation()
        }
    )
}

extension DependencyValues {
    var retryClient: RetryClient {
        get { self[RetryClient.self] }
        set { self[RetryClient.self] = newValue }
    }
}