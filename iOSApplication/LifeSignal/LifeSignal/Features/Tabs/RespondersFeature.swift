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
    case confirmRespondAll
}

// MARK: - Feature

@Reducer
struct RespondersFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.contacts) var allContacts: [Contact] = []
        @Shared(.currentUser) var currentUser: User? = nil
        
        var isLoading = false
        var errorMessage: String?
        
        // Add presentations
        @Presents var contactDetails: ContactDetailsSheetFeature.State?
        @Presents var confirmationAlert: AlertState<RespondersAlert>?
        
        // Computed property for responders
        var responders: [Contact] {
            allContacts.filter { contact in
                // Filter contacts that are marked as responders
                contact.isResponder
            }
        }
        
        var pendingPingsCount: Int {
            // Count responders that have incoming pings (these are the "busy" responders)
            responders.filter { $0.hasIncomingPing }.count
        }

        // MARK: - Formatting Functions

        func responderStatusText(for contact: Contact) -> String {
            if contact.hasIncomingPing {
                // Format time ago directly
                let calendar = Calendar.current
                let now = Date()
                let components = calendar.dateComponents([.minute, .hour, .day], from: contact.incomingPingTimestamp ?? Date(), to: now)

                if let day = components.day, day > 0 {
                    return "Pinged you " + (day == 1 ? "yesterday" : "\(day) days ago")
                } else if let hour = components.hour, hour > 0 {
                    return "Pinged you " + (hour == 1 ? "an hour ago" : "\(hour) hours ago")
                } else if let minute = components.minute, minute > 0 {
                    return "Pinged you " + (minute == 1 ? "a minute ago" : "\(minute) minutes ago")
                } else {
                    return "Pinged you just now"
                }
            }
            return ""
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
            let now = Date()

            // Check for pings first (most relevant for responders)
            if contact.hasIncomingPing {
                if let pingTime = contact.incomingPingTimestamp {
                    let timeSincePing = now.timeIntervalSince(pingTime)
                    if timeSincePing < 300 { // 5 minutes
                        return ("📥 Pinged You (Just Now)", .orange)
                    } else if timeSincePing < 3600 { // 1 hour
                        let minutes = Int(timeSincePing / 60)
                        return ("📥 Pinged You (\(minutes)m ago)", .orange)
                    } else {
                        return ("📥 Incoming Ping", .orange)
                    }
                } else {
                    return ("📥 Incoming Ping", .orange)
                }
            }

            if contact.hasOutgoingPing {
                if let pingTime = contact.outgoingPingTimestamp {
                    let timeSincePing = now.timeIntervalSince(pingTime)
                    if timeSincePing < 300 { // 5 minutes
                        return ("📤 You Pinged (Just Now)", .blue)
                    } else {
                        let minutes = Int(timeSincePing / 60)
                        return ("📤 You Pinged (\(minutes)m ago)", .blue)
                    }
                } else {
                    return ("📤 Outgoing Ping", .blue)
                }
            }

            // Check for manual alerts (responders might have their own alerts)
            if contact.manualAlertActive {
                if let alertTime = contact.manualAlertTimestamp {
                    let timeSinceAlert = now.timeIntervalSince(alertTime)
                    if timeSinceAlert < 300 { // 5 minutes
                        return ("🚨 Has Alert (Just Now)", .red)
                    } else if timeSinceAlert < 3600 { // 1 hour
                        let minutes = Int(timeSinceAlert / 60)
                        return ("🚨 Has Alert (\(minutes)m ago)", .red)
                    } else {
                        return ("🚨 Has Alert", .red)
                    }
                } else {
                    return ("🚨 Has Alert", .red)
                }
            }

            // Default state for responders
            return ("✅ Available", .green)
        }
    }

    enum Action {
        case refreshResponders
        case selectContact(Contact)
        case pingContact(Contact)
        case removeContact(Contact)
        case respondToAllPings
        case showRemoveConfirmation(Contact)
        case pingResponse(Result<Void, Error>)
        case removeResponse(Result<Void, Error>)
        case contactDetails(PresentationAction<ContactDetailsSheetFeature.Action>)
        case confirmationAlert(PresentationAction<RespondersAlert>)

        // Streaming integration
        case startContactStreaming
        case stopContactStreaming
        case contactUpdated(Contact)
    }

    @Dependency(\.contactRepository) var contactRepository
    @Dependency(\.hapticClient) var haptics
    @Dependency(\.analytics) var analytics
    @Dependency(\.logging) var logging

    private enum StreamingID { case contactUpdates }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .refreshResponders:
                guard state.currentUser != nil else { return .none }
                state.isLoading = true
                state.errorMessage = nil

                return .run { send in
                    await analytics.track(.featureUsed(feature: "responders_refresh", context: [:]))
                    // In production, this would refresh contacts from the repository
                    // The shared contacts will automatically update the responders list
                    try? await Task.sleep(for: .milliseconds(500))
                    await send(.pingResponse(.success(())))
                }

            case let .selectContact(contact):
                state.contactDetails = ContactDetailsSheetFeature.State(contact: contact)
                return .run { _ in
                    await analytics.track(.featureUsed(feature: "responder_details_view", context: ["contact_id": contact.id.uuidString]))
                }

            case let .pingContact(contact):
                state.isLoading = true
                state.errorMessage = nil

                return .run { send in
                    await haptics.notification(.warning)
                    await analytics.track(.featureUsed(feature: "ping_responder", context: ["contact_id": contact.id.uuidString]))
                    await send(.pingResponse(Result {
                        // In production, this would send a ping/notification to the responder
                        try await Task.sleep(for: .milliseconds(1000))
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

            case .respondToAllPings:
                guard state.pendingPingsCount > 0 else { return .none }

                state.confirmationAlert = AlertState {
                    TextState("Respond to All Pings")
                } actions: {
                    ButtonState(action: .confirmRespondAll) {
                        TextState("Respond")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("This will send a response to all pending pings from your responders.")
                }
                return .none

            case let .showRemoveConfirmation(contact):
                return .send(.removeContact(contact))

            case .confirmationAlert(.presented(.confirmRemove(let contact))):
                state.isLoading = true
                state.errorMessage = nil

                return .run { send in
                    await haptics.notification(.success)
                    await analytics.track(.featureUsed(feature: "remove_responder", context: ["contact_id": contact.id.uuidString]))
                    await send(.removeResponse(Result {
                        try await contactRepository.removeContact(contact.id)
                    }))
                }

            case .confirmationAlert(.presented(.confirmRespondAll)):
                state.isLoading = true
                state.errorMessage = nil

                return .run { [pendingPingsCount = state.pendingPingsCount] send in
                    await haptics.notification(.success)
                    await analytics.track(.featureUsed(feature: "respond_to_all_pings", context: ["ping_count": "\(pendingPingsCount)"]))
                    await send(.pingResponse(Result {
                        // In production, this would respond to all pending pings
                        try await Task.sleep(for: .milliseconds(1500))
                    }))
                }

            case .confirmationAlert:
                return .none

            case .pingResponse(.success):
                state.isLoading = false
                return .run { _ in
                    await haptics.notification(.success)
                }

            case let .pingResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none

            case .removeResponse(.success):
                state.isLoading = false
                return .run { _ in
                    await haptics.notification(.success)
                }

            case let .removeResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none

            case .contactDetails:
                return .none

            // Streaming integration
            case .startContactStreaming:
                return .run { send in
                    try await contactRepository.startStreaming()

                    // Listen for contact updates
                    let updates = contactRepository.contactUpdates()
                    for await contact in updates {
                        await send(.contactUpdated(contact))
                    }
                } catch: { error, _ in
                    // Handle streaming errors
                    print("Streaming error: \(error)")
                }
                .cancellable(id: StreamingID.contactUpdates, cancelInFlight: true)

            case .stopContactStreaming:
                return .run { _ in
                    await contactRepository.stopStreaming()
                }
                .cancellable(id: StreamingID.contactUpdates)

            case let .contactUpdated(updatedContact):
                // Handle real-time contact updates from streaming
                if updatedContact.isResponder {
                    state.$allContacts.withLock { contacts in
                        if let index = contacts.firstIndex(where: { $0.id == updatedContact.id }) {
                            contacts[index] = updatedContact
                        } else {
                            contacts.append(updatedContact)
                        }
                    }

                    return .run { _ in
                        await analytics.track(.featureUsed(feature: "responder_updated_realtime", context: [
                            "contact_id": updatedContact.id.uuidString,
                            "has_incoming_ping": "\(updatedContact.hasIncomingPing)",
                            "has_outgoing_ping": "\(updatedContact.hasOutgoingPing)"
                        ]))
                    }
                }
                return .none
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

    var body: some View {
        WithPerceptionTracking {
            // Simplified scrollable view with direct LazyVStack
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 12) {
                    if store.responders.isEmpty {
                        Text("No responders yet")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    } else {
                        // Use the responders from the feature state
                        ForEach(store.responders) { responder in
                            ResponderCardView(contact: responder, store: store)
                        }
                    }

                    // Add extra padding at the bottom to ensure content doesn't overlap with tab bar
                    Spacer()
                        .frame(height: 20)
                }
                .padding(.horizontal)
                .padding(.bottom, 70) // Add padding to ensure content doesn't overlap with tab bar
            }
            .background(Color(UIColor.systemGroupedBackground))
            .edgesIgnoringSafeArea(.bottom) // Extend background to bottom edge
            .onAppear {
                store.send(.refreshResponders)
                // Start streaming for real-time updates
                store.send(.startContactStreaming)
            }
            .onDisappear {
                // Stop streaming when view disappears
                store.send(.stopContactStreaming)
            }
            .toolbar {
                // Respond to All button (grayed out when there are no pending pings)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        store.send(.respondToAllPings)
                    }) {
                        Image(systemName: store.pendingPingsCount > 0 ? "bell.badge.slash.fill" : "bell.fill")
                            .foregroundColor(store.pendingPingsCount > 0 ? .blue : Color.blue.opacity(0.5))
                            .font(.system(size: 18))
                    }
                    .disabled(store.pendingPingsCount == 0)
                }

                // Notification Center button
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // This should be handled by parent feature if needed
                    }) {
                        Image(systemName: "square.fill.text.grid.1x2")
                    }
                }
            }

            .alert($store.scope(state: \.confirmationAlert, action: \.confirmationAlert))
            .sheet(item: $store.scope(state: \.contactDetails, action: \.contactDetails)) { store in
                ContactDetailsSheetView(store: store)
            }
        }
    }
}

struct ResponderCardView: View {
    let contact: Contact
    let store: StoreOf<RespondersFeature>

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(contact.name.prefix(1)))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                )

            // Name and status
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                    .font(.body)
                    .foregroundColor(.primary)

                let statusText = store.state.responderStatusText(for: contact)
                if !statusText.isEmpty {
                    Text(statusText)
                        .font(.footnote)
                        .foregroundColor(Color.secondary)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)

            Spacer()

            // Trailing content (ping icon - non-interactive as per requirements)
            if contact.hasIncomingPing {
                // Display ping icon without button functionality
                Circle()
                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 18))
                    )
                    .accessibilityLabel("Ping notification from \(contact.name)")
            }
        }
        .padding() // This padding is inside the card
        .background(
            Color(UIColor.secondarySystemGroupedBackground)
        )
        .cornerRadius(12)
        .onTapGesture {
            // Haptic feedback handled by TCA action
            store.send(.selectContact(contact))
        }
    }
}