import Foundation
import SwiftUI

/// View model for the responders screen
class RespondersViewModel: ObservableObject {
    // MARK: - Published Properties

    /// A UUID used to force refresh the view
    @Published var refreshID = UUID()

    /// Show clear all pings confirmation alert
    @Published var showClearAllPingsConfirmation = false

    /// Mock responders data
    @Published var responders: [Contact] = []

    /// Selected contact for detail sheet
    @Published var selectedContactID: ContactID? = nil

    // MARK: - Initialization

    init() {
        // Initialize with mock data
        self.responders = Contact.mockContacts().filter { $0.isResponder }
    }

    // MARK: - Methods

    /// Get sorted responders with pending pings at the top
    /// - Returns: Sorted array of responders
    func getSortedResponders() -> [Contact] {
        // Safety check - if responders is empty, return an empty array
        if responders.isEmpty {
            return []
        }

        // Partition into responders with incoming pings and others
        let (pendingPings, others) = responders.partitioned { $0.hasIncomingPing }

        // Sort pending pings by most recent incoming ping timestamp
        let sortedPendingPings = pendingPings.sorted {
            ($0.incomingPingTimestamp ?? .distantPast) > ($1.incomingPingTimestamp ?? .distantPast)
        }

        // Sort others alphabetically
        let sortedOthers = others.sorted { $0.name < $1.name }

        // Combine with pending pings at the top
        return sortedPendingPings + sortedOthers
    }

    /// Get the number of pending pings
    var pendingPingsCount: Int {
        responders.filter { $0.hasIncomingPing }.count
    }

    /// Respond to a ping from a contact
    /// - Parameter contact: The contact who sent the ping
    func respondToPing(from contact: Contact) {
        if let index = responders.firstIndex(where: { $0.id == contact.id }) {
            responders[index].hasIncomingPing = false
            responders[index].incomingPingTimestamp = nil
        }

        // Post notification to refresh other views
        NotificationCenter.default.post(name: NSNotification.Name("RefreshRespondersView"), object: nil)

        // Force UI update
        objectWillChange.send()

        // Show a silent local notification
        NotificationManager.shared.showAllPingsClearedNotification()
    }

    /// Respond to all pings
    func respondToAllPings() {
        for index in responders.indices where responders[index].hasIncomingPing {
            responders[index].hasIncomingPing = false
            responders[index].incomingPingTimestamp = nil
        }

        // Force refresh immediately
        refreshID = UUID()

        // Post notification to refresh other views
        NotificationCenter.default.post(name: NSNotification.Name("RefreshRespondersView"), object: nil)

        // Force UI update
        objectWillChange.send()

        // Show a silent local notification
        NotificationManager.shared.showAllPingsClearedNotification()
    }

    /// Debug print contacts
    func debugPrintContacts() {
        print("\n===== DEBUG: RESPONDERS =====")
        for (index, contact) in responders.enumerated() {
            print("\(index): \(contact.name) - ID: \(contact.id) - Has Ping: \(contact.hasIncomingPing)")
        }
        print("==============================\n")
    }
}