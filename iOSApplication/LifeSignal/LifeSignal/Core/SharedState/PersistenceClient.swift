import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation

// MARK: - Persistence Models

enum PersistenceError: Error, Equatable {
    case fileNotFound(String)
    case encodingFailed(String)
    case decodingFailed(String)
    case diskSpaceInsufficient
    case permissionDenied
    case corruptedData(String)

    var localizedDescription: String {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .encodingFailed(let reason):
            return "Failed to encode data: \(reason)"
        case .decodingFailed(let reason):
            return "Failed to decode data: \(reason)"
        case .diskSpaceInsufficient:
            return "Insufficient disk space"
        case .permissionDenied:
            return "Permission denied to access file"
        case .corruptedData(let reason):
            return "Data corrupted: \(reason)"
        }
    }
}

enum PersistentContainer: String, CaseIterable, Sendable {
    case users = "users"
    case contacts = "contacts"
    case settings = "settings"
    case cache = "cache"
    case notifications = "notifications"
    case offline = "offline"
    case analytics = "analytics"
}

struct PersistenceStats: Sendable, Equatable {
    let totalFiles: Int
    let totalSize: Int64
    let oldestFile: Date?
    let newestFile: Date?
    let corruptedFiles: Int
}

// MARK: - Persistence Client

@DependencyClient
struct PersistenceClient {
    // Core persistence operations
    var save: @Sendable (String, Any, PersistentContainer) async throws -> Void = { _, _, _ in }
    var load: @Sendable (String, Any.Type, PersistentContainer) async throws -> Any? = { _, _, _ in nil }
    var delete: @Sendable (String, PersistentContainer) async throws -> Void = { _, _ in }
    var exists: @Sendable (String, PersistentContainer) async -> Bool = { _, _ in false }
}

extension PersistenceClient: DependencyKey {
    static let liveValue: PersistenceClient = PersistenceClient()
    static let testValue = PersistenceClient()
    static let mockValue = PersistenceClient()
}

extension DependencyValues {
    var persistence: PersistenceClient {
        get { self[PersistenceClient.self] }
        set { self[PersistenceClient.self] = newValue }
    }
}