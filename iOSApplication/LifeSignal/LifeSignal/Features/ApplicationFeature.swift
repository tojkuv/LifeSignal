import ComposableArchitecture
import Foundation
import SwiftUI
import Firebase
import UserNotifications
import Perception

@Reducer
struct ApplicationFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.currentUser) var currentUser: User? = nil
        @Shared(.contacts) var contacts: [Contact] = []
        @Shared(.isOnline) var isOnline: Bool = true
        @Shared(.offlineQueue) var offlineQueue: [OfflineAction] = []

        var isActive: Bool = true
        var error: String? = nil
        
        var mainTabs = MainTabsFeature.State()
        var authentication = AuthenticationFeature.State()
        var onboarding = OnboardingFeature.State()
        var connectivity = ConnectivityFeature.State()
        var notifications = NotificationCenterFeature.State()

        var isLoggedIn: Bool { currentUser != nil }
        var offlineQueueCount: Int { offlineQueue.count }

        init() {}
    }

    enum Action {
        case onAppear
        case appDidBecomeActive
        case appDidEnterBackground
        case appWillTerminate
        case clearError
        
        case mainTabs(MainTabsFeature.Action)
        case authentication(AuthenticationFeature.Action)
        case onboarding(OnboardingFeature.Action)
        case connectivity(ConnectivityFeature.Action)
        case notifications(NotificationCenterFeature.Action)
        
        case performBackgroundSync
        case backgroundSyncCompleted(Result<Int, Error>)
        case handleNotificationNavigation(String)
        // case debugSkipToHome
    }

    @Dependency(\.userRepository) var userRepository
    @Dependency(\.offlineQueue) var offlineQueue
    @Dependency(\.sessionClient) var sessionClient

    init() {}

    var body: some ReducerOf<Self> {
        Scope(state: \.mainTabs, action: \.mainTabs) {
            MainTabsFeature()
        }

        Scope(state: \.authentication, action: \.authentication) {
            AuthenticationFeature()
        }

        Scope(state: \.onboarding, action: \.onboarding) {
            OnboardingFeature()
        }

        Scope(state: \.connectivity, action: \.connectivity) {
            ConnectivityFeature()
        }

        Scope(state: \.notifications, action: \.notifications) {
            NotificationCenterFeature()
        }

        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none

            case .appDidBecomeActive:
                state.isActive = true
                return .none

            case .appDidEnterBackground:
                state.isActive = false
                return .none

            case .appWillTerminate:
                return .none

            case .clearError:
                state.error = nil
                return .none

            case .performBackgroundSync:
                return .none

            case .backgroundSyncCompleted(.success( _)):
                return .none

            case .backgroundSyncCompleted(.failure(let error)):
                state.error = error.localizedDescription
                return .none

            case .handleNotificationNavigation:
                return .none

            // case .debugSkipToHome:

            case .mainTabs, .authentication, .onboarding, .connectivity, .notifications:
                return .none
            }
        }
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
    
    // Handle Firebase Messaging registration
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Firebase Messaging will handle this automatically due to swizzling
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }
}

// MARK: - Main App

@main
struct LifeSignalApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    let store = Store(initialState: ApplicationFeature.State()) {
        ApplicationFeature()
    } withDependencies: { dependencies in
        // Force use of mock implementations for MVP
        dependencies.sessionClient = .mockValue
        dependencies.userRepository = .mockValue
        dependencies.contactRepository = .mockValue
        dependencies.haptics = .mockValue
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
                MainTabsView(store: store.scope(
                    state: \.mainTabs,
                    action: \.mainTabs
                ))
            } else {
                AuthenticationView(store: store.scope(
                    state: \.authentication,
                    action: \.authentication
                ))
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}

