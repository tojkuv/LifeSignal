import Foundation
import SwiftUI
import ComposableArchitecture
import Perception
@_exported import Sharing

@Reducer 
struct SignInFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.currentUser) var currentUser: User? = nil
        @Shared(.sessionState) var sessionState: SessionState = .unauthenticated
        @Shared(.needsOnboarding) var needsOnboarding: Bool = false

        // UI state
        var phoneNumber = ""
        var verificationCode = ""
        var verificationID: String? = nil
        var isLoading = false
        var errorMessage: String?
        var showPhoneEntry = true
        var selectedRegion = "US"
        var showRegionPicker = false
        var phoneNumberFieldFocused = false
        var verificationCodeFieldFocused = false
        
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
        
        // Authentication actions
        case signOut
        
        // Internal actions
        case verificationCodeSent(Result<String, Error>)
        case sessionStartResult(Result<Void, Error>)
    }

    @Dependency(\.sessionClient) var sessionClient
    @Dependency(\.hapticClient) var haptics

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .clearError:
                state.errorMessage = nil
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
                    state.errorMessage = "Please enter a phone number"
                    return .none
                }
                
                state.isLoading = true
                state.errorMessage = nil
                
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
                    state.errorMessage = "Please enter the verification code"
                    return .none
                }
                
                guard let verificationID = state.verificationID else {
                    state.errorMessage = "Verification session expired. Please try again."
                    return .none
                }
                
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { [verificationID = verificationID, code = state.verificationCode] send in
                    await send(.sessionStartResult(
                        Result {
                            try await sessionClient.verifyPhoneCodeAndStartSession(verificationID, code)
                        }
                    ))
                }
                
            case .changeToPhoneEntryView:
                state.showPhoneEntry = true
                state.verificationCode = ""
                state.verificationID = nil
                state.errorMessage = nil
                return .none

                
            case .signOut:
                state.isLoading = true
                return .run { send in
                    do {
                        try await sessionClient.endSession()
                        await haptics.notification(.success)
                    } catch {
                        // Handle error silently, session cleanup should still happen
                    }
                    await send(.binding(.set(\.isLoading, false)))
                }
                
            case let .verificationCodeSent(.success(verificationID)):
                // Verification code sent successfully
                state.isLoading = false
                state.verificationID = verificationID
                state.showPhoneEntry = false
                return .none
                
            case let .verificationCodeSent(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .run { send in
                    await haptics.notification(.error)
                }
                
            case let .sessionStartResult(.success):
                state.isLoading = false
                state.errorMessage = nil
                return .run { send in
                    await haptics.notification(.success)
                }
                
            case let .sessionStartResult(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .run { send in
                    await haptics.notification(.error)
                }

            }
        }
    }
    
}

// MARK: - SignInView

struct SignInView: View {
    @Bindable var store: StoreOf<SignInFeature>
    @FocusState private var phoneNumberFieldFocused: Bool
    @FocusState private var verificationCodeFieldFocused: Bool

    var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                VStack {
                    if store.showPhoneEntry {
                        phoneEntryView
                    } else {
                        verificationView
                    }
                }
                .padding()
                .navigationTitle("Sign In")
                .alert("Error", isPresented: .constant(store.errorMessage != nil)) {
                    Button("OK") {
                        store.send(.clearError)
                    }
                } message: {
                    Text(store.errorMessage ?? "")
                }
                .onAppear {
                    store.send(.focusPhoneNumberField)
                }
                .onChange(of: store.phoneNumberFieldFocused) { _, newValue in
                    phoneNumberFieldFocused = newValue
                }
                .onChange(of: store.verificationCodeFieldFocused) { _, newValue in
                    verificationCodeFieldFocused = newValue
                }
                .background(Color(UIColor.systemGroupedBackground))
            }
        }
    }

    @ViewBuilder
    private var phoneEntryView: some View {
        VStack(spacing: 24) {
            // App logo placeholder
            ZStack {
                Circle()
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .frame(width: 120, height: 120)

                Image(systemName: "shield.checkered")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.blue)
            }
            .padding(.top, 40)

            // Debug button under the logo
            #if DEBUG
            Button(action: {
                store.send(.skipAuthentication, animation: .default)
            }) {
                Text("Debug: Skip to Home")
                    .font(.caption)
                    .padding(8)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }
            #endif

            Text("Enter your phone number")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 16) {
                // Region picker
                HStack {
                    Text("Region")
                        .font(.body)

                    Spacer()

                    Button(action: {
                        store.send(.toggleRegionPicker)
                    }) {
                        HStack {
                            // Show the currently selected region
                            let selectedRegionInfo = SignInFeature.State.regions.first { $0.0 == store.selectedRegion }!
                            Text("\(selectedRegionInfo.0) (\(selectedRegionInfo.1))")
                                .foregroundColor(.primary)

                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .popover(isPresented: $store.showRegionPicker) {
                        List {
                            ForEach(SignInFeature.State.regions, id: \.0) { region in
                                Button(action: {
                                    store.send(.updateSelectedRegion(region))
                                }) {
                                    HStack {
                                        Text("\(region.0) (\(region.1))")

                                        Spacer()

                                        if store.selectedRegion == region.0 {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                        }
                        .presentationDetents([.medium])
                    }
                }
                .padding(.horizontal, 4)

                // Phone number field with formatting
                TextField(store.phoneNumberPlaceholder, text: $store.phoneNumber)
                    .keyboardType(.phonePad)
                    .font(.body)
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .focused($phoneNumberFieldFocused)
                    .disabled(store.isLoading)
                    .onChange(of: store.phoneNumber) { _, newValue in
                        store.send(.handlePhoneNumberChange(newValue))
                    }

                Button(action: {
                    store.send(.sendVerificationCode, animation: .default)
                }) {
                    Text("Send Verification Code")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .disabled(store.isLoading)
                .background(store.isLoading || !store.canSendCode ? Color.gray : Color.blue)
                .cornerRadius(10)
                .disabled(store.isLoading || !store.canSendCode)
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    @ViewBuilder
    private var verificationView: some View {
        VStack(spacing: 24) {
            // App logo placeholder
            ZStack {
                Circle()
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .frame(width: 120, height: 120)

                Image(systemName: "shield.checkered")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.blue)
            }
            .padding(.top, 40)

            // Debug button under the logo
            #if DEBUG
            Button(action: {
                store.send(.skipAuthentication, animation: .default)
            }) {
                Text("Debug: Skip to Home")
                    .font(.caption)
                    .padding(8)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }
            #endif

            Text("Enter verification code")
                .font(.title2)
                .fontWeight(.bold)

            // Verification code field with improved formatting
            TextField("XXX-XXX", text: $store.verificationCode)
                .keyboardType(.numberPad)
                .font(.body)
                .padding(.vertical, 12)
                .padding(.horizontal)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .focused($verificationCodeFieldFocused)
                .disabled(store.isLoading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .onChange(of: store.verificationCode) { _, newValue in
                    store.send(.handleVerificationCodeChange(newValue))
                }

            Button(action: {
                store.send(.verifyCode, animation: .default)
            }) {
                Text("Verify")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .background(store.canVerifyCode ? Color.blue : Color.gray)
            .cornerRadius(12)
            .padding(.horizontal)
            .disabled(!store.canVerifyCode)

            Button(action: {
                store.send(.changeToPhoneEntryView, animation: .default)
            }) {
                Text("Change phone number")
                    .foregroundColor(.blue)
            }
            .disabled(store.isLoading)

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