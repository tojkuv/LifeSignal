import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    @Binding var isAuthenticated: Bool
    @Binding var needsOnboarding: Bool

    @StateObject private var viewModel = AuthenticationViewModel()

    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.showPhoneEntry {
                    phoneEntryView
                } else {
                    verificationView
                }
            }
            .padding()
            .navigationTitle("Sign In")
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }

    private var phoneEntryView: some View {
        VStack(spacing: 24) {
            Image(systemName: "phone.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
                .padding(.top, 40)

            Text("Enter your phone number")
                .font(.title2)
                .fontWeight(.bold)

            TextField("Phone number", text: $viewModel.phoneNumber)
                .keyboardType(.phonePad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .disabled(viewModel.isLoading) // Disable during loading

            Button(action: sendVerificationCode) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("Continue")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(viewModel.isLoading ? Color.gray : Color.blue)
            .cornerRadius(12)
            .padding(.horizontal)
            .disabled(viewModel.isLoading || viewModel.phoneNumber.isEmpty)

            Spacer()
        }
    }

    private var verificationView: some View {
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

            Text("We sent a verification code to \(viewModel.phoneNumber)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextField("Verification code", text: $viewModel.verificationCode)
                .keyboardType(.numberPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .disabled(viewModel.isLoading) // Disable during loading

            Button(action: verifyCode) {
                if viewModel.isLoading {
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
            .background(viewModel.isLoading ? Color.gray : Color.blue)
            .cornerRadius(12)
            .padding(.horizontal)
            .disabled(viewModel.isLoading || viewModel.verificationCode.isEmpty)

            Button(action: {
                viewModel.showPhoneEntry = true
                viewModel.verificationId = ""
            }) {
                Text("Change phone number")
                    .foregroundColor(.blue)
            }
            .disabled(viewModel.isLoading)

            Spacer()
        }
    }

    private func sendVerificationCode() {
        viewModel.sendVerificationCode { success in
            // No additional action needed, the view model handles the UI state
        }
    }

    private func verifyCode() {
        viewModel.verifyCode(needsOnboarding: { needsOnboarding in
            self.needsOnboarding = needsOnboarding
        }) { success in
            if success {
                isAuthenticated = true
            }
        }
    }
}

#Preview {
    AuthenticationView(
        isAuthenticated: .constant(false),
        needsOnboarding: .constant(false)
    )
    .environmentObject(UserViewModel())
}
