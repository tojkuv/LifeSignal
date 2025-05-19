import Foundation
import SwiftUI
import Combine

/// Global app state
/// This class is designed to mirror the structure of AppFeature.State in the TCA implementation
class AppViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Whether the user is authenticated
    @Published var isAuthenticated: Bool = false

    /// Whether the user needs onboarding
    @Published var needsOnboarding: Bool = false

    /// Whether the app is in the foreground
    @Published var isActive: Bool = true

    /// Error state
    @Published var error: String? = nil

    /// Loading state
    @Published var isLoading: Bool = false

    /// Presentation states (will be @Presents in TCA)
    @Published var showContactDetails: Bool = false
    @Published var selectedContactId: String? = nil

    // MARK: - Initialization

    init() {
        // Start with the authentication flow
        self.isAuthenticated = false
        self.needsOnboarding = false
    }

    // MARK: - Methods

    /// Sign in the user
    func signIn() {
        isAuthenticated = true
        // Check if the user needs onboarding
        needsOnboarding = true
    }

    /// Complete onboarding
    func completeOnboarding() {
        needsOnboarding = false
    }

    /// Sign out the user
    func signOut() {
        print("AppState.signOut() called")

        // Reset authentication state
        self.isAuthenticated = false
        self.needsOnboarding = false

        // Publish changes to ensure UI updates
        objectWillChange.send()

        // Post notification for app-wide sign out
        NotificationCenter.default.post(name: NSNotification.Name("UserSignedOut"), object: nil)

        // Log for debugging
        print("User signed out: isAuthenticated = \(isAuthenticated)")
    }

    /// Set error message
    func setError(_ message: String?) {
        error = message
    }

    /// Set loading state
    func setLoading(_ loading: Bool) {
        isLoading = loading
    }

    /// Show contact details
    func showContactDetails(for contactId: String) {
        selectedContactId = contactId
        showContactDetails = true
    }

    /// Hide contact details
    func hideContactDetails() {
        showContactDetails = false
        selectedContactId = nil
    }
}

// For backward compatibility
typealias AppState = AppViewModel
