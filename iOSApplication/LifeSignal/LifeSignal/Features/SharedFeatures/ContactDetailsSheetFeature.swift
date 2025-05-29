import SwiftUI
import Foundation
import ComposableArchitecture
import Perception

enum ContactDetailsAlert: Equatable {
    case confirmDelete
    case confirmRoleChange(ContactRole, Bool)
    case pingDisabled
    case confirmSendPing
    case confirmCancelPing
}

enum ContactRole: Equatable {
    case responder
    case dependent
}

@Reducer
struct ContactDetailsSheetFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.authenticationInternalState) var authState: ReadOnlyAuthenticationState
        var contact: Contact
        var isLoading = false
        @Presents var alert: AlertState<ContactDetailsAlert>?
        
        var isNotResponsive: Bool {
            contact.hasNotResponsiveAlert
        }
        
        init(contact: Contact) {
            self.contact = contact
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case pingContact
        case callContact
        case messageContact
        case removeContact
        case updateResponderStatus(Bool)
        case updateDependentStatus(Bool)
        case alert(PresentationAction<ContactDetailsAlert>)
        case contactUpdateResponse(Result<Contact, Error>)
        case contactDeleteResponse(Result<Void, Error>)
        case pingResponse(Result<Void, Error>)
        case dismiss
    }

    @Dependency(\.contactsClient) var contactsClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.hapticClient) var haptics

    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case .pingContact:
                guard state.contact.isDependent else {
                    state.alert = AlertState {
                        TextState("Cannot Ping")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("OK")
                        }
                    } message: {
                        TextState("This contact must have the Dependent role to be pinged.")
                    }
                    return .none
                }
                
                // Show confirmation alert for ping actions
                let contactName = state.contact.name
                if state.contact.hasOutgoingPing {
                    // Confirm clearing existing ping
                    state.alert = AlertState {
                        TextState("Cancel Ping")
                    } actions: {
                        ButtonState(action: .confirmCancelPing) {
                            TextState("Cancel Ping")
                        }
                        ButtonState(role: .cancel) {
                            TextState("Keep Ping")
                        }
                    } message: {
                        TextState("Are you sure you want to cancel the ping to \(contactName)?")
                    }
                    return .none
                } else {
                    // Confirm sending new ping
                    state.alert = AlertState {
                        TextState("Send Ping")
                    } actions: {
                        ButtonState(action: .confirmSendPing) {
                            TextState("Send Ping")
                        }
                        ButtonState(role: .cancel) {
                            TextState("Cancel")
                        }
                    } message: {
                        TextState("Send a ping to \(contactName) to check on them?")
                    }
                    return .none
                }
                
            case .callContact:
                return .run { [contact = state.contact] _ in
                    await haptics.impact(.light)
                    if let url = URL(string: "tel:\(contact.phoneNumber)") {
                        await MainActor.run {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                
            case .messageContact:
                return .run { [contact = state.contact] _ in
                    await haptics.impact(.light)
                    if let url = URL(string: "sms:\(contact.phoneNumber)") {
                        await MainActor.run {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                
            case .removeContact:
                state.alert = AlertState {
                    TextState("Delete Contact")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmDelete) {
                        TextState("Delete")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("Are you sure you want to delete this contact? This action cannot be undone.")
                }
                return .none
                
            case let .updateResponderStatus(isResponder):
                // Check if this would remove all roles
                if !isResponder && !state.contact.isDependent {
                    state.alert = AlertState {
                        TextState("Role Required")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("OK")
                        }
                    } message: {
                        TextState("This contact must have at least one role. To remove this contact completely, use the Delete Contact button.")
                    }
                    return .none
                }
                
                state.alert = AlertState {
                    TextState(isResponder ? "Add Responder Role" : "Remove Responder Role")
                } actions: {
                    ButtonState(action: .confirmRoleChange(.responder, isResponder)) {
                        TextState("Confirm")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState(isResponder ? 
                        "This contact will be able to respond to your alerts and check-ins." :
                        "This contact will no longer be able to respond to your alerts and check-ins.")
                }
                return .none
                
            case let .updateDependentStatus(isDependent):
                // Check if this would remove all roles
                if !isDependent && !state.contact.isResponder {
                    state.alert = AlertState {
                        TextState("Role Required")
                    } actions: {
                        ButtonState(role: .cancel) {
                            TextState("OK")
                        }
                    } message: {
                        TextState("This contact must have at least one role. To remove this contact completely, use the Delete Contact button.")
                    }
                    return .none
                }
                
                // If removing dependent role and there's an active outgoing ping, mention it will be cancelled
                let alertMessage: String
                if !isDependent && state.contact.hasOutgoingPing {
                    alertMessage = "You will no longer be able to check on this contact or send them pings. The current pending ping will be cancelled."
                } else if isDependent {
                    alertMessage = "You will be able to check on this contact and send them pings."
                } else {
                    alertMessage = "You will no longer be able to check on this contact or send them pings."
                }
                
                state.alert = AlertState {
                    TextState(isDependent ? "Add Dependent Role" : "Remove Dependent Role")
                } actions: {
                    ButtonState(action: .confirmRoleChange(.dependent, isDependent)) {
                        TextState("Confirm")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState(alertMessage)
                }
                return .none
                
            case .alert(.presented(.confirmDelete)):
                state.isLoading = true
                return .run { [contact = state.contact, authToken = state.authState.authenticationToken] send in
                    await haptics.notification(.warning)
                    await send(.contactDeleteResponse(Result {
                        guard let token = authToken else {
                            throw ContactsClientError.authenticationRequired
                        }
                        try await contactsClient.removeContact(contact.id, token)
                    }))
                }
                
            case .alert(.presented(.confirmRoleChange(let role, let newValue))):
                var updatedContact = state.contact
                switch role {
                case .responder:
                    updatedContact.isResponder = newValue
                case .dependent:
                    updatedContact.isDependent = newValue
                    // Cancel any outgoing ping if removing dependent role
                    if !newValue && updatedContact.hasOutgoingPing {
                        updatedContact.hasOutgoingPing = false
                        updatedContact.outgoingPingTimestamp = nil
                    }
                }
                state.contact = updatedContact
                state.isLoading = true
                
                return .run { [contact = updatedContact, originalContact = state.contact, authToken = state.authState.authenticationToken] send in
                    await haptics.notification(.success)
                    
                    // If we cancelled an outgoing ping, send notification
                    if role == .dependent && !newValue && originalContact.hasOutgoingPing, let token = authToken {
                        try? await notificationClient.sendPingNotification(
                            .cancelDependentPing,
                            "Ping Cancelled",
                            "Ping to \(contact.name) was cancelled when removing dependent role",
                            contact.id,
                            token
                        )
                    }
                    
                    await send(.contactUpdateResponse(Result {
                        guard let token = authToken else {
                            throw ContactsClientError.authenticationRequired
                        }
                        try await contactsClient.updateContact(contact, token)
                        return contact
                    }))
                }
                
            case .alert(.presented(.confirmSendPing)):
                return .run { [contact = state.contact, authToken = state.authState.authenticationToken] send in
                    await haptics.impact(.medium)
                    do {
                        guard let token = authToken else {
                            throw ContactsClientError.authenticationRequired
                        }
                        
                        // Update contact to show outgoing ping
                        var updatedContact = contact
                        updatedContact.hasOutgoingPing = true
                        updatedContact.outgoingPingTimestamp = Date()
                        try await contactsClient.updateContact(updatedContact, token)
                        
                        // Send ping notification
                        try await notificationClient.sendPingNotification(
                            .sendDependentPing,
                            "Ping Sent",
                            "You sent a ping to \(contact.name)",
                            contact.id,
                            token
                        )
                        await send(.pingResponse(.success(())))
                    } catch {
                        await send(.pingResponse(.failure(error)))
                    }
                }
                
            case .alert(.presented(.confirmCancelPing)):
                return .run { [contact = state.contact, authToken = state.authState.authenticationToken] send in
                    await haptics.impact(.medium)
                    do {
                        guard let token = authToken else {
                            throw ContactsClientError.authenticationRequired
                        }
                        
                        // Clear the ping
                        var updatedContact = contact
                        updatedContact.hasOutgoingPing = false
                        updatedContact.outgoingPingTimestamp = nil
                        try await contactsClient.updateContact(updatedContact, token)
                        
                        // Send notification about clearing ping
                        try await notificationClient.sendPingNotification(
                            .cancelDependentPing,
                            "Ping Cancelled",
                            "You cancelled the ping to \(contact.name)",
                            contact.id,
                            token
                        )
                        await send(.pingResponse(.success(())))
                    } catch {
                        await send(.pingResponse(.failure(error)))
                    }
                }
                
            case .alert:
                return .none
                
            case .contactUpdateResponse(.success(let contact)):
                state.isLoading = false
                state.contact = contact
                return .run { [haptics, notificationClient] _ in
                    await haptics.notification(.success)
                    try? await notificationClient.sendSystemNotification(
                        "Contact Updated",
                        "Successfully updated \(contact.name)'s roles"
                    )
                }
                
            case .contactUpdateResponse(.failure(let error)):
                state.isLoading = false
                return .run { [haptics, notificationClient] _ in
                    await haptics.notification(.error)
                    try? await notificationClient.sendSystemNotification(
                        "Update Failed",
                        "Unable to update contact: \(error.localizedDescription)"
                    )
                }
                
            case .contactDeleteResponse(.success):
                state.isLoading = false
                return .run { [contact = state.contact, haptics, notificationClient] send in
                    await haptics.notification(.success)
                    try? await notificationClient.sendSystemNotification(
                        "Contact Deleted",
                        "Successfully deleted \(contact.name)"
                    )
                    await send(.dismiss)
                }
                
            case .contactDeleteResponse(.failure(let error)):
                state.isLoading = false
                return .run { [haptics, notificationClient] _ in
                    await haptics.notification(.error)
                    try? await notificationClient.sendSystemNotification(
                        "Delete Failed",
                        "Unable to delete contact: \(error.localizedDescription)"
                    )
                }
                
            case .pingResponse(.success):
                // Update the contact state in this feature to reflect the ping changes
                @Shared(.contacts) var contacts
                if let updatedContact = contacts.contact(by: state.contact.id) {
                    state.contact = updatedContact
                }
                return .run { [haptics, notificationClient] _ in
                    await haptics.notification(.success)
                    try? await notificationClient.sendSystemNotification(
                        "Ping Updated",
                        "Successfully updated ping status"
                    )
                }
                
            case .pingResponse(.failure(let error)):
                return .run { [haptics, notificationClient] _ in
                    await haptics.notification(.error)
                    try? await notificationClient.sendSystemNotification(
                        "Ping Failed",
                        "Unable to update ping: \(error.localizedDescription)"
                    )
                }
                
            case .dismiss:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

struct ContactDetailsSheetView: View {
    @Bindable var store: StoreOf<ContactDetailsSheetFeature>
    @Environment(\.colorScheme) private var colorScheme
    
    @Dependency(\.phoneNumberFormatter) var phoneNumberFormatter
    
    private var hasAlertCards: Bool {
        store.contact.hasManualAlertActive || 
        store.contact.hasNotResponsiveAlert || 
        (store.contact.hasIncomingPing && store.contact.isResponder) || 
        (store.contact.hasOutgoingPing && store.contact.isDependent)
    }
    
    var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        // Header
                        contactHeaderView()
                        
                        // Action Buttons
                        actionButtonsView()
                        
                        // Alert Cards (only show if there are alerts)
                        if hasAlertCards {
                            alertCardsView()
                        }
                        
                        // Information Cards
                        noteCardView()
                        rolesCardView()
                        checkInCardView()
                        deleteButtonView()
                    }
                }
                .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
                .navigationTitle("Contact Info")
                .navigationBarTitleDisplayMode(.inline)
            }
            .alert($store.scope(state: \.alert, action: \.alert))
        }
    }
    
    
    // MARK: - Contact Header View
    @ViewBuilder
    private func contactHeaderView() -> some View {
        VStack(spacing: 12) {
            CommonAvatarView(
                name: store.contact.name,
                size: 100,
                backgroundColor: Color.blue.opacity(0.1),
                textColor: .blue,
                strokeWidth: 2,
                strokeColor: .blue
            )
            .padding(.top)
                
            Text(store.contact.name)
                .font(.headline)
                .bold()
                .foregroundColor(.primary)
                
            Text(phoneNumberFormatter.formatPhoneNumberForDisplay(store.contact.phoneNumber))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Action Buttons View
    @ViewBuilder
    private func actionButtonsView() -> some View {
        HStack(spacing: 12) {
            // Call Button
            Button(action: {
                store.send(.callContact)
            }) {
                VStack(spacing: 6) {
                    Image(systemName: "phone")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                    
                    Text("Call")
                        .font(.body)
                        .foregroundColor(.primary)
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .frame(height: 75)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
            
            // Message Button
            Button(action: {
                store.send(.messageContact)
            }) {
                VStack(spacing: 6) {
                    Image(systemName: "message")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                    
                    Text("Message")
                        .font(.body)
                        .foregroundColor(.primary)
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .frame(height: 75)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
            
            // Ping Button
            Button(action: {
                store.send(.pingContact)
            }) {
                VStack(spacing: 6) {
                    Image(systemName: store.contact.hasOutgoingPing ? "bell.slash" : "bell.badge.waveform")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                    
                    Text(store.contact.hasOutgoingPing ? "Clear" : "Ping")
                        .font(.body)
                        .foregroundColor(.primary)
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .frame(height: 75)
                .background(
                    store.contact.hasOutgoingPing ?
                        Color.blue.opacity(0.1) : Color(UIColor.secondarySystemGroupedBackground)
                )
                .cornerRadius(12)
                .opacity(store.contact.isDependent ? 1.0 : 0.5)
            }
            .disabled(!store.contact.isDependent)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Alert Cards View
    @ViewBuilder
    private func alertCardsView() -> some View {
        VStack(spacing: 16) {
            // Emergency Alert Card
            if store.contact.hasManualAlertActive {
                alertCard(
                    title: "Sent out an Alert",
                    description: "This dependent has sent an emergency alert.",
                    timestamp: store.contact.emergencyAlertTimestamp,
                    color: .red
                )
            }
            
            // Non-responsive Card
            if store.contact.hasNotResponsiveAlert {
                alertCard(
                    title: "Non-responsive",
                    description: "This dependent has not checked in within their scheduled interval.",
                    timestamp: store.contact.notResponsiveAlertTimestamp,
                    color: colorScheme == .light ? .orange : .yellow
                )
            }
            
            // Incoming Ping Card
            if store.contact.hasIncomingPing && store.contact.isResponder {
                alertCard(
                    title: "Pinged You",
                    description: "This contact has sent you a ping requesting a response.",
                    timestamp: store.contact.incomingPingTimestamp,
                    color: .blue
                )
            }
            
            // Outgoing Ping Card
            if store.contact.hasOutgoingPing && store.contact.isDependent {
                alertCard(
                    title: "You Pinged Them",
                    description: "You have sent a ping to this dependent.",
                    timestamp: store.contact.outgoingPingTimestamp,
                    color: .blue
                )
            }
        }
    }
    
    @ViewBuilder
    private func alertCard(title: String, description: String, timestamp: Date?, color: Color) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(color)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let timestamp = timestamp {
                    Text(formatTimeAgo(timestamp))
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal)
        }
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Information Card Views
    @ViewBuilder
    private func noteCardView() -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(store.contact.emergencyNote.isEmpty ? "No emergency information provided yet." : store.contact.emergencyNote)
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
    
    @ViewBuilder
    private func rolesCardView() -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Dependent")
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { store.contact.isDependent },
                    set: { store.send(.updateDependentStatus($0)) }
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
                    set: { store.send(.updateResponderStatus($0)) }
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
    
    @ViewBuilder
    private func checkInCardView() -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Check-in interval")
                    .foregroundColor(.primary)
                    .font(.body)
                Spacer()
                Text(formatInterval(store.contact.checkInInterval))
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
                if let lastCheckIn = store.contact.lastCheckInTimestamp {
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
    
    @ViewBuilder
    private func deleteButtonView() -> some View {
        Button(action: {
            store.send(.removeContact)
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
    
    // MARK: - Helper Functions
    private func formatTimeAgo(_ date: Date) -> String {
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
    
    private func formatInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        if hours < 24 {
            return "\(hours) hours"
        } else {
            let days = hours / 24
            return "\(days) days"
        }
    }
}