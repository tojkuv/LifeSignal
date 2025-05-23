import Foundation

// MARK: - NotificationItem

struct NotificationItem: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let type: Notification
    let title: String
    let message: String
    var isRead: Bool
    let timestamp: Date
    
    init(
        id: UUID = UUID(),
        type: Notification,
        title: String,
        message: String,
        isRead: Bool = false,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.isRead = isRead
        self.timestamp = timestamp
    }
}