import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation

// MARK: - Cache Models

struct CacheKey: Hashable, Sendable {
    let namespace: String
    let identifier: String

    init(namespace: String, identifier: String) {
        self.namespace = namespace
        self.identifier = identifier
    }

    /// Create a cache key with automatic identifier conversion
    init<T>(namespace: String, identifier: T) {
        self.namespace = namespace
        self.identifier = String(describing: identifier)
    }

    /// Full key string for storage
    var fullKey: String {
        return "\(namespace):\(identifier)"
    }
}

struct CachePattern: Sendable {
    let namespace: String
    let prefix: String?

    init(namespace: String, prefix: String? = nil) {
        self.namespace = namespace
        self.prefix = prefix
    }

    /// Pattern string for matching
    var patternString: String {
        if let prefix = prefix {
            return "\(namespace):\(prefix)*"
        } else {
            return "\(namespace):*"
        }
    }
}

struct TTL: Sendable {
    let seconds: TimeInterval

    init(seconds: TimeInterval) {
        self.seconds = seconds
    }

    init(minutes: TimeInterval) {
        self.seconds = minutes * 60
    }

    init(hours: TimeInterval) {
        self.seconds = hours * 3600
    }

    init(days: TimeInterval) {
        self.seconds = days * 86400
    }

    /// Default TTL values
    static let short = TTL(minutes: 5)
    static let medium = TTL(minutes: 30)
    static let long = TTL(hours: 24)
    static let persistent = TTL(days: 7)

    /// Expiration date from now
    var expirationDate: Date {
        return Date().addingTimeInterval(seconds)
    }
}

// MARK: - Cache Entry

private struct CacheEntry: Codable {
    let data: Data
    let expirationDate: Date?
    let createdAt: Date

    init(data: Data, ttl: TTL?) {
        self.data = data
        self.expirationDate = ttl?.expirationDate
        self.createdAt = Date()
    }

    var isExpired: Bool {
        guard let expirationDate = expirationDate else { return false }
        return Date() > expirationDate
    }

    var age: TimeInterval {
        return Date().timeIntervalSince(createdAt)
    }
}

// MARK: - Cache Statistics

struct CacheStats: Sendable {
    let hits: Int
    let misses: Int
    let sets: Int
    let invalidations: Int
    let totalEntries: Int
    let totalSizeBytes: Int

    var hitRate: Double {
        let total = hits + misses
        return total > 0 ? Double(hits) / Double(total) : 0.0
    }
}

// MARK: - Cache Client

@DependencyClient
struct CacheClient {
    // Core operations
    var get: @Sendable (CacheKey, Any.Type) async -> Any? = { _, _ in nil }
    var set: @Sendable (CacheKey, Any, TTL?) async -> Void = { _, _, _ in }
    var remove: @Sendable (CacheKey) async -> Void = { _ in }
    var invalidate: @Sendable (CachePattern) async -> Void = { _ in }
    var clear: @Sendable () async -> Void = { }

    // Batch operations
    var getBatch: @Sendable ([CacheKey]) async -> [CacheKey: Any] = { _ in [:] }
    var setBatch: @Sendable ([(CacheKey, Any, TTL?)]) async -> Void = { _ in }
    var removeBatch: @Sendable ([CacheKey]) async -> Void = { _ in }

    // Utility operations
    var exists: @Sendable (CacheKey) async -> Bool = { _ in false }
    var getStats: @Sendable () async -> CacheStats = {
        CacheStats(hits: 0, misses: 0, sets: 0, invalidations: 0, totalEntries: 0, totalSizeBytes: 0)
    }
    var getSize: @Sendable () async -> Int = { 0 }
    var getAllKeys: @Sendable (String?) async -> [CacheKey] = { _ in [] }

    // Expiration management
    var cleanupExpired: @Sendable () async -> Int = { 0 }
    var setTTL: @Sendable (CacheKey, TTL) async -> Bool = { _, _ in false }
    var getTTL: @Sendable (CacheKey) async -> TimeInterval? = { _ in nil }
}

// MARK: - Type-Safe Extensions

extension CacheClient {
    /// Type-safe get operation
    func get<T: Codable>(_ key: CacheKey, as type: T.Type) async -> T? {
        return await get(key, type) as? T
    }

    /// Type-safe set operation
    func set<T: Codable>(_ key: CacheKey, value: T, ttl: TTL? = nil) async {
        await set(key, value, ttl)
    }

    /// Get or set pattern - returns cached value or computes and caches new value
    func getOrSet<T: Codable>(
        _ key: CacheKey,
        ttl: TTL? = nil,
        compute: () async throws -> T
    ) async throws -> T {
        if let cached: T = await get(key, as: T.self) {
            return cached
        }

        let computed = try await compute()
        await set(key, value: computed, ttl: ttl)
        return computed
    }

    /// Memoize a function with caching
    func memoize<Input: Hashable & Sendable, Output: Codable>(
        namespace: String,
        ttl: TTL? = nil,
        function: @escaping (Input) async throws -> Output
    ) -> (Input) async throws -> Output {
        return { input in
            let key = CacheKey(namespace: namespace, identifier: input)
            return try await self.getOrSet(key, ttl: ttl) {
                try await function(input)
            }
        }
    }
}

// MARK: - Live Implementation

extension CacheClient: DependencyKey {
    static let liveValue: CacheClient = {
        actor CacheStorage {
            private var storage: [String: CacheEntry] = [:]
            private var stats = CacheStats(hits: 0, misses: 0, sets: 0, invalidations: 0, totalEntries: 0, totalSizeBytes: 0)

            func get(key: CacheKey) -> Data? {
                let fullKey = key.fullKey
                guard let entry = storage[fullKey] else {
                    updateStats(misses: 1)
                    return nil
                }

                if entry.isExpired {
                    storage.removeValue(forKey: fullKey)
                    updateStats(misses: 1)
                    return nil
                }

                updateStats(hits: 1)
                return entry.data
            }

            func set(key: CacheKey, data: Data, ttl: TTL?) {
                let entry = CacheEntry(data: data, ttl: ttl)
                storage[key.fullKey] = entry
                updateStats(sets: 1, totalEntries: storage.count, totalSizeBytes: calculateTotalSize())
            }

            func remove(key: CacheKey) {
                storage.removeValue(forKey: key.fullKey)
                updateStats(totalEntries: storage.count, totalSizeBytes: calculateTotalSize())
            }

            func invalidate(pattern: CachePattern) {
                let patternString = pattern.patternString.replacingOccurrences(of: "*", with: "")
                let keysToRemove = storage.keys.filter { $0.hasPrefix(patternString) }

                for key in keysToRemove {
                    storage.removeValue(forKey: key)
                }

                updateStats(invalidations: 1, totalEntries: storage.count, totalSizeBytes: calculateTotalSize())
            }

            func clear() {
                storage.removeAll()
                updateStats(totalEntries: 0, totalSizeBytes: 0)
            }

            func exists(key: CacheKey) -> Bool {
                guard let entry = storage[key.fullKey] else { return false }
                if entry.isExpired {
                    storage.removeValue(forKey: key.fullKey)
                    return false
                }
                return true
            }

            func getStats() -> CacheStats {
                return stats
            }

            func getAllKeys(namespace: String?) -> [CacheKey] {
                let keys = storage.keys.compactMap { fullKey -> CacheKey? in
                    let components = fullKey.split(separator: ":", maxSplits: 1)
                    guard components.count == 2 else { return nil }

                    let keyNamespace = String(components[0])
                    let identifier = String(components[1])

                    if let namespace = namespace {
                        return keyNamespace == namespace ? CacheKey(namespace: keyNamespace, identifier: identifier) : nil
                    } else {
                        return CacheKey(namespace: keyNamespace, identifier: identifier)
                    }
                }
                return keys
            }

            func cleanupExpired() -> Int {
                let expiredKeys = storage.compactMap { (key, entry) in
                    entry.isExpired ? key : nil
                }

                for key in expiredKeys {
                    storage.removeValue(forKey: key)
                }

                updateStats(totalEntries: storage.count, totalSizeBytes: calculateTotalSize())
                return expiredKeys.count
            }

            func setTTL(key: CacheKey, ttl: TTL) -> Bool {
                guard var entry = storage[key.fullKey] else { return false }
                let newEntry = CacheEntry(data: entry.data, ttl: ttl)
                storage[key.fullKey] = newEntry
                return true
            }

            func getTTL(key: CacheKey) -> TimeInterval? {
                guard let entry = storage[key.fullKey],
                      let expirationDate = entry.expirationDate else { return nil }
                let remaining = expirationDate.timeIntervalSince(Date())
                return remaining > 0 ? remaining : nil
            }

            private func calculateTotalSize() -> Int {
                return storage.values.reduce(0) { $0 + $1.data.count }
            }

            private func updateStats(
                hits: Int = 0,
                misses: Int = 0,
                sets: Int = 0,
                invalidations: Int = 0,
                totalEntries: Int? = nil,
                totalSizeBytes: Int? = nil
            ) {
                stats = CacheStats(
                    hits: stats.hits + hits,
                    misses: stats.misses + misses,
                    sets: stats.sets + sets,
                    invalidations: stats.invalidations + invalidations,
                    totalEntries: totalEntries ?? stats.totalEntries,
                    totalSizeBytes: totalSizeBytes ?? stats.totalSizeBytes
                )
            }
        }

        let storage = CacheStorage()

        return CacheClient(
            get: { key, type in
                guard let data = await storage.get(key: key) else { return nil }

                do {
                    if type == Data.self {
                        return data
                    } else if type == String.self {
                        return String(data: data, encoding: .utf8)
                    } else if let codableType = type as? any Codable.Type {
                        return try JSONDecoder().decode(codableType, from: data)
                    }
                    return nil
                } catch {
                    print("⚠️ Cache decode error for key \(key.fullKey): \(error)")
                    return nil
                }
            },

            set: { key, value, ttl in
                do {
                    let data: Data
                    if let dataValue = value as? Data {
                        data = dataValue
                    } else if let stringValue = value as? String {
                        data = stringValue.data(using: .utf8) ?? Data()
                    } else if let codableValue = value as? any Codable {
                        data = try JSONEncoder().encode(codableValue)
                    } else {
                        print("⚠️ Cache: Cannot encode value of type \(type(of: value))")
                        return
                    }

                    await storage.set(key: key, data: data, ttl: ttl)
                    print("💾 Cache SET: \(key.fullKey) (TTL: \(ttl?.seconds ?? 0)s)")
                } catch {
                    print("⚠️ Cache encode error for key \(key.fullKey): \(error)")
                }
            },

            remove: { key in
                await storage.remove(key: key)
                print("🗑️ Cache REMOVE: \(key.fullKey)")
            },

            invalidate: { pattern in
                await storage.invalidate(pattern: pattern)
                print("🗑️ Cache INVALIDATE: \(pattern.patternString)")
            },

            clear: {
                await storage.clear()
                print("🧹 Cache CLEAR: All entries removed")
            },

            getBatch: { keys in
                var results: [CacheKey: Any] = [:]
                for key in keys {
                    if let value = await storage.get(key: key) {
                        results[key] = value
                    }
                }
                return results
            },

            setBatch: { items in
                for (key, value, ttl) in items {
                    // Reuse the main set implementation
                    await CacheClient.liveValue.set(key, value, ttl)
                }
            },

            removeBatch: { keys in
                for key in keys {
                    await storage.remove(key: key)
                }
            },

            exists: { key in
                await storage.exists(key: key)
            },

            getStats: {
                await storage.getStats()
            },

            getSize: {
                let stats = await storage.getStats()
                return stats.totalSizeBytes
            },

            getAllKeys: { namespace in
                await storage.getAllKeys(namespace: namespace)
            },

            cleanupExpired: {
                await storage.cleanupExpired()
            },

            setTTL: { key, ttl in
                await storage.setTTL(key: key, ttl: ttl)
            },

            getTTL: { key in
                await storage.getTTL(key: key)
            }
        )
    }()

    static let testValue = CacheClient(
        get: { _, _ in nil },
        set: { _, _, _ in },
        remove: { _ in },
        invalidate: { _ in },
        clear: { },
        getBatch: { _ in [:] },
        setBatch: { _ in },
        removeBatch: { _ in },
        exists: { _ in false },
        getStats: {
            CacheStats(hits: 0, misses: 0, sets: 0, invalidations: 0, totalEntries: 0, totalSizeBytes: 0)
        },
        getSize: { 0 },
        getAllKeys: { _ in [] },
        cleanupExpired: { 0 },
        setTTL: { _, _ in false },
        getTTL: { _ in nil }
    )
}

extension DependencyValues {
    var cache: CacheClient {
        get { self[CacheClient.self] }
        set { self[CacheClient.self] = newValue }
    }
}

// MARK: - Convenience Extensions

extension CacheClient {
    /// Cache with default medium TTL
    func setWithDefaultTTL<T: Codable>(_ key: CacheKey, value: T) async {
        await set(key, value: value, ttl: .medium)
    }

    /// Remove all entries in a namespace
    func clearNamespace(_ namespace: String) async {
        await invalidate(CachePattern(namespace: namespace))
    }

    /// Get cache hit rate as percentage
    func getHitRate() async -> Double {
        let stats = await getStats()
        return stats.hitRate * 100.0
    }
}