import SwiftUI
import Foundation
import UIKit

/// The main content view of the app
struct ContentView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    @EnvironmentObject private var appState: AppState

    var body: some View {
        MainTabView()
    }
}

#Preview {
    ContentView()
        .environmentObject(UserViewModel())
        .environmentObject(AppState())
}
