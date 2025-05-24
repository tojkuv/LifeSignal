import SwiftUI
import ComposableArchitecture
import Perception

struct AuthenticationView: View {
    // MARK: - Properties

    /// Store for the authentication process
    @Bindable var store: StoreOf<AuthenticationFeature>

    // MARK: - Body

    var body: some View {
        WithPerceptionTracking {
            NavigationStack {
            VStack {
                if !store.isCodeSent {
                    phoneEntryView
                } else {
                    verificationView
                }
            }
            .padding()
            .navigationTitle("Sign In")
            .alert("Error", isPresented: .constant(store.errorMessage != nil)) {
                Button("OK") { 
                    store.send(.binding(.set(\.errorMessage, nil)))
                }
            } message: {
                Text(store.errorMessage ?? "")
            }
            .onAppear {
                // Focus the phone number field when the view appears
            }
            .background(Color(UIColor.systemGroupedBackground))
            }
        }
    }

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
                store.send(.signOut)
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

                // Phone number field with formatting
                TextField("Phone Number", text: $store.phoneNumber)
                    .keyboardType(.phonePad)
                    .font(.body)
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center) // Center the text horizontally
                    .disabled(store.isLoading)

                Button(action: {
                    store.send(.sendVerificationCode)
                }) {
                    Text("Send Verification Code")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .disabled(!store.canSendCode)
                .background(!store.canSendCode ? Color.gray : Color.blue)
                .cornerRadius(10)
            }
            .padding(.horizontal)

            Spacer()
        }
    }

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
                store.send(.signOut)
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
                .multilineTextAlignment(.center) // Center the text horizontally
                .disabled(store.isLoading)
                .frame(maxWidth: .infinity) // Make it full width
                .padding(.horizontal) // Add horizontal padding to match button width

            Button(action: {
                store.send(.verifyCode)
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
                store.send(.binding(.set(\.isCodeSent, false)))
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

#Preview("Authentication View") {
    AuthenticationView(
        store: Store(initialState: AuthenticationFeature.State()) {
            AuthenticationFeature()
        }
    )
}