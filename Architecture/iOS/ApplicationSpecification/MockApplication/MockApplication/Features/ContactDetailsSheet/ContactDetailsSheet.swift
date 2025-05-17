import SwiftUI
import Foundation
import UIKit


struct ContactDetailsSheet: View {
    let contactID: String // Store the contact ID instead of a binding
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var userViewModel: UserViewModel
    @State private var showDeleteAlert = false
    @State private var isResponder: Bool
    @State private var isDependent: Bool
    @State private var showRoleAlert = false
    @State private var lastValidRoles: (Bool, Bool)
    @State private var activeAlert: ContactAlertType?
    @State private var pendingRoleChange: (RoleChanged, Bool)?
    @State private var pendingToggleRevert: RoleChanged?
    @State private var refreshID = UUID() // Used to force refresh the view
    @State private var shouldDismiss = false // Flag to indicate when sheet should dismiss
    @State private var originalList: String // Tracks which list the contact was opened from

    // Computed property to find the contact in the view model's contacts list
    private var contact: Contact? {
        return userViewModel.contacts.first(where: { $0.id == contactID })
    }

    init(contact: Contact) {
        self.contactID = contact.id
        self._isResponder = State(initialValue: contact.isResponder)
        self._isDependent = State(initialValue: contact.isDependent)
        self._lastValidRoles = State(initialValue: (contact.isResponder, contact.isDependent))

        // Determine which list the contact was opened from
        if contact.isResponder && contact.isDependent {
            self._originalList = State(initialValue: "both")
        } else if contact.isResponder {
            self._originalList = State(initialValue: "responders")
        } else {
            self._originalList = State(initialValue: "dependents")
        }
    }

    // MARK: - Contact Dismissed View
    private var contactDismissedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Contact role updated")
                .font(.headline)
            Text("This contact has been moved to a different list.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("Close") {
                HapticFeedback.triggerHaptic()
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            Spacer()
        }
        .padding()
        .onAppear {
            // Auto-dismiss after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }

    // MARK: - Contact Header View
    private var contactHeaderView: some View {
        Group {
            if let contact = contact {
                VStack(spacing: 12) {
                    CommonAvatarView(
                        name: contact.name,
                        size: 100,
                        backgroundColor: Color.blue.opacity(0.1),
                        textColor: .blue,
                        strokeWidth: 2,
                        strokeColor: .blue
                    )
                        .padding(.top, 24)
                    Text(contact.name)
                        .font(.headline)
                        .bold()
                        .foregroundColor(.primary)
                    Text(contact.phone)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            } else {
                Text("Contact not found")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Action Buttons View
    private var actionButtonsView: some View {
        Group {
            if let contact = contact {
                HStack(spacing: 12) {
                    ForEach(ActionButtonType.allCases, id: \._id) { type in
                        Button(action: {
                            // Show alert for disabled ping button, otherwise handle action normally
                            if type == .ping && !contact.isDependent {
                                activeAlert = .pingDisabled
                            } else {
                                handleAction(type)
                            }
                        }) {
                            // Visual styling for ping button
                            VStack(spacing: 6) {
                                Image(systemName: type.icon(for: contact))
                                    .font(.system(size: 20))
                                    .foregroundColor(type == .ping && contact.isDependent && contact.hasOutgoingPing ? Color.blue.opacity(0.7) : .blue)
                                Text(type.label(for: contact))
                                    .font(.body)
                                    .foregroundColor(type == .ping && contact.isDependent && contact.hasOutgoingPing ? Color.blue.opacity(0.7) : .primary)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .frame(height: 75)
                            .background(
                                type == .ping && contact.isDependent && contact.hasOutgoingPing ?
                                    Color.blue.opacity(0.1) : Color(UIColor.secondarySystemGroupedBackground)
                            )
                            .cornerRadius(12)
                            .opacity(type == .ping && !contact.isDependent ? 0.5 : 1.0)
                        }
                    }
                }
                .padding(.horizontal)
            } else {
                EmptyView()
            }
        }
    }

    // MARK: - Alert Card Views
    private var manualAlertCardView: some View {
        Group {
            if let contact = contact, contact.manualAlertActive, let ts = contact.manualAlertTimestamp {
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sent out an Alert")
                                .font(.body)
                                .foregroundColor(.red)

                            Text("This dependent has sent an emergency alert.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(formatTimeAgo(ts))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                }
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    private var pingCardView: some View {
        Group {
            if let contact = contact, contact.hasIncomingPing, let pingTime = contact.incomingPingTimestamp, contact.isResponder {
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pinged You")
                                .font(.body)
                                .foregroundColor(.blue)

                            Text("This contact has sent you a ping requesting a response.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(formatTimeAgo(pingTime))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                }
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    private var outgoingPingCardView: some View {
        Group {
            if let contact = contact, contact.hasOutgoingPing, let pingTime = contact.outgoingPingTimestamp {
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("You Pinged Them")
                                .font(.body)
                                .foregroundColor(.blue)

                            Text("You have sent a ping to this dependent.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(formatTimeAgo(pingTime))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                }
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    private var notResponsiveCardView: some View {
        Group {
            if let contact = contact, isNotResponsive(contact) {
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Non-responsive")
                                .font(.body)
                                .foregroundColor(Environment(\.colorScheme).wrappedValue == .light ? Color(UIColor.systemOrange) : .yellow)

                            Text("This dependent has not checked in within their scheduled interval.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if let lastCheckIn = contact.lastCheckIn {
                            let defaultInterval: TimeInterval = 24 * 60 * 60
                            let intervalToUse = contact.interval ?? defaultInterval
                            let expiration = lastCheckIn.addingTimeInterval(intervalToUse)
                            Text(formatTimeAgo(expiration))
                                .font(.body)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Never")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                }
                .background(Environment(\.colorScheme).wrappedValue == .light ? Color.orange.opacity(0.15) : Color.yellow.opacity(0.15))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Information Card Views
    private var noteCardView: some View {
        Group {
            if let contact = contact {
                VStack(spacing: 0) {
                    HStack {
                        Text(contact.note.isEmpty ? "No emergency information provided yet." : contact.note)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    private var rolesCardView: some View {
        Group {
            VStack(spacing: 0) {
                HStack {
                    Text("Dependent")
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    Toggle("", isOn: $isDependent)
                        .labelsHidden()
                        .onChange(of: isDependent) { oldValue, newValue in
                            HapticFeedback.selectionFeedback()
                            // Show confirmation dialog for role toggle
                            if newValue != oldValue {
                                pendingRoleChange = (.dependent, newValue)
                                isDependent = oldValue // Revert until confirmed
                                activeAlert = .roleToggle
                            }
                        }
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
                Divider().padding(.leading)
                HStack {
                    Text("Responder")
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    Toggle("", isOn: $isResponder)
                        .labelsHidden()
                        .onChange(of: isResponder) { oldValue, newValue in
                            HapticFeedback.selectionFeedback()
                            // Show confirmation dialog for role toggle
                            if newValue != oldValue {
                                pendingRoleChange = (.responder, newValue)
                                isResponder = oldValue // Revert until confirmed
                                activeAlert = .roleToggle
                            }
                        }
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    private var checkInCardView: some View {
        Group {
            if let contact = contact {
                VStack(spacing: 0) {
                    HStack {
                        Text("Check-in interval")
                            .foregroundColor(.primary)
                            .font(.body)
                        Spacer()
                        let defaultInterval: TimeInterval = 24 * 60 * 60
                        let intervalToUse = contact.interval ?? defaultInterval
                        Text(formatInterval(intervalToUse))
                            .foregroundColor(.secondary)
                            .font(.body)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                    Divider().padding(.leading)
                    HStack {
                        Text("Last check-in")
                            .foregroundColor(.primary)
                            .font(.body)
                        Spacer()
                        if let lastCheckIn = contact.lastCheckIn {
                            Text(formatTimeAgo(lastCheckIn))
                                .foregroundColor(.secondary)
                                .font(.body)
                        } else {
                            Text("Never")
                                .foregroundColor(.secondary)
                                .font(.body)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    private var deleteButtonView: some View {
        Group {
            if contact != nil {
                Button(action: {
                    HapticFeedback.triggerHaptic()
                    activeAlert = .delete
                }) {
                    Text("Delete Contact")
                        .font(.body)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if shouldDismiss {
                    // Show a message when the contact is removed from its original list
                    contactDismissedView
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // This is a hidden view that will trigger a refresh when refreshID changes
                            Text("")
                                .frame(width: 0, height: 0)
                                .opacity(0)
                                .id(refreshID)

                            // Header
                            contactHeaderView

                            // Button Row (moved above note)
                            actionButtonsView

                            // Alert Cards
                            if let contact = contact {
                                // Manual alert card - only show for dependents (1st priority)
                                if contact.isDependent && contact.manualAlertActive {
                                    manualAlertCardView
                                }

                                // Non-responsive card - only show for dependents (2nd priority)
                                if contact.isDependent && isNotResponsive(contact) {
                                    notResponsiveCardView
                                }

                                // Ping card - incoming pings (3rd priority)
                                if contact.hasIncomingPing && contact.isResponder {
                                    pingCardView
                                }

                                // Outgoing pings (4th priority)
                                if contact.isDependent && contact.hasOutgoingPing {
                                    outgoingPingCardView
                                }
                            }

                            // Information Cards
                            noteCardView
                            rolesCardView
                            checkInCardView
                            deleteButtonView
                        }
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Contact Info")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert(item: $activeAlert) { alertType in
            switch alertType {
            case .role:
                return Alert(
                    title: Text("Role Required"),
                    message: Text("This contact must have at least one role. To remove this contact completely, use the Delete Contact button."),
                    dismissButton: .default(Text("OK")) {
                        if let pending = pendingToggleRevert {
                            switch pending {
                            case .dependent:
                                isDependent = lastValidRoles.1
                            case .responder:
                                isResponder = lastValidRoles.0
                            }
                            pendingToggleRevert = nil
                        }
                    }
                )
            case .delete:
                return Alert(
                    title: Text("Delete Contact"),
                    message: Text("Are you sure you want to delete this contact? This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) { deleteContact() },
                    secondaryButton: .cancel()
                )
            case .ping:
                // Only allow pinging dependents
                // Check if the dependent has an outgoing ping
                guard let currentContact = contact else { return Alert(title: Text("Error"), message: Text("Contact not found"), dismissButton: .default(Text("OK"))) }
                if currentContact.isDependent && currentContact.hasOutgoingPing {
                    return Alert(
                        title: Text("Clear Ping"),
                        message: Text("Do you want to clear the pending ping to this contact?"),
                        primaryButton: .default(Text("Clear")) {
                            pingContact()
                        },
                        secondaryButton: .cancel()
                    )
                } else {
                    return Alert(
                        title: Text("Ping Contact"),
                        message: Text("Are you sure you want to ping this contact?"),
                        primaryButton: .default(Text("Ping")) {
                            pingContact()
                        },
                        secondaryButton: .cancel()
                    )
                }
            case .pingConfirmation:
                // This case is no longer used since we're using silent notifications
                // but we'll keep it for backward compatibility
                return Alert(
                    title: Text("Ping Sent"),
                    message: Text("The contact was successfully pinged."),
                    dismissButton: .default(Text("OK"))
                )
            case .pingDisabled:
                return Alert(
                    title: Text("Cannot Ping"),
                    message: Text("This contact must have the Dependent role to be pinged. Enable the Dependent role in the contact settings to use this feature."),
                    dismissButton: .default(Text("OK"))
                )
            case .roleToggle:
                // Get role name based on pending change
                let roleName = pendingRoleChange?.0 == .responder ? "Responder" : "Dependent"
                let action = pendingRoleChange?.1 == true ? "add" : "remove"

                // Create a more descriptive message based on the role
                var message = ""
                if roleName == "Responder" {
                    message = pendingRoleChange?.1 == true
                        ? "This contact will be able to respond to your alerts and check-ins."
                        : "This contact will no longer be able to respond to your alerts and check-ins."
                } else { // Dependent
                    message = pendingRoleChange?.1 == true
                        ? "You will be able to check on this contact and send them pings."
                        : "You will no longer be able to check on this contact or send them pings."
                }

                return Alert(
                    title: Text("\(action.capitalized) \(roleName) Role"),
                    message: Text(message),
                    primaryButton: .default(Text("Confirm")) {
                        applyRoleChange()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    private enum ActionButtonType: CaseIterable {
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

    private func handleAction(_ type: ActionButtonType) {
        HapticFeedback.triggerHaptic()
        switch type {
        case .call: callContact()
        case .message: messageContact()
        case .ping: activeAlert = .ping // Show confirmation dialog before pinging
        }
    }

    private func callContact() {
        guard let currentContact = contact else { return }
        if let url = URL(string: "tel://\(currentContact.phone)") {
            UIApplication.shared.open(url)
        }
    }

    private func messageContact() {
        guard let currentContact = contact else { return }
        if let url = URL(string: "sms://\(currentContact.phone)") {
            UIApplication.shared.open(url)
        }
    }

    private func pingContact() {
        HapticFeedback.notificationFeedback(type: .success)
        guard let currentContact = contact, currentContact.isDependent else { return }

        // For dependents, we're handling outgoing pings (user to dependent)
        if currentContact.hasOutgoingPing {
            // Clear outgoing ping
            if currentContact.isResponder {
                // If the contact is both a responder and a dependent, use the appropriate method
                // Clear outgoing ping implementation
                // No need to check if currentContact is nil as it's non-optional
            } else {
                userViewModel.clearPing(for: currentContact)
            }

            // Show a notification for clearing the ping
            NotificationManager.shared.showSilentLocalNotification(
                title: "Ping Cleared",
                body: "You have cleared the ping to \(currentContact.name).",
                type: .pingNotification
            )
        } else {
            // Send new ping
            if currentContact.isResponder {
                // If the contact is both a responder and a dependent, use the appropriate method
                // Send ping implementation
                // No need to check if currentContact is nil as it's non-optional
            } else {
                userViewModel.pingDependent(currentContact)
            }

            // Show a notification for sending the ping
            NotificationManager.shared.showPingNotification(contactName: currentContact.name)
        }

        // Force refresh the view after a short delay to allow the view model to update
        // Use a slightly longer delay to ensure the view model has fully updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Force refresh the view - our computed property will find the contact in the appropriate list
            self.refreshID = UUID()
        }
    }

    private enum RoleChanged { case dependent, responder }

    private func applyRoleChange() {
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

            // Update the contact in the view model
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

    // This method is no longer used - we've replaced it with the new role toggle confirmation flow
    private func validateRoles(changed: RoleChanged, skipConfirmation: Bool = false) {
        // This method is kept for reference but is no longer called
    }

    // New method to update contact roles
    private func updateContactRoles() {
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
        print("  Before counts - Responders: \(userViewModel.responders.count), Dependents: \(userViewModel.dependents.count)")

        // Check if we're removing the contact from its original list
        let removingFromOriginalList =
            (originalList == "responders" && wasResponder && !isResponder) ||
            (originalList == "dependents" && wasDependent && !isDependent)

        // If we're removing from original list, log it
        if removingFromOriginalList {
            print("  Contact will be removed from its original list (\(originalList))")
        }

        // If dependent role was turned off, clear any active pings
        let shouldClearPings = wasDependent && !isDependent && currentContact.hasOutgoingPing

        // Update the contact's position in the lists based on role changes
        userViewModel.updateContact(id: currentContact.id) { contact in
            contact.isResponder = isResponder
            contact.isDependent = isDependent

            // If dependent role was turned off, clear any active pings
            if shouldClearPings {
                contact.hasOutgoingPing = false
                contact.outgoingPingTimestamp = nil
                print("  Cleared outgoing ping because dependent role was turned off")
            }
        }

        // Force refresh the view after a short delay to allow the view model to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Force refresh the view - our computed property will find the contact in the appropriate list
            self.refreshID = UUID()
        }

        // Post notification to refresh the lists views
        NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("RefreshRespondersView"), object: nil)

        print("Contact sheet refreshed after role change")
        print("  Contact: \(currentContact.name)")
        print("  Roles: responder=\(isResponder), dependent=\(isDependent)")
        print("  After counts - Responders: \(userViewModel.responders.count), Dependents: \(userViewModel.dependents.count)\n==== END ROLE CHANGE ====\n")
    }

    private func deleteContact() {
        guard let currentContact = self.contact else {
            print("Cannot delete contact: contact not found")
            return
        }

        // Remove the contact from the appropriate lists
        // Remove contact implementation
        // No need to check if currentContact is nil as it's non-optional
        // In a real app, we would call a method to remove the contact

        // Show a notification for removing a contact
        NotificationManager.shared.showContactRemovedNotification(contactName: currentContact.name)

        // Post notification to refresh the lists views
        NotificationCenter.default.post(name: NSNotification.Name("RefreshDependentsView"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("RefreshRespondersView"), object: nil)

        // Add a small delay before dismissing to allow the user to see the result
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Dismiss the sheet
            self.presentationMode.wrappedValue.dismiss()
        }
    }

    // MARK: - Helpers

    private func formatTimeAgo(_ date: Date) -> String {
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

    private func formatInterval(_ interval: TimeInterval) -> String {
        let days = Int(interval / (24 * 60 * 60))
        let hours = Int((interval.truncatingRemainder(dividingBy: 24 * 60 * 60)) / (60 * 60))
        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s")"
        } else {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
    }

    private func isNotResponsive(_ contact: Contact?) -> Bool {
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

enum ContactAlertType: Identifiable {
    case role, delete, ping, pingConfirmation, pingDisabled, roleToggle
    var id: Int { hashValue }
}
