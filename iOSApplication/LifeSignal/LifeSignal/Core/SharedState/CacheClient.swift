import ComposableArchitecture
import Dependencies
import Foundation

struct CacheClient {
    var get: @Sendable (String, Any.Type) async -> Any? = { _, _ in nil }
    var set: @Sendable (String, Any) async -> Void = { _, _ in }
    var remove: @Sendable (String) async -> Void = { _ in }
    var clear: @Sendable () async -> Void = { }
    var contains: @Sendable (String) async -> Bool = { _ in false }
    var getAllKeys: @Sendable () async -> [String] = { [] }
    var size: @Sendable () async -> Int = { 0 }
    var memoryPressure: @Sendable () async -> Void = { }
}

extension CacheClient: DependencyKey {
    static let liveValue = CacheClient()
    static let mockValue = CacheClient()
    static let testValue = CacheClient()
}

extension DependencyValues {
    var cache: CacheClient {
        get { self[CacheClient.self] }
        set { self[CacheClient.self] = newValue }
    }
}