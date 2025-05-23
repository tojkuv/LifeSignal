import Foundation

// MARK: - Domain Model

struct Contact: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let userID: UUID
    var name: String
    var phoneNumber: String
    var relationship: Relationship
    var status: Status
    var lastUpdated: Date
    
    // MARK: - Legacy Properties (for migration)
    var qrCodeId: String
    var lastCheckIn: Date?
    var note: String
    var manualAlertActive: Bool
    var isNonResponsive: Bool
    var hasIncomingPing: Bool
    var incomingPingTimestamp: Date?
    
    enum Relationship: String, Codable, CaseIterable {
        case responder
        case dependent
    }
    
    enum Status: String, Codable, CaseIterable {
        case active, away, busy, offline
    }
    
    // MARK: - Legacy Properties (for migration) - continued
    var hasOutgoingPing: Bool
    var outgoingPingTimestamp: Date?
    var checkInInterval: TimeInterval
    var manualAlertTimestamp: Date?
    
    // MARK: - Computed Properties for Legacy Support
    
    var isResponder: Bool {
        relationship == .responder
    }
    
    var isDependent: Bool {
        relationship == .dependent
    }

    /// Alias for phoneNumber to match ContactDetailsSheetView usage  
    var phone: String { phoneNumber }
    
    /// Alias for lastCheckIn to match ContactDetailsSheetView usage
    var lastCheckInTime: Date? { lastCheckIn }

    /// Alias for checkInInterval to match ContactDetailsSheetView usage
    var interval: TimeInterval? { checkInInterval }

    /// Whether the contact has a pending ping (computed property)
    var hasPendingPing: Bool {
        return hasIncomingPing || hasOutgoingPing
    }

    /// The formatted time remaining until check-in expiration
    var formattedTimeRemaining: String {
        guard let lastCheckIn = lastCheckIn else { return "No check-in" }
        let expirationDate = lastCheckIn.addingTimeInterval(checkInInterval)
        let timeRemaining = expirationDate.timeIntervalSince(Date())

        if timeRemaining <= 0 {
            return "Expired"
        }

        // Format time interval directly
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
            id: UUID(),
            userID: UUID(),
            name: "",
            phoneNumber: "",
            relationship: .responder,
            status: .active,
            lastUpdated: Date(),
            qrCodeId: "",
            lastCheckIn: Date(),
            note: "",
            manualAlertActive: false,
            isNonResponsive: false,
            hasIncomingPing: false,
            incomingPingTimestamp: nil,
            hasOutgoingPing: false,
            outgoingPingTimestamp: nil,
            checkInInterval: 24 * 60 * 60,
            manualAlertTimestamp: nil
        )
    }

    /// Generate mock contacts for development and testing
    static func mockContacts() -> [Contact] {
        [
            // Regular responder with recent check-in and incoming ping
            Contact(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                userID: UUID(),
                name: "John Doe",
                phoneNumber: "555-123-4567",
                relationship: .responder,
                status: .active,
                lastUpdated: Date(),
                qrCodeId: "qr12345",
                lastCheckIn: Date().addingTimeInterval(-3600), // 1 hour ago
                note: "Lives alone, has a cat named Whiskers. Emergency contact: Sister Mary (555-888-9999). Allergic to penicillin.",
                manualAlertActive: false,
                isNonResponsive: false,
                hasIncomingPing: true,
                incomingPingTimestamp: Date().addingTimeInterval(-15 * 60), // 15 minutes ago
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 24 * 60 * 60, // 24 hours
                manualAlertTimestamp: nil
            ),

            // Dependent with manual alert active and incoming ping
            Contact(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                userID: UUID(),
                name: "Jane Smith",
                phoneNumber: "555-987-6543",
                relationship: .dependent,
                status: .active,
                lastUpdated: Date(),
                qrCodeId: "qr67890",
                lastCheckIn: Date().addingTimeInterval(-7200), // 2 hours ago
                note: "Has diabetes, check medicine cabinet if unresponsive. Emergency contacts: Husband Tom (555-222-3333), Dr. Wilson (555-444-5555).",
                manualAlertActive: true,
                isNonResponsive: false,
                hasIncomingPing: true,
                incomingPingTimestamp: Date().addingTimeInterval(-25 * 60), // 25 minutes ago
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 12 * 60 * 60, // 12 hours
                manualAlertTimestamp: Date().addingTimeInterval(-1800) // 30 minutes ago
            ),

            // Responder, not non-responsive (special case)
            Contact(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                userID: UUID(),
                name: "Bob Johnson",
                phoneNumber: "555-555-5555",
                relationship: .responder,
                status: .active,
                lastUpdated: Date(),
                qrCodeId: "qr54321",
                lastCheckIn: Date().addingTimeInterval(-10800), // 3 hours ago
                note: "Lives with roommate, check with them first. Has heart condition, medication in bathroom cabinet.",
                manualAlertActive: false,
                isNonResponsive: false, // Correctly not non-responsive since 3 hours < 8 hour interval
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 8 * 60 * 60, // 8 hours
                manualAlertTimestamp: nil
            ),

            // Responder with incoming ping
            Contact(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
                userID: UUID(),
                name: "Emily Chen",
                phoneNumber: "555-777-8888",
                relationship: .responder,
                status: .active,
                lastUpdated: Date(),
                qrCodeId: "qr98765",
                lastCheckIn: Date().addingTimeInterval(-5400), // 1.5 hours ago
                note: "Works night shifts at hospital. Has spare key under flowerpot.",
                manualAlertActive: false,
                isNonResponsive: false,
                hasIncomingPing: true,
                incomingPingTimestamp: Date().addingTimeInterval(-900), // 15 minutes ago
                hasOutgoingPing: false,
                outgoingPingTimestamp: nil,
                checkInInterval: 24 * 60 * 60, // 24 hours
                manualAlertTimestamp: nil
            ),

            // Dependent with outgoing ping and non-responsive status
            Contact(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
                userID: UUID(),
                name: "Michael Rodriguez",
                phoneNumber: "555-333-2222",
                relationship: .dependent,
                status: .offline,
                lastUpdated: Date(),
                qrCodeId: "qr24680",
                lastCheckIn: Date().addingTimeInterval(-25 * 60 * 60), // 25 hours ago (expired)
                note: "Lives in apartment 4B. Building manager: Sarah (555-111-0000). Has service dog named Rex.",
                manualAlertActive: false,
                isNonResponsive: true, // Correctly non-responsive since 25 hours > 24 hour interval
                hasIncomingPing: false,
                incomingPingTimestamp: nil,
                hasOutgoingPing: true,
                outgoingPingTimestamp: Date().addingTimeInterval(-1200), // 20 minutes ago
                checkInInterval: 24 * 60 * 60, // 24 hours
                manualAlertTimestamp: nil
            )
        ]
    }
}