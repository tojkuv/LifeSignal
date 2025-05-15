import Foundation
import SwiftUI
import Combine

/// View model for the onboarding process
class OnboardingViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The user's name
    @Published var name: String = ""

    /// The user's emergency note
    @Published var emergencyNote: String = ""

    /// Whether the onboarding process is loading
    @Published var isLoading: Bool = false

    /// The current step in the onboarding process
    @Published var currentStep: Int = 0

    /// Error message to display
    @Published var errorMessage: String = ""

    /// Whether to show an error
    @Published var showError: Bool = false

    // MARK: - Methods

    /// Complete the onboarding process
    /// - Parameter completion: Completion handler
    func completeOnboarding(completion: @escaping (Bool) -> Void) {
        isLoading = true

        // Simulate a network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false
            completion(true)
        }
    }

    /// Move to the next step
    func nextStep() {
        currentStep += 1
    }

    /// Move to the previous step
    func previousStep() {
        currentStep -= 1
    }
}