//
//  MainContentView.swift
//  MockApplication
//
//  Created by Livan on 5/14/25.
//

import SwiftUI

// This is a placeholder view that's not used in the app
struct MainContentView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = MainTabViewModel(initialTab: 0)

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            // Home tab
            NavigationStack {
                Text("Home View")
                    .navigationTitle("Home")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)

            // Responders tab
            NavigationStack {
                Text("Responders View")
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
                Text("Check-In View")
                    .navigationTitle("Check-In")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Check-In", systemImage: "iphone")
            }
            .tag(2)

            // Dependents tab
            NavigationStack {
                Text("Dependents View")
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
                Text("Profile View")
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
    }
}

#Preview {
    MainContentView()
        .environmentObject(AppState())
}
