import SwiftUI
import Foundation
import UIKit
import AVFoundation
import PhotosUI
import ComposableArchitecture
import Perception

// MARK: - Alert

enum RespondersAlert: Equatable {
    case confirmRemove(Contact)
    case confirmClearAllPings
}

// MARK: - Feature

@Reducer
struct RespondersFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.contacts) var contactsState: ReadOnlyContactsState
        @Shared(.currentUser) var currentUser: User? = nil
        
        var isLoading = false
        
        // Add presentations
        @Presents var contactDetails: ContactDetailsSheetFeature.State?
        @Presents var confirmationAlert: AlertState<RespondersAlert>?
        var showClearAllPingsConfirmation = false
        
        // Computed property for responders
        var responders: [Contact] {
            contactsState.contacts.filter { contact in
                // Filter contacts that are marked as responders
                contact.isResponder
            }
            .sorted { contact1, contact2 in
                // Priority groups: [manual alert, not responsive, ping status, default]
                let priority1 = getContactPriority(contact1)
                let priority2 = getContactPriority(contact2)
                
                if priority1 != priority2 {
                    return priority1 < priority2
                }
                
                // Within same priority group, sort by name
                return contact1.name < contact2.name
            }
        }
        
        private func getContactPriority(_ contact: Contact) -> Int {
            if contact.hasManualAlertActive { return 0 }
            if contact.hasNotResponsiveAlert { return 1 }
            if contact.hasIncomingPing || contact.hasOutgoingPing { return 2 }
            return 3 // default
        }
        
        var pendingPingsCount: Int {
            // Count responders that have incoming pings (these are the "busy" responders)
            responders.filter { $0.hasIncomingPing }.count
        }

        // MARK: - Formatting Functions

        func responderStatusText(for contact: Contact) -> String {
            return contact.hasIncomingPing ? "Pinged you" : ""
        }

        func statusDisplay(for contact: Contact) -> (String, Color) {
            if contact.hasIncomingPing {
                return ("Incoming Ping", .orange)
            } else if contact.hasOutgoingPing {
                return ("Outgoing Ping", .blue)
            } else {
                return ("Available", .green)
            }
        }

        func lastSeenText(for date: Date) -> String {
            let now = Date()
            let interval = now.timeIntervalSince(date)

            if interval < 60 {
                return "Just now"
            } else if interval < 3600 {
                let minutes = Int(interval / 60)
                return "\(minutes)m ago"
            } else if interval < 86400 {
                let hours = Int(interval / 3600)
                return "\(hours)h ago"
            } else if interval < 604800 { // 7 days
                let days = Int(interval / 86400)
                return "\(days)d ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                return formatter.string(from: date)
            }
        }

        func intervalText(for interval: TimeInterval) -> String {
            let hours = Int(interval / 3600)
            let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

            if hours > 0 && minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else if hours > 0 {
                return "\(hours)h"
            } else if minutes > 0 {
                return "\(minutes)m"
            } else {
                return "< 1m"
            }
        }

        func contactRoleText(for contact: Contact) -> String {
            if contact.isResponder && contact.isDependent {
                return "Responder & Dependent"
            } else if contact.isResponder {
                return "Responder"
            } else if contact.isDependent {
                return "Dependent"
            } else {
                return "Contact"
            }
        }

        func responderActivityStatus(for contact: Contact) -> (String, Color) {
            if contact.hasManualAlertActive {
                return alertStatus(for: contact, type: "Alert")
            }
            
            if contact.hasNotResponsiveAlert {
                return alertStatus(for: contact, type: "Not Responsive")
            }
            
            if contact.hasIncomingPing {
                return pingStatus(for: contact, direction: "incoming")
            }
            
            if contact.hasOutgoingPing {
                return pingStatus(for: contact, direction: "outgoing")
            }
            
            return ("✅ Available", .green)
        }
        
        private func alertStatus(for contact: Contact, type: String) -> (String, Color) {
            let timestamp = type == "Alert" ? contact.emergencyAlertTimestamp : contact.notResponsiveAlertTimestamp
            let emoji = type == "Alert" ? "🚨" : "❌"
            
            guard let alertTime = timestamp else {
                return ("\(emoji) \(type)", .red)
            }
            
            let timeSince = Date().timeIntervalSince(alertTime)
            if timeSince < 300 {
                return ("\(emoji) \(type) (Just Now)", .red)
            } else if timeSince < 3600 {
                let minutes = Int(timeSince / 60)
                return ("\(emoji) \(type) (\(minutes)m ago)", .red)
            } else {
                return ("\(emoji) \(type)", .red)
            }
        }
        
        private func pingStatus(for contact: Contact, direction: String) -> (String, Color) {
            let timestamp = direction == "incoming" ? contact.incomingPingTimestamp : contact.outgoingPingTimestamp
            let emoji = direction == "incoming" ? "📥" : "📤"
            let text = direction == "incoming" ? "Pinged You" : "You Pinged"
            let color: Color = direction == "incoming" ? .orange : .blue
            
            guard let pingTime = timestamp else {
                return ("\(emoji) \(text)", color)
            }
            
            let timeSince = Date().timeIntervalSince(pingTime)
            if timeSince < 300 {
                return ("\(emoji) \(text) (Just Now)", color)
            } else if timeSince < 3600 {
                let minutes = Int(timeSince / 60)
                return ("\(emoji) \(text) (\(minutes)m ago)", color)
            } else {
                return ("\(emoji) \(text)", color)
            }
        }
    }

    enum Action {
        // Data management
        case refreshResponders
        
        // Contact interactions
        case selectContact(Contact)
        case pingContact(Contact)
        case removeContact(Contact)
        case clearAllPings
        case showRemoveConfirmation(Contact)
        
        // UI presentations
        case contactDetails(PresentationAction<ContactDetailsSheetFeature.Action>)
        case confirmationAlert(PresentationAction<RespondersAlert>)
        
        // Network responses
        case pingResponse(Result<Void, Error>)
        case removeResponse(Result<Void, Error>)
        case refreshResponse(Result<Void, Error>)
    }

    @Dependency(\.contactsClient) var contactsClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.hapticClient) var haptics

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            // Data management
            case .refreshResponders:
                guard state.currentUser != nil else { return .none }
                state.isLoading = true

                return .run { [contactsClient] send in
                    await send(.refreshResponse(Result {
                        try await contactsClient.refreshContacts()
                    }))
                }

            // Contact interactions
            case let .selectContact(contact):
                state.contactDetails = ContactDetailsSheetFeature.State(contact: contact)
                return .none

            case let .pingContact(contact):
                state.isLoading = true
                let senderName = state.currentUser?.name ?? "Someone"

                return .run { send in
                    await haptics.notification(.warning)
                    await send(.pingResponse(Result {
                        // Send ping notification to responder via NotificationClient
                        try await notificationClient.sendPingNotification(
                            .receiveResponderPing,
                            "You Received a Ping", 
                            "\(senderName) sent you a check-in ping",
                            contact.id
                        )
                    }))
                }

            case let .removeContact(contact):
                state.confirmationAlert = AlertState {
                    TextState("Remove Responder")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmRemove(contact)) {
                        TextState("Remove")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("Are you sure you want to remove \(contact.name) as a responder?")
                }
                return .none

            case .clearAllPings:
                guard state.pendingPingsCount > 0 else { return .none }
                state.showClearAllPingsConfirmation = true
                return .none

            case let .showRemoveConfirmation(contact):
                return .send(.removeContact(contact))

            // UI presentations
            case .contactDetails:
                return .none

            case .confirmationAlert(.presented(.confirmRemove(let contact))):
                state.isLoading = true

                return .run { send in
                    await haptics.notification(.success)
                    await send(.removeResponse(Result {
                        try await contactsClient.removeContact(contact.id)
                    }))
                }

            case .confirmationAlert(.presented(.confirmClearAllPings)):
                state.isLoading = true
                state.showClearAllPingsConfirmation = false

                // Get contacts that need ping clearing before updating them
                let contactsToNotify = state.contactsState.contacts.filter { $0.isResponder && $0.hasIncomingPing }
                let contactsToUpdate = contactsToNotify.map { contact in
                    var updatedContact = contact
                    updatedContact.hasIncomingPing = false
                    updatedContact.incomingPingTimestamp = nil
                    return updatedContact
                }

                return .run { [contactsClient, notificationClient] send in
                    await haptics.notification(.success)
                    
                    // First: Send acknowledgment notifications to each contact who sent pings
                    for originalContact in contactsToNotify {
                        do {
                            try await notificationClient.sendPingNotification(
                                .sendResponderPingResponded,
                                "Ping Acknowledged",
                                "Your ping has been acknowledged",
                                originalContact.id
                            )
                        } catch {
                            // Continue with other notifications even if one fails
                            print("Failed to send acknowledgment to \(originalContact.name): \(error)")
                        }
                    }
                    
                    // Second: Update each contact's state to clear the pings
                    for contact in contactsToUpdate {
                        await contactsClient.updateContact(contact)
                    }
                    
                    await send(.pingResponse(Result {
                        // Clear notification history (but don't send duplicate notifications)
                        try await notificationClient.clearAllReceivedPings()
                    }))
                }

            case .confirmationAlert:
                return .none

            // Network responses
            case .pingResponse(.success):
                state.isLoading = false
                return .run { [haptics, notificationClient] _ in
                    await haptics.notification(.success)
                    try? await notificationClient.sendSystemNotification(
                        "Success",
                        "All incoming pings have been cleared successfully."
                    )
                }

            case let .pingResponse(.failure(error)):
                state.isLoading = false
                return .run { [haptics, notificationClient] _ in
                    await haptics.notification(.error)
                    try? await notificationClient.sendSystemNotification(
                        "Operation Failed",
                        "Unable to clear pings: \(error.localizedDescription)"
                    )
                }

            case .removeResponse(.success):
                state.isLoading = false
                return .run { [haptics, notificationClient] _ in
                    await haptics.notification(.success)
                    try? await notificationClient.sendSystemNotification(
                        "Responder Removed",
                        "The responder has been successfully removed from your list."
                    )
                }

            case let .removeResponse(.failure(error)):
                state.isLoading = false
                return .run { [haptics, notificationClient] _ in
                    await haptics.notification(.error)
                    try? await notificationClient.sendSystemNotification(
                        "Remove Failed",
                        "Unable to remove responder: \(error.localizedDescription)"
                    )
                }

            case .refreshResponse(.success):
                state.isLoading = false
                return .none

            case let .refreshResponse(.failure(error)):
                state.isLoading = false
                return .run { [haptics, notificationClient] _ in
                    await haptics.notification(.error)
                    try? await notificationClient.sendSystemNotification(
                        "Refresh Failed",
                        "Unable to refresh responders: \(error.localizedDescription)"
                    )
                }
            }
        }
        .ifLet(\.$contactDetails, action: \.contactDetails) {
            ContactDetailsSheetFeature()
        }
        .ifLet(\.$confirmationAlert, action: \.confirmationAlert)
    }
}

// MARK: - View

struct RespondersView: View {
    @Bindable var store: StoreOf<RespondersFeature>

    // MARK: - Body
    
    var body: some View {
        WithPerceptionTracking {
            contentView
                .toolbar { toolbarContent }
                .onAppear(perform: onAppear)
                .alert($store.scope(state: \.confirmationAlert, action: \.confirmationAlert))
                .alert("Clear All Pings", isPresented: confirmationBinding, actions: alertActions, message: alertMessage)
                .sheet(item: $store.scope(state: \.contactDetails, action: \.contactDetails)) { store in
                    ContactDetailsSheetView(store: store)
                }
        }
    }
}

// MARK: - Content Views

private extension RespondersView {
    
    @ViewBuilder
    var contentView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 12) {
                contactsContent
                Spacer().frame(height: 20)
            }
            .padding(.horizontal)
            .padding(.bottom, 70)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .edgesIgnoringSafeArea(.bottom)
    }
    
    @ViewBuilder
    var contactsContent: some View {
        if store.responders.isEmpty {
            emptyStateView
        } else {
            contactsListView
        }
    }
    
    @ViewBuilder
    var emptyStateView: some View {
        Text("No responders yet")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 40)
    }
    
    @ViewBuilder
    var contactsListView: some View {
        ForEach(store.responders) { responder in
            ContactCardView(
                contact: responder,
                style: .responder(statusText: store.state.responderStatusText(for: responder)),
                onTap: { store.send(.selectContact(responder), animation: .default) }
            )
        }
    }
}

// MARK: - Toolbar

private extension RespondersView {
    
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            clearAllPingsButton
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            notificationCenterButton
        }
    }
    
    @ViewBuilder
    var clearAllPingsButton: some View {
        Button(action: clearAllPingsAction) {
            HStack(spacing: 4) {
                Image(systemName: store.pendingPingsCount > 0 ? "bell.badge.slash.fill" : "bell.fill")
                    .font(.system(size: 18))
                Text("Clear")
                    .font(.body)
            }
            .foregroundColor(store.pendingPingsCount > 0 ? .blue : .gray)
        }
        .disabled(store.pendingPingsCount == 0)
    }
    
    @ViewBuilder
    var notificationCenterButton: some View {
        Button(action: notificationCenterAction) {
            Image(systemName: "square.fill.text.grid.1x2")
        }
        .simultaneousGesture(TapGesture().onEnded { _ in
            store.send(.clearAllPings, animation: .default)
        })
    }
}

// MARK: - Alerts

private extension RespondersView {
    
    var confirmationBinding: Binding<Bool> {
        Binding(
            get: { store.showClearAllPingsConfirmation },
            set: { _ in }
        )
    }
    
    @ViewBuilder
    func alertActions() -> some View {
        Button("Clear All") {
            store.send(.confirmationAlert(.presented(.confirmClearAllPings)), animation: .default)
        }
        Button("Cancel", role: .cancel) { }
    }
    
    @ViewBuilder
    func alertMessage() -> some View {
        Text("Are you sure you want to clear all pending pings?")
    }
}

// MARK: - Actions

private extension RespondersView {
    
    func onAppear() {
        store.send(.refreshResponders, animation: .default)
    }
    
    func clearAllPingsAction() {
        store.send(.clearAllPings, animation: .default)
    }
    
    func notificationCenterAction() {
        // This should be handled by parent feature if needed
    }
}

