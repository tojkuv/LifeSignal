import SwiftUI
import Foundation
import UIKit
import Combine

/// The main content view of the app
struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    // Cancellable for notification observation
    @State private var signOutCancellable: AnyCancellable? = nil

    var body: some View {
        // Use AppView to handle authentication and onboarding flows
        AppView()
            // Add a unique ID to prevent SwiftUI from reusing views
            .id(appState.isAuthenticated.description + appState.needsOnboarding.description)
        .onAppear {
            print("ContentView appeared: isAuthenticated = \(appState.isAuthenticated)")

            // Set up notification observer for sign out
            signOutCancellable = NotificationCenter.default
                .publisher(for: NSNotification.Name("UserSignedOut"))
                .sink { _ in
                    // Reset user data when signed out - removed userViewModel.resetUserData()
                    print("ContentView received UserSignedOut notification")
                }
        }
        .onDisappear {
            // Clean up notification observer
            signOutCancellable?.cancel()
            signOutCancellable = nil
        }
        .onChange(of: appState.isAuthenticated) { oldValue, newValue in
            print("ContentView - Authentication state changed: \(oldValue) -> \(newValue)")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
