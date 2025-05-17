import Foundation

/// A contact model
struct Contact: Identifiable, Equatable, Sendable {
    static func == (lhs: Contact, rhs: Contact) -> Bool {
        return lhs.id == rhs.id
    }
    /// The contact's ID
    var id: String

    /// The contact's name
    var name: String

    /// The contact's phone number
    var phone: String

    /// The contact's QR code ID
    var qrCodeId: String

    /// The contact's last check-in time
    var lastCheckIn: Date?

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

    /// Alias for checkInInterval to match ContactDetailsSheet usage
    var interval: TimeInterval? { checkInInterval }

    // Removed duplicate manualAlertActive property

    /// The timestamp of the manual alert
    var manualAlertTimestamp: Date? = nil

    /// The formatted time remaining until check-in expiration
    var formattedTimeRemaining: String {
        guard let interval = checkInInterval else { return "" }

        guard let lastCheckIn = lastCheckIn else { return "No check-in" }
        let expirationDate = lastCheckIn.addingTimeInterval(interval)
        let timeRemaining = expirationDate.timeIntervalSince(Date())

        if timeRemaining <= 0 {
            return "Expired"
        }

        // Format time interval directly instead of using TimeFormattingUtility
        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
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
            // Regular responder with recent check-in and incoming ping
            Contact(
                id: "1",
                name: "John Doe",
                phone: "555-123-4567",
                qrCodeId: "qr12345",
                lastCheckIn: Date().addingTimeInterval(-3600), // 1 hour ago
                note: "Lives alone, has a cat named Whiskers. Emergency contact: Sister Mary (555-888-9999). Allergic to penicillin.",
                manualAlertActive: false,
                isNonResponsive: false,
                hasIncomingPing: true,
                incomingPingTimestamp: Date().addingTimeInterval(-15 * 60), // 15 minutes ago
                isResponder: true,
                isDependent: false,
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 24 * 60 * 60, // 24 hours
                manualAlertTimestamp: nil
            ),

            // Dependent with manual alert active and incoming ping
            Contact(
                id: "2",
                name: "Jane Smith",
                phone: "555-987-6543",
                qrCodeId: "qr67890",
                lastCheckIn: Date().addingTimeInterval(-7200), // 2 hours ago
                note: "Has diabetes, check medicine cabinet if unresponsive. Emergency contacts: Husband Tom (555-222-3333), Dr. Wilson (555-444-5555).",
                manualAlertActive: true,
                isNonResponsive: false,
                hasIncomingPing: true,
                incomingPingTimestamp: Date().addingTimeInterval(-25 * 60), // 25 minutes ago
                isResponder: false,
                isDependent: true,
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 12 * 60 * 60, // 12 hours
                manualAlertTimestamp: Date().addingTimeInterval(-1800) // 30 minutes ago
            ),

            // Both responder and dependent, not non-responsive (special case)
            Contact(
                id: "3",
                name: "Bob Johnson",
                phone: "555-555-5555",
                qrCodeId: "qr54321",
                lastCheckIn: Date().addingTimeInterval(-10800), // 3 hours ago
                note: "Lives with roommate, check with them first. Has heart condition, medication in bathroom cabinet.",
                manualAlertActive: false,
                isNonResponsive: false, // Correctly not non-responsive since 3 hours < 8 hour interval
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                isResponder: true,
                isDependent: true,
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 8 * 60 * 60, // 8 hours
                manualAlertTimestamp: nil
            ),

            // Responder with incoming ping
            Contact(
                id: "4",
                name: "Emily Chen",
                phone: "555-777-8888",
                qrCodeId: "qr98765",
                lastCheckIn: Date().addingTimeInterval(-5400), // 1.5 hours ago
                note: "Works night shifts at hospital. Has spare key under flowerpot.",
                manualAlertActive: false,
                isNonResponsive: false,
                hasIncomingPing: true,
                incomingPingTimestamp: Date().addingTimeInterval(-900), // 15 minutes ago
                isResponder: true,
                isDependent: false,
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 24 * 60 * 60, // 24 hours
                manualAlertTimestamp: nil
            ),

            // Dependent with outgoing ping and non-responsive status
            Contact(
                id: "5",
                name: "Michael Rodriguez",
                phone: "555-333-2222",
                qrCodeId: "qr24680",
                lastCheckIn: Date().addingTimeInterval(-25 * 60 * 60), // 25 hours ago (expired)
                note: "Lives in apartment 4B. Building manager: Sarah (555-111-0000). Has service dog named Rex.",
                manualAlertActive: false,
                isNonResponsive: true, // Correctly non-responsive since 25 hours > 24 hour interval
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                isResponder: false,
                isDependent: true,
                hasOutgoingPing: true,
                outgoingPingTimestamp: Date().addingTimeInterval(-1200), // 20 minutes ago
                checkInInterval: 24 * 60 * 60, // 24 hours
                manualAlertTimestamp: nil
            ),

            // Both responder and dependent with very old check-in
            Contact(
                id: "6",
                name: "Olivia Wilson",
                phone: "555-444-9999",
                qrCodeId: "qr13579",
                lastCheckIn: Date().addingTimeInterval(-48 * 60 * 60), // 2 days ago
                note: "Elderly, lives alone. Has hearing aids. Emergency contact: Son David (555-666-7777).",
                manualAlertActive: false,
                isNonResponsive: true,
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                isResponder: true,
                isDependent: true,
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 12 * 60 * 60, // 12 hours
                manualAlertTimestamp: nil
            ),

            // Responder with both incoming and outgoing pings
            Contact(
                id: "7",
                name: "Alex Thompson",
                phone: "555-222-1111",
                qrCodeId: "qr11223",
                lastCheckIn: Date().addingTimeInterval(-4 * 60 * 60), // 4 hours ago
                note: "Hiker, often in remote areas. Emergency contact: Partner Jordan (555-999-1111).",
                manualAlertActive: false,
                isNonResponsive: false,
                hasIncomingPing: true,
                incomingPingTimestamp: Date().addingTimeInterval(-600), // 10 minutes ago
                isResponder: true,
                isDependent: false,
                hasOutgoingPing: true,
                outgoingPingTimestamp: Date().addingTimeInterval(-1800), // 30 minutes ago
                checkInInterval: 6 * 60 * 60, // 6 hours
                manualAlertTimestamp: nil
            ),

            // Responder with expired check-in
            Contact(
                id: "8",
                name: "Taylor Morgan",
                phone: "555-888-7777",
                qrCodeId: "qr-expired-test",
                lastCheckIn: Date().addingTimeInterval(-36 * 60 * 60), // 36 hours ago
                note: "Lives in remote cabin. Has medical alert bracelet. Emergency contact: Brother Chris (555-444-3333).",
                manualAlertActive: false,
                isNonResponsive: true,
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                isResponder: true,
                isDependent: false,
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 24 * 60 * 60, // 24 hours
                manualAlertTimestamp: nil
            ),

            // Responder with manual alert active
            Contact(
                id: "9",
                name: "Jordan Rivera",
                phone: "555-222-6666",
                qrCodeId: "qr-alert-test",
                lastCheckIn: Date().addingTimeInterval(-4 * 60 * 60), // 4 hours ago
                note: "Has epilepsy. Medication in nightstand. Service dog named Luna responds to seizures.",
                manualAlertActive: true,
                isNonResponsive: false,
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                isResponder: true,
                isDependent: false,
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 12 * 60 * 60, // 12 hours
                manualAlertTimestamp: Date().addingTimeInterval(-30 * 60) // 30 minutes ago
            ),

            // NEW DEPENDENTS WITH DIVERSE SCENARIOS



            // Dependent with very long check-in interval (7 days)
            Contact(
                id: "11",
                name: "Morgan Bailey",
                phone: "555-444-2222",
                qrCodeId: "qr-long-interval",
                lastCheckIn: Date().addingTimeInterval(-48 * 60 * 60), // 48 hours ago
                note: "Travels frequently for work. Has severe allergies, EpiPen in travel bag. Emergency contact: Assistant (555-888-3333).",
                manualAlertActive: false,
                isNonResponsive: false,
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                isResponder: false,
                isDependent: true,
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 7 * 24 * 60 * 60, // 7 days (very long)
                manualAlertTimestamp: nil
            ),

            // Dependent with manual alert and outgoing ping
            Contact(
                id: "12",
                name: "Harper Lee",
                phone: "555-888-7777",
                qrCodeId: "qr-alert-ping",
                lastCheckIn: Date().addingTimeInterval(-36 * 60 * 60), // 36 hours ago
                note: "Lives in remote cabin. Has medical alert bracelet. Emergency contact: Brother Chris (555-444-3333).",
                manualAlertActive: true,
                isNonResponsive: false,
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                isResponder: false,
                isDependent: true,
                hasOutgoingPing: true,
                outgoingPingTimestamp: Date().addingTimeInterval(-30 * 60), // 30 minutes ago
                checkInInterval: 24 * 60 * 60, // 24 hours
                manualAlertTimestamp: Date().addingTimeInterval(-2 * 60 * 60) // 2 hours ago
            ),

            // Dependent who is also a responder with multiple pings and is non-responsive
            Contact(
                id: "13",
                name: "Casey Kim",
                phone: "555-111-9999",
                qrCodeId: "qr-multi-role",
                lastCheckIn: Date().addingTimeInterval(-20 * 60 * 60), // 20 hours ago (exceeds check-in interval)
                note: "Mountain climber, often in remote areas. Emergency contacts: Partner Alex (555-777-2222), Guide Service (555-333-8888).",
                manualAlertActive: false,
                isNonResponsive: true, // Correctly non-responsive since 20 hours > 18 hour interval
                hasIncomingPing: true,
                incomingPingTimestamp: Date().addingTimeInterval(-45 * 60), // 45 minutes ago
                isResponder: true,
                isDependent: true,
                hasOutgoingPing: true,
                outgoingPingTimestamp: Date().addingTimeInterval(-2 * 60 * 60), // 2 hours ago
                checkInInterval: 18 * 60 * 60, // 18 hours
                manualAlertTimestamp: nil
            ),



            // Dependent with very recent check-in
            Contact(
                id: "15",
                name: "Sam Parker",
                phone: "555-777-3333",
                qrCodeId: "qr-recent-checkin",
                lastCheckIn: Date().addingTimeInterval(-30 * 60), // 30 minutes ago
                note: "Freelance photographer, often in urban exploration sites. Emergency contact: Partner Robin (555-111-7777).",
                manualAlertActive: false,
                isNonResponsive: false,
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                isResponder: false,
                isDependent: true,
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 8 * 60 * 60, // 8 hours
                manualAlertTimestamp: nil
            ),

            // NEW COMPREHENSIVE MOCK CONTACTS

            // Simple responder (no statuses)
            Contact(
                id: "16",
                name: "Chris Evans",
                phone: "555-100-1000",
                qrCodeId: "qr-simple-responder",
                lastCheckIn: Date().addingTimeInterval(-1 * 60 * 60), // 1 hour ago
                note: "Simple responder with no special status.",
                manualAlertActive: false,
                isNonResponsive: false,
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                isResponder: true,
                isDependent: false,
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 24 * 60 * 60, // 24 hours
                manualAlertTimestamp: nil
            ),

            // Simple dependent (no statuses)
            Contact(
                id: "17",
                name: "Diana Prince",
                phone: "555-200-2000",
                qrCodeId: "qr-simple-dependent",
                lastCheckIn: Date().addingTimeInterval(-2 * 60 * 60), // 2 hours ago
                note: "Simple dependent with no special status.",
                manualAlertActive: false,
                isNonResponsive: false,
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                isResponder: false,
                isDependent: true,
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 16 * 60 * 60, // 16 hours
                manualAlertTimestamp: nil
            ),

            // Both responder and dependent (no statuses)
            Contact(
                id: "18",
                name: "Bruce Wayne",
                phone: "555-300-3000",
                qrCodeId: "qr-both-roles",
                lastCheckIn: Date().addingTimeInterval(-3 * 60 * 60), // 3 hours ago
                note: "Both responder and dependent with no special status.",
                manualAlertActive: false,
                isNonResponsive: false,
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                isResponder: true,
                isDependent: true,
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 32 * 60 * 60, // 32 hours
                manualAlertTimestamp: nil
            ),

            // Responder with incoming ping only
            Contact(
                id: "19",
                name: "Natasha Romanoff",
                phone: "555-400-4000",
                qrCodeId: "qr-responder-incoming",
                lastCheckIn: Date().addingTimeInterval(-4 * 60 * 60), // 4 hours ago
                note: "Responder with incoming ping only.",
                manualAlertActive: false,
                isNonResponsive: false,
                hasIncomingPing: true,
                incomingPingTimestamp: Date().addingTimeInterval(-20 * 60), // 20 minutes ago
                isResponder: true,
                isDependent: false,
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 24 * 60 * 60, // 24 hours
                manualAlertTimestamp: nil
            ),

            // Dependent with outgoing ping only
            Contact(
                id: "20",
                name: "Tony Stark",
                phone: "555-500-5000",
                qrCodeId: "qr-dependent-outgoing",
                lastCheckIn: Date().addingTimeInterval(-5 * 60 * 60), // 5 hours ago
                note: "Dependent with outgoing ping only.",
                manualAlertActive: false,
                isNonResponsive: false,
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                isResponder: false,
                isDependent: true,
                hasOutgoingPing: true,
                outgoingPingTimestamp: Date().addingTimeInterval(-25 * 60), // 25 minutes ago
                checkInInterval: 8 * 60 * 60, // 8 hours
                manualAlertTimestamp: nil
            ),

            // Both roles with both ping types
            Contact(
                id: "21",
                name: "Steve Rogers",
                phone: "555-600-6000",
                qrCodeId: "qr-both-roles-both-pings",
                lastCheckIn: Date().addingTimeInterval(-6 * 60 * 60), // 6 hours ago
                note: "Both responder and dependent with both incoming and outgoing pings.",
                manualAlertActive: false,
                isNonResponsive: false,
                hasIncomingPing: true,
                incomingPingTimestamp: Date().addingTimeInterval(-30 * 60), // 30 minutes ago
                isResponder: true,
                isDependent: true,
                hasOutgoingPing: true,
                outgoingPingTimestamp: Date().addingTimeInterval(-35 * 60), // 35 minutes ago
                checkInInterval: 16 * 60 * 60, // 16 hours
                manualAlertTimestamp: nil
            ),

            // Responder with manual alert only
            Contact(
                id: "22",
                name: "Wanda Maximoff",
                phone: "555-700-7000",
                qrCodeId: "qr-responder-alert",
                lastCheckIn: Date().addingTimeInterval(-7 * 60 * 60), // 7 hours ago
                note: "Responder with manual alert only.",
                manualAlertActive: true,
                isNonResponsive: false,
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                isResponder: true,
                isDependent: false,
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 32 * 60 * 60, // 32 hours
                manualAlertTimestamp: Date().addingTimeInterval(-40 * 60) // 40 minutes ago
            ),

            // Dependent with non-responsive status only (correctly set because check-in interval has expired)
            Contact(
                id: "23",
                name: "Peter Parker",
                phone: "555-800-8000",
                qrCodeId: "qr-dependent-nonresponsive",
                lastCheckIn: Date().addingTimeInterval(-10 * 60 * 60), // 10 hours ago
                note: "Dependent with non-responsive status only.",
                manualAlertActive: false,
                isNonResponsive: true, // Correctly non-responsive since 10 hours > 8 hour interval
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                isResponder: false,
                isDependent: true,
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 8 * 60 * 60, // 8 hours
                manualAlertTimestamp: nil
            ),

            // Comprehensive contact with everything
            Contact(
                id: "24",
                name: "Carol Danvers",
                phone: "555-900-9000",
                qrCodeId: "qr-comprehensive",
                lastCheckIn: Date().addingTimeInterval(-9 * 60 * 60), // 9 hours ago
                note: "Comprehensive contact with all statuses: both roles, manual alert, non-responsive, incoming and outgoing pings.",
                manualAlertActive: true,
                isNonResponsive: true,
                hasIncomingPing: true,
                incomingPingTimestamp: Date().addingTimeInterval(-45 * 60), // 45 minutes ago
                isResponder: true,
                isDependent: true,
                hasOutgoingPing: true,
                outgoingPingTimestamp: Date().addingTimeInterval(-50 * 60), // 50 minutes ago
                checkInInterval: 8 * 60 * 60, // 8 hours
                manualAlertTimestamp: Date().addingTimeInterval(-55 * 60) // 55 minutes ago
            )
        ]
    }
}
