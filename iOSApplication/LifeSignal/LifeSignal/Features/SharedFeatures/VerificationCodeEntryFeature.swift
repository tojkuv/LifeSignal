import SwiftUI
import ComposableArchitecture
import UIKit

@Reducer
struct VerificationCodeEntryFeature {
    @ObservableState
    struct State: Equatable {
        var verificationCode: String = ""
        var buttonTitle: String
        var isLoading: Bool = false
        var canVerifyCode: Bool = false
        var changePhoneButtonTitle: String?
        var verificationCodeFieldFocused: Bool = false
        
        var isVerificationCodeValid: Bool {
            verificationCode.filter { $0.isNumber }.count == 6
        }
    }
    
    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case updateVerificationCode(String)
        case buttonTapped
        case changePhoneNumberTapped
        case focusVerificationCodeField(Bool)
        
        // Parent communication actions
        case delegate(Delegate)
        
        @CasePathable
        enum Delegate: Equatable {
            case verificationCodeChanged(String)
            case buttonTapped
            case changePhoneNumberTapped
        }
    }
    
    @Dependency(\.phoneNumberFormatter) var phoneNumberFormatter
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case let .updateVerificationCode(newValue):
                // Format the input (view already validated digit limits)
                let limitedValue = phoneNumberFormatter.limitVerificationCodeLength(newValue)
                let formattedValue = phoneNumberFormatter.formatVerificationCode(limitedValue)
                state.verificationCode = formattedValue
                state.canVerifyCode = state.isVerificationCodeValid
                return .send(.delegate(.verificationCodeChanged(formattedValue)))
                
            case .buttonTapped:
                return .send(.delegate(.buttonTapped))
                
            case .changePhoneNumberTapped:
                return .send(.delegate(.changePhoneNumberTapped))
                
            case let .focusVerificationCodeField(focused):
                state.verificationCodeFieldFocused = focused
                return .none
                
            case .delegate:
                return .none
            }
        }
    }
}

struct VerificationCodeEntryView: View {
    @Bindable var store: StoreOf<VerificationCodeEntryFeature>
    @FocusState private var verificationCodeFieldFocused: Bool
    @State private var localVerificationCode: String = ""
    
    var body: some View {
        VStack(spacing: 24) {
            // Verification code field with improved formatting
            LimitedDigitTextField(
                text: $localVerificationCode,
                placeholder: "000-000",
                digitLimit: 6,
                keyboardType: .numberPad,
                isDisabled: store.isLoading,
                onTextChange: { newValue in
                    store.send(.updateVerificationCode(newValue))
                },
                isFocused: store.verificationCodeFieldFocused
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .focused($verificationCodeFieldFocused)
                .onChange(of: verificationCodeFieldFocused) { _, newValue in
                    store.send(.focusVerificationCodeField(newValue))
                }
                .onChange(of: store.verificationCodeFieldFocused) { _, newValue in
                    verificationCodeFieldFocused = newValue
                }
                .onAppear {
                    // Initialize local state with store value
                    localVerificationCode = store.verificationCode
                }
                .onChange(of: store.verificationCode) { _, newValue in
                    // Always sync from store to local state to keep them in sync
                    if localVerificationCode != newValue {
                        localVerificationCode = newValue
                    }
                }

            Button(action: {
                store.send(.buttonTapped)
            }) {
                Text(store.buttonTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .background(store.canVerifyCode ? Color.blue : Color.gray)
            .cornerRadius(12)
            .disabled(!store.canVerifyCode)
            
            if let changePhoneButtonTitle = store.changePhoneButtonTitle {
                Button(action: {
                    store.send(.changePhoneNumberTapped)
                }) {
                    Text(changePhoneButtonTitle)
                        .foregroundColor(.blue)
                }
                .disabled(store.isLoading)
            }
        }
    }
}

// Preview
#Preview {
    VerificationCodeEntryView(
        store: Store(initialState: VerificationCodeEntryFeature.State(
            buttonTitle: "Verify",
            changePhoneButtonTitle: "Change phone number"
        )) {
            VerificationCodeEntryFeature()
        }
    )
    .padding()
}