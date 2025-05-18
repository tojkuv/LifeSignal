import SwiftUI
import Foundation
import UIKit

class ContactDetailsSheetViewModel: ObservableObject {
    // MARK: - Published Properties

    // Contact data
    @Published var contactID: String
    @Published var isResponder: Bool
    @Published var isDependent: Bool
    @Published var lastValidRoles: (Bool, Bool)
    @Published var originalList: String
    @Published var shouldDismiss: Bool = false
    @Published var refreshID = UUID() // Used to force refresh the view

    // Alert states
    @Published var showDeleteAlert = false
    @Published var activeAlert: ContactAlertType?
    @Published var pendingRoleChange: (RoleChanged, Bool)?
    @Published var pendingToggleRevert: RoleChanged?

    // Mock contacts data (to replace UserViewModel dependency)
    private var contacts: [Contact] = Contact.mockContacts()

    // MARK: - Computed Properties

    var contact: Contact? {
        return contacts.first(where: { $0.id == contactID })
    }

    // MARK: - Initialization

    init(contact: Contact) {
        self.contactID = contact.id
        self.isResponder = contact.isResponder
        self.isDependent = contact.isDependent
        self.lastValidRoles = (contact.isResponder, contact.isDependent)

        // Determine which list the contact was opened from
        if contact.isResponder && contact.isDependent {
            self.originalList = "both"
        } else if contact.isResponder {
            self.originalList = "responders"
        } else {
            self.originalList = "dependents"
        }
    }

    // MARK: - Methods

    func handleAction(_ type: ActionButtonType) {
        HapticFeedback.triggerHaptic()
        switch type {
        case .call: callContact()
        case .message: messageContact()
        case .ping: activeAlert = .ping // Show confirmation dialog before pinging
        }
    }

    func callContact() {
        guard let currentContact = contact else { return }
        if let url = URL(string: "tel://\(currentContact.phone)") {
            UIApplication.shared.open(url)
        }
    }

    func messageContact() {
        guard let currentContact = contact else { return }
        if let url = URL(string: "sms://\(currentContact.phone)") {
            UIApplication.shared.open(url)
        }
    }

    func pingContact() {
        HapticFeedback.notificationFeedback(type: .success)
        guard let currentContact = contact, currentContact.isDependent else { return }

        // Update the contact in our local contacts array
        if let index = contacts.firstIndex(where: { $0.id == currentContact.id }) {
            if currentContact.hasOutgoingPing {
                // Clear outgoing ping
                contacts[index].hasOutgoingPing = false
                contacts[index].outgoingPingTimestamp = nil

                // Show a notification for clearing the ping
                NotificationManager.shared.showSilentLocalNotification(
                    title: "Ping Cleared",
                    body: "You have cleared the ping to \(currentContact.name).",
                    type: .pingNotification
                )
            } else {
                // Send new ping
                contacts[index].hasOutgoingPing = true
                contacts[index].outgoingPingTimestamp = Date()

                // Show a notification for sending the ping
                NotificationManager.shared.showPingNotification(contactName: currentContact.name)
            }
        }

        // Force refresh the view after a short delay to allow the view model to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Force refresh the view
            self.refreshID = UUID()
        }

        // Post notification to refresh other views
        NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("RefreshRespondersView"), object: nil)
    }

    func applyRoleChange() {
        // Apply the pending role change if it exists
        if let (changed, newValue) = pendingRoleChange {
            // Check if this would remove the last role
            if !newValue && ((changed == .responder && !isDependent) || (changed == .dependent && !isResponder)) {
                // Can't remove the last role, show alert with OK button
                pendingRoleChange = nil
                pendingToggleRevert = changed
                activeAlert = .role
                return
            }

            // Apply the change
            if changed == .responder {
                isResponder = newValue
            } else {
                isDependent = newValue
            }

            // Clear the pending change
            pendingRoleChange = nil

            // Update the contact in our local contacts array
            updateContactRoles()

            // Show a silent notification for the role change
            if let contact = contact {
                let roleName = changed == .responder ? "Responder" : "Dependent"
                let action = newValue ? "added" : "removed"

                NotificationManager.shared.showContactRoleToggleNotification(
                    contactName: contact.name,
                    isResponder: isResponder,
                    isDependent: isDependent
                )
            }
        }
    }

    func updateContactRoles() {
        guard let currentContact = contact else {
            print("Cannot update roles: contact not found")
            return
        }

        // Store the previous roles for logging
        let wasResponder = currentContact.isResponder
        let wasDependent = currentContact.isDependent

        // Update the local state
        lastValidRoles = (isResponder, isDependent)

        print("\n==== ROLE CHANGE ====\nRole change for contact: \(currentContact.name)")
        print("  Before: responder=\(wasResponder), dependent=\(wasDependent)")
        print("  After: responder=\(isResponder), dependent=\(isDependent)")

        // Check if we're removing the contact from its original list
        let removingFromOriginalList =
            (originalList == "responders" && wasResponder && !isResponder) ||
            (originalList == "dependents" && wasDependent && !isDependent)

        // If we're removing from original list, log it
        if removingFromOriginalList {
            print("  Contact will be removed from its original list (\(originalList))")
            // Set shouldDismiss to true if removing from original list
            shouldDismiss = true
        }

        // If dependent role was turned off, clear any active pings
        let shouldClearPings = wasDependent && !isDependent && currentContact.hasOutgoingPing

        // Update the contact in our local contacts array
        if let index = contacts.firstIndex(where: { $0.id == currentContact.id }) {
            contacts[index].isResponder = isResponder
            contacts[index].isDependent = isDependent

            // If dependent role was turned off, clear any active pings
            if shouldClearPings {
                contacts[index].hasOutgoingPing = false
                contacts[index].outgoingPingTimestamp = nil
                print("  Cleared outgoing ping because dependent role was turned off")
            }
        }

        // Force refresh the view after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Force refresh the view
            self.refreshID = UUID()
        }

        // Post notification to refresh other views
        NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("RefreshRespondersView"), object: nil)

        print("Contact sheet refreshed after role change")
        print("  Contact: \(currentContact.name)")
        print("  Roles: responder=\(isResponder), dependent=\(isDependent)\n==== END ROLE CHANGE ====\n")
    }

    func deleteContact() {
        guard let currentContact = contact else {
            print("Cannot delete contact: contact not found")
            return
        }

        // Remove the contact from our local contacts array
        contacts.removeAll { $0.id == currentContact.id }

        // Show a notification for removing a contact
        NotificationManager.shared.showContactRemovedNotification(contactName: currentContact.name)

        // Post notification to refresh other views
        NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("RefreshRespondersView"), object: nil)
    }

    // MARK: - Helper Methods

    func formatTimeAgo(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)

        if let day = components.day, day > 0 {
            return day == 1 ? "Yesterday" : "\(day) days ago"
        } else if let hour = components.hour, hour > 0 {
            return hour == 1 ? "1 hour ago" : "\(hour) hours ago"
        } else if let minute = components.minute, minute > 0 {
            return minute == 1 ? "1 minute ago" : "\(minute) minutes ago"
        } else {
            return "Just now"
        }
    }

    func formatInterval(_ interval: TimeInterval) -> String {
        let days = Int(interval / (24 * 60 * 60))
        let hours = Int((interval.truncatingRemainder(dividingBy: 24 * 60 * 60)) / (60 * 60))
        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s")"
        } else {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
    }

    func isNotResponsive(_ contact: Contact?) -> Bool {
        guard let contact = contact else { return false }

        // Special case for Bob Johnson - only show as non-responsive if interval has expired
        if contact.name == "Bob Johnson" {
            // Check if interval has expired for Bob Johnson
            let defaultInterval: TimeInterval = 24 * 60 * 60
            let intervalToUse = contact.interval ?? defaultInterval
            if let last = contact.lastCheckIn {
                return last.addingTimeInterval(intervalToUse) < Date()
            } else {
                return true
            }
        }

        // Always check if countdown is expired, regardless of manual alert status
        let defaultInterval: TimeInterval = 24 * 60 * 60
        let intervalToUse = contact.interval ?? defaultInterval
        if let last = contact.lastCheckIn {
            return last.addingTimeInterval(intervalToUse) < Date()
        } else {
            return true
        }
    }
}

enum RoleChanged { case dependent, responder }

enum ActionButtonType: CaseIterable {
    case call, message, ping

    // Used for ForEach identification
    var _id: String {
        switch self {
        case .call: return "call"
        case .message: return "message"
        case .ping: return "ping"
        }
    }

    // Helper to determine if the button should be disabled
    func isDisabled(for contact: Contact) -> Bool {
        if self == .ping && !contact.isDependent {
            return true
        }
        return false
    }

    func icon(for contact: Contact) -> String {
        switch self {
        case .call: return "phone"
        case .message: return "message"
        case .ping:
            // Only show filled bell for dependents with outgoing pings
            if contact.isDependent {
                // Force evaluation with refreshID to ensure updates
                let _ = UUID() // This is just to silence the compiler warning
                return contact.hasOutgoingPing ? "bell.and.waves.left.and.right.fill" : "bell"
            } else {
                // For non-dependents, show a disabled bell icon
                return "bell.slash"
            }
        }
    }

    func label(for contact: Contact) -> String {
        switch self {
        case .call: return "Call"
        case .message: return "Message"
        case .ping:
            // Only show "Pinged" for dependents with outgoing pings
            if contact.isDependent {
                // Force evaluation with refreshID to ensure updates
                let _ = UUID() // This is just to silence the compiler warning
                return contact.hasOutgoingPing ? "Pinged" : "Ping"
            } else {
                // For non-dependents, show a disabled label
                return "Can't Ping"
            }
        }
    }
}
