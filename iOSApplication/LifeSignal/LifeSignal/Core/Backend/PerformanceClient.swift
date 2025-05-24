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
    let metadata: [String: Any]
    let childTraces: [String]
    let parentTrace: String?

    init(id: TraceID, name: String, parentTrace: String? = nil) {
        self.id = id
        self.name = name
        self.startTime = id.startTime
        self.endTime = nil
        self.duration = nil
        self.metadata = [:]
        self.childTraces = []
        self.parentTrace = parentTrace
    }

    func completed(at endTime: Date, metadata: [String: Any] = [:]) -> PerformanceTrace {
        PerformanceTrace(
            id: id,
            name: name,
            startTime: startTime,
            endTime: endTime,
            duration: endTime.timeIntervalSince(startTime),
            metadata: metadata,
            childTraces: childTraces,
            parentTrace: parentTrace
        )
    }

    var isCompleted: Bool {
        endTime != nil
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

enum MetricType: String, CaseIterable, Sendable {
    case counter = "counter"
    case gauge = "gauge"
    case histogram = "histogram"
    case timer = "timer"
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

// MARK: - Performance Client

@DependencyClient
struct PerformanceClient {
    // Tracing
    var startTrace: @Sendable (String) -> TraceID = { _ in TraceID(value: "") }
    var startChildTrace: @Sendable (String, TraceID) -> TraceID = { _, _ in TraceID(value: "") }
    var endTrace: @Sendable (TraceID, [String: Any]) -> Void = { _, _ in }
    var endTraceWithError: @Sendable (TraceID, Error, [String: Any]) -> Void = { _, _, _ in }
    var setTraceAttribute: @Sendable (TraceID, String, String) -> Void = { _, _, _ in }
    var addTraceEvent: @Sendable (TraceID, String, [String: Any]) -> Void = { _, _, _ in }

    // Metrics
    var recordMetric: @Sendable (String, Double, [String: String]) -> Void = { _, _, _ in }
    var recordCounter: @Sendable (String, Double, [String: String]) -> Void = { _, _, _ in }
    var recordGauge: @Sendable (String, Double, [String: String]) -> Void = { _, _, _ in }
    var recordHistogram: @Sendable (String, Double, [String: String]) -> Void = { _, _, _ in }
    var recordTimer: @Sendable (String, TimeInterval, [String: String]) -> Void = { _, _, _ in }
    var incrementCounter: @Sendable (String, [String: String]) -> Void = { _, _ in }

    // System metrics
    var recordMemoryUsage: @Sendable () -> Void = { }
    var recordCPUUsage: @Sendable () -> Void = { }
    var recordNetworkLatency: @Sendable (String, TimeInterval) -> Void = { _, _ in }
    var recordAppLaunchTime: @Sendable (TimeInterval) -> Void = { _ in }

    // Performance monitoring
    var getStats: @Sendable () -> PerformanceStats = {
        PerformanceStats(
            activeTraces: 0, completedTraces: 0, averageTraceDuration: 0,
            longestTrace: nil, longestTraceDuration: 0, metricsRecorded: 0,
            memoryUsage: 0, cpuUsage: 0
        )
    }
    var getActiveTraces: @Sendable () -> [PerformanceTrace] = { [] }
    var getMetrics: @Sendable (String?) -> [PerformanceMetric] = { _ in [] }
    var clearMetrics: @Sendable () -> Void = { }

    // Convenience wrappers
    var measureTime: @Sendable (String, () async throws -> Void) async throws -> Void = { _, operation in try await operation() }
    var measureTimeWithResult: @Sendable (String, () async throws -> Any) async throws -> Any = { _, operation in try await operation() }
}

// MARK: - Convenience Extensions

extension PerformanceClient {
    /// Measure execution time of an operation
    func measure<T>(
        _ operationName: String,
        tags: [String: String] = [:],
        operation: () async throws -> T
    ) async throws -> T {
        let traceId = startTrace(operationName)
        let startTime = Date()

        do {
            let result = try await operation()
            let duration = Date().timeIntervalSince(startTime)

            var metadata = tags.mapValues { $0 as Any }
            metadata["success"] = true
            metadata["duration_ms"] = duration * 1000

            endTrace(traceId, metadata)
            recordTimer(operationName, duration, tags)

            return result
        } catch {
            let duration = Date().timeIntervalSince(startTime)

            var metadata = tags.mapValues { $0 as Any }
            metadata["success"] = false
            metadata["error"] = error.localizedDescription
            metadata["duration_ms"] = duration * 1000

            endTraceWithError(traceId, error, metadata)
            recordTimer("\(operationName)_error", duration, tags)

            throw error
        }
    }

    /// Record a custom event with timing
    func recordEvent(_ eventName: String, duration: TimeInterval? = nil, tags: [String: String] = [:]) {
        incrementCounter(eventName, tags)

        if let duration = duration {
            recordTimer(eventName, duration, tags)
        }
    }

    /// Record screen load time
    func recordScreenLoad(_ screenName: String, duration: TimeInterval) {
        let tags = ["screen": screenName]
        recordTimer("screen_load_time", duration, tags)
        recordHistogram("screen_performance", duration * 1000, tags) // Convert to ms
    }

    /// Record API call performance
    func recordAPICall(_ endpoint: String, duration: TimeInterval, statusCode: Int?, error: Error? = nil) {
        var tags = ["endpoint": endpoint]

        if let statusCode = statusCode {
            tags["status_code"] = "\(statusCode)"
            tags["success"] = statusCode < 400 ? "true" : "false"
        }

        if let error = error {
            tags["error"] = error.localizedDescription
            tags["success"] = "false"
        }

        recordTimer("api_call_duration", duration, tags)
        incrementCounter("api_calls_total", tags)

        if error != nil {
            incrementCounter("api_errors_total", tags)
        }
    }

    /// Record database operation performance
    func recordDatabaseOperation(_ operation: String, table: String, duration: TimeInterval, recordCount: Int? = nil) {
        var tags = ["operation": operation, "table": table]
        if let count = recordCount {
            tags["record_count"] = "\(count)"
        }

        recordTimer("db_operation_duration", duration, tags)
        incrementCounter("db_operations_total", tags)

        if let count = recordCount {
            recordHistogram("db_record_count", Double(count), tags)
        }
    }
}

// MARK: - Live Implementation

extension PerformanceClient: DependencyKey {
    static let liveValue: PerformanceClient = {
        actor PerformanceStorage {
            private var activeTraces: [String: PerformanceTrace] = [:]
            private var completedTraces: [PerformanceTrace] = []
            private var metrics: [PerformanceMetric] = []
            private var traceCounter = 0

            func startTrace(_ name: String, parentId: String? = nil) -> TraceID {
                traceCounter += 1
                let traceId = TraceID(value: "\(name)-\(traceCounter)-\(UUID().uuidString.prefix(8))")
                let trace = PerformanceTrace(id: traceId, name: name, parentTrace: parentId)
                activeTraces[traceId.value] = trace
                return traceId
            }

            func endTrace(_ traceId: TraceID, metadata: [String: Any]) {
                guard let trace = activeTraces.removeValue(forKey: traceId.value) else { return }
                let completedTrace = trace.completed(at: Date(), metadata: metadata)
                completedTraces.append(completedTrace)

                // Keep only last 1000 completed traces to prevent memory bloat
                if completedTraces.count > 1000 {
                    completedTraces.removeFirst(completedTraces.count - 1000)
                }
            }

            func setTraceAttribute(_ traceId: TraceID, key: String, value: String) {
                // In production, this would add attributes to the trace
            }

            func addTraceEvent(_ traceId: TraceID, name: String, attributes: [String: Any]) {
                // In production, this would add events to the trace timeline
            }

            func recordMetric(_ metric: PerformanceMetric) {
                metrics.append(metric)

                // Keep only last 10000 metrics to prevent memory bloat
                if metrics.count > 10000 {
                    metrics.removeFirst(metrics.count - 10000)
                }
            }

            func getStats() -> PerformanceStats {
                let avgDuration = completedTraces.isEmpty ? 0 :
                    completedTraces.compactMap { $0.duration }.reduce(0, +) / Double(completedTraces.count)

                let longestTrace = completedTraces.max {
                    ($0.duration ?? 0) < ($1.duration ?? 0)
                }

                return PerformanceStats(
                    activeTraces: activeTraces.count,
                    completedTraces: completedTraces.count,
                    averageTraceDuration: avgDuration,
                    longestTrace: longestTrace?.name,
                    longestTraceDuration: longestTrace?.duration ?? 0,
                    metricsRecorded: metrics.count,
                    memoryUsage: getCurrentMemoryUsage(),
                    cpuUsage: getCurrentCPUUsage()
                )
            }

            func getActiveTraces() -> [PerformanceTrace] {
                Array(activeTraces.values)
            }

            func getMetrics(filter: String?) -> [PerformanceMetric] {
                if let filter = filter {
                    return metrics.filter { $0.name.contains(filter) }
                }
                return metrics
            }

            func clearMetrics() {
                metrics.removeAll()
            }

            private func getCurrentMemoryUsage() -> Double {
                let info = mach_task_basic_info()
                var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

                let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
                    }
                }

                if kerr == KERN_SUCCESS {
                    return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
                }
                return 0.0
            }

            private func getCurrentCPUUsage() -> Double {
                var info = task_basic_info()
                var count = mach_msg_type_number_t(MemoryLayout<task_basic_info>.size)/4

                let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        task_info(mach_task_self_, task_flavor_t(TASK_BASIC_INFO), $0, &count)
                    }
                }

                if kerr == KERN_SUCCESS {
                    return Double(info.user_time.seconds + info.system_time.seconds)
                }
                return 0.0
            }
        }

        let storage = PerformanceStorage()

        return PerformanceClient(
            startTrace: { name in
                await storage.startTrace(name)
            },

            startChildTrace: { name, parentId in
                await storage.startTrace(name, parentId: parentId.value)
            },

            endTrace: { traceId, metadata in
                await storage.endTrace(traceId, metadata: metadata)
                let duration = traceId.age
                print("⏱️ Trace '\(traceId.value)' completed in \(String(format: "%.2f", duration * 1000))ms")
                if !metadata.isEmpty {
                    print("   Metadata: \(metadata)")
                }
            },

            endTraceWithError: { traceId, error, metadata in
                var errorMetadata = metadata
                errorMetadata["error"] = error.localizedDescription
                errorMetadata["success"] = false
                await storage.endTrace(traceId, metadata: errorMetadata)
                print("❌ Trace '\(traceId.value)' failed: \(error.localizedDescription)")
            },

            setTraceAttribute: { traceId, key, value in
                await storage.setTraceAttribute(traceId, key: key, value: value)
            },

            addTraceEvent: { traceId, name, attributes in
                await storage.addTraceEvent(traceId, name: name, attributes: attributes)
            },

            recordMetric: { name, value, tags in
                let metric = PerformanceMetric(name: name, value: value, tags: tags)
                await storage.recordMetric(metric)
                print("📈 Metric '\(name)': \(value) \(tags.isEmpty ? "" : "\(tags)")")
            },

            recordCounter: { name, value, tags in
                let metric = PerformanceMetric(name: name, value: value, unit: "count", tags: tags)
                await storage.recordMetric(metric)
                print("🔢 Counter '\(name)': +\(value)")
            },

            recordGauge: { name, value, tags in
                let metric = PerformanceMetric(name: name, value: value, unit: "gauge", tags: tags)
                await storage.recordMetric(metric)
                print("📊 Gauge '\(name)': \(value)")
            },

            recordHistogram: { name, value, tags in
                let metric = PerformanceMetric(name: name, value: value, unit: "histogram", tags: tags)
                await storage.recordMetric(metric)
                print("📈 Histogram '\(name)': \(value)")
            },

            recordTimer: { name, duration, tags in
                let metric = PerformanceMetric(name: name, value: duration * 1000, unit: "ms", tags: tags)
                await storage.recordMetric(metric)
                print("⏱️ Timer '\(name)': \(String(format: "%.2f", duration * 1000))ms")
            },

            incrementCounter: { name, tags in
                let metric = PerformanceMetric(name: name, value: 1, unit: "count", tags: tags)
                await storage.recordMetric(metric)
                print("➕ Counter '\(name)': +1")
            },

            recordMemoryUsage: {
                let stats = await storage.getStats()
                let metric = PerformanceMetric(name: "memory_usage", value: stats.memoryUsage, unit: "MB")
                await storage.recordMetric(metric)
            },

            recordCPUUsage: {
                let stats = await storage.getStats()
                let metric = PerformanceMetric(name: "cpu_usage", value: stats.cpuUsage, unit: "percent")
                await storage.recordMetric(metric)
            },

            recordNetworkLatency: { endpoint, latency in
                let tags = ["endpoint": endpoint]
                let metric = PerformanceMetric(name: "network_latency", value: latency * 1000, unit: "ms", tags: tags)
                await storage.recordMetric(metric)
                print("🌐 Network latency '\(endpoint)': \(String(format: "%.2f", latency * 1000))ms")
            },

            recordAppLaunchTime: { duration in
                let metric = PerformanceMetric(name: "app_launch_time", value: duration * 1000, unit: "ms")
                await storage.recordMetric(metric)
                print("🚀 App launch time: \(String(format: "%.2f", duration * 1000))ms")
            },

            getStats: {
                await storage.getStats()
            },

            getActiveTraces: {
                await storage.getActiveTraces()
            },

            getMetrics: { filter in
                await storage.getMetrics(filter: filter)
            },

            clearMetrics: {
                await storage.clearMetrics()
                print("🧹 Performance metrics cleared")
            },

            measureTime: { name, operation in
                let traceId = await storage.startTrace(name)
                let startTime = Date()

                do {
                    try await operation()
                    let duration = Date().timeIntervalSince(startTime)
                    await storage.endTrace(traceId, metadata: ["duration_ms": duration * 1000, "success": true])
                } catch {
                    let duration = Date().timeIntervalSince(startTime)
                    await storage.endTrace(traceId, metadata: ["duration_ms": duration * 1000, "success": false, "error": error.localizedDescription])
                    throw error
                }
            },

            measureTimeWithResult: { name, operation in
                let traceId = await storage.startTrace(name)
                let startTime = Date()

                do {
                    let result = try await operation()
                    let duration = Date().timeIntervalSince(startTime)
                    await storage.endTrace(traceId, metadata: ["duration_ms": duration * 1000, "success": true])
                    return result
                } catch {
                    let duration = Date().timeIntervalSince(startTime)
                    await storage.endTrace(traceId, metadata: ["duration_ms": duration * 1000, "success": false, "error": error.localizedDescription])
                    throw error
                }
            }
        )
    }()

    static let testValue = PerformanceClient(
        startTrace: { _ in TraceID(value: "test-trace") },
        startChildTrace: { _, _ in TraceID(value: "test-child-trace") },
        endTrace: { _, _ in },
        endTraceWithError: { _, _, _ in },
        setTraceAttribute: { _, _, _ in },
        addTraceEvent: { _, _, _ in },
        recordMetric: { _, _, _ in },
        recordCounter: { _, _, _ in },
        recordGauge: { _, _, _ in },
        recordHistogram: { _, _, _ in },
        recordTimer: { _, _, _ in },
        incrementCounter: { _, _ in },
        recordMemoryUsage: { },
        recordCPUUsage: { },
        recordNetworkLatency: { _, _ in },
        recordAppLaunchTime: { _ in },
        getStats: {
            PerformanceStats(
                activeTraces: 0, completedTraces: 0, averageTraceDuration: 0,
                longestTrace: nil, longestTraceDuration: 0, metricsRecorded: 0,
                memoryUsage: 0, cpuUsage: 0
            )
        },
        getActiveTraces: { [] },
        getMetrics: { _ in [] },
        clearMetrics: { },
        measureTime: { _, operation in try await operation() },
        measureTimeWithResult: { _, operation in try await operation() }
    )
}

extension DependencyValues {
    var performance: PerformanceClient {
        get { self[PerformanceClient.self] }
        set { self[PerformanceClient.self] = newValue }
    }
}