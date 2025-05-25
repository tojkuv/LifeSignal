import SwiftUI

struct AuthenticationView: View {
    // MARK: - Properties

    /// Binding to track authentication state
    @Binding var isAuthenticated: Bool

    /// Binding to track onboarding state
    @Binding var needsOnboarding: Bool

    /// View model for the authentication process
    @StateObject private var viewModel = AuthenticationViewModel()

    /// Focus state for the phone number field
    @FocusState private var phoneNumberFieldFocused: Bool

    /// Focus state for the verification code field
    @FocusState private var verificationCodeFieldFocused: Bool

    // MARK: - Body

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
            .onAppear {
                // Set callbacks
                viewModel.setAuthenticationSuccessCallback { success in
                    if success {
                        isAuthenticated = true
                    }
                }

                viewModel.setNeedsOnboardingCallback { needsOnboarding in
                    self.needsOnboarding = needsOnboarding
                }

                // Focus the phone number field when the view appears
                viewModel.focusPhoneNumberField()
            }
            .onChange(of: viewModel.phoneNumberFieldFocused) { _, newValue in
                phoneNumberFieldFocused = newValue
            }
            .onChange(of: viewModel.verificationCodeFieldFocused) { _, newValue in
                verificationCodeFieldFocused = newValue
            }
            .onChange(of: phoneNumberFieldFocused) { _, newValue in
                viewModel.phoneNumberFieldFocused = newValue
            }
            .onChange(of: verificationCodeFieldFocused) { _, newValue in
                viewModel.verificationCodeFieldFocused = newValue
            }
            .background(Color(UIColor.systemGroupedBackground))
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
                HapticFeedback.triggerHaptic()
                viewModel.skipAuthentication()
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

                    Button(action: viewModel.toggleRegionPicker) {
                        HStack {
                            // Show the currently selected region
                            let selectedRegionInfo = viewModel.regions.first { $0.0 == viewModel.selectedRegion }!
                            Text("\(selectedRegionInfo.0) (\(selectedRegionInfo.1))")
                                .foregroundColor(.primary)

                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .popover(isPresented: $viewModel.showRegionPicker) {
                        List {
                            ForEach(viewModel.regions, id: \.0) { region in
                                Button(action: { viewModel.updateSelectedRegion(region) }) {
                                    HStack {
                                        Text("\(region.0) (\(region.1))")

                                        Spacer()

                                        if viewModel.selectedRegion == region.0 {
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
                TextField(viewModel.phoneNumberPlaceholder, text: $viewModel.phoneNumber)
                    .keyboardType(.phonePad)
                    .font(.body)
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center) // Center the text horizontally
                    .focused($phoneNumberFieldFocused)
                    .disabled(viewModel.isLoading)
                    .onChange(of: viewModel.phoneNumber) { _, newValue in
                        viewModel.handlePhoneNumberChange(newValue: newValue)
                    }

                Button(action: {
                    HapticFeedback.triggerHaptic()
                    viewModel.sendVerificationCode()
                }) {
                    Text("Send Verification Code")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .disabled(viewModel.isLoading)
                .background(viewModel.isLoading || !isPhoneNumberValid ? Color.gray : Color.blue)
                .cornerRadius(10)
                .disabled(viewModel.isLoading || !isPhoneNumberValid)
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    /// Check if the phone number is valid based on the selected region
    private var isPhoneNumberValid: Bool {
        // Allow development testing number
        if viewModel.phoneNumber == "+11234567890" {
            return true
        }

        // Count only digits
        let digitCount = viewModel.phoneNumber.filter { $0.isNumber }.count

        // Check if we have a complete phone number (10 digits for all supported regions)
        return digitCount == 10
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
                HapticFeedback.triggerHaptic()
                viewModel.skipAuthentication()
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
            TextField("XXX-XXX", text: $viewModel.verificationCode)
                .keyboardType(.numberPad)
                .font(.body)
                .padding(.vertical, 12)
                .padding(.horizontal)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center) // Center the text horizontally
                .focused($verificationCodeFieldFocused)
                .disabled(viewModel.isLoading)
                .frame(maxWidth: .infinity) // Make it full width
                .padding(.horizontal) // Add horizontal padding to match button width
                .onChange(of: viewModel.verificationCode) { _, newValue in
                    viewModel.handleVerificationCodeChange(newValue: newValue)
                }

            Button(action: {
                HapticFeedback.triggerHaptic()
                viewModel.verifyCode()
            }) {
                Text("Verify")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .background(viewModel.isVerificationCodeValid ? Color.blue : Color.gray)
            .cornerRadius(12)
            .padding(.horizontal)
            .disabled(!viewModel.isVerificationCodeValid)

            Button(action: {
                HapticFeedback.lightImpact()
                viewModel.changeToPhoneEntryView()
            }) {
                Text("Change phone number")
                    .foregroundColor(.blue)
            }
            .disabled(viewModel.isLoading)

            Spacer()
        }
    }

    /// A standalone verification view as a computed property
    private var standaloneVerificationView: some View {
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

            Text("We sent a verification code")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextField("Verification code", text: $viewModel.verificationCode)
                .keyboardType(.numberPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .disabled(viewModel.isLoading) // Disable during loading
                .multilineTextAlignment(.center)
                .onChange(of: viewModel.verificationCode) { _, newValue in
                    viewModel.handleVerificationCodeChange(newValue: newValue)
                }

            Button(action: viewModel.verifyCode) {
                Text("Verify")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .disabled(viewModel.isLoading)
            .background(viewModel.isLoading || viewModel.verificationCode.isEmpty ? Color.gray : Color.blue)
            .cornerRadius(12)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .disabled(viewModel.isLoading || viewModel.verificationCode.isEmpty)

            Button(action: viewModel.changeToPhoneEntryView) {
                Text("Change phone number")
                    .foregroundColor(.blue)
            }
            .disabled(viewModel.isLoading)

            Spacer()
        }
    }
}

// MARK: - Previews

#Preview("Authentication View") {
    AuthenticationView(
        isAuthenticated: .constant(false),
        needsOnboarding: .constant(false)
    )
}
