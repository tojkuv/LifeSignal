import SwiftUI

struct AuthenticationView: View {
    /// Available regions
    let regions = [
        ("US", "+1"),
        ("CA", "+1"),
        ("UK", "+44"),
        ("AU", "+61")
    ]

    /// Focus state for the phone number field
    @FocusState private var phoneNumberFieldFocused: Bool

    /// Focus state for the verification code field
    @FocusState private var verificationCodeFieldFocused: Bool
    @EnvironmentObject private var userViewModel: UserViewModel
    @Binding var isAuthenticated: Bool
    @Binding var needsOnboarding: Bool

    @StateObject private var viewModel = AuthenticationViewModel()

    var body: some View {
        NavigationStack {
            VStack {
                // Debug button at the top of the screen
                #if DEBUG
                Button(action: {
                    // Skip authentication and go directly to home screen
                    HapticFeedback.triggerHaptic()
                    isAuthenticated = true
                    needsOnboarding = false
                }) {
                    Text("Debug: Skip to Home")
                        .font(.caption)
                        .padding(8)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
                .padding(.top, 8)
                .hapticFeedback()
                #endif

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
                // Focus the phone number field when the view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    phoneNumberFieldFocused = true
                }
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
                        // Add haptic feedback when tapping the region button
                        HapticFeedback.selectionFeedback()
                        // Toggle the region picker
                        viewModel.showRegionPicker.toggle()
                    }) {
                        HStack {
                            // Show the currently selected region
                            let selectedRegionInfo = regions.first { $0.0 == viewModel.selectedRegion }!
                            Text("\(selectedRegionInfo.0) (\(selectedRegionInfo.1))")
                                .foregroundColor(.primary)

                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .popover(isPresented: $viewModel.showRegionPicker) {
                        List {
                            ForEach(regions, id: \.0) { region in
                                Button(action: {
                                    // Update the selected region
                                    let oldRegion = viewModel.selectedRegion
                                    viewModel.selectedRegion = region.0
                                    viewModel.showRegionPicker = false
                                    HapticFeedback.selectionFeedback()

                                    // If the region format is different, reformat the phone number
                                    if oldRegion != region.0 && !viewModel.phoneNumber.isEmpty {
                                        let filtered = viewModel.phoneNumber.filter { $0.isNumber }
                                        if region.0 == "US" || region.0 == "CA" {
                                            formatUSPhoneNumber(filtered)
                                        } else if region.0 == "UK" {
                                            formatUKPhoneNumber(filtered)
                                        } else if region.0 == "AU" {
                                            formatAUPhoneNumber(filtered)
                                        }
                                    }
                                }) {
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
                TextField(getPhoneNumberPlaceholder(), text: $viewModel.phoneNumber)
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
                    .onChange(of: viewModel.phoneNumber) { newValue in
                        // Check for development testing number
                        if newValue == "+11234567890" || newValue == "1234567890" {
                            // Allow the development testing number as is
                            viewModel.phoneNumber = "+11234567890"
                            return
                        }

                        // Format the phone number based on the selected region
                        let filtered = newValue.filter { $0.isNumber }

                        switch viewModel.selectedRegion {
                        case "US", "CA":
                            // Format for US and Canada: XXX-XXX-XXXX
                            formatUSPhoneNumber(filtered)
                        case "UK":
                            // Format for UK: XXXX-XXX-XXX
                            formatUKPhoneNumber(filtered)
                        case "AU":
                            // Format for Australia: XXXX-XXX-XXX
                            formatAUPhoneNumber(filtered)
                        default:
                            // Default format: XXX-XXX-XXXX
                            formatUSPhoneNumber(filtered)
                        }
                    }

                Button(action: sendVerificationCode) {
                    Text("Send Verification Code")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .disabled(viewModel.isLoading)
                .background(viewModel.isLoading || !isPhoneNumberValid() ? Color.gray : Color.blue)
                .cornerRadius(10)
                .disabled(viewModel.isLoading || !isPhoneNumberValid())
                .hapticFeedback()
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
                .onChange(of: viewModel.verificationCode) { oldValue, newValue in
                    // Format the verification code as XXX-XXX
                    let filtered = newValue.filter { $0.isNumber }

                    // Limit to 6 digits
                    let limitedFiltered = String(filtered.prefix(6))

                    // Format with hyphen
                    if limitedFiltered.count > 3 {
                        let firstPart = limitedFiltered.prefix(3)
                        let secondPart = limitedFiltered.dropFirst(3)
                        viewModel.verificationCode = "\(firstPart)-\(secondPart)"
                    } else if limitedFiltered != viewModel.verificationCode {
                        // Just use the filtered digits if 3 or fewer
                        viewModel.verificationCode = limitedFiltered
                    }
                }

            Button(action: verifyCode) {
                Text("Verify")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .background(viewModel.isLoading || viewModel.verificationCode.count < 7 ? Color.gray : Color.blue)
            .cornerRadius(12)
            .padding(.horizontal)
            .disabled(viewModel.isLoading || viewModel.verificationCode.count < 7)
            .hapticFeedback()

            Button(action: {
                HapticFeedback.triggerHaptic()
                viewModel.showPhoneEntry = true
                viewModel.verificationId = ""
            }) {
                Text("Change phone number")
                    .foregroundColor(.blue)
            }
            .disabled(viewModel.isLoading)
            .hapticFeedback(style: .light)

            Spacer()
        }
    }

    private func sendVerificationCode() {
        HapticFeedback.triggerHaptic()
        viewModel.sendVerificationCode { success in
            // Focus the verification code field when the view changes
            if success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.verificationCodeFieldFocused = true
                }
            }
        }
    }

    private func verifyCode() {
        HapticFeedback.triggerHaptic()
        viewModel.verifyCode(needsOnboarding: { needsOnboarding in
            // Always set needsOnboarding to true for the mock application
            self.needsOnboarding = true
        }) { success in
            if success {
                isAuthenticated = true
                HapticFeedback.notificationFeedback(type: .success)
            }
        }
    }

    /// Get the phone number placeholder based on the selected region
    private func getPhoneNumberPlaceholder() -> String {
        let selectedRegionCode = regions.first { $0.0 == viewModel.selectedRegion }!.1

        switch viewModel.selectedRegion {
        case "US", "CA":
            return "XXX-XXX-XXXX" // Format for US and Canada
        case "UK":
            return "XXXX-XXX-XXX" // Format for UK
        case "AU":
            return "XXXX-XXX-XXX" // Format for Australia
        default:
            return "XXX-XXX-XXXX" // Default format
        }
    }

    /// Format a US/Canada phone number (XXX-XXX-XXXX)
    private func formatUSPhoneNumber(_ filtered: String) {
        // Limit to 10 digits
        let limitedFiltered = String(filtered.prefix(10))

        // Format with hyphens
        if limitedFiltered.count > 6 {
            let areaCode = limitedFiltered.prefix(3)
            let prefix = limitedFiltered.dropFirst(3).prefix(3)
            let lineNumber = limitedFiltered.dropFirst(6)
            viewModel.phoneNumber = "\(areaCode)-\(prefix)-\(lineNumber)"
        } else if limitedFiltered.count > 3 {
            let areaCode = limitedFiltered.prefix(3)
            let prefix = limitedFiltered.dropFirst(3)
            viewModel.phoneNumber = "\(areaCode)-\(prefix)"
        } else if limitedFiltered.count > 0 {
            viewModel.phoneNumber = limitedFiltered
        } else {
            viewModel.phoneNumber = ""
        }
    }

    /// Format a UK phone number (XXXX-XXX-XXX)
    private func formatUKPhoneNumber(_ filtered: String) {
        // Limit to 10 digits
        let limitedFiltered = String(filtered.prefix(10))

        // Format with hyphens
        if limitedFiltered.count > 7 {
            let areaCode = limitedFiltered.prefix(4)
            let prefix = limitedFiltered.dropFirst(4).prefix(3)
            let lineNumber = limitedFiltered.dropFirst(7)
            viewModel.phoneNumber = "\(areaCode)-\(prefix)-\(lineNumber)"
        } else if limitedFiltered.count > 4 {
            let areaCode = limitedFiltered.prefix(4)
            let prefix = limitedFiltered.dropFirst(4)
            viewModel.phoneNumber = "\(areaCode)-\(prefix)"
        } else if limitedFiltered.count > 0 {
            viewModel.phoneNumber = limitedFiltered
        } else {
            viewModel.phoneNumber = ""
        }
    }

    /// Format an Australian phone number (XXXX-XXX-XXX)
    private func formatAUPhoneNumber(_ filtered: String) {
        // Limit to 10 digits
        let limitedFiltered = String(filtered.prefix(10))

        // Format with hyphens
        if limitedFiltered.count > 7 {
            let areaCode = limitedFiltered.prefix(4)
            let prefix = limitedFiltered.dropFirst(4).prefix(3)
            let lineNumber = limitedFiltered.dropFirst(7)
            viewModel.phoneNumber = "\(areaCode)-\(prefix)-\(lineNumber)"
        } else if limitedFiltered.count > 4 {
            let areaCode = limitedFiltered.prefix(4)
            let prefix = limitedFiltered.dropFirst(4)
            viewModel.phoneNumber = "\(areaCode)-\(prefix)"
        } else if limitedFiltered.count > 0 {
            viewModel.phoneNumber = limitedFiltered
        } else {
            viewModel.phoneNumber = ""
        }
    }

    /// Check if the phone number is valid based on the selected region
    private func isPhoneNumberValid() -> Bool {
        // Allow development testing number
        if viewModel.phoneNumber == "+11234567890" {
            return true
        }

        // Count only digits
        let digitCount = viewModel.phoneNumber.filter { $0.isNumber }.count

        // Check if we have a complete phone number (10 digits for all supported regions)
        return digitCount == 10
    }
}

#Preview {
    AuthenticationView(
        isAuthenticated: .constant(false),
        needsOnboarding: .constant(false)
    )
    .environmentObject(UserViewModel())
}
