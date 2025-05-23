import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation

struct TraceID: Equatable {
    let value: String
}

@DependencyClient
struct PerformanceClient {
    var startTrace: @Sendable (String) -> TraceID = { _ in TraceID(value: "") }
    var endTrace: @Sendable (TraceID, [String: Any]) -> Void = { _, _ in }
    var recordMetric: @Sendable (String, Double, [String: String]) -> Void = { _, _, _ in }
}

extension PerformanceClient: DependencyKey {
    static let liveValue = PerformanceClient(
        startTrace: { name in
            TraceID(value: "\(name)-\(UUID().uuidString.prefix(8))")
        },
        endTrace: { traceID, metadata in
            print("⏱️ Trace \(traceID.value) completed: \(metadata)")
        },
        recordMetric: { name, value, tags in
            print("📈 Metric \(name): \(value) \(tags)")
        }
    )
    
    static let testValue = PerformanceClient(
        startTrace: { _ in TraceID(value: "test") },
        endTrace: { _, _ in },
        recordMetric: { _, _, _ in }
    )
}

extension DependencyValues {
    var performance: PerformanceClient {
        get { self[PerformanceClient.self] }
        set { self[PerformanceClient.self] = newValue }
    }
}