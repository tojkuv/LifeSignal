import SwiftUI
import ComposableArchitecture
import Firebase

@main
struct LifeSignalApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ApplicationView(
                store: Store(initialState: ApplicationFeature.State()) {
                    ApplicationFeature()
                }
            )
        }
    }
}