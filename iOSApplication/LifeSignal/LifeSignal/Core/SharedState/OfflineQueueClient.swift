import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation

// MARK: - Offline Action Types

struct OfflineAction: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let type: ActionType
    let data: Data
    let timestamp: Date
    let retryCount: Int
    
    init(id: UUID = UUID(), type: ActionType, data: Data, timestamp: Date = Date(), retryCount: Int = 0) {
        self.id = id
        self.type = type
        self.data = data
        self.timestamp = timestamp
        self.retryCount = retryCount
    }
    
    enum ActionType: String, Codable, CaseIterable {
        case createContact
        case updateContact
        case deleteContact
        case updateUser
        case sendNotification
        case recordCheckIn
    }
}

struct OfflineActionItem: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let action: OfflineAction
    let status: Status
    let lastAttempt: Date?
    let errorMessage: String?
    
    enum Status: String, Codable {
        case pending
        case processing
        case completed
        case failed
    }
}

struct OfflineQueueStats: Codable, Equatable, Sendable {
    let totalItems: Int
    let pendingItems: Int
    let failedItems: Int
    let processingItems: Int
    let oldestItemAge: TimeInterval?
    let averageRetryCount: Double
}

// MARK: - Offline Queue Client

@DependencyClient
struct OfflineQueueClient {
    // Queue management
    var enqueue: @Sendable (OfflineAction) async -> Void = { _ in }
    var dequeue: @Sendable () async -> OfflineActionItem? = { nil }
    var remove: @Sendable (UUID) async -> Void = { _ in }
    var clear: @Sendable () async -> Void = { }
    var getAll: @Sendable () async -> [OfflineActionItem] = { [] }
    var getStats: @Sendable () async -> OfflineQueueStats = {
        OfflineQueueStats(totalItems: 0, pendingItems: 0, failedItems: 0, processingItems: 0, oldestItemAge: nil, averageRetryCount: 0.0)
    }

    // Processing
    var startProcessing: @Sendable () async -> Void = { }
    var stopProcessing: @Sendable () async -> Void = { }
    var processNext: @Sendable () async -> Bool = { false }
    var markAsProcessing: @Sendable (UUID) async -> Void = { _ in }
    var markAsCompleted: @Sendable (UUID) async -> Void = { _ in }
    var markAsFailed: @Sendable (UUID, String) async -> Void = { _, _ in }

    // Retry management
    var retryFailed: @Sendable () async -> Int = { 0 }
    
    // Persistence
    var saveToDisk: @Sendable () async -> Bool = { true }
}

extension OfflineQueueClient: DependencyKey {
    static let liveValue: OfflineQueueClient = OfflineQueueClient()
    static let testValue = OfflineQueueClient()
    static let mockValue = OfflineQueueClient()
}

extension DependencyValues {
    var offlineQueue: OfflineQueueClient {
        get { self[OfflineQueueClient.self] }
        set { self[OfflineQueueClient.self] = newValue }
    }
}