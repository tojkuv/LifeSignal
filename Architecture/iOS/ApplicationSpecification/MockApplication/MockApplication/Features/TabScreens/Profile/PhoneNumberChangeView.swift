import SwiftUI
import Foundation


/// A view for changing the user's phone number
struct PhoneNumberChangeView: View {
    /// The user view model
    @EnvironmentObject private var userViewModel: UserViewModel

    /// Dismiss action
    @Environment(\.dismiss) private var dismiss

    /// The new phone number
    @State private var newPhone: String = ""

    /// The verification code
    @State private var verificationCode: String = ""

    /// Whether the verification code has been sent
    @State private var isCodeSent: Bool = false

    /// Whether the view is in loading state
    @State private var isLoading: Bool = false

    /// Error message
    @State private var errorMessage: String? = nil

    /// The selected region
    @State private var selectedRegion: String = "US"

    /// Focus state for the phone number field
    @FocusState private var phoneNumberFieldFocused: Bool

    /// Focus state for the verification code field
    @FocusState private var verificationCodeFieldFocused: Bool

    /// Available regions
    let regions = [
        ("US", "+1"),
        ("CA", "+1"),
        ("UK", "+44"),
        ("AU", "+61")
    ]

    /// Computed property to check if the phone number is valid
    var isValidPhoneNumber: Bool {
        // Match login screen validation
        // Allow development testing numbers
        if newPhone == "1234567890" || newPhone == "0000000000" || newPhone == "+11234567890" {
            return true
        }

        // Simple validation: at least 10 digits
        return newPhone.filter { $0.isNumber }.count >= 10
    }

    /// Computed property to check if the verification code is valid
    var isValidVerificationCode: Bool {
        // Remove any non-digit characters and check if we have 6 digits
        return verificationCode.filter { $0.isNumber }.count == 6
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                // Use system grouped background for the main background
                Color(UIColor.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                    .frame(height: 0) // Zero height to not take up space
                if !isCodeSent {
                    // Initial phone number change view
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Current Phone Number")
                            .font(.headline)
                            .padding(.horizontal, 4)

                        Text(userViewModel.phone.isEmpty ? "(954) 234-5678" : userViewModel.phone)
                            .font(.body)
                            .padding(.vertical, 12)
                            .padding(.horizontal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                            .foregroundColor(.primary)

                        Text("New Phone Number")
                            .font(.headline)
                            .padding(.horizontal, 4)
                            .padding(.top, 8)

                        // Region picker
                        HStack {
                            Text("Region")
                                .font(.body)

                            Spacer()

                            Picker("Region", selection: $selectedRegion) {
                                ForEach(regions, id: \.0) { region in
                                    Text("\(region.0) (\(region.1))").tag(region.0)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .onChange(of: selectedRegion) { _, _ in
                                HapticFeedback.selectionFeedback()
                            }
                        }
                        .padding(.horizontal, 4)

                        TextField(getPhoneNumberPlaceholder(), text: $newPhone)
                            .keyboardType(.phonePad)
                            .font(.body)
                            .padding(.vertical, 12)
                            .padding(.horizontal)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading) // Left align the text
                            .focused($phoneNumberFieldFocused)
                            .onChange(of: newPhone) { newValue in
                                // Check for development testing number
                                if newValue == "+11234567890" || newValue == "1234567890" || newValue == "0000000000" {
                                    // Allow the development testing number as is
                                    return
                                }

                                // Format the phone number based on the selected region
                                let filtered = newValue.filter { $0.isNumber }

                                switch selectedRegion {
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

                        Text("Enter your new phone number. We'll send a verification code to confirm.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)

                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 4)
                        }

                        Button(action: {
                            HapticFeedback.triggerHaptic()
                            sendVerificationCode()
                        }) {
                            Text("Send Verification Code")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isLoading || !isValidPhoneNumber ? Color.gray : Color.blue)
                                .cornerRadius(10)
                        }
                        .disabled(isLoading || !isValidPhoneNumber)
                        .padding(.top, 16)
                    }
                    .padding(.horizontal)
                    .padding(.top, 24)
                } else {
                    // Verification code view
                    VStack(alignment: .leading, spacing: 16) {
                        // Removed back button to prevent users from going back during verification
                        Text("Verification Code")
                            .font(.headline)
                            .padding(.horizontal, 4)

                        Text("We've sent a verification code to your new phone number. Please enter it below.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)

                        TextField("XXX-XXX", text: $verificationCode)
                            .keyboardType(.numberPad)
                            .font(.body)
                            .padding(.vertical, 12)
                            .padding(.horizontal)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                            .foregroundColor(.primary)
                            .focused($verificationCodeFieldFocused)
                            .onChange(of: verificationCode) { oldValue, newValue in
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

                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 4)
                        }

                        Button(action: {
                            HapticFeedback.triggerHaptic()
                            verifyCode()
                        }) {
                            Text("Verify Code")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isLoading || !isValidVerificationCode ? Color.gray : Color.blue)
                                .cornerRadius(10)
                        }
                        .disabled(isLoading || !isValidVerificationCode)
                        .padding(.top, 16)
                    }
                    .padding(.horizontal)
                    .padding(.top, 24)
                }

                Spacer(minLength: 0)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Change Phone Number")
            .background(Color(UIColor.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticFeedback.triggerHaptic()
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Focus the appropriate text field when the view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if isCodeSent {
                        verificationCodeFieldFocused = true
                    } else {
                        phoneNumberFieldFocused = true
                    }
                }
            }
        }
    }

    /// Send a verification code to the new phone number
    private func sendVerificationCode() {
        // Provide haptic feedback
        HapticFeedback.notificationFeedback(type: .success)
        // Validate phone number
        guard !newPhone.isEmpty else {
            errorMessage = "Please enter a phone number."
            return
        }

        // Show loading state
        isLoading = true

        // Simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Reset loading state
            isLoading = false

            // Set code sent state
            isCodeSent = true

            // Clear error message
            errorMessage = nil

            // Focus the verification code field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                verificationCodeFieldFocused = true
            }
        }
    }

    /// Verify the verification code
    private func verifyCode() {
        // Provide haptic feedback
        HapticFeedback.notificationFeedback(type: .success)
        // Validate verification code
        guard !verificationCode.isEmpty else {
            errorMessage = "Please enter the verification code."
            return
        }

        // Show loading state
        isLoading = true

        // Simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Reset loading state
            isLoading = false

            // Check if verification code is valid (mock implementation)
            if verificationCode == "123456" || verificationCode == "000000" {
                // Update phone number
                let regionCode = regions.first(where: { $0.0 == selectedRegion })?.1 ?? "+1"
                userViewModel.phone = "\(regionCode) \(newPhone)"

                // Show a silent notification for successful phone number change
                NotificationManager.shared.showPhoneNumberChangedNotification()

                // Dismiss the view
                dismiss()
            } else {
                // Show error message
                errorMessage = "Invalid verification code. Please try again."
            }
        }
    }

    /// Get the phone number placeholder based on the selected region
    private func getPhoneNumberPlaceholder() -> String {
        switch selectedRegion {
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
            newPhone = "\(areaCode)-\(prefix)-\(lineNumber)"
        } else if limitedFiltered.count > 3 {
            let areaCode = limitedFiltered.prefix(3)
            let prefix = limitedFiltered.dropFirst(3)
            newPhone = "\(areaCode)-\(prefix)"
        } else if limitedFiltered.count > 0 {
            newPhone = limitedFiltered
        } else {
            newPhone = ""
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
            newPhone = "\(areaCode)-\(prefix)-\(lineNumber)"
        } else if limitedFiltered.count > 4 {
            let areaCode = limitedFiltered.prefix(4)
            let prefix = limitedFiltered.dropFirst(4)
            newPhone = "\(areaCode)-\(prefix)"
        } else if limitedFiltered.count > 0 {
            newPhone = limitedFiltered
        } else {
            newPhone = ""
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
            newPhone = "\(areaCode)-\(prefix)-\(lineNumber)"
        } else if limitedFiltered.count > 4 {
            let areaCode = limitedFiltered.prefix(4)
            let prefix = limitedFiltered.dropFirst(4)
            newPhone = "\(areaCode)-\(prefix)"
        } else if limitedFiltered.count > 0 {
            newPhone = limitedFiltered
        } else {
            newPhone = ""
        }
    }
}
