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
        // Request notification permissions when the app starts
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userViewModel)
                .environmentObject(appState)
        }
    }
}
