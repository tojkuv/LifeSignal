import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation

struct CacheKey: Hashable {
    let namespace: String
    let identifier: String
}

struct CachePattern {
    let namespace: String
    let prefix: String?
}

struct TTL {
    let seconds: TimeInterval
}

@DependencyClient
struct CacheClient {
    var get: @Sendable (CacheKey, Any.Type) async -> Any? = { _, _ in nil }
    var set: @Sendable (CacheKey, Any, TTL?) async -> Void = { _, _, _ in }
    var invalidate: @Sendable (CachePattern) async -> Void = { _ in }
}

extension CacheClient: DependencyKey {
    static let liveValue = CacheClient(
        get: { key, type in
            // Mock implementation
            nil
        },
        set: { key, value, ttl in
            print("💾 Cache SET: \(key) = \(value)")
        },
        invalidate: { pattern in
            print("🗑️ Cache INVALIDATE: \(pattern.namespace)/\(pattern.prefix ?? "*")")
        }
    )
    
    static let testValue = CacheClient()
}

extension DependencyValues {
    var cache: CacheClient {
        get { self[CacheClient.self] }
        set { self[CacheClient.self] = newValue }
    }
}