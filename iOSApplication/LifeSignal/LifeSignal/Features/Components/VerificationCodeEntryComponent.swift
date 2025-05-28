import SwiftUI
import ComposableArchitecture

struct VerificationCodeEntryComponent: View {
    let verificationCode: String
    let buttonTitle: String
    let isLoading: Bool
    let canVerifyCode: Bool
    let changePhoneButtonTitle: String?
    
    let onVerificationCodeChange: (String) -> Void
    let onButtonTap: () -> Void
    let onChangePhoneNumber: (() -> Void)?
    
    @FocusState private var verificationCodeFieldFocused: Bool
    @Dependency(\.phoneNumberFormatter) var phoneNumberFormatter
    
    var body: some View {
        VStack(spacing: 24) {
            // Verification code field with improved formatting
            TextField("XXX-XXX", text: Binding(
                get: { verificationCode },
                set: { newValue in
                    let limitedValue = phoneNumberFormatter.limitVerificationCodeLength(newValue)
                    let formattedValue = phoneNumberFormatter.formatVerificationCode(limitedValue)
                    onVerificationCodeChange(formattedValue)
                }
            ))
                .keyboardType(.numberPad)
                .font(.body)
                .padding(.vertical, 12)
                .padding(.horizontal)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .focused($verificationCodeFieldFocused)
                .disabled(isLoading)
                .frame(maxWidth: .infinity)

            Button(action: onButtonTap) {
                Text(buttonTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .background(canVerifyCode ? Color.blue : Color.gray)
            .cornerRadius(12)
            .disabled(!canVerifyCode)
            
            if let changePhoneButtonTitle = changePhoneButtonTitle,
               let onChangePhoneNumber = onChangePhoneNumber {
                Button(action: onChangePhoneNumber) {
                    Text(changePhoneButtonTitle)
                        .foregroundColor(.blue)
                }
                .disabled(isLoading)
            }
        }
    }
}

// Preview
#Preview {
    VerificationCodeEntryComponent(
        verificationCode: "",
        buttonTitle: "Verify",
        isLoading: false,
        canVerifyCode: false,
        changePhoneButtonTitle: "Change phone number",
        onVerificationCodeChange: { _ in },
        onButtonTap: {},
        onChangePhoneNumber: {}
    )
    .padding()
}