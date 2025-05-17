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