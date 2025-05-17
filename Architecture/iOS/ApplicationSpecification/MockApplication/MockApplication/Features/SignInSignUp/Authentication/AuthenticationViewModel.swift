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
    @Published var verificationCode: String = "123456" // Test verification code

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

    // MARK: - Methods

    /// Send a verification code
    /// - Parameter completion: Completion handler
    func sendVerificationCode(completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = ""

        // Simulate a network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false
            self.verificationId = "mock-verification-id"
            self.showPhoneEntry = false
            completion(true)

            // Clear the verification code when showing the verification view
            self.verificationCode = ""
        }
    }

    /// Verify a code
    /// - Parameters:
    ///   - needsOnboarding: Whether the user needs onboarding
    ///   - completion: Completion handler
    func verifyCode(needsOnboarding: @escaping (Bool) -> Void, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = ""

        // Simulate a network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false

            // For the mock app, we'll always succeed and show onboarding
            needsOnboarding(true)
            completion(true)
        }
    }
}