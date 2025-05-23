import Foundation
import SwiftUI
import ComposableArchitecture
import Sharing

@Reducer
struct RespondersFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.contacts) var allContacts: [Contact] = []
        @Shared(.currentUser) var currentUser: User? = nil
        
        var isLoading = false
        var errorMessage: String?
        @Presents var contactDetails: ContactDetailsSheetFeature.State?
        @Presents var confirmationAlert: AlertState<Action.Alert>?
        
        var responders: [Contact] {
            allContacts.filter { contact in
                // In production, check if contact is marked as responder
                contact.status != .offline
            }
        }
        
        var pendingPingsCount: Int {
            // In production, this would check for actual pending notifications
            responders.filter { $0.status == .busy }.count
        }
    }

    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case refreshResponders
        case selectContact(Contact)
        case pingContact(Contact)
        case removeContact(Contact)
        case respondToAllPings
        case showRemoveConfirmation(Contact)
        case contactDetails(PresentationAction<ContactDetailsSheetFeature.Action>)
        case confirmationAlert(PresentationAction<Alert>)
        case pingResponse(Result<Void, Error>)
        case removeResponse(Result<Void, Error>)
        
        enum Alert: Equatable {
            case confirmRemove(Contact)
            case confirmRespondAll
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
                
            case .refreshResponders:
                guard let currentUser = state.currentUser else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { send in
                    await analytics.track(.featureUsed(feature: "responders_refresh", context: [:]))
                    // In production, this would refresh contacts from the repository
                    // The shared contacts will automatically update the responders list
                    try? await Task.sleep(for: .milliseconds(500))
                    await send(.binding(.set(\.$isLoading, false)))
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
                
            case .contactDetails:
                return .none
                
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
                
                return .run { send in
                    await haptics.notification(.success)
                    await analytics.track(.featureUsed(feature: "respond_to_all_pings", context: ["ping_count": "\(state.pendingPingsCount)"]))
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
            }
        }
        .ifLet(\.$contactDetails, action: \.contactDetails) {
            ContactDetailsSheetFeature()
        }
        .ifLet(\.$confirmationAlert, action: \.confirmationAlert)
    }
}