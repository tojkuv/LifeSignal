import Foundation

/// A contact model
struct Contact: Identifiable, Equatable, Sendable {
    /// The contact's ID
    var id: String

    /// The contact's name
    var name: String

    /// The contact's phone number
    var phone: String

    /// The contact's QR code ID
    var qrCodeId: String

    /// The contact's last check-in time
    var lastCheckIn: Date

    /// The contact's note
    var note: String

    /// Whether the contact has an active manual alert
    var manualAlertActive: Bool

    /// Whether the contact is non-responsive
    var isNonResponsive: Bool

    /// Whether the contact has an incoming ping
    var hasIncomingPing: Bool

    /// The timestamp of the incoming ping
    var incomingPingTimestamp: Date?

    /// Whether the contact is a responder
    var isResponder: Bool

    /// Whether the contact is a dependent
    var isDependent: Bool

    /// Whether the contact has an outgoing ping
    var hasOutgoingPing: Bool = false

    /// The timestamp of the outgoing ping
    var outgoingPingTimestamp: Date? = nil

    /// The check-in interval in seconds
    var checkInInterval: TimeInterval? = 24 * 60 * 60 // Default to 24 hours

    /// The formatted time remaining until check-in expiration
    var formattedTimeRemaining: String {
        guard let interval = checkInInterval else { return "" }

        let expirationDate = lastCheckIn.addingTimeInterval(interval)
        let timeRemaining = expirationDate.timeIntervalSince(Date())

        if timeRemaining <= 0 {
            return "Expired"
        }

        return TimeFormatting.formatTimeInterval(timeRemaining)
    }

    /// An empty contact
    static var empty: Contact {
        Contact(
            id: UUID().uuidString,
            name: "",
            phone: "",
            qrCodeId: "",
            lastCheckIn: Date(),
            note: "",
            manualAlertActive: false,
            isNonResponsive: false,
            hasIncomingPing: false,
            incomingPingTimestamp: nil,
            isResponder: false,
            isDependent: false
        )
    }

    /// Generate mock contacts
    static func mockContacts() -> [Contact] {
        [
            Contact(
                id: "1",
                name: "John Doe",
                phone: "555-123-4567",
                qrCodeId: "qr12345",
                lastCheckIn: Date().addingTimeInterval(-3600),
                note: "Lives alone, has a cat named Whiskers",
                manualAlertActive: false,
                isNonResponsive: false,
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                isResponder: true,
                isDependent: false
            ),
            Contact(
                id: "2",
                name: "Jane Smith",
                phone: "555-987-6543",
                qrCodeId: "qr67890",
                lastCheckIn: Date().addingTimeInterval(-7200),
                note: "Has a medical condition, check medicine cabinet if unresponsive",
                manualAlertActive: true,
                isNonResponsive: false,
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                isResponder: false,
                isDependent: true
            ),
            Contact(
                id: "3",
                name: "Bob Johnson",
                phone: "555-555-5555",
                qrCodeId: "qr54321",
                lastCheckIn: Date().addingTimeInterval(-10800),
                note: "Lives with roommate, check with them first",
                manualAlertActive: false,
                isNonResponsive: true,
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                isResponder: true,
                isDependent: true
            )
        ]
    }
}
