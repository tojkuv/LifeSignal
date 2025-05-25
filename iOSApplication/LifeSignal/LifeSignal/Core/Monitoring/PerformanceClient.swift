import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation

// MARK: - Performance Models

struct TraceID: Equatable, Sendable {
    let value: String
    let startTime: Date

    init(value: String) {
        self.value = value
        self.startTime = Date()
    }

    var age: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
}

struct PerformanceTrace: Sendable {
    let id: TraceID
    let name: String
    let startTime: Date
    let endTime: Date?
    let duration: TimeInterval?
    let metadata: [String: String]

    init(id: TraceID, name: String) {
        self.id = id
        self.name = name
        self.startTime = id.startTime
        self.endTime = nil
        self.duration = nil
        self.metadata = [:]
    }
}

struct PerformanceMetric: Sendable {
    let name: String
    let value: Double
    let unit: String
    let tags: [String: String]
    let timestamp: Date

    init(name: String, value: Double, unit: String = "", tags: [String: String] = [:]) {
        self.name = name
        self.value = value
        self.unit = unit
        self.tags = tags
        self.timestamp = Date()
    }
}

struct PerformanceStats: Sendable {
    let activeTraces: Int
    let completedTraces: Int
    let averageTraceDuration: TimeInterval
    let longestTrace: String?
    let longestTraceDuration: TimeInterval
    let metricsRecorded: Int
    let memoryUsage: Double // MB
    let cpuUsage: Double // Percentage
}

// MARK: - Performance Client (MVP Mock Implementation)

@DependencyClient
struct PerformanceClient {
    // Tracing
    var startTrace: @Sendable (String) async -> TraceID = { _ in TraceID(value: "mock-trace") }
    var startChildTrace: @Sendable (String, TraceID) async -> TraceID = { _, _ in TraceID(value: "mock-child-trace") }
    var endTrace: @Sendable (TraceID, [String: Any]) async -> Void = { _, _ in }
    var endTraceWithError: @Sendable (TraceID, Error, [String: Any]) async -> Void = { _, _, _ in }
    var setTraceAttribute: @Sendable (TraceID, String, String) async -> Void = { _, _, _ in }
    var addTraceEvent: @Sendable (TraceID, String, [String: Any]) async -> Void = { _, _, _ in }

    // Metrics
    var recordMetric: @Sendable (String, Double, [String: String]) async -> Void = { _, _, _ in }
    var recordCounter: @Sendable (String, Double, [String: String]) async -> Void = { _, _, _ in }
    var recordGauge: @Sendable (String, Double, [String: String]) async -> Void = { _, _, _ in }
    var recordHistogram: @Sendable (String, Double, [String: String]) async -> Void = { _, _, _ in }
    var recordTimer: @Sendable (String, TimeInterval, [String: String]) async -> Void = { _, _, _ in }
    var incrementCounter: @Sendable (String, [String: String]) async -> Void = { _, _ in }

    // System metrics
    var recordMemoryUsage: @Sendable () async -> Void = { }
    var recordCPUUsage: @Sendable () async -> Void = { }
    var recordNetworkLatency: @Sendable (String, TimeInterval) async -> Void = { _, _ in }
    var recordAppLaunchTime: @Sendable (TimeInterval) async -> Void = { _ in }

    // Performance monitoring
    var getStats: @Sendable () async -> PerformanceStats = {
        PerformanceStats(
            activeTraces: 0, completedTraces: 0, averageTraceDuration: 0,
            longestTrace: nil, longestTraceDuration: 0, metricsRecorded: 0,
            memoryUsage: 0, cpuUsage: 0
        )
    }
    var getActiveTraces: @Sendable () async -> [PerformanceTrace] = { [] }
    var getMetrics: @Sendable (String?) async -> [PerformanceMetric] = { _ in [] }
    var clearMetrics: @Sendable () async -> Void = { }

    // Convenience wrappers
    var measureTime: @Sendable (String, () async throws -> Void) async throws -> Void = { _, operation in try await operation() }
    var measureTimeWithResult: @Sendable (String, () async throws -> Any) async throws -> Any = { _, operation in try await operation() }
}

extension PerformanceClient: DependencyKey {
    static let liveValue = PerformanceClient.mockValue
    static let testValue = PerformanceClient.mockValue
    
    static let mockValue = PerformanceClient(
        startTrace: { name in
            let traceId = TraceID(value: "mock-\(name)-\(UUID().uuidString.prefix(8))")
            print("⏱️ [MOCK] Started trace: \(name) (\(traceId.value))")
            return traceId
        },

        startChildTrace: { name, parentId in
            let traceId = TraceID(value: "mock-child-\(name)-\(UUID().uuidString.prefix(8))")
            print("⏱️ [MOCK] Started child trace: \(name) (parent: \(parentId.value))")
            return traceId
        },

        endTrace: { traceId, metadata in
            let duration = traceId.age
            print("⏱️ [MOCK] Ended trace: \(traceId.value) (\(String(format: "%.2f", duration * 1000))ms)")
            if !metadata.isEmpty {
                print("   Metadata: \(metadata)")
            }
        },

        endTraceWithError: { traceId, error, metadata in
            let duration = traceId.age
            print("❌ [MOCK] Failed trace: \(traceId.value) (\(String(format: "%.2f", duration * 1000))ms)")
            print("   Error: \(error.localizedDescription)")
            if !metadata.isEmpty {
                print("   Metadata: \(metadata)")
            }
        },

        setTraceAttribute: { traceId, key, value in
            print("🏷️ [MOCK] Trace attribute: \(traceId.value) - \(key): \(value)")
        },

        addTraceEvent: { traceId, name, attributes in
            print("📝 [MOCK] Trace event: \(traceId.value) - \(name)")
            if !attributes.isEmpty {
                print("   Attributes: \(attributes)")
            }
        },

        recordMetric: { name, value, tags in
            print("📈 [MOCK] Metric '\(name)': \(value)")
            if !tags.isEmpty {
                print("   Tags: \(tags)")
            }
        },

        recordCounter: { name, value, tags in
            print("🔢 [MOCK] Counter '\(name)': +\(value)")
            if !tags.isEmpty {
                print("   Tags: \(tags)")
            }
        },

        recordGauge: { name, value, tags in
            print("📊 [MOCK] Gauge '\(name)': \(value)")
            if !tags.isEmpty {
                print("   Tags: \(tags)")
            }
        },

        recordHistogram: { name, value, tags in
            print("📈 [MOCK] Histogram '\(name)': \(value)")
            if !tags.isEmpty {
                print("   Tags: \(tags)")
            }
        },

        recordTimer: { name, duration, tags in
            print("⏱️ [MOCK] Timer '\(name)': \(String(format: "%.2f", duration * 1000))ms")
            if !tags.isEmpty {
                print("   Tags: \(tags)")
            }
        },

        incrementCounter: { name, tags in
            print("➕ [MOCK] Counter '\(name)': +1")
            if !tags.isEmpty {
                print("   Tags: \(tags)")
            }
        },

        recordMemoryUsage: {
            print("💾 [MOCK] Memory usage recorded")
        },

        recordCPUUsage: {
            print("🖥️ [MOCK] CPU usage recorded")
        },

        recordNetworkLatency: { endpoint, latency in
            print("🌐 [MOCK] Network latency '\(endpoint)': \(String(format: "%.2f", latency * 1000))ms")
        },

        recordAppLaunchTime: { duration in
            print("🚀 [MOCK] App launch time: \(String(format: "%.2f", duration * 1000))ms")
        },

        getStats: {
            PerformanceStats(
                activeTraces: 0, completedTraces: 0, averageTraceDuration: 0,
                longestTrace: nil, longestTraceDuration: 0, metricsRecorded: 0,
                memoryUsage: 0, cpuUsage: 0
            )
        },

        getActiveTraces: {
            []
        },

        getMetrics: { _ in
            []
        },

        clearMetrics: {
            print("🧹 [MOCK] Performance metrics cleared")
        },

        measureTime: { name, operation in
            let startTime = Date()
            print("⏱️ [MOCK] Starting measurement: \(name)")
            
            do {
                try await operation()
                let duration = Date().timeIntervalSince(startTime)
                print("⏱️ [MOCK] Completed measurement: \(name) (\(String(format: "%.2f", duration * 1000))ms)")
            } catch {
                let duration = Date().timeIntervalSince(startTime)
                print("❌ [MOCK] Failed measurement: \(name) (\(String(format: "%.2f", duration * 1000))ms)")
                print("   Error: \(error.localizedDescription)")
                throw error
            }
        },

        measureTimeWithResult: { name, operation in
            let startTime = Date()
            print("⏱️ [MOCK] Starting measurement: \(name)")
            
            do {
                let result = try await operation()
                let duration = Date().timeIntervalSince(startTime)
                print("⏱️ [MOCK] Completed measurement: \(name) (\(String(format: "%.2f", duration * 1000))ms)")
                return result
            } catch {
                let duration = Date().timeIntervalSince(startTime)
                print("❌ [MOCK] Failed measurement: \(name) (\(String(format: "%.2f", duration * 1000))ms)")
                print("   Error: \(error.localizedDescription)")
                throw error
            }
        }
    )
}

// MARK: - Convenience Extensions

extension PerformanceClient {
    /// Measure execution time of an operation
    func measure<T>(
        _ operationName: String,
        tags: [String: String] = [:],
        operation: () async throws -> T
    ) async throws -> T {
        let traceId = await startTrace(operationName)
        let startTime = Date()

        do {
            let result = try await operation()
            let duration = Date().timeIntervalSince(startTime)

            var metadata = tags.mapValues { $0 as Any }
            metadata["success"] = true
            metadata["duration_ms"] = duration * 1000

            await endTrace(traceId, metadata)
            await recordTimer(operationName, duration, tags)

            return result
        } catch {
            let duration = Date().timeIntervalSince(startTime)

            var metadata = tags.mapValues { $0 as Any }
            metadata["success"] = false
            metadata["error"] = error.localizedDescription
            metadata["duration_ms"] = duration * 1000

            await endTraceWithError(traceId, error, metadata)
            await recordTimer("\(operationName)_error", duration, tags)

            throw error
        }
    }

    /// Record a custom event with timing
    func recordEvent(_ eventName: String, duration: TimeInterval? = nil, tags: [String: String] = [:]) async {
        await incrementCounter(eventName, tags)

        if let duration = duration {
            await recordTimer(eventName, duration, tags)
        }
    }

    /// Record screen load time
    func recordScreenLoad(_ screenName: String, duration: TimeInterval) async {
        let tags = ["screen": screenName]
        await recordTimer("screen_load_time", duration, tags)
        await recordHistogram("screen_performance", duration * 1000, tags) // Convert to ms
    }

    /// Record API call performance
    func recordAPICall(_ endpoint: String, duration: TimeInterval, statusCode: Int?, error: Error? = nil) async {
        var tags = ["endpoint": endpoint]

        if let statusCode = statusCode {
            tags["status_code"] = "\(statusCode)"
            tags["success"] = statusCode < 400 ? "true" : "false"
        }

        if let error = error {
            tags["error"] = error.localizedDescription
            tags["success"] = "false"
        }

        await recordTimer("api_call_duration", duration, tags)
        await incrementCounter("api_calls_total", tags)

        if error != nil {
            await incrementCounter("api_errors_total", tags)
        }
    }

    /// Record database operation performance
    func recordDatabaseOperation(_ operation: String, table: String, duration: TimeInterval, recordCount: Int? = nil) async {
        var tags = ["operation": operation, "table": table]
        if let count = recordCount {
            tags["record_count"] = "\(count)"
        }

        await recordTimer("db_operation_duration", duration, tags)
        await incrementCounter("db_operations_total", tags)

        if let count = recordCount {
            await recordHistogram("db_record_count", Double(count), tags)
        }
    }
}

extension DependencyValues {
    var performance: PerformanceClient {
        get { self[PerformanceClient.self] }
        set { self[PerformanceClient.self] = newValue }
    }
}