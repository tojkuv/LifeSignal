import Foundation

/// A utility class for generating mock data for testing
class MockDataGenerator {
    // MARK: - Contact Generators

    /// Generate a contact with an expired check-in
    /// - Returns: A contact with an expired check-in
    static func generateExpiredContact() -> Contact {
        Contact(
            id: UUID().uuidString,
            name: "Taylor Morgan",
            phone: "555-888-7777",
            qrCodeId: "qr-expired-\(Int.random(in: 1000...9999))",
            lastCheckIn: Date().addingTimeInterval(-36 * 60 * 60), // 36 hours ago
            note: "Lives in remote cabin. Has medical alert bracelet. Emergency contact: Brother Chris (555-444-3333).",
            manualAlertActive: false,
            isNonResponsive: true,
            hasIncomingPing: false,
            incomingPingTimestamp: nil,
            isResponder: false,
            isDependent: true,
            hasOutgoingPing: false,
            outgoingPingTimestamp: nil,
            checkInInterval: 24 * 60 * 60, // 24 hours
            manualAlertTimestamp: nil
        )
    }

    /// Generate a contact with an active manual alert
    /// - Returns: A contact with an active manual alert
    static func generateManualAlertContact() -> Contact {
        Contact(
            id: UUID().uuidString,
            name: "Jordan Rivera",
            phone: "555-222-6666",
            qrCodeId: "qr-alert-\(Int.random(in: 1000...9999))",
            lastCheckIn: Date().addingTimeInterval(-4 * 60 * 60), // 4 hours ago
            note: "Has epilepsy. Medication in nightstand. Service dog named Luna responds to seizures.",
            manualAlertActive: true,
            isNonResponsive: false,
            hasIncomingPing: false,
            incomingPingTimestamp: nil,
            isResponder: true,
            isDependent: true,
            hasOutgoingPing: false,
            outgoingPingTimestamp: nil,
            checkInInterval: 12 * 60 * 60, // 12 hours
            manualAlertTimestamp: Date().addingTimeInterval(-30 * 60) // 30 minutes ago
        )
    }

    /// Generate a contact with multiple pings and non-responsive status
    /// - Returns: A contact with multiple pings and non-responsive status
    static func generateMultiplePingContact() -> Contact {
        Contact(
            id: UUID().uuidString,
            name: "Casey Kim",
            phone: "555-111-9999",
            qrCodeId: "qr-pings-\(Int.random(in: 1000...9999))",
            lastCheckIn: Date().addingTimeInterval(-20 * 60 * 60), // 20 hours ago (exceeds check-in interval)
            note: "Mountain climber, often in remote areas. Emergency contacts: Partner Alex (555-777-2222), Guide Service (555-333-8888).",
            manualAlertActive: false,
            isNonResponsive: true, // Explicitly set as non-responsive
            hasIncomingPing: true,
            incomingPingTimestamp: Date().addingTimeInterval(-45 * 60), // 45 minutes ago
            isResponder: true,
            isDependent: true,
            hasOutgoingPing: true,
            outgoingPingTimestamp: Date().addingTimeInterval(-2 * 60 * 60), // 2 hours ago
            checkInInterval: 18 * 60 * 60, // 18 hours
            manualAlertTimestamp: nil
        )
    }

    /// Generate a contact with a very short check-in interval
    /// - Returns: A contact with a very short check-in interval
    static func generateShortIntervalContact() -> Contact {
        Contact(
            id: UUID().uuidString,
            name: "Alex Parker",
            phone: "555-666-1111",
            qrCodeId: "qr-short-\(Int.random(in: 1000...9999))",
            lastCheckIn: Date().addingTimeInterval(-2 * 60 * 60), // 2 hours ago
            note: "Security guard, works night shifts. Has pacemaker. Emergency contact: Supervisor (555-999-7777).",
            manualAlertActive: false,
            isNonResponsive: false,
            hasIncomingPing: false,
            incomingPingTimestamp: nil,
            isResponder: false,
            isDependent: true,
            hasOutgoingPing: false,
            outgoingPingTimestamp: nil,
            checkInInterval: 3 * 60 * 60, // 3 hours (very short)
            manualAlertTimestamp: nil
        )
    }

    /// Generate a contact with a very long check-in interval
    /// - Returns: A contact with a very long check-in interval
    static func generateLongIntervalContact() -> Contact {
        Contact(
            id: UUID().uuidString,
            name: "Morgan Bailey",
            phone: "555-444-2222",
            qrCodeId: "qr-long-\(Int.random(in: 1000...9999))",
            lastCheckIn: Date().addingTimeInterval(-48 * 60 * 60), // 48 hours ago
            note: "Travels frequently for work. Has severe allergies, EpiPen in travel bag. Emergency contact: Assistant (555-888-3333).",
            manualAlertActive: false,
            isNonResponsive: false,
            hasIncomingPing: false,
            incomingPingTimestamp: nil,
            isResponder: true,
            isDependent: false,
            hasOutgoingPing: false,
            outgoingPingTimestamp: nil,
            checkInInterval: 7 * 24 * 60 * 60, // 7 days (very long)
            manualAlertTimestamp: nil
        )
    }

    // MARK: - User Generators

    /// Generate a user with an almost expired check-in
    /// - Returns: A user view model with an almost expired check-in
    static func generateAlmostExpiredUser() -> UserViewModel {
        let viewModel = UserViewModel()
        viewModel.name = "Emma Thompson"
        viewModel.phone = "+1 (555) 333-7777"
        viewModel.profileDescription = "I have asthma. Inhaler in bathroom cabinet. Emergency contacts: Sister (555-222-1111), Neighbor in 3B (555-888-4444)."
        viewModel.lastCheckIn = Date().addingTimeInterval(-11 * 60 * 60) // 11 hours ago
        viewModel.checkInInterval = 12 * 60 * 60 // 12 hours
        return viewModel
    }

    /// Generate a user with an active alert
    /// - Returns: A user view model with an active alert
    static func generateAlertActiveUser() -> UserViewModel {
        let viewModel = UserViewModel()
        viewModel.name = "Sam Martinez"
        viewModel.phone = "+1 (555) 777-1111"
        viewModel.profileDescription = "I have a heart condition. Medication in kitchen cabinet. Medical alert bracelet has details. Emergency contacts: Partner (555-444-9999), Doctor (555-666-8888)."
        viewModel.lastCheckIn = Date().addingTimeInterval(-6 * 60 * 60) // 6 hours ago
        viewModel.checkInInterval = 24 * 60 * 60 // 24 hours
        viewModel.isAlertActive = true
        return viewModel
    }

    // MARK: - Ping Generators

    /// Generate a list of pending pings
    /// - Returns: A list of pending ping events
    static func generatePendingPings() -> [PingEvent] {
        [
            PingEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-10 * 60), // 10 minutes ago
                contactId: "pending-1",
                contactName: "Jordan Rivera",
                direction: .outgoing,
                status: .pending
            ),
            PingEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-30 * 60), // 30 minutes ago
                contactId: "pending-2",
                contactName: "Casey Kim",
                direction: .incoming,
                status: .pending
            ),
            PingEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-2 * 60 * 60), // 2 hours ago
                contactId: "pending-3",
                contactName: "Alex Parker",
                direction: .outgoing,
                status: .pending
            )
        ]
    }

    /// Generate a mixed list of ping events
    /// - Returns: A mixed list of ping events
    static func generateMixedPings() -> [PingEvent] {
        [
            PingEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-5 * 60), // 5 minutes ago
                contactId: "mixed-1",
                contactName: "Taylor Morgan",
                direction: .outgoing,
                status: .pending
            ),
            PingEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-20 * 60), // 20 minutes ago
                contactId: "mixed-2",
                contactName: "Morgan Bailey",
                direction: .incoming,
                status: .responded
            ),
            PingEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-1 * 60 * 60), // 1 hour ago
                contactId: "mixed-3",
                contactName: "Emma Thompson",
                direction: .outgoing,
                status: .responded
            ),
            PingEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-4 * 60 * 60), // 4 hours ago
                contactId: "mixed-4",
                contactName: "Sam Martinez",
                direction: .incoming,
                status: .pending
            )
        ]
    }
}
