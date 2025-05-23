import Foundation
import SwiftUI
import ComposableArchitecture
import Sharing

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
        @Presents var confirmationAlert: AlertState<Action.Alert>?
        
        var dependents: [Contact] {
            let filtered = allContacts.filter { contact in
                // In production, check if contact is marked as dependent
                contact.status != .offline
            }
            
            switch sortMode {
            case .name:
                return filtered.sorted { $0.name < $1.name }
            case .status:
                return filtered.sorted { $0.status.rawValue < $1.status.rawValue }
            case .lastUpdated:
                return filtered.sorted { $0.lastUpdated > $1.lastUpdated }
            }
        }
        
        enum SortMode: String, CaseIterable, Equatable {
            case name = "Name"
            case status = "Status"
            case lastUpdated = "Last Updated"
        }
    }

    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case refreshDependents
        case selectContact(Contact)
        case pingContact(Contact)
        case removeContact(Contact)
        case setSortMode(State.SortMode)
        case showRemoveConfirmation(Contact)
        case contactDetails(PresentationAction<ContactDetailsSheetFeature.Action>)
        case confirmationAlert(PresentationAction<Alert>)
        case pingResponse(Result<Void, Error>)
        case removeResponse(Result<Void, Error>)
        
        enum Alert: Equatable {
            case confirmRemove(Contact)
            case confirmPing(Contact)
        }
    }

    @Dependency(\.contactRepository) var contactRepository
    @Dependency(\.hapticClient) var haptics
    @Dependency(\.analytics) var analytics
    @Dependency(\.loggingClient) var logging

    var body: some Reducer<State, Action> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case .refreshDependents:
                guard let currentUser = state.currentUser else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { send in
                    await analytics.track(.featureUsed(feature: "dependents_refresh", context: [:]))
                    // In production, this would refresh contacts from the repository
                    // The shared contacts will automatically update the dependents list
                    try? await Task.sleep(for: .milliseconds(500))
                    await send(.binding(.set(\.$isLoading, false)))
                }
                
            case let .selectContact(contact):
                state.contactDetails = ContactDetailsSheetFeature.State(contact: contact)
                return .run { _ in
                    await analytics.track(.featureUsed(feature: "dependent_details_view", context: ["contact_id": contact.id.uuidString]))
                }
                
            case let .pingContact(contact):
                state.confirmationAlert = AlertState {
                    TextState("Check on Dependent")
                } actions: {
                    ButtonState(action: .confirmPing(contact)) {
                        TextState("Send Check-in")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("This will send a check-in request to \(contact.name).")
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
                    TextState("Are you sure you want to remove \(contact.name) as a dependent?")
                }
                return .none
                
            case let .setSortMode(mode):
                state.sortMode = mode
                return .run { _ in
                    await haptics.selection()
                    await analytics.track(.featureUsed(feature: "dependents_sort", context: ["sort_mode": mode.rawValue]))
                }
                
            case let .showRemoveConfirmation(contact):
                return .send(.removeContact(contact))
                
            case .contactDetails:
                return .none
                
            case .confirmationAlert(.presented(.confirmPing(let contact))):
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { send in
                    await haptics.notification(.success)
                    await analytics.track(.featureUsed(feature: "ping_dependent", context: ["contact_id": contact.id.uuidString]))
                    await send(.pingResponse(Result {
                        // In production, this would send a check-in request to the dependent
                        try await Task.sleep(for: .milliseconds(1000))
                    }))
                }
                
            case .confirmationAlert(.presented(.confirmRemove(let contact))):
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { send in
                    await haptics.notification(.success)
                    await analytics.track(.featureUsed(feature: "remove_dependent", context: ["contact_id": contact.id.uuidString]))
                    await send(.removeResponse(Result {
                        try await contactRepository.removeContact(contact.id)
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
            }
        }
        .ifLet(\.$contactDetails, action: \.contactDetails) {
            ContactDetailsSheetFeature()
        }
        .ifLet(\.$confirmationAlert, action: \.confirmationAlert)
    }
}
