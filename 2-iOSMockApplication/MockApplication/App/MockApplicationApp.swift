//
//  MockApplicationApp.swift
//  MockApplication
//
//  Created by Livan on 5/14/25.
//

import SwiftUI
import UserNotifications

@main
struct MockApplicationApp: App {
    // Create shared view models for the app
    @StateObject private var mockApplicationViewModel = MockApplicationViewModel()

    init() {
        // Set up notification delegate - this is fine in init() as it's not accessing @StateObject
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            if !mockApplicationViewModel.isAuthenticated {
                // Authentication flow
                AuthenticationView(
                    isAuthenticated: $mockApplicationViewModel.isAuthenticated,
                    needsOnboarding: $mockApplicationViewModel.needsOnboarding
                )
            } else if mockApplicationViewModel.needsOnboarding {
                // Onboarding flow
                OnboardingView(
                    isOnboarding: $mockApplicationViewModel.needsOnboarding
                )
            } else {
                // Main app with tabs
                MainTabView()
            }
        }
    }


}
