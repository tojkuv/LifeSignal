import Foundation
import SwiftUI
import Combine

/// View model for the ping feature
class PingViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The user view model
    private var userViewModel: UserViewModel = UserViewModel()

    /// The ping history
    @Published var pingHistory: [PingEvent] = []

    /// Whether the ping confirmation is showing
    @Published var showPingConfirmation: Bool = false

    /// The contact to ping
    @Published var contactToPing: Contact? = nil

    /// Whether the ping is being sent
    @Published var isSending: Bool = false

    // MARK: - Initialization

    init() {
        // Generate mock ping history with diverse scenarios
        pingHistory = [
            // Recent outgoing ping, still pending
            PingEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-15 * 60), // 15 minutes ago
                contactId: "5",
                contactName: "Michael Rodriguez",
                direction: .outgoing,
                status: .pending
            ),

            // Recent incoming ping, responded to
            PingEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-45 * 60), // 45 minutes ago
                contactId: "4",
                contactName: "Emily Chen",
                direction: .incoming,
                status: .responded
            ),

            // Older outgoing ping, responded to
            PingEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-3 * 60 * 60), // 3 hours ago
                contactId: "1",
                contactName: "John Doe",
                direction: .outgoing,
                status: .responded
            ),

            // Older incoming ping, responded to
            PingEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-6 * 60 * 60), // 6 hours ago
                contactId: "7",
                contactName: "Alex Thompson",
                direction: .incoming,
                status: .responded
            ),

            // Yesterday's outgoing ping, responded to
            PingEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-25 * 60 * 60), // 25 hours ago
                contactId: "2",
                contactName: "Jane Smith",
                direction: .outgoing,
                status: .responded
            ),

            // Yesterday's incoming ping, responded to
            PingEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-30 * 60 * 60), // 30 hours ago
                contactId: "3",
                contactName: "Bob Johnson",
                direction: .incoming,
                status: .responded
            ),

            // Older outgoing ping, still pending (unusual case)
            PingEvent(
                id: UUID().uuidString,
                timestamp: Date().addingTimeInterval(-48 * 60 * 60), // 2 days ago
                contactId: "6",
                contactName: "Olivia Wilson",
                direction: .outgoing,
                status: .pending
            )
        ]
    }

    // MARK: - Methods

    /// Send a ping to a contact
    /// - Parameter contact: The contact to ping
    func sendPing(to contact: Contact) {
        showPingConfirmation = false
        isSending = true

        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isSending = false

            // Update the user view model
            self.userViewModel.pingDependent(contact)

            // Add to history
            self.pingHistory.insert(
                PingEvent(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    contactId: contact.id,
                    contactName: contact.name,
                    direction: .outgoing,
                    status: .pending
                ),
                at: 0
            )
        }
    }

    /// Respond to a ping
    /// - Parameter pingId: The ping ID
    func respondToPing(pingId: String) {
        // Find the ping in history
        if let index = pingHistory.firstIndex(where: { $0.id == pingId }) {
            pingHistory[index].status = .responded
        }
    }

    /// Update the user view model
    /// - Parameter userViewModel: The user view model
    func updateUserViewModel(_ userViewModel: UserViewModel) {
        self.userViewModel = userViewModel
    }
}

/// A ping event
struct PingEvent: Identifiable, Equatable {
    /// The ping ID
    var id: String

    /// The ping timestamp
    var timestamp: Date

    /// The contact ID
    var contactId: String

    /// The contact name
    var contactName: String

    /// The ping direction
    var direction: PingDirection

    /// The ping status
    var status: PingStatus
}

/// Ping directions
enum PingDirection: String, CaseIterable, Identifiable {
    /// An outgoing ping
    case outgoing = "Outgoing"

    /// An incoming ping
    case incoming = "Incoming"

    /// The direction ID
    var id: String { self.rawValue }
}

/// Ping statuses
enum PingStatus: String, CaseIterable, Identifiable {
    /// A pending ping
    case pending = "Pending"

    /// A responded ping
    case responded = "Responded"

    /// The status ID
    var id: String { self.rawValue }
}
