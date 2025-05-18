import Foundation
import SwiftUI
import Combine
import UserNotifications
import UIKit

/// View model for user data
/// This class is designed to mirror the structure of UserFeature.State in the TCA implementation
class UserViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The user's ID
    @Published var id: String = "user-"+UUID().uuidString

    /// The user's name
    @Published var name: String = "Sarah Johnson"

    /// The user's phone number
    @Published var phone: String = "+1 (555) 987-6543"

    /// The user's QR code ID
    @Published var qrCodeId: String = UUID().uuidString.uppercased()

    /// The user's emergency profile description
    @Published var profileDescription: String = "I have type 1 diabetes. My insulin and supplies are in the refrigerator. Emergency contacts: Mom (555-111-2222), Roommate Jen (555-333-4444). Allergic to penicillin. My doctor is Dr. Martinez at City Medical Center (555-777-8888)."

    /// The user's last check-in time
    @Published var lastCheckIn: Date = Date().addingTimeInterval(-5 * 60 * 60) // 5 hours ago

    /// The user's check-in interval in seconds
    @Published var checkInInterval: TimeInterval = 12 * 60 * 60 // 12 hours

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

    /// Whether the user has enabled sending alerts to responders
    @Published var sendAlertActive: Bool = false

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

    /// Debug function to print all contacts and their roles
    func debugPrintContacts() {
        print("\n===== DEBUG: ALL CONTACTS =====")
        for (index, contact) in contacts.enumerated() {
            print("\(index): \(contact.name) - ID: \(contact.id) - Responder: \(contact.isResponder) - Dependent: \(contact.isDependent)")
        }
        print("===== DEBUG: RESPONDERS =====")
        for (index, contact) in responders.enumerated() {
            print("\(index): \(contact.name) - ID: \(contact.id)")
        }
        print("===== DEBUG: DEPENDENTS =====")
        for (index, contact) in dependents.enumerated() {
            print("\(index): \(contact.name) - ID: \(contact.id)")
        }
        print("==============================\n")
    }

    /// The number of pending pings
    var pendingPingsCount: Int {
        responders.filter { $0.hasIncomingPing }.count
    }

    /// The number of non-responsive dependents
    var nonResponsiveDependentsCount: Int {
        dependents.filter { $0.isNonResponsive || $0.manualAlertActive }.count
    }

    /// Whether to show the alert confirmation dialog
    @Published var showAlertConfirmation: Bool = false

    /// Whether to show the QR code sheet
    @Published var showQRCodeSheet: Bool = false

    /// The user's avatar image
    @Published var avatarImage: UIImage? = nil

    /// Whether the user is using the default avatar
    var isUsingDefaultAvatar: Bool {
        return avatarImage == nil
    }

    // MARK: - Initialization

    init() {
        // Load persisted data from UserDefaults
        loadPersistedData()
    }

    // MARK: - Methods

    /// Check in the user
    func checkIn() {
        lastCheckIn = Date()

        // Save to UserDefaults
        UserDefaults.standard.set(lastCheckIn, forKey: "lastCheckIn")
        UserDefaults.standard.set(checkInExpiration, forKey: "checkInExpiration")

        // Force UI update
        objectWillChange.send()

        // Show a silent notification for check-in
        NotificationManager.shared.showCheckInNotification()

        // In a real app, we would update the server
    }

    /// Update the user's check-in interval
    /// - Parameter interval: The new interval in seconds
    func updateCheckInInterval(_ interval: TimeInterval) {
        checkInInterval = interval

        // Save to UserDefaults
        UserDefaults.standard.set(interval, forKey: "checkInInterval")

        // Force UI update
        objectWillChange.send()

        // In a real app, we would update the server
    }

    /// Update notification preferences
    /// - Parameters:
    ///   - notify30Min: Whether to notify 30 minutes before check-in expiration
    ///   - notify2Hours: Whether to notify 2 hours before check-in expiration
    func updateNotificationPreferences(notify30Min: Bool, notify2Hours: Bool) {
        notify30MinBefore = notify30Min
        notify2HoursBefore = notify2Hours

        // Save to UserDefaults
        UserDefaults.standard.set(notify30Min, forKey: "notify30MinBefore")
        UserDefaults.standard.set(notify2Hours, forKey: "notify2HoursBefore")

        // Force UI update
        objectWillChange.send()

        // In a real app, we would update the server
    }

    /// Generate a new QR code ID
    func generateNewQRCode() {
        // Generate a new UUID in the format 1B987C92-73FC-4425-A11B-CBE41D2C0FF9
        qrCodeId = UUID().uuidString.uppercased()
        // In a real app, we would update the server
    }

    /// Add a new contact
    /// - Parameter contact: The contact to add
    func addContact(_ contact: Contact) {
        contacts.append(contact)
        // Show a notification for adding a contact
        NotificationManager.shared.showContactAddedNotification(contactName: contact.name)
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

            // Save to UserDefaults
            saveContactDetails()

            // In a real app, we would update the server
        }
    }

    /// Remove a contact
    /// - Parameter id: The ID of the contact to remove
    func removeContact(id: String) {
        // Get the contact name before removing
        let contactName = contacts.first(where: { $0.id == id })?.name ?? "Unknown contact"

        // Remove the contact
        contacts.removeAll { $0.id == id }

        // Show a notification for removing a contact
        NotificationManager.shared.showContactRemovedNotification(contactName: contactName)

        // In a real app, we would update the server
    }

    /// Toggle the responder role for a contact
    /// - Parameter id: The ID of the contact
    func toggleResponderRole(for id: String) {
        updateContact(id: id) { contact in
            contact.isResponder.toggle()
        }

        // Save to UserDefaults
        saveContactRoles()

        // Show a silent notification
        if let contact = contacts.first(where: { $0.id == id }) {
            NotificationManager.shared.showContactRoleToggleNotification(
                contactName: contact.name,
                isResponder: contact.isResponder,
                isDependent: contact.isDependent
            )
        }
    }

    /// Toggle the dependent role for a contact
    /// - Parameter id: The ID of the contact
    func toggleDependentRole(for id: String) {
        updateContact(id: id) { contact in
            contact.isDependent.toggle()
        }

        // Save to UserDefaults
        saveContactRoles()

        // Show a silent notification
        if let contact = contacts.first(where: { $0.id == id }) {
            NotificationManager.shared.showContactRoleToggleNotification(
                contactName: contact.name,
                isResponder: contact.isResponder,
                isDependent: contact.isDependent
            )
        }
    }

    /// Toggle the manual alert for a contact
    /// - Parameter id: The ID of the contact
    func toggleManualAlert(for id: String) {
        updateContact(id: id) { contact in
            contact.manualAlertActive.toggle()
            contact.manualAlertTimestamp = contact.manualAlertActive ? Date() : nil
        }

        // Save to UserDefaults
        saveContactAlertStates()

        // Show a silent notification
        if let contact = contacts.first(where: { $0.id == id }) {
            let status = contact.manualAlertActive ? "activated" : "cleared"
            showSilentLocalNotification(title: "Alert Status", body: "Manual alert for \(contact.name) has been \(status).", type: .manualAlert)
        }
    }

    /// Respond to a ping from a contact
    /// - Parameter contact: The contact who sent the ping
    func respondToPing(from contact: Contact) {
        updateContact(id: contact.id) { contact in
            contact.hasIncomingPing = false
            contact.incomingPingTimestamp = nil
        }

        // Save to UserDefaults
        savePingStates()

        // Notify that a ping was responded to
        NotificationCenter.default.post(name: NSNotification.Name("PingResponded"), object: nil, userInfo: ["contactId": contact.id])

        // Force UI update
        objectWillChange.send()
    }

    /// Respond to a ping from a contact by ID
    /// - Parameter id: The ID of the contact
    func respondToPing(from id: String) {
        updateContact(id: id) { contact in
            contact.hasIncomingPing = false
            contact.incomingPingTimestamp = nil
        }

        // Save to UserDefaults
        savePingStates()

        // Notify that a ping was responded to
        NotificationCenter.default.post(name: NSNotification.Name("PingResponded"), object: nil, userInfo: ["contactId": id])

        // Force UI update
        objectWillChange.send()
    }

    /// Send a ping to a contact
    /// - Parameter id: The ID of the contact
    func sendPing(to id: String) {
        updateContact(id: id) { contact in
            contact.hasOutgoingPing = true
            contact.outgoingPingTimestamp = Date()
        }

        // Save to UserDefaults
        savePingStates()

        // Show a silent notification
        if let contact = contacts.first(where: { $0.id == id }) {
            showSilentLocalNotification(title: "Ping Sent", body: "You sent a ping to \(contact.name).", type: .pingNotification)
        }
    }

    /// Ping a dependent
    /// - Parameter contact: The dependent to ping
    func pingDependent(_ contact: Contact) {
        updateContact(id: contact.id) { contact in
            contact.hasOutgoingPing = true
            contact.outgoingPingTimestamp = Date()
        }

        // Save to UserDefaults
        savePingStates()

        // Notify that a ping was sent
        NotificationCenter.default.post(name: NSNotification.Name("PingSent"), object: nil, userInfo: ["contactId": contact.id])

        // Show a silent local notification
        NotificationManager.shared.showPingNotification(contactName: contact.name)

        // Force UI update
        objectWillChange.send()
    }

    /// Clear a ping for a contact
    /// - Parameter contact: The contact to clear the ping for
    func clearPing(for contact: Contact) {
        updateContact(id: contact.id) { contact in
            contact.hasOutgoingPing = false
            contact.outgoingPingTimestamp = nil
        }

        // Save to UserDefaults
        savePingStates()

        // Notify that a ping was cleared
        NotificationCenter.default.post(name: NSNotification.Name("PingCleared"), object: nil, userInfo: ["contactId": contact.id])

        // Show a silent local notification
        showSilentLocalNotification(title: "Ping Cleared", body: "You cleared the ping to \(contact.name)", type: .pingNotification)

        // Force UI update
        objectWillChange.send()
    }

    /// Show a silent local notification
    /// - Parameters:
    ///   - title: The notification title
    ///   - body: The notification body
    ///   - type: The notification type
    private func showSilentLocalNotification(title: String, body: String, type: NotificationType) {
        // Use the NotificationManager to show a silent notification
        NotificationManager.shared.showSilentLocalNotification(title: title, body: body, type: type) { error in
            if let error = error {
                print("Error showing notification: \(error)")
            }
        }
    }

    // Note: updateLastCheckedIn has been replaced by the checkIn method

    /// Load persisted data from UserDefaults
    private func loadPersistedData() {
        // Load last check-in time
        if let lastCheckIn = UserDefaults.standard.object(forKey: "lastCheckIn") as? Date {
            self.lastCheckIn = lastCheckIn
        }

        // Load check-in interval
        if let checkInInterval = UserDefaults.standard.object(forKey: "checkInInterval") as? TimeInterval {
            self.checkInInterval = checkInInterval
        }

        // Load notification preferences
        if UserDefaults.standard.object(forKey: "notify30MinBefore") != nil {
            self.notify30MinBefore = UserDefaults.standard.bool(forKey: "notify30MinBefore")
        }

        if UserDefaults.standard.object(forKey: "notify2HoursBefore") != nil {
            self.notify2HoursBefore = UserDefaults.standard.bool(forKey: "notify2HoursBefore")
        }

        // Load send alert active state
        sendAlertActive = UserDefaults.standard.bool(forKey: "sendAlertActive")

        // Load avatar image if available
        loadAvatarImage()

        // Load contact roles and ping states
        if let contactRoles = UserDefaults.standard.dictionary(forKey: "contactRoles") as? [String: [String: Bool]] {
            for (contactId, roles) in contactRoles {
                if let index = contacts.firstIndex(where: { $0.id == contactId }) {
                    if let isResponder = roles["isResponder"] {
                        contacts[index].isResponder = isResponder
                    }
                    if let isDependent = roles["isDependent"] {
                        contacts[index].isDependent = isDependent
                    }
                }
            }
        }

        // Load ping states
        if let pingStates = UserDefaults.standard.dictionary(forKey: "pingStates") as? [String: [String: Any]] {
            for (contactId, state) in pingStates {
                if let index = contacts.firstIndex(where: { $0.id == contactId }) {
                    if let hasOutgoingPing = state["hasOutgoingPing"] as? Bool {
                        contacts[index].hasOutgoingPing = hasOutgoingPing
                    }
                    if let hasIncomingPing = state["hasIncomingPing"] as? Bool {
                        contacts[index].hasIncomingPing = hasIncomingPing
                    }
                    if let timestamp = state["outgoingPingTimestamp"] as? Date {
                        contacts[index].outgoingPingTimestamp = timestamp
                    }
                    if let timestamp = state["incomingPingTimestamp"] as? Date {
                        contacts[index].incomingPingTimestamp = timestamp
                    }
                }
            }
        }

        // Load alert states
        if let alertStates = UserDefaults.standard.dictionary(forKey: "alertStates") as? [String: [String: Any]] {
            for (contactId, state) in alertStates {
                if let index = contacts.firstIndex(where: { $0.id == contactId }) {
                    if let manualAlertActive = state["manualAlertActive"] as? Bool {
                        contacts[index].manualAlertActive = manualAlertActive
                    }
                    if let timestamp = state["manualAlertTimestamp"] as? Date {
                        contacts[index].manualAlertTimestamp = timestamp
                    }
                    if let isNonResponsive = state["isNonResponsive"] as? Bool {
                        contacts[index].isNonResponsive = isNonResponsive
                    }
                }
            }
        }

        // Load contact details
        if let contactDetails = UserDefaults.standard.dictionary(forKey: "contactDetails") as? [String: [String: Any]] {
            for (contactId, details) in contactDetails {
                if let index = contacts.firstIndex(where: { $0.id == contactId }) {
                    if let name = details["name"] as? String {
                        contacts[index].name = name
                    }
                    if let phone = details["phone"] as? String {
                        contacts[index].phone = phone
                    }
                    if let note = details["note"] as? String {
                        contacts[index].note = note
                    }
                    if let lastCheckIn = details["lastCheckIn"] as? Date {
                        contacts[index].lastCheckIn = lastCheckIn
                    }
                    if let checkInInterval = details["checkInInterval"] as? TimeInterval {
                        contacts[index].checkInInterval = checkInInterval
                    }
                }
            }
        }
    }

    /// Save contact roles to UserDefaults
    private func saveContactRoles() {
        var contactRoles: [String: [String: Bool]] = [:]

        for contact in contacts {
            contactRoles[contact.id] = [
                "isResponder": contact.isResponder,
                "isDependent": contact.isDependent
            ]
        }

        UserDefaults.standard.set(contactRoles, forKey: "contactRoles")
    }

    /// Save ping states to UserDefaults
    private func savePingStates() {
        var pingStates: [String: [String: Any]] = [:]

        for contact in contacts {
            var state: [String: Any] = [
                "hasOutgoingPing": contact.hasOutgoingPing,
                "hasIncomingPing": contact.hasIncomingPing
            ]

            if let timestamp = contact.outgoingPingTimestamp {
                state["outgoingPingTimestamp"] = timestamp
            }

            if let timestamp = contact.incomingPingTimestamp {
                state["incomingPingTimestamp"] = timestamp
            }

            pingStates[contact.id] = state
        }

        UserDefaults.standard.set(pingStates, forKey: "pingStates")
    }

    /// Save alert states to UserDefaults
    private func saveContactAlertStates() {
        var alertStates: [String: [String: Any]] = [:]

        for contact in contacts {
            var state: [String: Any] = [
                "manualAlertActive": contact.manualAlertActive,
                "isNonResponsive": contact.isNonResponsive
            ]

            if let timestamp = contact.manualAlertTimestamp {
                state["manualAlertTimestamp"] = timestamp
            }

            alertStates[contact.id] = state
        }

        UserDefaults.standard.set(alertStates, forKey: "alertStates")
    }

    /// Save contact details to UserDefaults
    private func saveContactDetails() {
        var contactDetails: [String: [String: Any]] = [:]

        for contact in contacts {
            var details: [String: Any] = [
                "name": contact.name,
                "phone": contact.phone,
                "note": contact.note,
                "lastCheckIn": contact.lastCheckIn
            ]

            if let checkInInterval = contact.checkInInterval {
                details["checkInInterval"] = checkInInterval
            }

            contactDetails[contact.id] = details
        }

        UserDefaults.standard.set(contactDetails, forKey: "contactDetails")
    }

    /// Trigger an alert to responders
    func triggerAlert() {
        isAlertActive = true

        // Show a silent notification for alert activation that is tracked in the notification center
        NotificationManager.shared.showSilentLocalNotification(
            title: "Alert Activated",
            body: "You have activated an alert. Your responders have been notified.",
            type: .manualAlert
        )
    }

    /// Toggle the send alert active state
    /// - Parameter active: The new state
    func toggleSendAlertActive(_ active: Bool) {
        sendAlertActive = active

        // Save to UserDefaults
        UserDefaults.standard.set(sendAlertActive, forKey: "sendAlertActive")

        // Show appropriate silent notification based on the state change that is tracked in the notification center
        if active {
            // Alert was activated
            NotificationManager.shared.showSilentLocalNotification(
                title: "Alert Activated",
                body: "You have activated an alert. Your responders have been notified.",
                type: .manualAlert
            )
        } else {
            // Alert was deactivated
            NotificationManager.shared.showSilentLocalNotification(
                title: "Alert Deactivated",
                body: "You have deactivated your alert.",
                type: .manualAlert
            )
        }
    }

    // MARK: - Avatar Methods

    /// Set the user's avatar image
    /// - Parameter image: The new avatar image
    func setAvatarImage(_ image: UIImage) {
        self.avatarImage = image
        saveAvatarImage(image)
    }

    /// Delete the user's avatar image
    func deleteAvatarImage() {
        self.avatarImage = nil
        removeAvatarImage()
        // Add haptic feedback when deleting avatar
        HapticFeedback.notificationFeedback(type: .success)
    }

    /// Save the avatar image to UserDefaults
    /// - Parameter image: The image to save
    private func saveAvatarImage(_ image: UIImage) {
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            UserDefaults.standard.set(imageData, forKey: "userAvatarImage")
        }
    }

    /// Load the avatar image from UserDefaults
    private func loadAvatarImage() {
        if let imageData = UserDefaults.standard.data(forKey: "userAvatarImage") {
            self.avatarImage = UIImage(data: imageData)
        }
    }

    /// Remove the avatar image from UserDefaults
    private func removeAvatarImage() {
        UserDefaults.standard.removeObject(forKey: "userAvatarImage")
    }

    /// Reset user data when signing out
    func resetUserData() {
        // Clear any user-specific data from UserDefaults
        UserDefaults.standard.removeObject(forKey: "lastCheckIn")
        UserDefaults.standard.removeObject(forKey: "checkInExpiration")
        UserDefaults.standard.removeObject(forKey: "checkInInterval")
        UserDefaults.standard.removeObject(forKey: "notify30MinBefore")
        UserDefaults.standard.removeObject(forKey: "notify2HoursBefore")
        UserDefaults.standard.removeObject(forKey: "userAvatarImage")
        UserDefaults.standard.removeObject(forKey: "contactRoles")
        UserDefaults.standard.removeObject(forKey: "pingStates")
        UserDefaults.standard.removeObject(forKey: "alertStates")
        UserDefaults.standard.removeObject(forKey: "contactDetails")

        // Reset in-memory state
        avatarImage = nil
        isAlertActive = false
        sendAlertActive = false
        contacts = Contact.mockContacts() // Reset to default mock contacts
        lastCheckIn = Date().addingTimeInterval(-5 * 60 * 60) // Reset to default
        checkInInterval = 12 * 60 * 60 // Reset to default
        notify30MinBefore = true // Reset to default
        notify2HoursBefore = true // Reset to default
    }
}
