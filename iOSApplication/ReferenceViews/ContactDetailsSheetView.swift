import SwiftUI
import Foundation
import UIKit

struct ContactDetailsSheetView: View {
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel: ContactDetailsSheetViewModel

    // Initialize with a contact
    init(contact: Contact) {
        _viewModel = StateObject(wrappedValue: ContactDetailsSheetViewModel(contact: contact))
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
            if let contact = viewModel.contact {
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
            if let contact = viewModel.contact {
                HStack(spacing: 12) {
                    ForEach(ActionButtonType.allCases, id: \._id) { type in
                        Button(action: {
                            // Show alert for disabled ping button, otherwise handle action normally
                            if type == .ping && !contact.isDependent {
                                viewModel.activeAlert = .pingDisabled
                            } else {
                                viewModel.handleAction(type)
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
            if let contact = viewModel.contact, contact.manualAlertActive, let ts = contact.manualAlertTimestamp {
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
                        Text(viewModel.formatTimeAgo(ts))
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
            if let contact = viewModel.contact, contact.hasIncomingPing, let pingTime = contact.incomingPingTimestamp, contact.isResponder {
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
                        Text(viewModel.formatTimeAgo(pingTime))
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
            if let contact = viewModel.contact, contact.hasOutgoingPing, let pingTime = contact.outgoingPingTimestamp {
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
                        Text(viewModel.formatTimeAgo(pingTime))
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
            if let contact = viewModel.contact, viewModel.isNotResponsive(contact) {
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Non-responsive")
                                .font(.body)
                                .foregroundColor(colorScheme == .light ? Color(UIColor.systemOrange) : .yellow)

                            Text("This dependent has not checked in within their scheduled interval.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if let lastCheckIn = contact.lastCheckIn {
                            let defaultInterval: TimeInterval = 24 * 60 * 60
                            let intervalToUse = contact.interval ?? defaultInterval
                            let expiration = lastCheckIn.addingTimeInterval(intervalToUse)
                            Text(viewModel.formatTimeAgo(expiration))
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
                .background(colorScheme == .light ? Color.orange.opacity(0.15) : Color.yellow.opacity(0.15))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Information Card Views
    private var noteCardView: some View {
        Group {
            if let contact = viewModel.contact {
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
                    Toggle("", isOn: Binding(
                        get: { viewModel.isDependent },
                        set: { newValue in
                            HapticFeedback.selectionFeedback()
                            // Show confirmation dialog for role toggle
                            if newValue != viewModel.isDependent {
                                viewModel.pendingRoleChange = (.dependent, newValue)
                                viewModel.activeAlert = .roleToggle
                            }
                        }
                    ))
                    .labelsHidden()
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
                Divider().padding(.leading)
                HStack {
                    Text("Responder")
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { viewModel.isResponder },
                        set: { newValue in
                            HapticFeedback.selectionFeedback()
                            // Show confirmation dialog for role toggle
                            if newValue != viewModel.isResponder {
                                viewModel.pendingRoleChange = (.responder, newValue)
                                viewModel.activeAlert = .roleToggle
                            }
                        }
                    ))
                    .labelsHidden()
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
            if let contact = viewModel.contact {
                VStack(spacing: 0) {
                    HStack {
                        Text("Check-in interval")
                            .foregroundColor(.primary)
                            .font(.body)
                        Spacer()
                        let defaultInterval: TimeInterval = 24 * 60 * 60
                        let intervalToUse = contact.interval ?? defaultInterval
                        Text(viewModel.formatInterval(intervalToUse))
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
                            Text(viewModel.formatTimeAgo(lastCheckIn))
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
            if viewModel.contact != nil {
                Button(action: {
                    HapticFeedback.triggerHaptic()
                    viewModel.activeAlert = .delete
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
                if viewModel.shouldDismiss {
                    // Show a message when the contact is removed from its original list
                    contactDismissedView
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // This is a hidden view that will trigger a refresh when refreshID changes
                            Text("")
                                .frame(width: 0, height: 0)
                                .opacity(0)
                                .id(viewModel.refreshID)

                            // Header
                            contactHeaderView

                            // Button Row (moved above note)
                            actionButtonsView

                            // Alert Cards
                            if let contact = viewModel.contact {
                                // Manual alert card - only show for dependents (1st priority)
                                if contact.isDependent && contact.manualAlertActive {
                                    manualAlertCardView
                                }

                                // Non-responsive card - only show for dependents (2nd priority)
                                if contact.isDependent && viewModel.isNotResponsive(contact) {
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
        .alert(item: $viewModel.activeAlert) { alertType in
            switch alertType {
            case .role:
                return Alert(
                    title: Text("Role Required"),
                    message: Text("This contact must have at least one role. To remove this contact completely, use the Delete Contact button."),
                    dismissButton: .default(Text("OK")) {
                        if let pending = viewModel.pendingToggleRevert {
                            switch pending {
                            case .dependent:
                                viewModel.isDependent = viewModel.lastValidRoles.1
                            case .responder:
                                viewModel.isResponder = viewModel.lastValidRoles.0
                            }
                            viewModel.pendingToggleRevert = nil
                        }
                    }
                )
            case .delete:
                return Alert(
                    title: Text("Delete Contact"),
                    message: Text("Are you sure you want to delete this contact? This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        viewModel.deleteContact()
                        // Add a small delay before dismissing to allow the user to see the result
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            // Dismiss the sheet
                            presentationMode.wrappedValue.dismiss()
                        }
                    },
                    secondaryButton: .cancel()
                )
            case .ping:
                // Only allow pinging dependents
                // Check if the dependent has an outgoing ping
                guard let currentContact = viewModel.contact else { return Alert(title: Text("Error"), message: Text("Contact not found"), dismissButton: .default(Text("OK"))) }
                if currentContact.isDependent && currentContact.hasOutgoingPing {
                    return Alert(
                        title: Text("Clear Ping"),
                        message: Text("Do you want to clear the pending ping to this contact?"),
                        primaryButton: .default(Text("Clear")) {
                            viewModel.pingContact()
                        },
                        secondaryButton: .cancel()
                    )
                } else {
                    return Alert(
                        title: Text("Ping Contact"),
                        message: Text("Are you sure you want to ping this contact?"),
                        primaryButton: .default(Text("Ping")) {
                            viewModel.pingContact()
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
                let roleName = viewModel.pendingRoleChange?.0 == .responder ? "Responder" : "Dependent"
                let action = viewModel.pendingRoleChange?.1 == true ? "add" : "remove"

                // Create a more descriptive message based on the role
                var message = ""
                if roleName == "Responder" {
                    message = viewModel.pendingRoleChange?.1 == true
                        ? "This contact will be able to respond to your alerts and check-ins."
                        : "This contact will no longer be able to respond to your alerts and check-ins."
                } else { // Dependent
                    message = viewModel.pendingRoleChange?.1 == true
                        ? "You will be able to check on this contact and send them pings."
                        : "You will no longer be able to check on this contact or send them pings."
                }

                return Alert(
                    title: Text("\(action.capitalized) \(roleName) Role"),
                    message: Text(message),
                    primaryButton: .default(Text("Confirm")) {
                        viewModel.applyRoleChange()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}

enum ContactAlertType: Identifiable {
    case role, delete, ping, pingConfirmation, pingDisabled, roleToggle
    var id: Int { hashValue }
}
