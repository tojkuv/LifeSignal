import SwiftUI

/// The main app view that handles authentication state
struct AppView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if !appState.isAuthenticated {
                // Authentication flow
                AuthenticationView(
                    isAuthenticated: $appState.isAuthenticated,
                    needsOnboarding: $appState.needsOnboarding
                )
            } else if appState.needsOnboarding {
                // Onboarding flow
                OnboardingView(
                    isOnboarding: $appState.needsOnboarding
                )
            } else {
                // Main app with tabs
                MainTabView()
            }
        }
        .onAppear {
            // App appeared
            print("AppView appeared: isAuthenticated = \(appState.isAuthenticated)")
        }
        .onChange(of: appState.isAuthenticated) { oldValue, newValue in
            print("Authentication state changed: \(oldValue) -> \(newValue)")
        }
        .onChange(of: UIApplication.shared.applicationState) { oldState, newState in
            // App state changed
            appState.isActive = (newState == .active)
        }
    }
}

#Preview {
    AppView()
        .environmentObject(AppState())
}
