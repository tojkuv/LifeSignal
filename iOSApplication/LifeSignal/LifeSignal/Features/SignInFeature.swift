import Foundation
import SwiftUI
import ComposableArchitecture
import Perception
@_exported import Sharing

@Reducer 
struct SignInFeature {
    @ObservableState
    struct State: Equatable {
        // Read-only access to shared state through SessionClient only (no direct mutation)
        @Shared(.currentUser) var currentUser: User? = nil
        @Shared(.sessionState) var sessionState: SessionState = .unauthenticated
        @Shared(.needsOnboarding) var needsOnboarding: Bool = false

        // UI state
        var phoneNumber = ""
        var verificationCode = ""
        var verificationID: String? = nil
        var showPhoneEntry = true
        var selectedRegion = "US"
        var showRegionPicker = false
        var phoneNumberFieldFocused = false
        var verificationCodeFieldFocused = false
        var isLoading = false
        
        // Available regions
        static let regions: [(String, String)] = [
            ("US", "+1"),
            ("CA", "+1"),
            ("UK", "+44"),
            ("AU", "+61")
        ]
        
        // Computed properties
        var phoneNumberPlaceholder: String {
            let selectedRegionInfo = Self.regions.first { $0.0 == selectedRegion }!
            return "\(selectedRegionInfo.1) (000) 000-0000"
        }

        var canSendCode: Bool {
            isPhoneNumberValid && !isLoading
        }
        
        var canVerifyCode: Bool {
            isVerificationCodeValid && !isLoading
        }
        
        var isPhoneNumberValid: Bool {
            let digitCount = phoneNumber.filter { $0.isNumber }.count
            return digitCount == 10 || phoneNumber == "+11234567890" // Allow dev testing
        }
        
        var isVerificationCodeValid: Bool {
            verificationCode.filter { $0.isNumber }.count == 6
        }
    }

    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        // UI actions
        case clearError
        case focusPhoneNumberField
        case toggleRegionPicker
        case updateSelectedRegion((String, String))
        case handlePhoneNumberChange(String)
        case sendVerificationCode
        case handleVerificationCodeChange(String)
        case verifyCode
        case changeToPhoneEntryView
        case resetForm
        
        // Authentication actions
        case signOut
        
        // Debug actions
        case debugSkipSignInAndOnboarding
        
        // Internal actions
        case verificationCodeSent(Result<String, Error>)
        case sessionStartResult(Result<Void, Error>)
        case debugSessionResult(Result<Void, Error>)
    }

    // Features only use SessionClient, which orchestrates other clients
    @Dependency(\.sessionClient) var sessionClient

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .clearError:
                return .none
                
            case .focusPhoneNumberField:
                state.phoneNumberFieldFocused = true
                return .none
                
            case .toggleRegionPicker:
                state.showRegionPicker.toggle()
                return .none
                
            case let .updateSelectedRegion(region):
                state.selectedRegion = region.0
                state.showRegionPicker = false
                return .none
                
            case let .handlePhoneNumberChange(newValue):
                state.phoneNumber = newValue
                return .none
                
            case .sendVerificationCode:
                guard !state.phoneNumber.isEmpty else {
                    return .none
                }
                
                state.isLoading = true
                
                return .run { [phoneNumber = state.phoneNumber] send in
                    await send(.verificationCodeSent(
                        Result {
                            try await sessionClient.sendVerificationCode(phoneNumber)
                        }
                    ))
                }
                
            case let .handleVerificationCodeChange(newValue):
                state.verificationCode = newValue
                return .none
                
            case .verifyCode:
                guard !state.verificationCode.isEmpty else {
                    return .none
                }
                
                guard let verificationID = state.verificationID else {
                    return .none
                }
                
                state.isLoading = true
                
                return .run { [verificationID = verificationID, code = state.verificationCode] send in
                    await send(.sessionStartResult(
                        Result {
                            try await sessionClient.verifyPhoneCodeAndStartSession(verificationID, code)
                        }
                    ))
                }
                
            case .changeToPhoneEntryView:
                state.showPhoneEntry = true
                state.phoneNumber = ""
                state.verificationCode = ""
                state.verificationID = nil
                state.isLoading = false
                return .none

            case .resetForm:
                state.phoneNumber = ""
                state.verificationCode = ""
                state.verificationID = nil
                state.showPhoneEntry = true
                state.showRegionPicker = false
                state.phoneNumberFieldFocused = false
                state.verificationCodeFieldFocused = false
                state.isLoading = false
                return .none
                
            case .signOut:
                return .run { send in
                    do {
                        try await sessionClient.endSession()
                    } catch {
                        // Handle error silently, session cleanup should still happen
                    }
                    // Session cleanup completed
                }
                
            case .debugSkipSignInAndOnboarding:
                state.isLoading = true
                return .run { send in
                    await send(.debugSessionResult(
                        Result {
                            try await sessionClient.debugSkipAuthenticationAndOnboarding()
                        }
                    ))
                }
                
            case let .verificationCodeSent(.success(verificationID)):
                // Verification code sent successfully
                state.isLoading = false
                state.verificationID = verificationID
                state.showPhoneEntry = false
                return .none
                
            case let .verificationCodeSent(.failure(error)):
                state.isLoading = false
                return .none
                
            case let .sessionStartResult(.success):
                state.isLoading = false
                return .none
                
            case let .sessionStartResult(.failure(error)):
                state.isLoading = false
                return .none
                
            case let .debugSessionResult(.success):
                state.isLoading = false
                return .none
                
            case let .debugSessionResult(.failure(error)):
                state.isLoading = false
                return .none

            }
        }
    }
    
}

// MARK: - SignInView

struct SignInView: View {
    @Bindable var store: StoreOf<SignInFeature>
    @FocusState private var phoneNumberFieldFocused: Bool
    @FocusState private var verificationCodeFieldFocused: Bool
    
    @Dependency(\.phoneNumberFormatter) var phoneNumberFormatter

    var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        if store.showPhoneEntry {
                            phoneEntryView()
                        } else {
                            verificationView()
                        }
                        
                        // Add extra padding at the bottom
                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 50)
                }
                .background(Color(UIColor.systemGroupedBackground))
                .edgesIgnoringSafeArea(.bottom)
                .navigationTitle("Sign In")
                .onAppear {
                    store.send(.focusPhoneNumberField)
                }
                .onChange(of: store.phoneNumberFieldFocused) { _, newValue in
                    phoneNumberFieldFocused = newValue
                }
                .onChange(of: store.verificationCodeFieldFocused) { _, newValue in
                    verificationCodeFieldFocused = newValue
                }
            }
        }
    }

    @ViewBuilder
    private func phoneEntryView() -> some View {
        VStack(spacing: 24) {
            // App logo
            Image("LifeSignalLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .padding(.top, 20)

            // Debug button (only shown in debug builds)
            // #if DEBUG
            // Button(action: {
            //     store.send(.debugSkipSignInAndOnboarding, animation: .default)
            // }) {
            //     Text("🚀 DEBUG: Skip Sign In & Onboarding")
            //         .font(.system(size: 13, weight: .medium, design: .rounded))
            //         .foregroundColor(.primary)
            //         .frame(maxWidth: .infinity)
            //         .padding(.vertical, 12)
            //         .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            //         .overlay(
            //             RoundedRectangle(cornerRadius: 12)
            //                 .stroke(.quaternary, lineWidth: 0.5)
            //         )
            // }
            // .disabled(store.isLoading)
            // .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            // #endif

            Text("Enter your phone number")
                .font(.title2)
                .fontWeight(.bold)

            PhoneNumberEntryComponent(
                selectedRegion: store.selectedRegion,
                regions: SignInFeature.State.regions,
                phoneNumber: store.phoneNumber,
                phoneNumberPlaceholder: store.phoneNumberPlaceholder,
                buttonTitle: "Send Verification Code",
                isLoading: store.isLoading,
                canSendCode: store.canSendCode,
                showRegionPicker: store.showRegionPicker,
                onRegionPickerToggle: {
                    store.send(.toggleRegionPicker)
                },
                onRegionSelection: { region in
                    store.send(.updateSelectedRegion(region))
                },
                onPhoneNumberChange: { newValue in
                    store.send(.handlePhoneNumberChange(newValue))
                },
                onButtonTap: {
                    store.send(.sendVerificationCode, animation: .default)
                }
            )

            Spacer()
        }
    }

    @ViewBuilder
    private func verificationView() -> some View {
        VStack(spacing: 24) {
            // App logo
            Image("LifeSignalLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .padding(.top, 20)


            Text("Enter verification code")
                .font(.title2)
                .fontWeight(.bold)

            VerificationCodeEntryComponent(
                verificationCode: store.verificationCode,
                buttonTitle: "Verify",
                isLoading: store.isLoading,
                canVerifyCode: store.canVerifyCode,
                changePhoneButtonTitle: "Change phone number",
                onVerificationCodeChange: { newValue in
                    store.send(.handleVerificationCodeChange(newValue))
                },
                onButtonTap: {
                    store.send(.verifyCode, animation: .default)
                },
                onChangePhoneNumber: {
                    store.send(.changeToPhoneEntryView, animation: .default)
                }
            )

            Spacer()
        }
    }
}

// MARK: - Previews

#Preview("Sign In View") {
    SignInView(
        store: Store(initialState: SignInFeature.State()) {
            SignInFeature()
        } withDependencies: {
            $0.sessionClient = .mockValue
        }
    )
}