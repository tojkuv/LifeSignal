//
//  MockApplicationApp.swift
//  MockApplication
//
//  Created by Livan on 5/14/25.
//

import SwiftUI

@main
struct MockApplicationApp: App {
    // Create shared view models for the app
    @StateObject private var userViewModel = UserViewModel()
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userViewModel)
        }
    }
}
