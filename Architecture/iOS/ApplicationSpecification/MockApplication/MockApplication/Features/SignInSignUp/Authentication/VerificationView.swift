import SwiftUI

/// A view for verifying a phone number
struct VerificationView: View {
    /// The verification code
    @Binding var verificationCode: String

    /// The phone number
    let phoneNumber: String

    /// Whether the view is in a loading state
    @Binding var isLoading: Bool

    /// Callback when the verification code is submitted
    let onSubmit: () -> Void

    /// Callback when the user wants to change the phone number
    let onChangePhone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
                .padding(.top, 40)

            Text("Enter verification code")
                .font(.title2)
                .fontWeight(.bold)

            Text("We sent a verification code to \(phoneNumber)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextField("Verification code", text: $verificationCode)
                .keyboardType(.numberPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .disabled(isLoading) // Disable during loading
                .multilineTextAlignment(.center)
                .onChange(of: verificationCode) { newValue in
                    // Format the verification code as XXX-XXX
                    let filtered = newValue.filter { $0.isNumber }

                    // Limit to 6 digits
                    let limitedFiltered = String(filtered.prefix(6))

                    // Format with hyphen
                    if limitedFiltered.count > 3 {
                        let firstPart = limitedFiltered.prefix(3)
                        let secondPart = limitedFiltered.dropFirst(3)
                        verificationCode = "\(firstPart)-\(secondPart)"
                    } else if limitedFiltered != verificationCode {
                        // Just use the filtered digits if 3 or fewer
                        verificationCode = limitedFiltered
                    }
                }

            Button(action: onSubmit) {
                Text("Verify")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .disabled(isLoading)
            .background(isLoading || verificationCode.isEmpty ? Color.gray : Color.blue)
            .cornerRadius(12)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .disabled(isLoading || verificationCode.isEmpty)

            Button(action: onChangePhone) {
                Text("Change phone number")
                    .foregroundColor(.blue)
            }
            .disabled(isLoading)

            Spacer()
        }
    }
}

#Preview {
    VerificationView(
        verificationCode: .constant("123456"),
        phoneNumber: "+1 (555) 123-4567",
        isLoading: .constant(false),
        onSubmit: {},
        onChangePhone: {}
    )
}
