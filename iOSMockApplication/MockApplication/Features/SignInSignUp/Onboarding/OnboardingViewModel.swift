import Foundation
import SwiftUI
import Combine

/// View model for the onboarding process
class OnboardingViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The user's first name
    @Published var firstName: String = ""

    /// The user's last name
    @Published var lastName: String = ""

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

    /// Whether to show instructions after onboarding
    @Published var showInstructions: Bool = false

    /// Whether first name field is focused
    @Published var firstNameFieldFocused: Bool = false

    /// Whether last name field is focused
    @Published var lastNameFieldFocused: Bool = false

    /// Whether note field is focused
    @Published var noteFieldFocused: Bool = false

    /// Binding for isOnboarding to communicate with parent view
    @Published var isOnboarding: Bool = true

    // MARK: - Computed Properties

    /// The user's full name (computed from first and last name)
    var name: String {
        let formattedFirstName = formatName(firstName)
        let formattedLastName = formatName(lastName)

        if formattedFirstName.isEmpty && formattedLastName.isEmpty {
            return ""
        } else if formattedFirstName.isEmpty {
            return formattedLastName
        } else if formattedLastName.isEmpty {
            return formattedFirstName
        } else {
            return "\(formattedFirstName) \(formattedLastName)"
        }
    }

    /// Whether both first and last name fields are filled
    var areBothNamesFilled: Bool {
        return !formatName(firstName).isEmpty && !formatName(lastName).isEmpty
    }

    // MARK: - Mock User Data

    /// Default check-in interval (24 hours in seconds)
    private let defaultCheckInInterval: TimeInterval = 24 * 60 * 60

    /// Default notification preference (30 min before)
    private let defaultNotify30MinBefore: Bool = false

    /// Default notification preference (2 hours before)
    private let defaultNotify2HoursBefore: Bool = true

    // MARK: - Methods

    /// Initialize the view model
    init() {
        // Auto-focus the first name field when initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.firstNameFieldFocused = true
        }
    }

    /// Complete the onboarding process
    /// - Parameter completion: Completion handler
    func completeOnboarding(completion: @escaping (Bool) -> Void) {
        isLoading = true

        // Simulate a network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false

            // Save user data to UserDefaults
            self.saveUserData()

            // Show instructions sheet
            self.showInstructions = true

            completion(true)
        }
    }

    /// Save user data to UserDefaults
    private func saveUserData() {
        // Save user name and profile description
        UserDefaults.standard.set(name.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "userName")
        UserDefaults.standard.set(emergencyNote.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "userProfileDescription")

        // Save default check-in interval and notification preferences
        let now = Date()
        UserDefaults.standard.set(defaultCheckInInterval, forKey: "checkInInterval")
        UserDefaults.standard.set(defaultNotify30MinBefore, forKey: "notify30MinBefore")
        UserDefaults.standard.set(defaultNotify2HoursBefore, forKey: "notify2HoursBefore")
        UserDefaults.standard.set(now, forKey: "lastCheckIn")
    }

    /// Handle instructions sheet dismissal
    func handleInstructionsDismissal() {
        // Use a slight delay to ensure the sheet is dismissed before changing isOnboarding
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isOnboarding = false
        }
    }

    /// Handle "Got it" button tap in instructions
    func handleGotItButtonTap() {
        // First dismiss the sheet, then mark onboarding as complete
        showInstructions = false

        // Use a slight delay to ensure the sheet is dismissed before changing isOnboarding
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isOnboarding = false
        }
    }

    /// Move to the next step
    func nextStep() {
        currentStep += 1

        // Focus the note field when moving to the next step
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.noteFieldFocused = true
        }
    }

    /// Move to the previous step
    func previousStep() {
        currentStep -= 1

        // Focus the first name field when going back
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.firstNameFieldFocused = true
        }
    }

    /// Format a name to have proper capitalization
    /// - Parameter name: The name to format
    /// - Returns: The formatted name
    func formatName(_ name: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return ""
        }

        // Split the name by spaces to handle multiple words (e.g., for compound last names)
        let words = trimmedName.components(separatedBy: " ")

        // Format each word to have first letter capitalized and rest lowercase
        let formattedWords = words.map { word -> String in
            if word.isEmpty { return "" }

            let firstChar = word.prefix(1).uppercased()
            let restOfWord = word.dropFirst().lowercased()
            return firstChar + restOfWord
        }

        // Join the words back together with spaces
        return formattedWords.joined(separator: " ")
    }

    /// Format a name as the user types, ensuring proper capitalization
    /// - Parameter name: The name being typed
    /// - Returns: The formatted name
    func formatNameAsTyped(_ name: String) -> String {
        if name.isEmpty {
            return ""
        }

        // Split the name by spaces to handle multiple words
        let components = name.components(separatedBy: " ")

        // Format each word as it's being typed
        let formattedComponents = components.enumerated().map { (index, component) -> String in
            if component.isEmpty { return "" }

            // For all words, capitalize first letter and lowercase the rest
            let firstChar = component.prefix(1).uppercased()
            let restOfWord = component.dropFirst().lowercased()

            return firstChar + restOfWord
        }

        // Join the components back together with spaces
        return formattedComponents.joined(separator: " ")
    }
}