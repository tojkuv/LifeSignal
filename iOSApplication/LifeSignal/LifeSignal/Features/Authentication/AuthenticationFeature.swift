import Foundation
import SwiftUI
import ComposableArchitecture
import DependenciesMacros

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
    
    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                state.errorMessage = nil
                return .none

            case .sendVerificationCode:
                let phoneValidation = validation.validatePhoneNumber(state.phoneNumber)
                guard phoneValidation.isValid else {
                    state.errorMessage = phoneValidation.errorMessage
                    return .run { [phoneNumber = state.phoneNumber] _ in
                        await haptics.notification(.error)
                        logging.warning("Invalid phone number format", ["phoneNumber": phoneNumber])
                    }
                }
                
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { [phoneNumber = state.phoneNumber] send in
                    await haptics.selection()
                    await send(.sendCodeResponse(Result {
                        try await userRepository.sendVerificationCode(phoneNumber)
                    }))
                }
                
            case .verifyCode:
                guard let verificationID = state.verificationID,
                      !state.verificationCode.isEmpty else {
                    state.errorMessage = "Verification code is required"
                    return .run { _ in
                        await haptics.notification(.error)
                    }
                }
                
                let codeValidation = validation.validateVerificationCode(state.verificationCode)
                guard codeValidation.isValid else {
                    state.errorMessage = codeValidation.errorMessage
                    return .run { _ in
                        await haptics.notification(.error)
                    }
                }
                
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { [verificationID, code = state.verificationCode] send in
                    await haptics.selection()
                    await send(.verificationResponse(Result {
                        try await userRepository.verifyPhoneNumber(verificationID, code)
                    }))
                }
                
            case .createAccount:
                guard validation.validateName(state.name).isValid else {
                    state.errorMessage = validation.validateName(state.name).errorMessage
                    return .run { _ in
                        await haptics.notification(.error)
                    }
                }
                
                state.isCreatingAccount = true
                state.errorMessage = nil
                
                return .run { [name = state.name, phoneNumber = state.phoneNumber] send in
                    await haptics.selection()
                    await send(.verificationResponse(Result {
                        try await userRepository.createAccountWithPhone(name, phoneNumber)
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
                return .run { _ in
                    await haptics.notification(.success)
                    logging.info("Verification code sent successfully", [:])
                }
                
            case let .sendCodeResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .run { [phoneNumber = state.phoneNumber] _ in
                    await haptics.notification(.error)
                    logging.error("Failed to send verification code", error, ["phoneNumber": phoneNumber])
                }
                
            case let .verificationResponse(.success(user)):
                state.isLoading = false
                state.isCreatingAccount = false
                state.$currentUser.withLock { $0 = user.firebaseUID.isEmpty ? nil : user }
                if !user.firebaseUID.isEmpty {
                    state.phoneNumber = ""
                    state.verificationCode = ""
                    state.verificationID = nil
                    state.name = ""
                    state.isCodeSent = false
                }
                guard !user.firebaseUID.isEmpty else { return .none }
                return .run { [uid = user.firebaseUID] _ in
                    await haptics.notification(.success)
                    logging.info("Phone verification successful", ["uid": uid])
                }

            case let .verificationResponse(.failure(error)):
                state.isLoading = false
                state.isCreatingAccount = false
                state.errorMessage = error.localizedDescription
                return .run { [phoneNumber = state.phoneNumber] _ in
                    await haptics.notification(.error)
                    logging.error("Phone verification failed", error, ["phoneNumber": phoneNumber])
                }
                
            case let .setCurrentUser(user):
                state.$currentUser.withLock { $0 = user }
                return .none
            }
        }
    }
}
