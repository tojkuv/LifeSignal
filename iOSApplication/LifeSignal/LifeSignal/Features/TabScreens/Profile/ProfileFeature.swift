import Foundation
import SwiftUI
import UIKit
import ComposableArchitecture
import Sharing

@Reducer
struct ProfileFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.currentUser) var currentUser: User? = nil
        var editingUser: User?
        var isLoading = false
        var errorMessage: String?

        var isEditing: Bool { editingUser != nil }
        var canSave: Bool {
            guard let editing = editingUser else { return false }
            return !editing.name.isEmpty && !editing.phoneNumber.isEmpty && editing != currentUser
        }
    }
    
    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case edit
        case save
        case cancel
        case uploadAvatar(Data)
        case response(Result<User, Error>)
        case uploadResponse(Result<URL, Error>)
    }
    
    @Dependency(\.userRepository) var userRepository
    @Dependency(\.validationClient) var validation
    @Dependency(\.hapticClient) var haptics
    @Dependency(\.analytics) var analytics
    
    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.editingUser):
                state.errorMessage = nil
                return .none

            case .binding:
                return .none

            case .edit:
                state.editingUser = state.currentUser
                return .run { _ in
                    await analytics.track(.featureUsed(feature: "profile_edit", context: [:]))
                }

            case .save:
                guard let user = state.editingUser else { return .none }
                
                // Validate inputs before saving
                guard validation.validateName(user.name).isValid else {
                    haptics.notification(.error)
                    state.errorMessage = validation.validateName(user.name).errorMessage
                    return .none
                }
                
                guard validation.validatePhoneNumber(user.phoneNumber).isValid else {
                    haptics.notification(.error)
                    state.errorMessage = validation.validatePhoneNumber(user.phoneNumber).errorMessage
                    return .none
                }
                
                state.isLoading = true
                state.errorMessage = nil
                haptics.selection()
                return .run { send in
                    await send(.response(Result {
                        try await userRepository.updateProfile(user)
                    }))
                }

            case .cancel:
                state.editingUser = nil
                return .none

            case let .uploadAvatar(data):
                state.isLoading = true
                return .run { send in
                    await send(.uploadResponse(Result {
                        try await userRepository.uploadAvatar(data)
                    }))
                }

            case let .response(.success(user)):
                state.isLoading = false
                state.currentUser = user
                state.editingUser = nil
                haptics.notification(.success)
                return .none

            case let .response(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                haptics.notification(.error)
                return .none

            case let .uploadResponse(.success(url)):
                state.isLoading = false
                state.editingUser?.avatarURL = url.absoluteString
                haptics.notification(.success)
                return .none

            case let .uploadResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                haptics.notification(.error)
                return .none
            }
        }
    }
}
