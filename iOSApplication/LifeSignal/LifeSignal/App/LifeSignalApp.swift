import SwiftUI
import ComposableArchitecture
import Firebase
import UserNotifications

@main
struct LifeSignalApp: App {
    let store = Store(initialState: ApplicationFeature.State()) {
        ApplicationFeature()
    }
    
    init() {
        FirebaseApp.configure()
        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
    var body: some Scene {
        WindowGroup {
            AppRootView(store: store)
        }
    }
}

struct AppRootView: View {
    @Bindable var store: StoreOf<ApplicationFeature>
    
    var body: some View {
        Group {
            if store.isLoggedIn {
                VStack(spacing: 0) {
                    // Connectivity indicator
                    if !store.isOnline {
                        HStack {
                            Image(systemName: "wifi.slash")
                            Text("Offline")
                            if store.offlineQueueCount > 0 {
                                Text("(\(store.offlineQueueCount) pending)")
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.orange)
                        .frame(maxWidth: .infinity)
                    }
                    
                    MainTabsView(store: store.scope(
                        state: \.mainTabs,
                        action: \.mainTabs
                    ))
                }
            } else {
                AuthenticationView(store: store.scope(
                    state: \.authentication,
                    action: \.authentication
                ))
            }
        }
        .sheet(item: $store.scope(state: \.contactDetails, action: \.contactDetails)) { contactStore in
            ContactDetailsSheetView(store: contactStore)
        }
        .sheet(item: $store.scope(state: \.notificationCenter, action: \.notificationCenter)) { notificationStore in
            NotificationCenterView(store: notificationStore)
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}

// MARK: - Notification Delegate
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationDelegate()
    
    private override init() {
        super.init()
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification taps
        completionHandler()
    }
}
