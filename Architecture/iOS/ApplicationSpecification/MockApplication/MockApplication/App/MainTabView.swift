//
//  MainTabView.swift
//  MockApplication
//
//  Created by Livan on 5/14/25.
//

import SwiftUI
import Foundation

/// The main tab view of the app
struct MainTabView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: MainTabViewModel

    init() {
        // Initialize the view model with Check-in as the default tab
        _viewModel = StateObject(wrappedValue: MainTabViewModel(initialTab: 0))
    }

    // MARK: - Lifecycle

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            // Home tab
            NavigationStack {
                HomeView()
                    .navigationTitle("Home")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)

            // Responders tab
            NavigationStack {
                RespondersView()
                    .navigationTitle("Responders")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Responders", systemImage: "person.2.fill")
            }
            .if(viewModel.pendingPingsCount > 0) { view in
                view.badge(viewModel.pendingPingsCount)
            }
            .tag(1)

            // Check-in tab (center)
            NavigationStack {
                CheckInView()
                    .navigationTitle("Check-In")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Check-In", systemImage: "iphone")
            }
            .tag(2)

            // Dependents tab
            NavigationStack {
                DependentsView()
                    .navigationTitle("Dependents")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Dependents", systemImage: "person.3.fill")
            }
            .if(viewModel.nonResponsiveDependentsCount > 0) { view in
                view.badge(viewModel.nonResponsiveDependentsCount)
            }
            .tag(3)

            // Profile tab
            NavigationStack {
                ProfileView()
                    .navigationTitle("Profile")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle.dashed")
            }
            .tag(4)
        }
        .accentColor(.blue)
        .background(.ultraThinMaterial)
        .onAppear {
            // Sync view model with user view model
            viewModel.isAlertActive = userViewModel.isAlertActive
            viewModel.pendingPingsCount = userViewModel.pendingPingsCount
            viewModel.nonResponsiveDependentsCount = userViewModel.nonResponsiveDependentsCount
        }
    }
}

#Preview {
    let userViewModel = UserViewModel()
    let appState = AppState()

    return MainTabView()
        .environmentObject(userViewModel)
        .environmentObject(appState)
}
