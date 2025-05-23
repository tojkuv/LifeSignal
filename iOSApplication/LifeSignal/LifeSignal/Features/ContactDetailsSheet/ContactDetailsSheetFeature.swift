import Foundation
import SwiftUI
import ComposableArchitecture

@Reducer
struct ContactDetailsSheetFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.currentUser) var currentUser: User? = nil
        
        var contact: Contact
        var editedContact: Contact
        var isEditing = false
        var isLoading = false
        var errorMessage: String?
        @Presents var confirmationAlert: AlertState<Action.Alert>?
        
        var canEdit: Bool { currentUser != nil }
        var canSave: Bool {
            guard isEditing else { return false }
            return !editedContact.name.isEmpty && 
                   !editedContact.phoneNumber.isEmpty && 
                   editedContact != contact
        }
        
        var lastUpdatedText: String {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: contact.lastUpdated, relativeTo: Date())
        }
        
        init(contact: Contact) {
            self.contact = contact
            self.editedContact = contact
        }
    }

    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case edit
        case save
        case cancel
        case delete
        case ping
        case showDeleteConfirmation
        case confirmationAlert(PresentationAction<Alert>)
        case updateResponse(Result<Contact, Error>)
        case deleteResponse(Result<Void, Error>)
        case pingResponse(Result<Void, Error>)
        
        enum Alert: Equatable {
            case confirmDelete
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
            case .binding(\State.$editedContact):
                state.errorMessage = nil
                return .none
                
            case .binding:
                return .none
                
            case .edit:
                guard state.canEdit else { return .none }
                state.isEditing = true
                state.editedContact = state.contact
                
                return .run { _ in
                    await haptics.impact(.medium)
                    await analytics.track(.featureUsed(feature: "contact_edit", context: ["contact_id": state.contact.id.uuidString]))
                }
                
            case .save:
                guard state.canSave else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { [editedContact = state.editedContact] send in
                    await send(.updateResponse(Result {
                        try await contactRepository.updateContactStatus(editedContact.id, editedContact.status)
                    }))
                }
                
            case .cancel:
                state.isEditing = false
                state.editedContact = state.contact
                state.errorMessage = nil
                
                return .run { _ in
                    await haptics.impact(.medium)
                }
                
            case .delete:
                state.confirmationAlert = AlertState {
                    TextState("Delete Contact")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmDelete) {
                        TextState("Delete")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("Are you sure you want to delete \(state.contact.name)? This action cannot be undone.")
                }
                return .none
                
            case .ping:
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { [contactId = state.contact.id] send in
                    await haptics.notification(.warning)
                    await analytics.track(.featureUsed(feature: "contact_ping", context: ["contact_id": contactId.uuidString]))
                    await send(.pingResponse(Result {
                        // In production, this would send a ping/notification to the contact
                        try await Task.sleep(for: .milliseconds(1000))
                    }))
                }
                
            case .showDeleteConfirmation:
                return .send(.delete)
                
            case .confirmationAlert(.presented(.confirmDelete)):
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { [contactId = state.contact.id] send in
                    await analytics.track(.featureUsed(feature: "contact_delete", context: ["contact_id": contactId.uuidString]))
                    await send(.deleteResponse(Result {
                        try await contactRepository.removeContact(contactId)
                    }))
                }
                
            case .confirmationAlert:
                return .none
                
            case let .updateResponse(.success(updatedContact)):
                state.isLoading = false
                state.isEditing = false
                state.contact = updatedContact
                state.editedContact = updatedContact
                
                return .run { _ in
                    await haptics.notification(.success)
                }
                
            case let .updateResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case .deleteResponse(.success):
                state.isLoading = false
                return .run { _ in
                    await haptics.notification(.success)
                    // The sheet should be dismissed by the parent feature
                }
                
            case let .deleteResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
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
            }
        }
        .ifLet(\.$confirmationAlert, action: \.confirmationAlert)
    }
}
