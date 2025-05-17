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
        // Show sign-in screen and onboarding by default
        appState.isAuthenticated = true
        appState.needsOnboarding = false

        // Initialize user data
        userViewModel.name = "Sarah Johnson"
        userViewModel.generateNewQRCode() // Generate a QR code ID
        userViewModel.checkInInterval = 8 * 3600 // 8 hours
        userViewModel.lastCheckIn = Date() // Set last check-in to now

        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        // Note: We're not requesting notification permissions here anymore
        // Permissions will be requested when needed through NotificationManager
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userViewModel)
                .environmentObject(appState)
        }
    }
}
