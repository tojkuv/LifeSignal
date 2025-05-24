import Foundation
import SwiftUI
import ComposableArchitecture
import Perception

@Reducer
struct AuthenticationFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.currentUser) var currentUser: User? = nil
        @Shared(.isOnline) var isOnline: Bool = true

        var phoneNumber = ""
        var verificationCode = ""
        var verificationID: String?
        var name = ""
        var isLoading = false
        var errorMessage: String?
        var isCodeSent = false
        var isCreatingAccount = false

        // Session state tracking
        var sessionState: SessionState = .unauthenticated
        var needsAccountCreation = false
        var accountCreationInfo: String? = nil

        var canSendCode: Bool {
            !phoneNumber.isEmpty && !isLoading && isOnline
        }

        var canVerifyCode: Bool {
            !verificationCode.isEmpty && !isLoading
        }

        var canCreateAccount: Bool {
            canVerifyCode && !name.isEmpty
        }

        var offlineMessage: String? {
            !isOnline ? "You need an internet connection to sign in" : nil
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
        case verificationResponse(Result<SessionState, Error>)
        case accountCreationResponse(Result<SessionState, Error>)
        case setCurrentUser(User)
        case sessionStateChanged(SessionState)
        case startSessionStateObservation
        case retryAfterError
        case clearError
        // case debugSkipToHome
    }

    @Dependency(\.sessionClient) var sessionClient
    @Dependency(\.validationClient) var validation
    @Dependency(\.hapticClient) var haptics
    @Dependency(\.analytics) var analytics
    @Dependency(\.logging) var logging
    @Dependency(\.retryClient) var retry

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce<State, Action> { state, action in
            switch action {
            case .binding:
                return .none

            case .startSessionStateObservation:
                return .run { send in
                    for await sessionState in sessionClient.sessionStateStream() {
                        await send(.sessionStateChanged(sessionState))
                    }
                }

            case let .sessionStateChanged(sessionState):
                state.sessionState = sessionState

                switch sessionState {
                case .authenticated(let session):
                    state.$currentUser.withLock { $0 = session.appUser }
                    state.isLoading = false
                    state.isCreatingAccount = false
                    state.needsAccountCreation = false
                    state.accountCreationInfo = nil
                    state.errorMessage = nil
                    // Clear form fields on successful authentication
                    state.phoneNumber = ""
                    state.verificationCode = ""
                    state.verificationID = nil
                    state.name = ""
                    state.isCodeSent = false

                case .creatingAccount(let firebaseUID, let phoneNumber, let phoneRegion):
                    state.needsAccountCreation = true
                    state.accountCreationInfo = firebaseUID
                    state.isLoading = false
                    // Don't clear form - user might need to enter name

                case .unauthenticated:
                    state.$currentUser.withLock { $0 = nil }
                    state.isLoading = false
                    state.isCreatingAccount = false
                    state.needsAccountCreation = false
                    state.accountCreationInfo = nil

                case .error(let errorMessage):
                    state.errorMessage = errorMessage
                    state.isLoading = false
                    state.isCreatingAccount = false

                case .authenticating, .verifyingCode:
                    state.isLoading = true
                    state.errorMessage = nil

                case .expired:
                    state.$currentUser.withLock { $0 = nil }
                    state.errorMessage = "Session expired. Please sign in again."
                    state.isLoading = false

                case .unknown:
                    // Don't change UI state for unknown
                    break
                }

                return .none

            case .sendVerificationCode:
                guard state.isOnline else {
                    state.errorMessage = "Internet connection required to send verification code"
                    return .run { _ in
                        await haptics.notification(.error)
                    }
                }

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

                    let result = await Result {
                        try await sessionClient.sendVerificationCode(phoneNumber)
                    }

                    await send(.sendCodeResponse(result))
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

                    let result = await Result {
                        try await sessionClient.verifyCodeAndSignIn(verificationID, code)
                    }

                    await send(.verificationResponse(result))
                }

            case .createAccount:
                guard validation.validateName(state.name).isValid else {
                    state.errorMessage = validation.validateName(state.name).errorMessage
                    return .run { _ in
                        await haptics.notification(.error)
                    }
                }

                guard let accountInfo = state.accountCreationInfo else {
                    state.errorMessage = "Account creation information missing"
                    return .run { _ in
                        await haptics.notification(.error)
                    }
                }

                state.isCreatingAccount = true
                state.isLoading = true
                state.errorMessage = nil

                return .run { [name = state.name, firebaseUID = accountInfo, phoneNumber = state.phoneNumber] send in
                    await haptics.selection()

                    let result = await Result {
                        try await sessionClient.createAccount(
                            firebaseUID,
                            name,
                            phoneNumber,
                            "US"
                        )
                    }

                    await send(.accountCreationResponse(result))
                }

            case .signOut:
                state.isLoading = true
                state.errorMessage = nil

                return .run { send in
                    do {
                        try await sessionClient.signOut()
                        await haptics.notification(.success)
                        logging.info("User signed out successfully", [:])
                    } catch {
                        await send(.sessionStateChanged(.error(error.localizedDescription)))
                        await haptics.notification(.error)
                        logging.error("Sign out failed", error, [:])
                    }
                }

            case let .sendCodeResponse(.success(verificationID)):
                state.isLoading = false
                state.verificationID = verificationID
                state.isCodeSent = true
                state.errorMessage = nil

                return .run { [phoneNumber = state.phoneNumber] _ in
                    await haptics.notification(.success)
                    logging.info("Verification code sent successfully", ["phoneNumber": phoneNumber])
                }

            case let .sendCodeResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription

                return .run { [phoneNumber = state.phoneNumber] _ in
                    await haptics.notification(.error)
                    logging.error("Failed to send verification code", error, ["phoneNumber": phoneNumber])
                }

            case let .verificationResponse(.success(sessionState)):
                // Session state will be handled by .sessionStateChanged
                switch sessionState {
                case .authenticated:
                    return .run { _ in
                        await haptics.notification(.success)
                        logging.info("Phone verification successful", [:])
                    }
                case .creatingAccount:
                    return .run { _ in
                        await haptics.notification(.success)
                        logging.info("Phone verified, account creation required", [:])
                    }
                default:
                    return .none
                }

            case let .verificationResponse(.failure(error)):
                state.isLoading = false
                state.isCreatingAccount = false
                state.errorMessage = error.localizedDescription

                return .run { [phoneNumber = state.phoneNumber] _ in
                    await haptics.notification(.error)
                    logging.error("Phone verification failed", error, ["phoneNumber": phoneNumber])
                }

            case let .accountCreationResponse(.success(sessionState)):
                // Session state will be handled by .sessionStateChanged
                if case .authenticated = sessionState {
                    return .run { _ in
                        await haptics.notification(.success)
                        logging.info("Account created successfully", [:])
                    }
                }
                return .none

            case let .accountCreationResponse(.failure(error)):
                state.isLoading = false
                state.isCreatingAccount = false
                state.errorMessage = error.localizedDescription

                return .run { [name = state.name] _ in
                    await haptics.notification(.error)
                    logging.error("Account creation failed", error, ["name": name])
                }

            case let .setCurrentUser(user):
                state.$currentUser.withLock { $0 = user }
                return .none

            case .retryAfterError:
                state.errorMessage = nil
                state.isLoading = false
                // Allow user to retry the failed operation
                return .none

            case .clearError:
                state.errorMessage = nil
                return .none
                
            // case .debugSkipToHome:
                // Debug action moved to ApplicationFeature
            }
        }
    }
}