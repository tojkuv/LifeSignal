import Foundation
import SwiftUI
import ComposableArchitecture
import Perception
@_exported import Sharing

@Reducer 
struct SignInFeature {
    @ObservableState
    struct State: Equatable {
        // SignInFeature does not read session state - only ApplicationFeature handles session management

        // UI state
        var verificationID: String? = nil
        var showPhoneEntry = true
        var isLoading = false
        
        // Available regions
        static let regions: [(String, String)] = [
            ("US", "+1"),
            ("CA", "+1"),
            ("UK", "+44"),
            ("AU", "+61")
        ]
        
        // Child feature states
        var phoneNumberEntry = PhoneNumberEntryFeature.State(
            selectedRegion: "US",
            regions: SignInFeature.State.regions,
            buttonTitle: "Send Verification Code"
        )
        
        var verificationCodeEntry = VerificationCodeEntryFeature.State(
            buttonTitle: "Verify"
        )
    }

    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        // Child feature actions
        case phoneNumberEntry(PhoneNumberEntryFeature.Action)
        case verificationCodeEntry(VerificationCodeEntryFeature.Action)
        
        // UI actions
        case clearError
        case changeToPhoneEntryView
        case resetForm
        case viewAppeared
        
        // Authentication actions
        case signOut
        
        // Debug actions
        case debugSkipSignInAndOnboarding
        
        // Internal actions
        case verificationCodeSent(Result<String, Error>)
        case sessionStartResult(Result<Void, Error>)
        case debugSessionResult(Result<Void, Error>)
    }

    // SignInFeature only uses AuthenticationClient for shared state
    // PureUtilities clients are allowed for UI/device functionality
    @Dependency(\.authenticationClient) var authenticationClient

    var body: some ReducerOf<Self> {
        Scope(state: \.phoneNumberEntry, action: \.phoneNumberEntry) {
            PhoneNumberEntryFeature()
        }
        
        Scope(state: \.verificationCodeEntry, action: \.verificationCodeEntry) {
            VerificationCodeEntryFeature()
        }
        
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .clearError:
                return .none
                
            case .viewAppeared:
                if state.showPhoneEntry {
                    return .run { send in
                        try await Task.sleep(for: .milliseconds(100))
                        await send(.phoneNumberEntry(.focusPhoneNumberField(true)))
                    }
                }
                return .none
                
            case .changeToPhoneEntryView:
                state.showPhoneEntry = true
                state.phoneNumberEntry.phoneNumber = ""
                state.phoneNumberEntry.canSendCode = false
                state.verificationCodeEntry.verificationCode = ""
                state.verificationCodeEntry.canVerifyCode = false
                state.verificationID = nil
                state.isLoading = false
                return .run { send in
                    try await Task.sleep(for: .milliseconds(100))
                    await send(.phoneNumberEntry(.focusPhoneNumberField(true)))
                }

            case .resetForm:
                state.phoneNumberEntry.phoneNumber = ""
                state.phoneNumberEntry.canSendCode = false
                state.verificationCodeEntry.verificationCode = ""
                state.verificationCodeEntry.canVerifyCode = false
                state.verificationID = nil
                state.showPhoneEntry = true
                state.phoneNumberEntry.showRegionPicker = false
                state.phoneNumberEntry.phoneNumberFieldFocused = false
                state.verificationCodeEntry.verificationCodeFieldFocused = false
                state.isLoading = false
                return .none
                
            case .signOut:
                // SignInFeature should not handle coordinated sign out - that's ApplicationFeature's responsibility
                return .none
                
            case .debugSkipSignInAndOnboarding:
                // This debug feature is no longer available with the new architecture
                state.isLoading = false
                return .none
                
            case let .verificationCodeSent(.success(verificationID)):
                // Verification code sent successfully
                state.isLoading = false
                state.phoneNumberEntry.isLoading = false
                state.verificationID = verificationID
                state.showPhoneEntry = false
                return .run { send in
                    try await Task.sleep(for: .milliseconds(100))
                    await send(.verificationCodeEntry(.focusVerificationCodeField(true)))
                }
                
            case let .verificationCodeSent(.failure(error)):
                state.isLoading = false
                state.phoneNumberEntry.isLoading = false
                return .none
                
            case let .sessionStartResult(.success):
                state.isLoading = false
                state.verificationCodeEntry.isLoading = false
                // Don't change UI state or clear form yet - let ApplicationFeature handle navigation
                // Form will be cleared when the user signs out or when resetForm is called
                return .none
                
            case let .sessionStartResult(.failure(error)):
                state.isLoading = false
                state.verificationCodeEntry.isLoading = false
                return .none
                
            case let .debugSessionResult(.success):
                state.isLoading = false
                return .none
                
            case let .debugSessionResult(.failure(error)):
                state.isLoading = false
                return .none

            // Handle child feature delegate actions
            case .phoneNumberEntry(.delegate(.buttonTapped)):
                guard !state.phoneNumberEntry.phoneNumber.isEmpty else {
                    return .none
                }
                
                state.isLoading = true
                state.phoneNumberEntry.isLoading = true
                
                return .run { [phoneNumber = state.phoneNumberEntry.phoneNumber] send in
                    await send(.verificationCodeSent(
                        Result {
                            try await authenticationClient.sendVerificationCode(phoneNumber)
                        }
                    ))
                }
                
            case .verificationCodeEntry(.delegate(.buttonTapped)):
                guard !state.verificationCodeEntry.verificationCode.isEmpty else {
                    return .none
                }
                
                guard let verificationID = state.verificationID else {
                    return .none
                }
                
                state.isLoading = true
                state.verificationCodeEntry.isLoading = true
                
                return .run { [verificationID = verificationID, code = state.verificationCodeEntry.verificationCode] send in
                    await send(.sessionStartResult(
                        Result {
                            try await authenticationClient.createAuthenticationSession(verificationID, code)
                            // ApplicationFeature will handle user data loading after authentication
                        }
                    ))
                }
                
            case .phoneNumberEntry:
                return .none
                
            case .verificationCodeEntry:
                return .none

            }
        }
    }
    
}

// MARK: - SignInView

struct SignInView: View {
    @Bindable var store: StoreOf<SignInFeature>
    
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
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    store.send(.viewAppeared)
                }
                .toolbar {
                    if !store.showPhoneEntry {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: {
                                store.send(.changeToPhoneEntryView, animation: .default)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("Back")
                                }
                                .foregroundColor(.blue)
                            }
                        }
                    }
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

            PhoneNumberEntryView(
                store: store.scope(state: \.phoneNumberEntry, action: \.phoneNumberEntry)
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

            Text("Enter verification code")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Sent to \(phoneNumberFormatter.formatPhoneNumberWithRegionCode(store.phoneNumberEntry.phoneNumber))")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VerificationCodeEntryView(
                store: store.scope(state: \.verificationCodeEntry, action: \.verificationCodeEntry)
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
            $0.authenticationClient = .mockValue
        }
    )
}