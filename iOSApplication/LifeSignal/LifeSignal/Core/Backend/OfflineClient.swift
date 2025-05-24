import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation
import Network

// MARK: - Offline Action Types

enum OfflineAction: Codable, Equatable, Identifiable, Sendable {
    // Contact actions
    case addContact(phoneNumber: String, name: String, isResponder: Bool, isDependent: Bool)
    case updateContactResponder(contactID: UUID, isResponder: Bool)
    case updateContactDependent(contactID: UUID, isDependent: Bool)
    case updateContactPingStatus(contactID: UUID, hasIncoming: Bool, hasOutgoing: Bool)
    case updateContactManualAlert(contactID: UUID, isActive: Bool)
    case updateContactCheckIn(contactID: UUID, timestamp: Date)
    case updateContactInterval(contactID: UUID, interval: TimeInterval)
    case updateContactEmergencyNote(contactID: UUID, emergencyNote: String)
    case updateContactName(contactID: UUID, name: String)
    case removeContact(contactID: UUID)

    // User actions
    case updateUser(user: User)
    case updateUserProfile(userID: UUID, name: String, phoneNumber: String, phoneRegion: String)
    case updateUserNotificationSettings(userID: UUID, enabled: Bool, notify30Min: Bool, notify2Hours: Bool)
    case updateUserCheckInInterval(userID: UUID, interval: TimeInterval)
    case uploadAvatar(userID: UUID, imageData: Data)

    // Notification actions
    case sendNotification(type: String, title: String, message: String, contactID: UUID?)
    case markNotificationRead(notificationID: UUID)
    case deleteNotification(notificationID: UUID)

    // Emergency actions (high priority)
    case triggerEmergencyAlert(userID: UUID, location: String?)
    case cancelEmergencyAlert(userID: UUID)
    case sendSOSAlert(userID: UUID, contactIDs: [UUID])

    var id: String {
        switch self {
        case .addContact(let phoneNumber, _, _, _):
            return "add_contact_\(phoneNumber)_\(UUID().uuidString)"
        case .updateContactResponder(let contactID, _):
            return "update_responder_\(contactID.uuidString)"
        case .updateContactDependent(let contactID, _):
            return "update_dependent_\(contactID.uuidString)"
        case .updateContactPingStatus(let contactID, _, _):
            return "update_ping_\(contactID.uuidString)"
        case .updateContactManualAlert(let contactID, _):
            return "update_alert_\(contactID.uuidString)"
        case .updateContactCheckIn(let contactID, _):
            return "update_checkin_\(contactID.uuidString)"
        case .updateContactInterval(let contactID, _):
            return "update_interval_\(contactID.uuidString)"
        case .updateContactEmergencyNote(let contactID, _):
            return "update_emergency_note_\(contactID.uuidString)"
        case .updateContactName(let contactID, _):
            return "update_name_\(contactID.uuidString)"
        case .removeContact(let contactID):
            return "remove_contact_\(contactID.uuidString)"
        case .updateUser(let user):
            return "update_user_\(user.id.uuidString)"
        case .updateUserProfile(let userID, _, _, _):
            return "update_user_profile_\(userID.uuidString)"
        case .updateUserNotificationSettings(let userID, _, _, _):
            return "update_user_notifications_\(userID.uuidString)"
        case .updateUserCheckInInterval(let userID, _):
            return "update_user_interval_\(userID.uuidString)"
        case .uploadAvatar(let userID, _):
            return "upload_avatar_\(userID.uuidString)"
        case .sendNotification(let type, _, _, let contactID):
            let contactSuffix = contactID?.uuidString ?? "general"
            return "send_notification_\(type)_\(contactSuffix)_\(UUID().uuidString)"
        case .markNotificationRead(let notificationID):
            return "mark_notification_read_\(notificationID.uuidString)"
        case .deleteNotification(let notificationID):
            return "delete_notification_\(notificationID.uuidString)"
        case .triggerEmergencyAlert(let userID, _):
            return "trigger_emergency_\(userID.uuidString)_\(UUID().uuidString)"
        case .cancelEmergencyAlert(let userID):
            return "cancel_emergency_\(userID.uuidString)"
        case .sendSOSAlert(let userID, _):
            return "send_sos_\(userID.uuidString)_\(UUID().uuidString)"
        }
    }

    var actionType: String {
        switch self {
        case .addContact: return "add_contact"
        case .updateContactResponder: return "update_contact_responder"
        case .updateContactDependent: return "update_contact_dependent"
        case .updateContactPingStatus: return "update_contact_ping_status"
        case .updateContactManualAlert: return "update_contact_manual_alert"
        case .updateContactCheckIn: return "update_contact_check_in"
        case .updateContactInterval: return "update_contact_interval"
        case .updateContactEmergencyNote: return "update_contact_emergency_note"
        case .updateContactName: return "update_contact_name"
        case .removeContact: return "remove_contact"
        case .updateUser: return "update_user"
        case .updateUserProfile: return "update_user_profile"
        case .updateUserNotificationSettings: return "update_user_notification_settings"
        case .updateUserCheckInInterval: return "update_user_check_in_interval"
        case .uploadAvatar: return "upload_avatar"
        case .sendNotification: return "send_notification"
        case .markNotificationRead: return "mark_notification_read"
        case .deleteNotification: return "delete_notification"
        case .triggerEmergencyAlert: return "trigger_emergency_alert"
        case .cancelEmergencyAlert: return "cancel_emergency_alert"
        case .sendSOSAlert: return "send_sos_alert"
        }
    }

    /// Priority for action execution (higher number = higher priority)
    var priority: Int {
        switch self {
        case .triggerEmergencyAlert, .sendSOSAlert:
            return 100 // Highest priority
        case .cancelEmergencyAlert:
            return 90
        case .updateContactManualAlert, .updateContactPingStatus:
            return 80
        case .sendNotification:
            return 70
        case .updateContactCheckIn:
            return 60
        case .addContact, .removeContact:
            return 50
        case .updateUser, .updateUserProfile:
            return 40
        case .uploadAvatar:
            return 30
        case .markNotificationRead, .deleteNotification:
            return 20
        default:
            return 10 // Lowest priority
        }
    }

    /// Whether this action can be retried if it fails
    var isRetryable: Bool {
        switch self {
        case .triggerEmergencyAlert, .sendSOSAlert, .cancelEmergencyAlert:
            return true // Critical actions should retry
        case .uploadAvatar:
            return false // Large data uploads shouldn't auto-retry
        default:
            return true
        }
    }

    /// Maximum retry attempts for this action
    var maxRetries: Int {
        switch self {
        case .triggerEmergencyAlert, .sendSOSAlert:
            return 10 // Critical actions get more retries
        case .cancelEmergencyAlert:
            return 5
        case .uploadAvatar:
            return 1
        default:
            return 3
        }
    }
}

// MARK: - Offline Action Queue Item

struct OfflineActionItem: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let action: OfflineAction
    let timestamp: Date
    var attempts: Int
    var lastAttempt: Date?
    var error: String?
    var isProcessing: Bool

    init(action: OfflineAction) {
        self.id = UUID()
        self.action = action
        self.timestamp = Date()
        self.attempts = 0
        self.lastAttempt = nil
        self.error = nil
        self.isProcessing = false
    }

    /// Whether this item should be retried
    var shouldRetry: Bool {
        guard action.isRetryable else { return false }
        return attempts < action.maxRetries
    }

    /// Time until next retry attempt
    var nextRetryDelay: TimeInterval {
        // Exponential backoff: 2^attempts seconds, max 60 seconds
        let delay = min(pow(2.0, Double(attempts)), 60.0)
        return delay
    }

    /// Whether enough time has passed for a retry
    var canRetryNow: Bool {
        guard let lastAttempt = lastAttempt else { return true }
        let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt)
        return timeSinceLastAttempt >= nextRetryDelay
    }
}

// MARK: - Connectivity Status

enum ConnectivityStatus: Equatable, Sendable {
    case online
    case offline
    case limited // Poor connection

    var isConnected: Bool {
        return self != .offline
    }
}

// MARK: - Offline Queue Statistics

struct OfflineQueueStats: Sendable {
    let totalItems: Int
    let pendingItems: Int
    let failedItems: Int
    let processingItems: Int
    let oldestItemAge: TimeInterval?
    let averageRetryCount: Double

    var isEmpty: Bool { totalItems == 0 }
    var hasFailures: Bool { failedItems > 0 }
}

// MARK: - Connectivity Client

@DependencyClient
struct ConnectivityClient {
    var isOnline: @Sendable () -> Bool = { true }
    var getStatus: @Sendable () -> ConnectivityStatus = { .online }
    var onlineStatusStream: @Sendable () -> AsyncStream<ConnectivityStatus> = {
        AsyncStream { continuation in
            continuation.yield(.online)
            continuation.finish()
        }
    }
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
    var retryItem: @Sendable (UUID) async -> Bool = { _ in false }
    var clearFailed: @Sendable () async -> Int = { 0 }

    // Priority management
    var enqueuePriority: @Sendable (OfflineAction) async -> Void = { _ in }
    var getNextPriority: @Sendable () async -> OfflineActionItem? = { nil }
}

// MARK: - Offline Manager

@DependencyClient
struct OfflineManager {
    var connectivity: ConnectivityClient
    var queue: OfflineQueueClient

    // High-level operations
    var executeOrQueue: @Sendable (OfflineAction) async -> Bool = { _ in true }
    var syncWhenOnline: @Sendable () async -> Void = { }
    var forceSyncNow: @Sendable () async -> Int = { 0 }
    var isOperationPending: @Sendable (String) async -> Bool = { _ in false }
}

// MARK: - Implementations

extension ConnectivityClient: DependencyKey {
    static let liveValue: ConnectivityClient = {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "connectivity.monitor")

        actor ConnectivityState {
            private var currentStatus: ConnectivityStatus = .online
            private var continuations: [AsyncStream<ConnectivityStatus>.Continuation] = []

            func updateStatus(_ status: ConnectivityStatus) {
                currentStatus = status
                for continuation in continuations {
                    continuation.yield(status)
                }
            }

            func getStatus() -> ConnectivityStatus {
                return currentStatus
            }

            func addContinuation(_ continuation: AsyncStream<ConnectivityStatus>.Continuation) {
                continuations.append(continuation)
            }

            func removeContinuation(_ continuation: AsyncStream<ConnectivityStatus>.Continuation) {
                continuations.removeAll { $0 === continuation }
            }
        }

        let state = ConnectivityState()

        monitor.pathUpdateHandler = { path in
            let status: ConnectivityStatus
            if path.status == .satisfied {
                if path.isExpensive || path.isConstrained {
                    status = .limited
                } else {
                    status = .online
                }
            } else {
                status = .offline
            }

            Task {
                await state.updateStatus(status)
            }
        }

        monitor.start(queue: queue)

        return ConnectivityClient(
            isOnline: {
                Task {
                    await state.getStatus().isConnected
                }.value
            },

            getStatus: {
                Task {
                    await state.getStatus()
                }.value
            },

            onlineStatusStream: {
                AsyncStream { continuation in
                    Task {
                        await state.addContinuation(continuation)

                        continuation.onTermination = { _ in
                            Task {
                                await state.removeContinuation(continuation)
                            }
                        }
                    }
                }
            }
        )
    }()

    static let testValue = ConnectivityClient(
        isOnline: { true },
        getStatus: { .online },
        onlineStatusStream: {
            AsyncStream { continuation in
                continuation.yield(.online)
                continuation.finish()
            }
        }
    )
}

extension OfflineQueueClient: DependencyKey {
    static let liveValue: OfflineQueueClient = {
        actor QueueStorage {
            private var items: [OfflineActionItem] = []
            private var isProcessing = false

            func enqueue(_ action: OfflineAction) {
                let item = OfflineActionItem(action: action)
                items.append(item)
                sortByPriority()
                print("📦 Offline Queue: Added \(action.actionType) (\(items.count) total)")
            }

            func enqueuePriority(_ action: OfflineAction) {
                let item = OfflineActionItem(action: action)
                items.insert(item, at: 0) // Add to front for immediate processing
                print("🚨 Offline Queue: Added priority \(action.actionType)")
            }

            func dequeue() -> OfflineActionItem? {
                guard let index = items.firstIndex(where: { !$0.isProcessing && $0.canRetryNow }) else {
                    return nil
                }
                let item = items[index]
                items[index].isProcessing = true
                return item
            }

            func getNextPriority() -> OfflineActionItem? {
                // Sort by priority and return highest priority item that can be processed
                let availableItems = items.filter { !$0.isProcessing && $0.canRetryNow }
                return availableItems.max { $0.action.priority < $1.action.priority }
            }

            func remove(_ id: UUID) {
                items.removeAll { $0.id == id }
            }

            func clear() {
                items.removeAll()
                print("🧹 Offline Queue: Cleared all items")
            }

            func getAll() -> [OfflineActionItem] {
                return items
            }

            func getStats() -> OfflineQueueStats {
                let total = items.count
                let pending = items.filter { !$0.isProcessing && $0.shouldRetry }.count
                let failed = items.filter { !$0.shouldRetry && $0.attempts > 0 }.count
                let processing = items.filter { $0.isProcessing }.count
                let oldestAge = items.map { Date().timeIntervalSince($0.timestamp) }.max()
                let avgRetries = items.isEmpty ? 0.0 : Double(items.map { $0.attempts }.reduce(0, +)) / Double(items.count)

                return OfflineQueueStats(
                    totalItems: total,
                    pendingItems: pending,
                    failedItems: failed,
                    processingItems: processing,
                    oldestItemAge: oldestAge,
                    averageRetryCount: avgRetries
                )
            }

            func markAsProcessing(_ id: UUID) {
                if let index = items.firstIndex(where: { $0.id == id }) {
                    items[index].isProcessing = true
                    items[index].attempts += 1
                    items[index].lastAttempt = Date()
                }
            }

            func markAsCompleted(_ id: UUID) {
                items.removeAll { $0.id == id }
                print("✅ Offline Queue: Completed action \(id)")
            }

            func markAsFailed(_ id: UUID, _ error: String) {
                if let index = items.firstIndex(where: { $0.id == id }) {
                    items[index].isProcessing = false
                    items[index].error = error
                    print("❌ Offline Queue: Failed action \(id) - \(error)")
                }
            }

            func retryFailed() -> Int {
                let failedItems = items.filter { !$0.shouldRetry && $0.attempts > 0 }
                for index in items.indices {
                    if !items[index].shouldRetry && items[index].attempts > 0 {
                        items[index].attempts = 0
                        items[index].error = nil
                        items[index].isProcessing = false
                    }
                }
                return failedItems.count
            }

            func retryItem(_ id: UUID) -> Bool {
                if let index = items.firstIndex(where: { $0.id == id }) {
                    items[index].attempts = 0
                    items[index].error = nil
                    items[index].isProcessing = false
                    return true
                }
                return false
            }

            func clearFailed() -> Int {
                let failedCount = items.filter { !$0.shouldRetry && $0.attempts > 0 }.count
                items.removeAll { !$0.shouldRetry && $0.attempts > 0 }
                return failedCount
            }

            private func sortByPriority() {
                items.sort { $0.action.priority > $1.action.priority }
            }
        }

        let storage = QueueStorage()

        return OfflineQueueClient(
            enqueue: { action in await storage.enqueue(action) },
            dequeue: { await storage.dequeue() },
            remove: { id in await storage.remove(id) },
            clear: { await storage.clear() },
            getAll: { await storage.getAll() },
            getStats: { await storage.getStats() },
            startProcessing: { print("▶️ Offline Queue: Started processing") },
            stopProcessing: { print("⏸️ Offline Queue: Stopped processing") },
            processNext: {
                if let item = await storage.dequeue() {
                    print("🔄 Offline Queue: Processing \(item.action.actionType)")
                    return true
                }
                return false
            },
            markAsProcessing: { id in await storage.markAsProcessing(id) },
            markAsCompleted: { id in await storage.markAsCompleted(id) },
            markAsFailed: { id, error in await storage.markAsFailed(id, error) },
            retryFailed: { await storage.retryFailed() },
            retryItem: { id in await storage.retryItem(id) },
            clearFailed: { await storage.clearFailed() },
            enqueuePriority: { action in await storage.enqueuePriority(action) },
            getNextPriority: { await storage.getNextPriority() }
        )
    }()

    static let testValue = OfflineQueueClient()
}

extension OfflineManager: DependencyKey {
    static let liveValue = OfflineManager(
        connectivity: .liveValue,
        queue: .liveValue,

        executeOrQueue: { action in
            let connectivity = ConnectivityClient.liveValue
            let queue = OfflineQueueClient.liveValue

            if connectivity.isOnline() {
                // Try to execute immediately
                // In production, this would attempt the actual network operation
                print("🌐 Executing online: \(action.actionType)")
                return true
            } else {
                // Queue for later
                if action.priority >= 80 {
                    await queue.enqueuePriority(action)
                } else {
                    await queue.enqueue(action)
                }
                return false
            }
        },

        syncWhenOnline: {
            let connectivity = ConnectivityClient.liveValue
            let queue = OfflineQueueClient.liveValue

            for await status in connectivity.onlineStatusStream() {
                if status.isConnected {
                    print("🔄 Connection restored, syncing offline actions...")
                    _ = await queue.processNext()
                }
            }
        },

        forceSyncNow: {
            let queue = OfflineQueueClient.liveValue
            var processedCount = 0

            while await queue.processNext() {
                processedCount += 1
            }

            print("🔄 Force sync completed: \(processedCount) actions processed")
            return processedCount
        },

        isOperationPending: { actionId in
            let queue = OfflineQueueClient.liveValue
            let items = await queue.getAll()
            return items.contains { $0.action.id == actionId }
        }
    )

    static let testValue = OfflineManager(
        connectivity: .testValue,
        queue: .testValue,
        executeOrQueue: { _ in true },
        syncWhenOnline: { },
        forceSyncNow: { 0 },
        isOperationPending: { _ in false }
    )
}

// MARK: - Dependency Extensions

extension DependencyValues {
    var connectivity: ConnectivityClient {
        get { self[ConnectivityClient.self] }
        set { self[ConnectivityClient.self] = newValue }
    }

    var offlineQueue: OfflineQueueClient {
        get { self[OfflineQueueClient.self] }
        set { self[OfflineQueueClient.self] = newValue }
    }

    var offlineManager: OfflineManager {
        get { self[OfflineManager.self] }
        set { self[OfflineManager.self] = newValue }
    }
}