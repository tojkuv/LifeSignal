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
    @StateObject private var userViewModel = UserViewModel()
    @StateObject private var appState = AppState()

    init() {
        // Set up notification delegate - this is fine in init() as it's not accessing @StateObject
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        // Configure default values for UserViewModel and AppState
        // This is done using a separate function to avoid accessing @StateObject directly
        configureDefaultValues()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userViewModel)
                .environmentObject(appState)
                .onAppear {
                    // This is the proper place to configure the view models
                    // as it happens after the StateObjects are properly initialized
                    configureAppState()
                }
        }
    }

    /// Configure default values for UserDefaults - this doesn't access @StateObject properties
    private func configureDefaultValues() {
        // Set default values in UserDefaults if they don't exist yet
        if UserDefaults.standard.object(forKey: "isFirstLaunch") == nil {
            UserDefaults.standard.set(false, forKey: "isAuthenticated")
            UserDefaults.standard.set(true, forKey: "needsOnboarding")
            UserDefaults.standard.set("Sarah Johnson", forKey: "userName")
            UserDefaults.standard.set(8 * 3600, forKey: "checkInInterval") // 8 hours
            UserDefaults.standard.set(Date(), forKey: "lastCheckIn")
            UserDefaults.standard.set(true, forKey: "isFirstLaunch")
        }
    }

    /// Configure app state after the view models are properly initialized
    private func configureAppState() {
        // Show sign-in screen and onboarding by default
        appState.isAuthenticated = UserDefaults.standard.bool(forKey: "isAuthenticated")
        appState.needsOnboarding = UserDefaults.standard.bool(forKey: "needsOnboarding")

        // Initialize user data
        if let name = UserDefaults.standard.string(forKey: "userName") {
            userViewModel.name = name
        } else {
            userViewModel.name = "Sarah Johnson"
        }

        userViewModel.generateNewQRCode() // Generate a QR code ID

        if let interval = UserDefaults.standard.object(forKey: "checkInInterval") as? TimeInterval {
            userViewModel.checkInInterval = interval
        } else {
            userViewModel.checkInInterval = 8 * 3600 // 8 hours
        }

        if let lastCheckIn = UserDefaults.standard.object(forKey: "lastCheckIn") as? Date {
            userViewModel.lastCheckIn = lastCheckIn
        } else {
            userViewModel.lastCheckIn = Date()
        }
    }
}
