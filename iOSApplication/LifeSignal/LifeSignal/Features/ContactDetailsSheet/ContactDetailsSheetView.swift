import SwiftUI
import Foundation
import UIKit
import ComposableArchitecture
import Perception

// MARK: - Helper Types

enum ActionButtonType: CaseIterable {
    case ping
    case call
    case remove
    
    var id: String {
        switch self {
        case .ping: return "ping"
        case .call: return "call"
        case .remove: return "remove"
        }
    }
    
    func icon(for contact: Contact) -> String {
        switch self {
        case .ping: return "bell.fill"
        case .call: return "phone.fill"
        case .remove: return "trash.fill"
        }
    }
    
    func label(for contact: Contact) -> String {
        switch self {
        case .ping: return "Ping"
        case .call: return "Call"
        case .remove: return "Remove"
        }
    }
}
struct ContactDetailsSheetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Perception.Bindable var store: StoreOf<ContactDetailsSheetFeature>

    // Initialize with a contact
    init(store: StoreOf<ContactDetailsSheetFeature>) {
        self.store = store
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
                store.send(.pingContact)
                store.send(.dismiss)
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
                store.send(.dismiss)
            }
        }
    }

    // MARK: - Contact Header View
    private var contactHeaderView: some View {
        VStack(spacing: 12) {
            CommonAvatarView(
                name: store.contact.name,
                size: 100,
                backgroundColor: Color.blue.opacity(0.1),
                textColor: .blue,
                strokeWidth: 2,
                strokeColor: .blue
            )
            .padding(.top, 24)
            
            Text(store.contact.name)
                .font(.headline)
                .bold()
                .foregroundColor(.primary)
            
            Text(store.contact.phoneNumber)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Action Buttons View
    private var actionButtonsView: some View {
        Group {
            if let contact = store.contact {
                HStack(spacing: 12) {
                    ForEach(ActionButtonType.allCases, id: \._id) { type in
                        Button(action: {
                            // Show alert for disabled ping button, otherwise handle action normally
                            if type == .ping && !contact.isDependent {
                                // TODO: Implement activeAlert
                            } else {
                                // TODO: Implement handleAction
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
            if let contact = store.contact, contact.manualAlertActive, let ts = contact.manualAlertTimestamp {
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
                        Text(store.formatTimeAgo(from: contact.lastCheckInTime ?? Date()))
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
            if let contact = store.contact, contact.hasIncomingPing, let pingTime = contact.incomingPingTimestamp, contact.isResponder {
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
                        Text(store.formatTimeAgo(from: contact.lastCheckInTime ?? Date()))
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
            if let contact = store.contact, contact.hasOutgoingPing, let pingTime = contact.outgoingPingTimestamp {
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
                        Text(store.formatTimeAgo(from: contact.lastCheckInTime ?? Date()))
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
            if let contact = store.contact, store.isNotResponsive {
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
                            Text(store.formatTimeAgo(from: contact.lastCheckInTime ?? Date()))
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
            if let contact = store.contact {
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
                        get: { store.contact.isDependent },
                        set: { newValue in
                            store.send(.pingContact)
                            // Show confirmation dialog for role toggle
                            if newValue != store.contact.isDependent {
                                // TODO: Implement pendingRoleChange
                                // TODO: Implement activeAlert
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
                        get: { store.contact.isResponder },
                        set: { newValue in
                            store.send(.pingContact)
                            // Show confirmation dialog for role toggle
                            if newValue != store.contact.isResponder {
                                // TODO: Implement pendingRoleChange
                                // TODO: Implement activeAlert
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
            if let contact = store.contact {
                VStack(spacing: 0) {
                    HStack {
                        Text("Check-in interval")
                            .foregroundColor(.primary)
                            .font(.body)
                        Spacer()
                        let defaultInterval: TimeInterval = 24 * 60 * 60
                        let intervalToUse = contact.interval ?? defaultInterval
                        Text(store.formatInterval(contact.checkInInterval))
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
                            Text(store.formatTimeAgo(from: contact.lastCheckInTime ?? Date()))
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
            if store.contact != nil {
                Button(action: {
                    store.send(.pingContact)
                    // TODO: Implement activeAlert
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
        WithPerceptionTracking {
            NavigationStack {
                Group {
                    if store.shouldDismiss {
                        // Show a message when the contact is removed from its original list
                        contactDismissedView
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                // This is a hidden view that will trigger a refresh when refreshID changes
                                Text("")
                                    .frame(width: 0, height: 0)
                                    .opacity(0)
                                    .id(store.refreshID)

                                // Header
                                contactHeaderView

                                // Button Row (moved above note)
                                actionButtonsView

                                // Alert Cards
                                if let contact = store.contact {
                                    // Manual alert card - only show for dependents (1st priority)
                                    if contact.isDependent && contact.manualAlertActive {
                                        manualAlertCardView
                                    }

                                    // Non-responsive card - only show for dependents (2nd priority)
                                    if contact.isDependent && store.isNotResponsive {
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
            // TODO: Re-implement alert system properly
        }
    }
}

enum ContactAlertType: Identifiable {
    case role, delete, ping, pingConfirmation, pingDisabled, roleToggle
    var id: Int { hashValue }
}
