import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation

// MARK: - Retry Models

enum RetryError: Error, Equatable {
    case notImplemented
    case maxAttemptsReached(attempts: Int, lastError: String)
    case operationCancelled
    case retryConditionNotMet(reason: String)
    case timeoutExceeded(duration: TimeInterval)

    var localizedDescription: String {
        switch self {
        case .notImplemented:
            return "Retry functionality not implemented"
        case .maxAttemptsReached(let attempts, let lastError):
            return "Max retry attempts (\(attempts)) reached. Last error: \(lastError)"
        case .operationCancelled:
            return "Retry operation was cancelled"
        case .retryConditionNotMet(let reason):
            return "Retry condition not met: \(reason)"
        case .timeoutExceeded(let duration):
            return "Retry timeout exceeded after \(duration) seconds"
        }
    }
}

enum RetryStrategy: Sendable {
    case exponential(base: TimeInterval = 1.0, multiplier: Double = 2.0, maxDelay: TimeInterval = 60.0)
    case linear(delay: TimeInterval)
    case fixed(delay: TimeInterval)
    case custom(delayCalculator: @Sendable (Int) -> TimeInterval)

    func calculateDelay(for attempt: Int) -> TimeInterval {
        switch self {
        case .exponential(let base, let multiplier, let maxDelay):
            let delay = base * pow(multiplier, Double(attempt - 1))
            return min(delay, maxDelay)
        case .linear(let baseDelay):
            return baseDelay * Double(attempt)
        case .fixed(let delay):
            return delay
        case .custom(let calculator):
            return calculator(attempt)
        }
    }
}

struct RetryPolicy: Sendable {
    let maxAttempts: Int
    let strategy: RetryStrategy
    let timeout: TimeInterval?
    let retryableErrors: Set<String>?
    let shouldRetry: (@Sendable (Error, Int) -> Bool)?
    let onRetry: (@Sendable (Error, Int, TimeInterval) async -> Void)?

    init(
        maxAttempts: Int = 3,
        strategy: RetryStrategy = .exponential(),
        timeout: TimeInterval? = nil,
        retryableErrors: Set<String>? = nil,
        shouldRetry: (@Sendable (Error, Int) -> Bool)? = nil,
        onRetry: (@Sendable (Error, Int, TimeInterval) async -> Void)? = nil
    ) {
        self.maxAttempts = maxAttempts
        self.strategy = strategy
        self.timeout = timeout
        self.retryableErrors = retryableErrors
        self.shouldRetry = shouldRetry
        self.onRetry = onRetry
    }

    func shouldRetryError(_ error: Error, attempt: Int) -> Bool {
        // Check custom retry condition first
        if let shouldRetry = shouldRetry {
            return shouldRetry(error, attempt)
        }

        // Check against retryable error types
        if let retryableErrors = retryableErrors {
            let errorType = String(describing: type(of: error))
            return retryableErrors.contains(errorType)
        }

        // Default retry logic for common error types
        return isRetryableError(error)
    }

    private func isRetryableError(_ error: Error) -> Bool {
        // Network errors are generally retryable
        if error is URLError {
            return true
        }

        // Add other retryable error types
        let errorString = error.localizedDescription.lowercased()
        let retryableKeywords = ["network", "timeout", "connection", "unreachable", "temporary"]

        return retryableKeywords.contains { errorString.contains($0) }
    }

    /// Predefined policies for common scenarios
    static let networkOperation = RetryPolicy(
        maxAttempts: 3,
        strategy: .exponential(base: 1.0, multiplier: 2.0, maxDelay: 30.0),
        timeout: 120.0
    )

    static let criticalOperation = RetryPolicy(
        maxAttempts: 5,
        strategy: .exponential(base: 0.5, multiplier: 1.5, maxDelay: 10.0),
        timeout: 60.0
    )

    static let backgroundTask = RetryPolicy(
        maxAttempts: 10,
        strategy: .exponential(base: 2.0, multiplier: 2.0, maxDelay: 300.0),
        timeout: 1800.0 // 30 minutes
    )

    static let quickRetry = RetryPolicy(
        maxAttempts: 2,
        strategy: .fixed(delay: 0.5),
        timeout: 5.0
    )
}

struct RetryAttempt: Sendable {
    let attemptNumber: Int
    let errorDescription: String?
    let delay: TimeInterval
    let timestamp: Date

    init(attemptNumber: Int, error: Error? = nil, delay: TimeInterval = 0) {
        self.attemptNumber = attemptNumber
        self.errorDescription = error?.localizedDescription
        self.delay = delay
        self.timestamp = Date()
    }
}

// MARK: - Sendable Value Storage
enum SendableValue: Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case data(Data)
    case url(URL)
    case date(Date)
    case array([SendableValue])
    case dictionary([String: SendableValue])
    case none
    
    init<T: Sendable>(_ value: T) {
        switch value {
        case let string as String:
            self = .string(string)
        case let int as Int:
            self = .int(int)
        case let double as Double:
            self = .double(double)
        case let bool as Bool:
            self = .bool(bool)
        case let data as Data:
            self = .data(data)
        case let url as URL:
            self = .url(url)
        case let date as Date:
            self = .date(date)
        default:
            // For other Sendable types, convert to string representation
            self = .string(String(describing: value))
        }
    }
    
    func get<T>() -> T? {
        switch self {
        case .string(let value):
            return value as? T
        case .int(let value):
            return value as? T
        case .double(let value):
            return value as? T
        case .bool(let value):
            return value as? T
        case .data(let value):
            return value as? T
        case .url(let value):
            return value as? T
        case .date(let value):
            return value as? T
        case .array(let value):
            return value as? T
        case .dictionary(let value):
            return value as? T
        case .none:
            return nil
        }
    }
    
    var anyValue: Any {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .bool(let value):
            return value
        case .data(let value):
            return value
        case .url(let value):
            return value
        case .date(let value):
            return value
        case .array(let value):
            return value
        case .dictionary(let value):
            return value
        case .none:
            return Optional<Any>.none as Any
        }
    }
}

// MARK: - Sendable RetryResult
struct RetryResult<T: Sendable>: Sendable {
    let value: T?
    let attempts: [RetryAttempt]
    let totalDuration: TimeInterval
    let succeeded: Bool
    let finalErrorDescription: String?

    init(value: T?, attempts: [RetryAttempt], totalDuration: TimeInterval, succeeded: Bool, finalError: Error?) {
        self.value = value
        self.attempts = attempts
        self.totalDuration = totalDuration
        self.succeeded = succeeded
        self.finalErrorDescription = finalError?.localizedDescription
    }

    var attemptCount: Int { attempts.count }
    var averageDelay: TimeInterval {
        let totalDelay = attempts.map { $0.delay }.reduce(0, +)
        return attempts.isEmpty ? 0 : totalDelay / Double(attempts.count)
    }
}

// Type-erased sendable result for internal use
struct AnySendableRetryResult: Sendable {
    let value: SendableValue?
    let attempts: [RetryAttempt]
    let totalDuration: TimeInterval
    let succeeded: Bool
    let finalErrorDescription: String?

    init(value: SendableValue?, attempts: [RetryAttempt], totalDuration: TimeInterval, succeeded: Bool, finalError: Error?) {
        self.value = value
        self.attempts = attempts
        self.totalDuration = totalDuration
        self.succeeded = succeeded
        self.finalErrorDescription = finalError?.localizedDescription
    }
}

// MARK: - Retry Client

@DependencyClient
struct RetryClient {
    // Core retry functionality
    var withRetry: @Sendable (
        @escaping @Sendable () async throws -> SendableValue,
        Int,
        Duration
    ) async throws -> SendableValue = { _, _, _ in throw RetryError.notImplemented }

    var withRetryPolicy: @Sendable (
        @escaping @Sendable () async throws -> SendableValue,
        RetryPolicy
    ) async throws -> SendableValue = { _, _ in throw RetryError.notImplemented }

    var withRetryResult: @Sendable (
        @escaping @Sendable () async throws -> SendableValue,
        RetryPolicy
    ) async -> AnySendableRetryResult = { _, _ in
        AnySendableRetryResult(value: nil, attempts: [], totalDuration: 0, succeeded: false, finalError: RetryError.notImplemented)
    }

    // Specialized retry methods
    var retryNetworkOperation: @Sendable (
        @escaping @Sendable () async throws -> SendableValue
    ) async throws -> SendableValue = { _ in throw RetryError.notImplemented }

    var retryCriticalOperation: @Sendable (
        @escaping @Sendable () async throws -> SendableValue
    ) async throws -> SendableValue = { _ in throw RetryError.notImplemented }

    var retryBackgroundTask: @Sendable (
        @escaping @Sendable () async throws -> SendableValue
    ) async throws -> SendableValue = { _ in throw RetryError.notImplemented }

    // Conditional retry
    var retryIf: @Sendable (
        @escaping @Sendable () async throws -> SendableValue,
        @escaping @Sendable (Error, Int) -> Bool,
        Int,
        TimeInterval
    ) async throws -> SendableValue = { _, _, _, _ in throw RetryError.notImplemented }

    // Timeout with retry
    var withTimeout: @Sendable (
        @escaping @Sendable () async throws -> SendableValue,
        TimeInterval,
        RetryPolicy
    ) async throws -> SendableValue = { _, _, _ in throw RetryError.notImplemented }
}

// MARK: - Type-Safe Extensions

extension RetryClient {
    /// Type-safe retry with policy
    func withRetry<T: Sendable>(
        policy: RetryPolicy = RetryPolicy(),
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let result = try await withRetryPolicy({ SendableValue(try await operation()) }, policy)
        return result.get()!
    }

    /// Type-safe retry with detailed result
    func withRetryResult<T: Sendable>(
        policy: RetryPolicy = RetryPolicy(),
        operation: @escaping @Sendable () async throws -> T
    ) async -> RetryResult<T> {
        let result = await withRetryResult({ SendableValue(try await operation()) }, policy)
        return RetryResult(
            value: result.value?.get(),
            attempts: result.attempts,
            totalDuration: result.totalDuration,
            succeeded: result.succeeded,
            finalError: nil // We use finalErrorDescription in the new RetryResult
        )
    }

    /// Retry with custom condition
    func retryWhile<T: Sendable>(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        condition: @escaping @Sendable (Error, Int) -> Bool,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let result = try await retryIf({ SendableValue(try await operation()) }, condition, maxAttempts, delay)
        return result.get()!
    }

    /// Simple exponential backoff retry
    func withExponentialBackoff<T: Sendable>(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 1.0,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let policy = RetryPolicy(
            maxAttempts: maxAttempts,
            strategy: .exponential(base: baseDelay, multiplier: 2.0, maxDelay: 60.0)
        )
        return try await withRetry(policy: policy, operation: operation)
    }

    /// Linear backoff retry
    func withLinearBackoff<T: Sendable>(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 1.0,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let policy = RetryPolicy(
            maxAttempts: maxAttempts,
            strategy: .linear(delay: baseDelay)
        )
        return try await withRetry(policy: policy, operation: operation)
    }
}

// MARK: - Live Implementation

extension RetryClient: DependencyKey {
    static let liveValue: RetryClient = {
        @Dependency(\.performance) var performance

        return RetryClient(
            withRetry: { operation, maxAttempts, baseDelay in
                let policy = RetryPolicy(
                    maxAttempts: maxAttempts,
                    strategy: .exponential(base: baseDelay.timeInterval, multiplier: 2.0, maxDelay: 60.0)
                )
                return try await RetryClient.liveValue.withRetryPolicy(operation, policy)
            },

            withRetryPolicy: { operation, policy in
                let startTime = Date()
                var attempts: [RetryAttempt] = []
                var lastError: Error?

                // Check for timeout
                let timeoutTask: Task<Void, Never>? = policy.timeout.map { timeout in
                    Task {
                        try? await Task.sleep(for: .seconds(timeout))
                    }
                }

                defer {
                    timeoutTask?.cancel()
                }

                for attempt in 1...policy.maxAttempts {
                    do {
                        // Check if we've exceeded timeout
                        if let timeoutTask = timeoutTask, timeoutTask.isCancelled {
                            throw RetryError.timeoutExceeded(duration: policy.timeout ?? 0)
                        }

                        let result = try await operation()

                        // Success - record attempt and return
                        attempts.append(RetryAttempt(attemptNumber: attempt))

                        // Record successful retry metrics
                        if attempt > 1 {
                            await performance.recordCounter("retry_success_total", 1, [
                                "attempts": "\(attempt)",
                                "strategy": String(describing: policy.strategy)
                            ])
                        }

                        return result

                    } catch {
                        lastError = error
                        attempts.append(RetryAttempt(attemptNumber: attempt, error: error))

                        // Check if we should retry this error
                        if !policy.shouldRetryError(error, attempt: attempt) {
                            await performance.recordCounter("retry_failed_non_retryable", 1, [
                                "error_type": String(describing: type(of: error)),
                                "attempt": "\(attempt)"
                            ])
                            throw error
                        }

                        // Don't delay after the last attempt
                        if attempt >= policy.maxAttempts {
                            break
                        }

                        // Calculate delay for next attempt
                        let delay = policy.strategy.calculateDelay(for: attempt)
                        attempts[attempts.count - 1] = RetryAttempt(
                            attemptNumber: attempt,
                            error: error,
                            delay: delay
                        )

                        // Call retry callback if provided
                        await policy.onRetry?(error, attempt, delay)

                        // Record retry metrics
                        await performance.recordTimer("retry_delay", delay, [
                            "attempt": "\(attempt)",
                            "strategy": String(describing: policy.strategy)
                        ])

                        print("🔄 Retry attempt \(attempt)/\(policy.maxAttempts) failed: \(error.localizedDescription)")
                        print("   Retrying in \(String(format: "%.2f", delay))s...")

                        // Wait before next attempt
                        try await Task.sleep(for: .seconds(delay))
                    }
                }

                // All attempts failed
                let finalError = RetryError.maxAttemptsReached(
                    attempts: policy.maxAttempts,
                    lastError: lastError?.localizedDescription ?? "Unknown error"
                )

                await performance.recordCounter("retry_failed_max_attempts", 1, [
                    "max_attempts": "\(policy.maxAttempts)",
                    "strategy": String(describing: policy.strategy)
                ])

                throw finalError
            },

            withRetryResult: { operation, policy in
                let startTime = Date()

                do {
                    let result = try await RetryClient.liveValue.withRetryPolicy(operation, policy)
                    let duration = Date().timeIntervalSince(startTime)

                    return AnySendableRetryResult(
                        value: result,
                        attempts: [],
                        totalDuration: duration,
                        succeeded: true,
                        finalError: nil
                    )
                } catch {
                    let duration = Date().timeIntervalSince(startTime)

                    return AnySendableRetryResult(
                        value: nil,
                        attempts: [],
                        totalDuration: duration,
                        succeeded: false,
                        finalError: error
                    )
                }
            },

            retryNetworkOperation: { operation in
                try await RetryClient.liveValue.withRetryPolicy(operation, .networkOperation)
            },

            retryCriticalOperation: { operation in
                try await RetryClient.liveValue.withRetryPolicy(operation, .criticalOperation)
            },

            retryBackgroundTask: { operation in
                try await RetryClient.liveValue.withRetryPolicy(operation, .backgroundTask)
            },

            retryIf: { operation, condition, maxAttempts, delay in
                let policy = RetryPolicy(
                    maxAttempts: maxAttempts,
                    strategy: .fixed(delay: delay),
                    shouldRetry: condition
                )
                return try await RetryClient.liveValue.withRetryPolicy(operation, policy)
            },

            withTimeout: { operation, timeout, policy in
                return try await withThrowingTaskGroup(of: SendableValue.self) { group in
                    // Add timeout task
                    group.addTask {
                        try await Task.sleep(for: .seconds(timeout))
                        throw RetryError.timeoutExceeded(duration: timeout)
                    }
                    
                    // Add operation task
                    group.addTask {
                        try await RetryClient.liveValue.withRetryPolicy(operation, policy)
                    }
                    
                    // Return first completed task result
                    let result = try await group.next()!
                    group.cancelAll()
                    return result
                }
            }
        )
    }()

    static let testValue = RetryClient(
        withRetry: { operation, _, _ in
            try await operation()
        },
        withRetryPolicy: { operation, _ in
            try await operation()
        },
        withRetryResult: { operation, _ in
            do {
                let result = try await operation()
                return AnySendableRetryResult(value: result, attempts: [], totalDuration: 0, succeeded: true, finalError: nil)
            } catch {
                return AnySendableRetryResult(value: nil, attempts: [], totalDuration: 0, succeeded: false, finalError: error)
            }
        },
        retryNetworkOperation: { operation in
            try await operation()
        },
        retryCriticalOperation: { operation in
            try await operation()
        },
        retryBackgroundTask: { operation in
            try await operation()
        },
        retryIf: { operation, _, _, _ in
            try await operation()
        },
        withTimeout: { operation, _, _ in
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

// MARK: - Duration Extension

extension Duration {
    var timeInterval: TimeInterval {
        return Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000.0
    }
}
