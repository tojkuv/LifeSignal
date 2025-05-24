import Foundation
import SwiftUI
import ComposableArchitecture

// Define Alert enum outside to avoid circular dependencies
enum DependentsAlert: Equatable {
    case confirmRemove(Contact)
    case confirmPing(Contact)
}

@Reducer
struct DependentsFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.contacts) var allContacts: [Contact] = []
        @Shared(.currentUser) var currentUser: User? = nil
        
        var isLoading = false
        var errorMessage: String?
        var sortMode: SortMode = .lastUpdated
        @Presents var contactDetails: ContactDetailsSheetFeature.State?
        @Presents var confirmationAlert: AlertState<DependentsAlert>?
        
        var dependents: [Contact] {
            let filtered = allContacts.filter { contact in
                // Filter for contacts marked as dependents
                contact.isDependent
            }
            
            switch sortMode {
            case .name:
                return filtered.sorted { $0.name < $1.name }
            case .activity:
                return filtered.sorted { (contact1, contact2) in
                    // Sort by most recent activity (check-in, ping, or manual alert)
                    let date1 = [contact1.lastCheckInTime, contact1.incomingPingTimestamp, contact1.outgoingPingTimestamp, contact1.manualAlertTimestamp]
                        .compactMap { $0 }
                        .max() ?? contact1.lastUpdated
                    let date2 = [contact2.lastCheckInTime, contact2.incomingPingTimestamp, contact2.outgoingPingTimestamp, contact2.manualAlertTimestamp]
                        .compactMap { $0 }
                        .max() ?? contact2.lastUpdated
                    return date1 > date2
                }
            case .lastUpdated:
                return filtered.sorted { $0.lastUpdated > $1.lastUpdated }
            case .alertStatus:
                return filtered.sorted { (contact1, contact2) in
                    // Sort by alert priority: manual alerts first, then ping status, then by name
                    if contact1.manualAlertActive != contact2.manualAlertActive {
                        return contact1.manualAlertActive && !contact2.manualAlertActive
                    }
                    if contact1.hasIncomingPing != contact2.hasIncomingPing {
                        return contact1.hasIncomingPing && !contact2.hasIncomingPing
                    }
                    if contact1.hasOutgoingPing != contact2.hasOutgoingPing {
                        return contact1.hasOutgoingPing && !contact2.hasOutgoingPing
                    }
                    return contact1.name < contact2.name
                }
            }
        }
        
        enum SortMode: String, CaseIterable, Equatable {
            case name = "Name"
            case activity = "Recent Activity"
            case lastUpdated = "Last Updated"
            case alertStatus = "Alert Status"
        }
        
        var dependentCount: Int {
            dependents.count
        }
        
        var activeDependents: [Contact] {
            dependents.filter { contact in
                // Consider a dependent "active" if they've checked in recently or have active pings
                contact.hasIncomingPing || contact.hasOutgoingPing || contact.manualAlertActive ||
                (contact.lastCheckInTime?.timeIntervalSinceNow ?? -Double.infinity) > -contact.interval
            }
        }
        
        var alertingDependents: [Contact] {
            dependents.filter { $0.manualAlertActive }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case refreshDependents
        case selectContact(Contact)
        case pingContact(Contact)
        case removeContact(Contact)
        case toggleDependentStatus(Contact)
        case setSortMode(State.SortMode)
        case showRemoveConfirmation(Contact)
        case contactDetails(PresentationAction<ContactDetailsSheetFeature.Action>)
        case confirmationAlert(PresentationAction<DependentsAlert>)
        case pingResponse(Result<Void, Error>)
        case removeResponse(Result<Void, Error>)
        case dependentStatusResponse(Result<Contact, Error>)
    }

    @Dependency(\.contactRepository) var contactRepository
    @Dependency(\.hapticClient) var haptics
    @Dependency(\.analytics) var analytics
    @Dependency(\.loggingClient) var logging

    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce<State, Action> { state, action in
            switch action {
            case .binding:
                return .none
                
            case .refreshDependents:
                guard let currentUser = state.currentUser else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                
                let dependentCount = state.dependents.count
                
                return .run { [allContacts = state.$allContacts] send in
                    await analytics.track(.featureUsed(feature: "dependents_refresh", context: [
                        "dependent_count": "\(dependentCount)"
                    ]))
                    
                    // Refresh contacts from the repository
                    do {
                        let contacts = try await contactRepository.getContacts()
                        // Update shared contacts directly
                        allContacts.withLock { $0 = contacts }
                        await send(.binding(.set(\.isLoading, false)))
                    } catch {
                        await send(.binding(.set(\.isLoading, false)))
                        await send(.binding(.set(\.errorMessage, error.localizedDescription)))
                    }
                }
                
            case let .selectContact(contact):
                state.contactDetails = ContactDetailsSheetFeature.State(contact: contact)
                return .run { _ in
                    await analytics.track(.featureUsed(feature: "dependent_details_view", context: [
                        "contact_id": contact.id.uuidString,
                        "has_manual_alert": "\(contact.manualAlertActive)",
                        "has_incoming_ping": "\(contact.hasIncomingPing)",
                        "has_outgoing_ping": "\(contact.hasOutgoingPing)"
                    ]))
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
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { send in
                    await analytics.track(.contactDependentStatusChanged(contactId: contact.id, isDependent: !contact.isDependent))
                    await send(.dependentStatusResponse(Result {
                        try await contactRepository.updateContactDependent(contact.id, !contact.isDependent)
                    }))
                }
                
            case let .setSortMode(mode):
                state.sortMode = mode
                return .run { _ in
                    await haptics.impact(.light)
                    await analytics.track(.featureUsed(feature: "dependents_sort", context: ["mode": mode.rawValue]))
                }
                
            case let .showRemoveConfirmation(contact):
                return .send(.removeContact(contact))
                
            case .contactDetails:
                return .none
                
            case .confirmationAlert(.presented(.confirmPing(let contact))):
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { send in
                    await haptics.notification(.warning)
                    await analytics.track(.featureUsed(feature: "ping_dependent", context: [
                        "contact_id": contact.id.uuidString,
                        "contact_name": contact.name
                    ]))
                    await send(.pingResponse(Result {
                        // Update ping status for the contact
                        _ = try await contactRepository.updateContactPingStatus(contact.id, true, false)
                        // In production, this would also send a notification to the dependent
                        try await Task.sleep(for: .milliseconds(1000))
                    }))
                }
                
            case .confirmationAlert(.presented(.confirmRemove(let contact))):
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { send in
                    await haptics.notification(.success)
                    await analytics.track(.featureUsed(feature: "remove_dependent_status", context: [
                        "contact_id": contact.id.uuidString,
                        "contact_name": contact.name
                    ]))
                    await send(.dependentStatusResponse(Result {
                        // Remove dependent status rather than deleting the contact entirely
                        try await contactRepository.updateContactDependent(contact.id, false)
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
                
            case let .dependentStatusResponse(.success(updatedContact)):
                state.isLoading = false
                // Update the contact in the shared state
                state.$allContacts.withLock { contacts in
                    if let index = contacts.firstIndex(where: { $0.id == updatedContact.id }) {
                        contacts[index] = updatedContact
                    }
                }
                return .run { _ in
                    await haptics.notification(.success)
                }
                
            case let .dependentStatusResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
            }
        }
        .ifLet(\.$contactDetails, action: \.contactDetails) {
            ContactDetailsSheetFeature()
        }
        .ifLet(\.$confirmationAlert, action: \.confirmationAlert)
    }
}
