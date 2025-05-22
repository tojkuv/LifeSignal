import Foundation
import SwiftUI
import Combine

/// View model for the authentication process
class AuthenticationViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Whether to show the phone entry view
    @Published var showPhoneEntry: Bool = true

    /// The phone number
    @Published var phoneNumber: String = "" // Empty by default

    /// The verification code
    @Published var verificationCode: String = "" // Empty by default

    /// The verification ID
    @Published var verificationId: String = ""

    /// Whether the authentication process is loading
    @Published var isLoading: Bool = false

    /// Error message to display
    @Published var errorMessage: String = ""

    /// Whether to show an error
    @Published var showError: Bool = false

    /// The selected region
    @Published var selectedRegion: String = "US"

    /// Whether to show the region picker
    @Published var showRegionPicker: Bool = false

    /// Whether the phone number field is focused
    @Published var phoneNumberFieldFocused: Bool = false

    /// Whether the verification code field is focused
    @Published var verificationCodeFieldFocused: Bool = false

    // MARK: - Callback Properties

    /// Callback for when authentication is successful
    private var authenticationSuccessCallback: ((Bool) -> Void)? = nil

    /// Callback for when onboarding is needed
    private var needsOnboardingCallback: ((Bool) -> Void)? = nil

    // MARK: - Constants

    /// Available regions
    let regions = [
        ("US", "+1"),
        ("CA", "+1"),
        ("UK", "+44"),
        ("AU", "+61")
    ]

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Set the authentication success callback
    /// - Parameter callback: The callback to call when authentication is successful
    func setAuthenticationSuccessCallback(_ callback: @escaping (Bool) -> Void) {
        authenticationSuccessCallback = callback
    }

    /// Set the needs onboarding callback
    /// - Parameter callback: The callback to call when onboarding is needed
    func setNeedsOnboardingCallback(_ callback: @escaping (Bool) -> Void) {
        needsOnboardingCallback = callback
    }

    /// Focus the phone number field
    func focusPhoneNumberField() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.phoneNumberFieldFocused = true
        }
    }

    /// Focus the verification code field
    func focusVerificationCodeField() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.verificationCodeFieldFocused = true
        }
    }

    /// Toggle the region picker
    func toggleRegionPicker() {
        HapticFeedback.selectionFeedback()
        showRegionPicker.toggle()
    }

    /// Update the selected region
    /// - Parameter region: The region to select
    func updateSelectedRegion(_ region: (String, String)) {
        let oldRegion = selectedRegion
        selectedRegion = region.0
        showRegionPicker = false
        HapticFeedback.selectionFeedback()

        // If the region format is different, reformat the phone number
        if oldRegion != region.0 && !phoneNumber.isEmpty {
            let filtered = phoneNumber.filter { $0.isNumber }
            phoneNumber = PhoneFormatter.formatPhoneNumberForEditing(filtered, region: region.0)
        }
    }

    /// Handle phone number change
    /// - Parameter newValue: The new phone number value
    func handlePhoneNumberChange(newValue: String) {
        // Check for development testing number
        if newValue == "+11234567890" || newValue == "1234567890" {
            // Allow the development testing number as is
            phoneNumber = "+11234567890"
            return
        }

        // Format the phone number based on the selected region
        let filtered = newValue.filter { $0.isNumber }
        phoneNumber = PhoneFormatter.formatPhoneNumberForEditing(filtered, region: selectedRegion)
    }

    /// Get the phone number placeholder based on the selected region
    var phoneNumberPlaceholder: String {
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

    /// Handle verification code change
    /// - Parameter newValue: The new verification code value
    func handleVerificationCodeChange(newValue: String) {
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

    /// Skip authentication (debug mode)
    func skipAuthentication() {
        HapticFeedback.triggerHaptic()

        // Call callbacks to update the app state directly
        // This will update the bindings in the parent view
        authenticationSuccessCallback?(true)
        needsOnboardingCallback?(false)
    }

    /// Change to phone entry view
    func changeToPhoneEntryView() {
        HapticFeedback.triggerHaptic()
        showPhoneEntry = true
        verificationId = ""
    }

    /// Send a verification code
    func sendVerificationCode() {
        HapticFeedback.triggerHaptic()
        isLoading = true
        errorMessage = ""

        // Simulate a network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false
            self.verificationId = "mock-verification-id"
            self.showPhoneEntry = false

            // Clear the verification code when showing the verification view
            self.verificationCode = ""

            // Focus the verification code field
            self.focusVerificationCodeField()
        }
    }

    /// Verify a code
    func verifyCode() {
        HapticFeedback.triggerHaptic()
        isLoading = true
        errorMessage = ""

        // Simulate a network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false

            // No need to save to UserDefaults, we'll use the binding directly

            // For the mock app, we'll always succeed and show onboarding
            self.needsOnboardingCallback?(true)
            self.authenticationSuccessCallback?(true)
            HapticFeedback.notificationFeedback(type: .success)
        }
    }

    /// Check if the verification code is valid
    var isVerificationCodeValid: Bool {
        return !isLoading && verificationCode.count >= 7
    }
}