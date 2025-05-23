import Foundation

// MARK: - Offline Action Queue Item

struct OfflineActionItem: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let action: OfflineAction
    let timestamp: Date
    var attempts: Int
    var lastAttempt: Date?
    
    init(action: OfflineAction) {
        self.id = UUID()
        self.action = action
        self.timestamp = Date()
        self.attempts = 0
        self.lastAttempt = nil
    }
}