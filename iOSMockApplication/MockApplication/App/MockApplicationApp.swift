//
//  Application.swift
//  MockApplication
//
//  Created by Livan on 5/14/25.
//

import SwiftUI
import UserNotifications

@main
struct Application: App {
    // Create shared view models for the app
    @StateObject private var applicationViewModel = MockApplicationViewModel()

    init() {
        // Set up notification delegate - this is fine in init() as it's not accessing @StateObject
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            if !applicationViewModel.isAuthenticated {
                // Authentication flow
                AuthenticationView(
                    isAuthenticated: $applicationViewModel.isAuthenticated,
                    needsOnboarding: $applicationViewModel.needsOnboarding
                )
            } else if applicationViewModel.needsOnboarding {
                // Onboarding flow
                OnboardingView(
                    isOnboarding: $applicationViewModel.needsOnboarding
                )
            } else {
                // Main app with tabs
                MainTabsView()
            }
        }
    }


}
