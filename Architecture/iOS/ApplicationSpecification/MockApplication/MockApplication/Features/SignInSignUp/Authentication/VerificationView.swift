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
                .padding(.horizontal)
                .disabled(isLoading) // Disable during loading
            
            Button(action: onSubmit) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("Verify")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(isLoading || verificationCode.isEmpty ? Color.gray : Color.blue)
            .cornerRadius(12)
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
