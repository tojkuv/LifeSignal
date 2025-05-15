import Foundation
import SwiftUI
import Combine

/// View model for user data
/// This class is designed to mirror the structure of UserFeature.State in the TCA implementation
class UserViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The user's ID
    @Published var id: String = UUID().uuidString

    /// The user's name
    @Published var name: String = "John Doe"

    /// The user's phone number
    @Published var phone: String = "+1 (555) 123-4567"

    /// The user's QR code ID
    @Published var qrCodeId: String = UUID().uuidString

    /// The user's emergency profile description
    @Published var profileDescription: String = "Emergency contact information and medical details"

    /// The user's last check-in time
    @Published var lastCheckIn: Date = Date().addingTimeInterval(-3600) // 1 hour ago

    /// The user's check-in interval in seconds
    @Published var checkInInterval: TimeInterval = 24 * 60 * 60 // 24 hours

    /// The user's check-in expiration time
    var checkInExpiration: Date {
        return lastCheckIn.addingTimeInterval(checkInInterval)
    }

    /// Whether the user has notifications enabled
    @Published var notificationsEnabled: Bool = true

    /// Whether to notify 30 minutes before check-in expiration
    @Published var notify30MinBefore: Bool = true

    /// Whether to notify 2 hours before check-in expiration
    @Published var notify2HoursBefore: Bool = true

    /// Whether the user has an active alert
    @Published var isAlertActive: Bool = false

    /// The user's contacts
    @Published var contacts: [Contact] = Contact.mockContacts()

    /// The user's responders (contacts who are responders)
    var responders: [Contact] {
        contacts.filter { $0.isResponder }
    }

    /// The user's dependents (contacts who are dependents)
    var dependents: [Contact] {
        contacts.filter { $0.isDependent }
    }

    /// The number of pending pings
    var pendingPingsCount: Int {
        responders.filter { $0.hasIncomingPing }.count
    }

    /// The number of non-responsive dependents
    var nonResponsiveDependentsCount: Int {
        dependents.filter { $0.isNonResponsive || $0.manualAlertActive }.count
    }

    // MARK: - Initialization

    init() {
        // In a real app, we would load user data from a service
    }

    // MARK: - Methods

    /// Check in the user
    func checkIn() {
        lastCheckIn = Date()
        // In a real app, we would update the server
    }

    /// Update the user's check-in interval
    /// - Parameter interval: The new interval in seconds
    func updateCheckInInterval(_ interval: TimeInterval) {
        checkInInterval = interval
        // In a real app, we would update the server
    }

    /// Generate a new QR code ID
    func generateNewQRCode() {
        qrCodeId = UUID().uuidString
        // In a real app, we would update the server
    }

    /// Add a new contact
    /// - Parameter contact: The contact to add
    func addContact(_ contact: Contact) {
        contacts.append(contact)
        // In a real app, we would update the server
    }

    /// Update a contact
    /// - Parameters:
    ///   - id: The ID of the contact to update
    ///   - updates: A closure that updates the contact
    func updateContact(id: String, updates: (inout Contact) -> Void) {
        if let index = contacts.firstIndex(where: { $0.id == id }) {
            var contact = contacts[index]
            updates(&contact)
            contacts[index] = contact
            // In a real app, we would update the server
        }
    }

    /// Remove a contact
    /// - Parameter id: The ID of the contact to remove
    func removeContact(id: String) {
        contacts.removeAll { $0.id == id }
        // In a real app, we would update the server
    }

    /// Toggle the responder role for a contact
    /// - Parameter id: The ID of the contact
    func toggleResponderRole(for id: String) {
        updateContact(id: id) { contact in
            contact.isResponder.toggle()
        }
    }

    /// Toggle the dependent role for a contact
    /// - Parameter id: The ID of the contact
    func toggleDependentRole(for id: String) {
        updateContact(id: id) { contact in
            contact.isDependent.toggle()
        }
    }

    /// Toggle the manual alert for a contact
    /// - Parameter id: The ID of the contact
    func toggleManualAlert(for id: String) {
        updateContact(id: id) { contact in
            contact.manualAlertActive.toggle()
        }
    }

    /// Respond to a ping from a contact
    /// - Parameter contact: The contact who sent the ping
    func respondToPing(from contact: Contact) {
        updateContact(id: contact.id) { contact in
            contact.hasIncomingPing = false
            contact.incomingPingTimestamp = nil
        }
    }

    /// Respond to a ping from a contact by ID
    /// - Parameter id: The ID of the contact
    func respondToPing(from id: String) {
        updateContact(id: id) { contact in
            contact.hasIncomingPing = false
            contact.incomingPingTimestamp = nil
        }
    }

    /// Send a ping to a contact
    /// - Parameter id: The ID of the contact
    func sendPing(to id: String) {
        updateContact(id: id) { contact in
            contact.hasOutgoingPing = true
            contact.outgoingPingTimestamp = Date()
        }
    }

    /// Ping a dependent
    /// - Parameter contact: The dependent to ping
    func pingDependent(_ contact: Contact) {
        updateContact(id: contact.id) { contact in
            contact.hasOutgoingPing = true
            contact.outgoingPingTimestamp = Date()
        }
    }

    /// Clear a ping for a contact
    /// - Parameter contact: The contact to clear the ping for
    func clearPing(for contact: Contact) {
        updateContact(id: contact.id) { contact in
            contact.hasOutgoingPing = false
            contact.outgoingPingTimestamp = nil
        }
    }

    /// Update the last checked in time
    func updateLastCheckedIn() {
        lastCheckIn = Date()
    }
}
