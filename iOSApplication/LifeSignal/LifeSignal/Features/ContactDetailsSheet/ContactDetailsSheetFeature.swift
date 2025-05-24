import Foundation
import SwiftUI
import ComposableArchitecture

// Define Alert enum outside to avoid circular dependencies
enum ContactDetailsAlert: Equatable {
    case confirmDelete
}

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
        @Presents var confirmationAlert: AlertState<ContactDetailsAlert>?
        
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

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case edit
        case save
        case cancel
        case delete
        case ping
        case showDeleteConfirmation
        case confirmationAlert(PresentationAction<ContactDetailsAlert>)
        case updateResponse(Result<Contact, Error>)
        case deleteResponse(Result<Void, Error>)
        case pingResponse(Result<Void, Error>)
    }

    @Dependency(\.contactRepository) var contactRepository
    @Dependency(\.hapticClient) var haptics
    @Dependency(\.analytics) var analytics
    @Dependency(\.loggingClient) var logging

    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding(\.editedContact):
                state.errorMessage = nil
                return .none
                
            case .binding:
                return .none
                
            case .edit:
                guard state.canEdit else { return .none }
                state.isEditing = true
                state.editedContact = state.contact
                
                let contactId = state.contact.id.uuidString
                return .run { _ in
                    await analytics.track(.featureUsed(feature: "contact_edit_start", context: ["contact_id": contactId]))
                    await haptics.impact(.light)
                }
                
            case .save:
                guard state.canSave else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                
                let updatedContact = state.editedContact
                return .run { send in
                    await haptics.impact(.medium)
                    await analytics.track(.featureUsed(feature: "contact_save", context: ["contact_id": updatedContact.id.uuidString]))
                    await send(.updateResponse(Result {
                        // Update the contact with the current timestamp
                        var contactToUpdate = updatedContact
                        contactToUpdate.lastUpdated = Date()
                        return try await contactRepository.updateContact(contactToUpdate)
                    }))
                }
                
            case .cancel:
                state.isEditing = false
                state.editedContact = state.contact
                state.errorMessage = nil
                return .run { _ in
                    await haptics.impact(.light)
                }
                
            case .delete:
                return .send(.showDeleteConfirmation)
                
            case .ping:
                state.isLoading = true
                state.errorMessage = nil
                
                let contact = state.contact
                return .run { send in
                    await haptics.notification(.warning)
                    await analytics.track(.featureUsed(feature: "contact_ping", context: ["contact_id": contact.id.uuidString]))
                    await send(.pingResponse(Result {
                        // In production, this would send a notification to the contact
                        try await Task.sleep(for: .milliseconds(1000))
                    }))
                }
                
            case .showDeleteConfirmation:
                let contactName = state.contact.name
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
                    TextState("Are you sure you want to delete \(contactName)? This action cannot be undone.")
                }
                return .none
                
            case .confirmationAlert(.presented(.confirmDelete)):
                state.isLoading = true
                state.errorMessage = nil
                
                let contactId = state.contact.id
                return .run { send in
                    await haptics.notification(.warning)
                    await analytics.track(.featureUsed(feature: "contact_delete", context: ["contact_id": contactId.uuidString]))
                    await send(.deleteResponse(Result {
                        try await contactRepository.removeContact(contactId)
                    }))
                }
                
            case .confirmationAlert:
                return .none
                
            case let .updateResponse(.success(contact)):
                state.isLoading = false
                state.isEditing = false
                state.contact = contact
                state.editedContact = contact
                return .run { _ in
                    await haptics.notification(.success)
                }
                
            case let .updateResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case .deleteResponse(.success):
                state.isLoading = false
                // Parent will handle dismissal
                return .run { _ in
                    await haptics.notification(.success)
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
