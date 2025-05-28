import SwiftUI
import Foundation
import UIKit
import AVFoundation
import PhotosUI
import ComposableArchitecture
import Perception

// Define Alert enum outside to avoid circular dependencies
enum DependentsAlert: Equatable {
    case confirmRemove(Contact)
    case confirmPing(Contact)
}

@Reducer
struct DependentsFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.contacts) var contactsState: ReadOnlyContactsState
        @Shared(.currentUser) var currentUser: User? = nil
        
        var sortMode: SortMode = .timeLeft
        @Presents var contactDetails: ContactDetailsSheetFeature.State?
        @Presents var confirmationAlert: AlertState<DependentsAlert>?
        @Presents var notificationsHistory: NotificationsHistorySheetFeature.State?
        
        var dependentCards: IdentifiedArrayOf<ContactCardFeature.State> = []
        
        var dependents: [Contact] {
            let filtered = contactsState.contacts.filter(\.isDependent)
            return sortedContacts(filtered, by: sortMode)
        }
        
        mutating func updateDependentCards() {
            dependentCards = IdentifiedArray(uniqueElements: dependents.map { contact in
                ContactCardFeature.State(
                    contact: contact,
                    style: .dependent(
                        statusText: statusText(for: contact),
                        statusColor: statusColor(for: contact)
                    )
                )
            })
        }
        
        private func sortedContacts(_ contacts: [Contact], by mode: SortMode) -> [Contact] {
            // First group by priority: [manual alert, not responsive, ping status, default]
            let grouped = Dictionary(grouping: contacts) { getContactPriority($0) }
            let sortedKeys = grouped.keys.sorted()
            
            var result: [Contact] = []
            for priority in sortedKeys {
                let contactsInGroup = grouped[priority] ?? []
                let sortedGroup: [Contact]
                
                // Sort within each priority group by the selected mode
                switch mode {
                case .timeLeft:
                    sortedGroup = contactsInGroup.sorted { timeRemaining(for: $0) < timeRemaining(for: $1) }
                case .name:
                    sortedGroup = contactsInGroup.sorted { $0.name < $1.name }
                case .dateAdded:
                    sortedGroup = contactsInGroup.sorted { $0.dateAdded > $1.dateAdded }
                }
                result.append(contentsOf: sortedGroup)
            }
            return result
        }
        
        private func getContactPriority(_ contact: Contact) -> Int {
            if contact.hasManualAlertActive { return 0 }
            if contact.hasNotResponsiveAlert { return 1 }
            if contact.hasOutgoingPing { return 2 } // Only outgoing pings for dependents
            return 3 // default
        }
        
        private func timeRemaining(for contact: Contact) -> TimeInterval {
            guard let lastCheckIn = contact.lastCheckInTimestamp else {
                return -Double.infinity
            }
            let timeSince = Date().timeIntervalSince(lastCheckIn)
            return contact.checkInInterval - timeSince
        }
        
        enum SortMode: String, CaseIterable, Equatable {
            case timeLeft = "Time Left"
            case name = "Name"
            case dateAdded = "Date Added"
        }
        
        var dependentCount: Int {
            dependents.count
        }
        
        var activeDependents: [Contact] {
            dependents.filter { contact in
                // Consider a dependent "active" if they've checked in recently or have active pings
                contact.hasIncomingPing || contact.hasOutgoingPing || contact.hasManualAlertActive ||
                (contact.lastCheckInTimestamp?.timeIntervalSinceNow ?? -Double.infinity) > -contact.checkInInterval
            }
        }
        
        var alertingDependents: [Contact] {
            dependents.filter { $0.hasManualAlertActive || $0.hasNotResponsiveAlert }
        }

        // MARK: - Formatting Functions

        func statusText(for contact: Contact) -> String {
            // Priority order: Alert > Non-responsive (including expired check-ins) > Active check-in status
            if contact.hasManualAlertActive {
                if let alertTime = contact.emergencyAlertTimestamp {
                    let timeSince = Date().timeIntervalSince(alertTime)
                    return "Sent out an alert \(formatTimeAgo(timeSince))"
                } else {
                    return "Sent out an alert"
                }
            } else if contact.hasNotResponsiveAlert {
                if let alertTime = contact.notResponsiveAlertTimestamp {
                    let timeSince = Date().timeIntervalSince(alertTime)
                    return "Non-responsive \(formatTimeAgo(timeSince))"
                } else {
                    return "Non-responsive"
                }
            } else if let lastCheckIn = contact.lastCheckInTimestamp {
                // Check if check-in has expired - treat as non-responsive
                let timeSinceCheckIn = Date().timeIntervalSince(lastCheckIn)
                let timeRemaining = contact.checkInInterval - timeSinceCheckIn
                
                if timeRemaining > 0 {
                    // Active - show time remaining until check-in expires
                    let days = Int(timeRemaining) / 86400
                    let hours = Int(timeRemaining) % 86400 / 3600
                    let minutes = Int(timeRemaining) % 3600 / 60
                    
                    if days > 0 {
                        if hours > 0 {
                            return "\(days)d \(hours)h"
                        } else {
                            return "\(days)d"
                        }
                    } else if hours > 0 {
                        if minutes > 0 {
                            return "\(hours)h \(minutes)m"
                        } else {
                            return "\(hours)h"
                        }
                    } else {
                        return "\(minutes)m"
                    }
                } else {
                    // Overdue check-in = Non-responsive status
                    let expiredTime = abs(timeRemaining)
                    return "Non-responsive \(formatTimeAgo(expiredTime))"
                }
            } else {
                return ""
            }
            // Note: Removed outgoing ping subtext - only show bell badge on avatar
        }
        
        private func formatTimeAgo(_ timeInterval: TimeInterval) -> String {
            let days = Int(timeInterval) / 86400
            let hours = Int(timeInterval) % 86400 / 3600
            let minutes = Int(timeInterval) % 3600 / 60
            
            if days > 0 {
                if hours > 0 {
                    return "\(days)d \(hours)h ago"
                } else {
                    return "\(days)d ago"
                }
            } else if hours > 0 {
                if minutes > 0 {
                    return "\(hours)h \(minutes)m ago"
                } else {
                    return "\(hours)h ago"
                }
            } else {
                return "\(minutes)m ago"
            }
        }

        func statusColor(for contact: Contact) -> Color {
            if contact.hasManualAlertActive {
                return .red
            } else if contact.hasNotResponsiveAlert {
                return .orange
            } else if let lastCheckIn = contact.lastCheckInTimestamp {
                // Check if check-in has expired - treat as non-responsive (orange)
                let timeSinceCheckIn = Date().timeIntervalSince(lastCheckIn)
                let timeRemaining = contact.checkInInterval - timeSinceCheckIn
                if timeRemaining <= 0 {
                    return .orange // Expired check-in = Non-responsive
                }
            }
            return .secondary
            // Note: Removed outgoing ping color - only show bell badge on avatar
        }

        func cardBackgroundColor(for contact: Contact) -> Color {
            if contact.hasManualAlertActive || contact.hasNotResponsiveAlert {
                return Color.red.opacity(0.1)
            } else if contact.isResponder {
                return Color.green.opacity(0.1)
            } else {
                return Color(UIColor.secondarySystemGroupedBackground)
            }
        }

        func statusDisplay(for contact: Contact) -> (String, Color) {
            // Determine status based on contact's current state
            if contact.hasManualAlertActive {
                return ("Alert Active", .red)
            } else if contact.hasNotResponsiveAlert {
                return ("Not Responsive", .red)
            } else if contact.hasIncomingPing {
                return ("Incoming Ping", .orange)
            } else if contact.hasOutgoingPing {
                return ("Outgoing Ping", .blue)
            } else if let lastCheckIn = contact.lastCheckInTimestamp {
                let timeSinceCheckIn = Date().timeIntervalSince(lastCheckIn)
                let timeRemaining = contact.checkInInterval - timeSinceCheckIn
                
                if timeRemaining > 0 {
                    // Active - show time remaining until check-in expires (same format as CheckInFeature)
                    let days = Int(timeRemaining) / 86400
                    let hours = Int(timeRemaining) % 86400 / 3600
                    let minutes = Int(timeRemaining) % 3600 / 60
                    
                    let timeText: String
                    if days > 0 {
                        if hours > 0 {
                            timeText = "\(days)d \(hours)h"
                        } else {
                            timeText = "\(days)d"
                        }
                    } else if hours > 0 {
                        if minutes > 0 {
                            timeText = "\(hours)h \(minutes)m"
                        } else {
                            timeText = "\(hours)h"
                        }
                    } else {
                        timeText = "\(minutes)m"
                    }
                    return (timeText, .green)
                } else {
                    // Overdue - show how long expired (same format as CheckInFeature)
                    let expiredTime = abs(timeRemaining)
                    let days = Int(expiredTime) / 86400
                    let hours = Int(expiredTime) % 86400 / 3600
                    let minutes = Int(expiredTime) % 3600 / 60
                    
                    let expiredText: String
                    if days > 30 {
                        // Show generic message for very old
                        expiredText = "Expired long ago"
                    } else if days > 0 {
                        if hours > 0 {
                            expiredText = "Expired \(days)d \(hours)h ago"
                        } else {
                            expiredText = "Expired \(days)d ago"
                        }
                    } else if hours > 0 {
                        if minutes > 0 {
                            expiredText = "Expired \(hours)h \(minutes)m ago"
                        } else {
                            expiredText = "Expired \(hours)h ago"
                        }
                    } else {
                        expiredText = "Expired \(minutes)m ago"
                    }
                    
                    // Color coding for overdue time
                    let overdueColor: Color
                    if timeRemaining < -contact.checkInInterval {
                        overdueColor = .red  // Very overdue (more than one full interval)
                    } else {
                        overdueColor = .orange  // Recently overdue
                    }
                    
                    return (expiredText, overdueColor)
                }
            } else {
                return ("No Check-in", .gray)
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

        func contactActivityStatus(for contact: Contact) -> (String, Color) {
            if contact.hasManualAlertActive {
                return alertActivityStatus(for: contact, type: "Alert")
            }
            
            if contact.hasNotResponsiveAlert {
                return alertActivityStatus(for: contact, type: "Not Responsive")
            }
            
            if contact.hasIncomingPing {
                return pingActivityStatus(for: contact, direction: "incoming")
            }
            
            if contact.hasOutgoingPing {
                return pingActivityStatus(for: contact, direction: "outgoing")
            }
            
            return checkInActivityStatus(for: contact)
        }
        
        private func alertActivityStatus(for contact: Contact, type: String) -> (String, Color) {
            let timestamp = type == "Alert" ? contact.emergencyAlertTimestamp : contact.notResponsiveAlertTimestamp
            let emoji = type == "Alert" ? "🚨" : "❌"
            
            guard let alertTime = timestamp else {
                return ("\(emoji) \(type) Active", .red)
            }
            
            let timeSince = Date().timeIntervalSince(alertTime)
            if timeSince < 300 {
                return ("\(emoji) \(type) (Just Now)", .red)
            } else if timeSince < 3600 {
                let minutes = Int(timeSince / 60)
                return ("\(emoji) \(type) (\(minutes)m ago)", .red)
            } else {
                return ("\(emoji) \(type) Active", .red)
            }
        }
        
        private func pingActivityStatus(for contact: Contact, direction: String) -> (String, Color) {
            let timestamp = direction == "incoming" ? contact.incomingPingTimestamp : contact.outgoingPingTimestamp
            let emoji = direction == "incoming" ? "📥" : "📤"
            let text = direction == "incoming" ? "Pinged" : "Sent Ping"
            let color: Color = direction == "incoming" ? .orange : .blue
            
            guard let pingTime = timestamp else {
                return ("\(emoji) \(text)", color)
            }
            
            let timeSince = Date().timeIntervalSince(pingTime)
            if timeSince < 300 {
                return ("\(emoji) \(text) (Just Now)", color)
            } else {
                let minutes = Int(timeSince / 60)
                return ("\(emoji) \(text) (\(minutes)m ago)", color)
            }
        }
        
        private func checkInActivityStatus(for contact: Contact) -> (String, Color) {
            guard let lastCheckIn = contact.lastCheckInTimestamp else {
                return ("❓ No Check-in", .gray)
            }
            
            let timeSinceCheckIn = Date().timeIntervalSince(lastCheckIn)
            let overdueFactor = timeSinceCheckIn / contact.checkInInterval

            if overdueFactor < 0.5 {
                return ("✅ Recently Active", .green)
            } else if overdueFactor < 1.0 {
                return ("⏰ Active", .green)
            } else if overdueFactor < 1.5 {
                return ("⚠️ Overdue", .yellow)
            } else if overdueFactor < 2.0 {
                return ("❗ Late Check-in", .orange)
            } else {
                return ("⚠️ Very Overdue", .orange)
            }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        // Data management
        case refreshDependents
        case setSortMode(State.SortMode)
        
        // Contact interactions
        case selectContact(Contact)
        case pingContact(Contact)
        case removeContact(Contact)
        case toggleDependentStatus(Contact)
        case showRemoveConfirmation(Contact)
        case showNotificationsHistory
        
        // UI presentations
        case contactDetails(PresentationAction<ContactDetailsSheetFeature.Action>)
        case confirmationAlert(PresentationAction<DependentsAlert>)
        case notificationsHistory(PresentationAction<NotificationsHistorySheetFeature.Action>)
        case contactCards(IdentifiedActionOf<ContactCardFeature>)
        
        // Network responses
        case pingResponse(Result<Void, Error>)
        case removeResponse(Result<Void, Error>)
        case dependentStatusResponse(Result<Contact, Error>)
        case refreshResponse(Result<Void, Error>)
    }

    @Dependency(\.contactsClient) var contactsClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.hapticClient) var haptics

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce<State, Action> { state, action in
            switch action {
            case .binding:
                return .none

            // Data management
            case .refreshDependents:
                guard state.currentUser != nil else { return .none }
                state.updateDependentCards() // Update cards with current data
                
                return .run { [contactsClient] send in
                    await send(.refreshResponse(Result {
                        try await contactsClient.refreshContacts()
                    }))
                }

            case let .setSortMode(mode):
                state.sortMode = mode
                state.updateDependentCards()
                return .run { _ in
                    await haptics.impact(.light)
                }

            // Contact interactions
            case let .selectContact(contact):
                state.contactDetails = ContactDetailsSheetFeature.State(contact: contact)
                return .run { _ in
                    await haptics.impact(.light)
                }

            case let .pingContact(contact):
                state.confirmationAlert = AlertState {
                    TextState("Ping Dependent")
                } actions: {
                    ButtonState(action: .confirmPing(contact)) {
                        TextState("Send Ping")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("Send a check-in ping to \(contact.name)?")
                }
                return .none

            case let .removeContact(contact):
                state.confirmationAlert = AlertState {
                    TextState("Remove Dependent")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmRemove(contact)) {
                        TextState("Remove")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("Are you sure you want to remove \(contact.name) as a dependent? This will not delete the contact entirely.")
                }
                return .none

            case let .toggleDependentStatus(contact):

                return .run { send in
                    // Since ContactsClient doesn't have updateContact method, 
                    // we simulate the status change by removing and re-adding
                    await send(.dependentStatusResponse(Result {
                        // This would be handled by gRPC streaming updates in production
                        var updatedContact = contact
                        updatedContact.isDependent.toggle()
                        return updatedContact
                    }))
                }

            case let .showRemoveConfirmation(contact):
                return .send(.removeContact(contact))

            case .showNotificationsHistory:
                state.notificationsHistory = NotificationsHistorySheetFeature.State()
                return .none

            // UI presentations
            case .contactDetails(.presented(.dismiss)):
                state.contactDetails = nil
                state.updateDependentCards() // Refresh the list after contact deletion
                return .none
                
            case .contactDetails(.presented(.contactDeleteResponse(.success))):
                // Contact was successfully deleted, refresh the list and close sheet if contact no longer exists
                state.updateDependentCards()
                
                // Check if the contact still exists in the shared state
                if let contactDetails = state.contactDetails,
                   state.contactsState.contact(by: contactDetails.contact.id) == nil {
                    // Contact was deleted, close the sheet
                    state.contactDetails = nil
                }
                return .none
                
            case .contactDetails:
                return .none

            case .notificationsHistory:
                return .none

            case .contactCards(.element(id: let contactId, action: .tapped)):
                // Handle contact card tap - forward to selectContact
                if let contact = state.contactsState.contacts.first(where: { $0.id.uuidString == contactId }) {
                    return .send(.selectContact(contact))
                }
                return .none

            case .contactCards:
                return .none

            case .confirmationAlert(.presented(.confirmPing(let contact))):

                return .run { send in
                    await haptics.notification(.warning)
                    await send(.pingResponse(Result {
                        // Update contact to show outgoing ping
                        var updatedContact = contact
                        updatedContact.hasOutgoingPing = true
                        updatedContact.outgoingPingTimestamp = Date()
                        await contactsClient.updateContact(updatedContact)
                        
                        // Send ping notification via NotificationClient
                        try await notificationClient.sendPingNotification(
                            .sendDependentPing,
                            "Ping Sent", 
                            "Sent check-in ping to \(contact.name)",
                            contact.id
                        )
                    }))
                }

            case .confirmationAlert(.presented(.confirmRemove(let contact))):

                return .run { send in
                    await haptics.notification(.success)
                    await send(.dependentStatusResponse(Result {
                        // Remove dependent status - would be handled by gRPC streaming in production
                        var updatedContact = contact
                        updatedContact.isDependent = false
                        return updatedContact
                    }))
                }

            case .confirmationAlert:
                return .none

            // Network responses
            case .pingResponse(.success):
                state.updateDependentCards()
                return .run { [haptics, notificationClient] _ in
                    await haptics.notification(.success)
                    try? await notificationClient.sendSystemNotification(
                        "Ping Sent",
                        "Check-in ping has been sent successfully to your dependent."
                    )
                }

            case let .pingResponse(.failure(error)):
                return .run { [haptics, notificationClient] _ in
                    await haptics.notification(.error)
                    try? await notificationClient.sendSystemNotification(
                        "Ping Failed",
                        "Unable to send ping: \(error.localizedDescription)"
                    )
                }

            case .removeResponse(.success):
                return .run { [haptics, notificationClient] _ in
                    await haptics.notification(.success)
                    try? await notificationClient.sendSystemNotification(
                        "Dependent Removed",
                        "The dependent has been successfully removed from your list."
                    )
                }

            case let .removeResponse(.failure(error)):
                return .run { [haptics, notificationClient] _ in
                    await haptics.notification(.error)
                    try? await notificationClient.sendSystemNotification(
                        "Remove Failed",
                        "Unable to remove dependent: \(error.localizedDescription)"
                    )
                }

            case let .dependentStatusResponse(.success(updatedContact)):
                return .run { [contactsClient, haptics, notificationClient] _ in
                    await contactsClient.updateContact(updatedContact)
                    await haptics.notification(.success)
                    try? await notificationClient.sendSystemNotification(
                        "Status Updated",
                        "Dependent status has been successfully updated."
                    )
                }

            case let .dependentStatusResponse(.failure(error)):
                return .run { [haptics, notificationClient] _ in
                    await haptics.notification(.error)
                    try? await notificationClient.sendSystemNotification(
                        "Status Update Failed",
                        "Unable to update dependent status: \(error.localizedDescription)"
                    )
                }

            case .refreshResponse(.success):
                state.updateDependentCards()
                // Also update the contact details if open and the contact still exists
                if let contactDetails = state.contactDetails,
                   let updatedContact = state.contactsState.contact(by: contactDetails.contact.id) {
                    state.contactDetails?.contact = updatedContact
                }
                return .none

            case .refreshResponse(.failure):
                return .run { [haptics, notificationClient] _ in
                    await haptics.notification(.warning)
                    try? await notificationClient.sendSystemNotification(
                        "Sync Issue",
                        "Unable to refresh dependents. Will retry automatically."
                    )
                }
            }
        }
        .ifLet(\.$contactDetails, action: \.contactDetails) {
            ContactDetailsSheetFeature()
        }
        .ifLet(\.$confirmationAlert, action: \.confirmationAlert)
        .ifLet(\.$notificationsHistory, action: \.notificationsHistory) {
            NotificationsHistorySheetFeature()
        }
        .forEach(\.dependentCards, action: \.contactCards) {
            ContactCardFeature()
        }
    }
}


struct DependentsView: View {
    @Bindable var store: StoreOf<DependentsFeature>
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Body
    
    var body: some View {
        WithPerceptionTracking {
            contentView
                .toolbar { toolbarContent }
                .onAppear(perform: onAppear)
                .alert($store.scope(state: \.confirmationAlert, action: \.confirmationAlert))
                .sheet(item: $store.scope(state: \.contactDetails, action: \.contactDetails)) { store in
                    ContactDetailsSheetView(store: store)
                }
                .sheet(item: $store.scope(state: \.notificationsHistory, action: \.notificationsHistory)) { store in
                    NotificationsHistorySheetView(store: store)
                }
        }
    }
}

// MARK: - Content Views

private extension DependentsView {
    
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
        if store.dependents.isEmpty {
            emptyStateView
        } else {
            contactsListView
        }
    }
    
    @ViewBuilder
    var emptyStateView: some View {
        Text("No dependents yet")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 40)
    }
    
    @ViewBuilder
    var contactsListView: some View {
        ForEach(store.scope(state: \.dependentCards, action: \.contactCards)) { cardStore in
            ContactCardView(store: cardStore, onTap: {})
        }
    }
}


// MARK: - Toolbar

private extension DependentsView {
    
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            sortMenuButton
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            notificationCenterButton
        }
    }
    
    @ViewBuilder
    var sortMenuButton: some View {
        Menu {
            ForEach(DependentsFeature.State.SortMode.allCases, id: \.self) { sortMode in
                Button(action: {
                    store.send(.setSortMode(sortMode), animation: .default)
                }) {
                    Label(sortMode.rawValue, systemImage: store.sortMode == sortMode ? "checkmark" : "")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                Text(store.sortMode.rawValue)
                    .font(.caption)
            }
        }
        .accessibilityLabel("Sort Dependents")
        .simultaneousGesture(TapGesture().onEnded { _ in
            store.send(.setSortMode(store.sortMode), animation: .default)
        })
    }
    
    @ViewBuilder
    var notificationCenterButton: some View {
        Button(action: notificationCenterAction) {
            Image(systemName: "square.fill.text.grid.1x2")
        }
    }
}

// MARK: - Actions

private extension DependentsView {
    
    func onAppear() {
        store.send(.refreshDependents, animation: .default)
    }
    
    func notificationCenterAction() {
        store.send(.showNotificationsHistory)
    }
}

