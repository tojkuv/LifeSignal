import Foundation
import SwiftUI
import ComposableArchitecture
import DependenciesMacros
import Sharing

@Reducer
struct AuthenticationFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.currentUser) var currentUser: User? = nil
        var phoneNumber = ""
        var verificationCode = ""
        var verificationID: String?
        var name = ""
        var isLoading = false
        var errorMessage: String?
        var isCodeSent = false
        var isCreatingAccount = false

        var canSendCode: Bool {
            !phoneNumber.isEmpty && !isLoading
        }
        
        var canVerifyCode: Bool {
            !verificationCode.isEmpty && !isLoading
        }
        
        var canCreateAccount: Bool {
            canVerifyCode && !name.isEmpty
        }
    }
    
    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case sendVerificationCode
        case verifyCode
        case createAccount
        case signOut
        case sendCodeResponse(Result<String, Error>)
        case verificationResponse(Result<User, Error>)
        case setCurrentUser(User)
    }
    
    @Dependency(\.userRepository) var userRepository
    @Dependency(\.validationClient) var validation
    @Dependency(\.hapticClient) var haptics
    @Dependency(\.analytics) var analytics
    @Dependency(\.loggingClient) var logging
    
    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                state.errorMessage = nil
                return .none

            case .sendVerificationCode:
                let phoneValidation = validation.validatePhoneNumber(state.phoneNumber)
                guard phoneValidation.isValid else {
                    haptics.notification(.error)
                    state.errorMessage = phoneValidation.errorMessage
                    logging.warning("Invalid phone number format", ["phoneNumber": state.phoneNumber])
                    return .none
                }
                
                state.isLoading = true
                state.errorMessage = nil
                haptics.selection()
                
                return .run { [phoneNumber = state.phoneNumber] send in
                    await send(.sendCodeResponse(Result {
                        try await userRepository.sendVerificationCode(phoneNumber)
                    }))
                }
                
            case .verifyCode:
                guard let verificationID = state.verificationID,
                      !state.verificationCode.isEmpty else {
                    haptics.notification(.error)
                    state.errorMessage = "Verification code is required"
                    return .none
                }
                
                let codeValidation = validation.validateVerificationCode(state.verificationCode)
                guard codeValidation.isValid else {
                    haptics.notification(.error)
                    state.errorMessage = codeValidation.errorMessage
                    return .none
                }
                
                state.isLoading = true
                state.errorMessage = nil
                haptics.selection()
                
                return .run { [verificationID, code = state.verificationCode] send in
                    await send(.verificationResponse(Result {
                        try await userRepository.verifyPhoneNumber(verificationID: verificationID, code: code)
                    }))
                }
                
            case .createAccount:
                guard validation.validateName(state.name).isValid else {
                    haptics.notification(.error)
                    state.errorMessage = validation.validateName(state.name).errorMessage
                    return .none
                }
                
                state.isCreatingAccount = true
                state.errorMessage = nil
                haptics.selection()
                
                return .run { [name = state.name, phoneNumber = state.phoneNumber] send in
                    await send(.verificationResponse(Result {
                        try await userRepository.createAccountWithPhone(name: name, phoneNumber: phoneNumber)
                    }))
                }

            case .signOut:
                return .run { send in
                    try await userRepository.signOut()
                    await send(.verificationResponse(.success(User(id: UUID(), firebaseUID: "", name: "", phoneNumber: ""))))
                }

            case let .sendCodeResponse(.success(verificationID)):
                state.isLoading = false
                state.verificationID = verificationID
                state.isCodeSent = true
                haptics.notification(.success)
                logging.info("Verification code sent successfully")
                return .none
                
            case let .sendCodeResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                haptics.notification(.error)
                logging.error("Failed to send verification code", error, ["phoneNumber": state.phoneNumber])
                return .none
                
            case let .verificationResponse(.success(user)):
                state.isLoading = false
                state.isCreatingAccount = false
                state.currentUser = user.firebaseUID.isEmpty ? nil : user
                if !user.firebaseUID.isEmpty {
                    state.phoneNumber = ""
                    state.verificationCode = ""
                    state.verificationID = nil
                    state.name = ""
                    state.isCodeSent = false
                    haptics.notification(.success)
                    logging.info("Phone verification successful", ["uid": user.firebaseUID])
                }
                return .none

            case let .verificationResponse(.failure(error)):
                state.isLoading = false
                state.isCreatingAccount = false
                state.errorMessage = error.localizedDescription
                haptics.notification(.error)
                logging.error("Phone verification failed", error, ["phoneNumber": state.phoneNumber])
                return .none
                
            case let .setCurrentUser(user):
                state.currentUser = user
                return .none
            }
        }
    }
}