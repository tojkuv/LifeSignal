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

@LifeSignalFeature
@Reducer
struct RespondersFeature: FeatureContext { // : FeatureContext (will be enforced by macro in Phase 2)
    @ObservableState
    struct State: Equatable {
        @Shared(.authenticationInternalState) var authState: AuthClientState
        @Shared(.contactsInternalState) var contactsState: ContactsClientState
        @Shared(.userInternalState) var userState: UserClientState
        
        var currentUser: User? { userState.currentUser }
        
        var isLoading = false
        
        // Add presentations
        @Presents var contactDetails: ContactDetailsSheetFeature.State?
        @Presents var confirmationAlert: AlertState<RespondersAlert>?
        @Presents var notificationsHistory: NotificationsHistorySheetFeature.State?
        var showClearAllPingsConfirmation = false
        
        var contactCards: IdentifiedArrayOf<ContactCardFeature.State> = []
        
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
        
        var responderCards: IdentifiedArrayOf<ContactCardFeature.State> = []
        
        mutating func updateResponderCards() {
            responderCards = IdentifiedArray(uniqueElements: responders.map { contact in
                ContactCardFeature.State(
                    contact: contact,
                    style: .responder(statusText: responderStatusText(for: contact))
                )
            })
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
        case contactsChanged
        
        // Contact interactions
        case selectContact(Contact)
        case pingContact(Contact)
        case removeContact(Contact)
        case clearAllPings
        case dismissClearAllPingsAlert
        case showRemoveConfirmation(Contact)
        case showNotificationsHistory
        
        // UI presentations
        case contactDetails(PresentationAction<ContactDetailsSheetFeature.Action>)
        case confirmationAlert(PresentationAction<RespondersAlert>)
        case notificationsHistory(PresentationAction<NotificationsHistorySheetFeature.Action>)
        case contactCards(IdentifiedActionOf<ContactCardFeature>)
        
        // Network responses
        case pingSuccess
        case pingFailure(Error)
        case removeSuccess
        case removeFailure(Error)
        case refreshSuccess
        case refreshFailure(Error)
        case checkInSuccess
        case checkInFailure(Error)
        
        // Biometric authentication
        case authenticateBiometricForPingClear
        case biometricAuthenticationSuccess(Bool)
        case biometricAuthenticationFailure(Error)
    }

    // Enhanced: Uses ReducerContext for architectural validation
    @Dependency(\.contactsClient) var contactsClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.hapticClient) var haptics
    @Dependency(\.userClient) var userClient
    @Dependency(\.biometricClient) var biometricClient
    
    // MARK: - Helper Action Methods
    
    private func refreshRespondersAction(state: inout State) -> Effect<Action> {
        guard state.currentUser != nil else { return .none }
        guard let authToken = state.authState.authenticationToken,
              let userId = state.userState.currentUser?.id else {
            return .send(.refreshFailure(ContactsClientError.authenticationRequired))
        }
        
        state.isLoading = true
        state.updateResponderCards()

        return .run { send in
            do {
                try await contactsClient.refreshContacts(authToken, userId)
                await send(.refreshSuccess)
            } catch {
                await send(.refreshFailure(error))
            }
        }
    }
    
    private func pingContactAction(state: inout State, contact: Contact) -> Effect<Action> {
        guard let authToken = state.authState.authenticationToken else {
            return .send(.pingFailure(ContactsClientError.authenticationRequired))
        }
        
        state.isLoading = true
        let senderName = state.currentUser?.name ?? "Someone"

        return .run { send in
            await haptics.notification(.warning)
            do {
                try await notificationClient.sendPingNotification(
                    .receiveResponderPing,
                    "You Received a Ping", 
                    "\(senderName) sent you a check-in ping",
                    contact.id,
                    authToken
                )
                await send(.pingSuccess)
            } catch {
                await send(.pingFailure(error))
            }
        }
    }
    
    private func removeContactAction(state: inout State, contact: Contact) -> Effect<Action> {
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
    }

    var body: some ReducerOf<Self> {
        Reduce<State, Action> { state, action in
            switch action {
            // Data management
            case .refreshResponders:
                return refreshRespondersAction(state: &state)

            case .contactsChanged:
                state.updateResponderCards()
                return .none

            // Contact interactions
            case let .selectContact(contact):
                state.contactDetails = ContactDetailsSheetFeature.State(contact: contact)
                return .none

            case let .pingContact(contact):
                return pingContactAction(state: &state, contact: contact)

            case let .removeContact(contact):
                return removeContactAction(state: &state, contact: contact)

            case .clearAllPings:
                guard state.pendingPingsCount > 0 else { return .none }
                state.showClearAllPingsConfirmation = true
                return .none

            case .dismissClearAllPingsAlert:
                state.showClearAllPingsConfirmation = false
                return .none

            case let .showRemoveConfirmation(contact):
                return .send(.removeContact(contact))

            case .showNotificationsHistory:
                state.notificationsHistory = NotificationsHistorySheetFeature.State()
                return .none

            // UI presentations
            case .contactDetails(.presented(.dismiss)):
                state.contactDetails = nil
                state.updateResponderCards() // Refresh the list after contact deletion
                return .none
                
            case .contactDetails(.presented(.contactDeleteResponse(.success))):
                // Contact was successfully deleted, refresh the list and close sheet if contact no longer exists
                state.updateResponderCards()
                
                // Check if the contact still exists in the shared state
                if let contactDetails = state.contactDetails,
                   !state.contactsState.contacts.contains(where: { $0.id == contactDetails.contact.id }) {
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

            case .confirmationAlert(.presented(.confirmRemove(let contact))):
                guard let authToken = state.authState.authenticationToken else {
                    return .send(.removeFailure(ContactsClientError.authenticationRequired))
                }
                
                state.isLoading = true

                return .run { send in
                    await haptics.notification(.success)
                    do {
                        try await contactsClient.removeContact(contact.id, authToken)
                        await send(.removeSuccess)
                    } catch {
                        await send(.removeFailure(error))
                    }
                }

            case .confirmationAlert(.presented(.confirmClearAllPings)):
                // Check biometric requirement before clearing pings
                if state.currentUser?.biometricAuthEnabled == true {
                    return .send(.authenticateBiometricForPingClear)
                }
                
                guard let authToken = state.authState.authenticationToken,
                      let currentUser = state.currentUser else {
                    return .send(.pingFailure(ContactsClientError.authenticationRequired))
                }
                
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

                return .run { send in
                    await haptics.notification(.success)
                    
                    // First: Perform check-in since responding to pings means user is safe
                    do {
                        // Update user with new check-in timestamp
                        var updatedUser = currentUser
                        updatedUser.lastCheckedIn = Date()
                        updatedUser.lastModified = Date()
                        
                        // Call updateUser to persist the check-in
                        try await userClient.updateUser(updatedUser, authToken)
                        await send(.checkInSuccess)
                    } catch {
                        await send(.checkInFailure(error))
                    }
                    
                    // Second: Send acknowledgment notifications to each contact who sent pings
                    for originalContact in contactsToNotify {
                        do {
                            try await notificationClient.sendPingNotification(
                                .receiveDependentPingResponded,
                                "Ping Acknowledged",
                                "Your ping has been acknowledged",
                                originalContact.id,
                                authToken
                            )
                        } catch {
                            // Continue with other notifications even if one fails
                            print("Failed to send acknowledgment to \(originalContact.name): \(error)")
                        }
                    }
                    
                    // Third: Update each contact's state to clear the pings
                    for contact in contactsToUpdate {
                        try await contactsClient.updateContact(contact, authToken)
                    }
                    
                    // Fourth: Clear notification history
                    do {
                        try await notificationClient.clearAllReceivedPings(authToken)
                        await send(.pingSuccess)
                    } catch {
                        await send(.pingFailure(error))
                    }
                }

            case .confirmationAlert:
                return .none

            // Network responses
            case .pingSuccess:
                state.isLoading = false
                return .run { _ in
                    await haptics.notification(.success)
                    try? await notificationClient.sendSystemNotification(
                        "Check-in Complete",
                        "You've checked in and responded to all pings."
                    )
                }

            case let .pingFailure(error):
                state.isLoading = false
                return .run { _ in
                    await haptics.notification(.error)
                    try? await notificationClient.sendSystemNotification(
                        "Operation Failed",
                        "Unable to clear pings: \(error.localizedDescription)"
                    )
                }

            case .removeSuccess:
                state.isLoading = false
                return .run { _ in
                    await haptics.notification(.success)
                    try? await notificationClient.sendSystemNotification(
                        "Responder Removed",
                        "The responder has been successfully removed from your list."
                    )
                }

            case let .removeFailure(error):
                state.isLoading = false
                return .run { _ in
                    await haptics.notification(.error)
                    try? await notificationClient.sendSystemNotification(
                        "Remove Failed",
                        "Unable to remove responder: \(error.localizedDescription)"
                    )
                }

            case .refreshSuccess:
                state.isLoading = false
                state.updateResponderCards()
                // Also update the contact details if open and the contact still exists
                if let contactDetails = state.contactDetails,
                   let updatedContact = state.contactsState.contacts.first(where: { $0.id == contactDetails.contact.id }) {
                    state.contactDetails?.contact = updatedContact
                }
                return .none

            case let .refreshFailure(error):
                state.isLoading = false
                return .run { _ in
                    await haptics.notification(.error)
                    try? await notificationClient.sendSystemNotification(
                        "Refresh Failed",
                        "Unable to refresh responders: \(error.localizedDescription)"
                    )
                }
                
            case .checkInSuccess:
                // Check-in successful - continue with ping clearing
                return .none
                
            case let .checkInFailure(error):
                // Check-in failed but continue with ping clearing anyway
                return .run { _ in
                    await haptics.notification(.warning)
                    try? await notificationClient.sendSystemNotification(
                        "Check-in Issue",
                        "Unable to complete check-in but pings were cleared: \(error.localizedDescription)"
                    )
                }
                
            // Biometric authentication
            case .authenticateBiometricForPingClear:
                return .run { send in
                    do {
                        let success = try await biometricClient.authenticate("Authenticate to respond to pings")
                        await send(.biometricAuthenticationSuccess(success))
                    } catch {
                        await send(.biometricAuthenticationFailure(error))
                    }
                }
                
            case let .biometricAuthenticationSuccess(success):
                if success {
                    // Proceed with ping clearing - reuse the existing logic
                    guard let authToken = state.authState.authenticationToken,
                          let currentUser = state.currentUser else {
                        return .send(.pingFailure(ContactsClientError.authenticationRequired))
                    }
                    
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

                    return .run { send in
                        await haptics.notification(.success)
                        
                        // First: Perform check-in since responding to pings means user is safe
                        do {
                            // Update user with new check-in timestamp
                            var updatedUser = currentUser
                            updatedUser.lastCheckedIn = Date()
                            updatedUser.lastModified = Date()
                            
                            // Call updateUser to persist the check-in
                            try await userClient.updateUser(updatedUser, authToken)
                            await send(.checkInSuccess)
                        } catch {
                            await send(.checkInFailure(error))
                        }
                        
                        // Second: Send acknowledgment notifications to each contact who sent pings
                        for originalContact in contactsToNotify {
                            do {
                                try await notificationClient.sendPingNotification(
                                    .receiveDependentPingResponded,
                                    "Ping Acknowledged",
                                    "Your ping has been acknowledged",
                                    originalContact.id,
                                    authToken
                                )
                            } catch {
                                // Continue with other notifications even if one fails
                                print("Failed to send acknowledgment to \(originalContact.name): \(error)")
                            }
                        }
                        
                        // Third: Update each contact's state to clear the pings
                        for contact in contactsToUpdate {
                            try await contactsClient.updateContact(contact, authToken)
                        }
                        
                        // Fourth: Clear notification history
                        do {
                            try await notificationClient.clearAllReceivedPings(authToken)
                            await send(.pingSuccess)
                        } catch {
                            await send(.pingFailure(error))
                        }
                    }
                } else {
                    return .run { _ in
                        await haptics.notification(.error)
                    }
                }
                
            case let .biometricAuthenticationFailure(error):
                return .run { [notificationClient] _ in
                    await haptics.notification(.error)
                    
                    let message: String
                    if let biometricError = error as? BiometricClientError {
                        switch biometricError {
                        case .userCancel:
                            message = "Biometric authentication was cancelled."
                        case .notAvailable:
                            message = "Biometric authentication is not available."
                        case .notEnrolled:
                            message = "No biometric data is enrolled on this device."
                        default:
                            message = biometricError.errorDescription ?? "Biometric authentication failed."
                        }
                    } else {
                        message = "Biometric authentication failed."
                    }
                    
                    try? await notificationClient.sendSystemNotification(
                        "Authentication Failed",
                        message
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
        .forEach(\.responderCards, action: \.contactCards) {
            ContactCardFeature()
        }
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
                .onChange(of: store.contactsState.contacts) { _, _ in
                    store.send(.contactsChanged)
                }
                .alert($store.scope(state: \.confirmationAlert, action: \.confirmationAlert))
                .alert("Clear All Pings", isPresented: confirmationBinding, actions: alertActions, message: alertMessage)
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
        ForEach(store.scope(state: \.responderCards, action: \.contactCards)) { cardStore in
            ContactCardView(store: cardStore, onTap: {})
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
                Text("Respond")
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
    }
}

// MARK: - Alerts

private extension RespondersView {
    
    var confirmationBinding: Binding<Bool> {
        Binding(
            get: { store.showClearAllPingsConfirmation },
            set: { newValue in
                if !newValue {
                    store.send(.dismissClearAllPingsAlert)
                }
            }
        )
    }
    
    @ViewBuilder
    func alertActions() -> some View {
        Button("Respond") {
            store.send(.confirmationAlert(.presented(.confirmClearAllPings)), animation: .default)
        }
        Button("Cancel", role: .cancel) {
            store.send(.dismissClearAllPingsAlert)
        }
    }
    
    @ViewBuilder
    func alertMessage() -> some View {
        Text("This will check you in and respond to all pending pings from your responders.")
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
        store.send(.showNotificationsHistory)
    }
}

