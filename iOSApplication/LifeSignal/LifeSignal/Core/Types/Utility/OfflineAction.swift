import Foundation

// MARK: - Offline Action Types

enum OfflineAction: Codable, Equatable, Identifiable, Sendable {
    case addContact(phoneNumber: String, relationship: Contact.Relationship)
    case updateContactStatus(contactID: UUID, status: Contact.Status)
    case removeContact(contactID: UUID)
    case updateUser(user: User)
    case sendNotification(type: Notification, title: String, message: String)
    
    var id: String {
        switch self {
        case .addContact(let phoneNumber, _):
            return "add_contact_\(phoneNumber)"
        case .updateContactStatus(let contactID, _):
            return "update_status_\(contactID.uuidString)"
        case .removeContact(let contactID):
            return "remove_contact_\(contactID.uuidString)"
        case .updateUser(let user):
            return "update_user_\(user.id.uuidString)"
        case .sendNotification(let type, _, _):
            return "send_notification_\(type.rawValue)_\(UUID().uuidString)"
        }
    }
    
    var timestamp: Date {
        Date()
    }
    
    var actionType: String {
        switch self {
        case .addContact: return "add_contact"
        case .updateContactStatus: return "update_contact_status"
        case .removeContact: return "remove_contact"
        case .updateUser: return "update_user"
        case .sendNotification: return "send_notification"
        }
    }
}