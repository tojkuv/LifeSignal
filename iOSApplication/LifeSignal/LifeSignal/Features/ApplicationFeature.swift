import ComposableArchitecture
import Foundation
import SwiftUI
import Firebase
import UserNotifications
import Perception
@_exported import Sharing

@Reducer
struct ApplicationFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.currentUser) var currentUser: User? = nil
        @Shared(.sessionState) var sessionState: SessionState = .unauthenticated
        @Shared(.needsOnboarding) var needsOnboarding: Bool = false
        @Shared(.contacts) var contacts: [Contact] = []
        @Shared(.isNetworkConnected) var isNetworkConnected: Bool = true
        @Shared(.offlineQueue) var offlineQueue: [OfflineAction] = []
        @Shared(.authenticationToken) var authenticationToken: String? = nil

        var isActive: Bool = true
        var error: String? = nil
        
        var mainTabs = MainTabsFeature.State()
        var signIn = SignInFeature.State()
        var onboarding = OnboardingFeature.State()
        var connectivity = ConnectivityFeature.State()
        var notifications = NotificationCenterFeature.State()

        var isLoggedIn: Bool { sessionState.isAuthenticated && currentUser != nil }
        var shouldShowOnboarding: Bool { sessionState.isAuthenticated && needsOnboarding }
        var shouldShowMainTabs: Bool { sessionState.isAuthenticated && !needsOnboarding && currentUser != nil }
        var offlineQueueCount: Int { offlineQueue.count }
        var hasValidSession: Bool { sessionState.isAuthenticated && authenticationToken != nil && currentUser != nil }
        var isOnline: Bool { isNetworkConnected }

        init() {}
    }

    enum Action {
        case onAppear
        case appDidBecomeActive
        case appDidEnterBackground
        case appWillTerminate
        case clearError
        
        // Session management
        case validateExistingSession
        case sessionValidated
        case sessionValidationFailed(Error)
        case sessionExpired
        case refreshSessionToken
        case tokenRefreshed
        case tokenRefreshFailed(Error)
        
        // Network monitoring
        case startNetworkMonitoring
        case networkStatusChanged(Bool)
        
        case mainTabs(MainTabsFeature.Action)
        case signIn(SignInFeature.Action)
        case onboarding(OnboardingFeature.Action)
        case connectivity(ConnectivityFeature.Action)
        case notifications(NotificationCenterFeature.Action)
        
        case performBackgroundSync
        case backgroundSyncCompleted(Result<Int, Error>)
        case handleNotificationNavigation(String)
    }

    @Dependency(\.userRepository) var userRepository
    @Dependency(\.offlineQueue) var offlineQueue
    @Dependency(\.sessionClient) var sessionClient

    init() {}

    var body: some ReducerOf<Self> {
        Scope(state: \.mainTabs, action: \.mainTabs) {
            MainTabsFeature()
        }

        Scope(state: \.signIn, action: \.signIn) {
            SignInFeature()
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
                return .run { send in
                    await send(.startNetworkMonitoring)
                    await send(.validateExistingSession)
                }

            case .appDidBecomeActive:
                state.isActive = true
                return .run { send in
                    // Validate session if we have one
                    if sessionClient.isAuthenticated() {
                        await send(.validateExistingSession)
                    }
                }

            case .appDidEnterBackground:
                state.isActive = false
                return .none

            case .appWillTerminate:
                return .none

            case .clearError:
                state.error = nil
                return .none

            case .validateExistingSession:
                return .run { send in
                    do {
                        try await sessionClient.validateExistingSession()
                        await send(.sessionValidated)
                    } catch {
                        await send(.sessionValidationFailed(error))
                    }
                }

            case .sessionValidated:
                // Session is valid, user is authenticated with valid user data
                return .none

            case .sessionValidationFailed(let error):
                if let sessionError = error as? SessionClientError {
                    switch sessionError {
                    case .sessionExpired, .tokenRefreshFailed:
                        return .run { send in
                            await send(.refreshSessionToken)
                        }
                    case .userLoadFailed:
                        return .run { send in
                            await send(.sessionExpired)
                        }
                    default:
                        state.error = error.localizedDescription
                        return .none
                    }
                } else {
                    state.error = error.localizedDescription
                    return .none
                }

            case .sessionExpired:
                // Handle session expiration by ending session
                return .run { send in
                    do {
                        try await sessionClient.endSession()
                    } catch {
                        // Log error but continue with cleanup
                    }
                }
                
            case .refreshSessionToken:
                return .run { send in
                    do {
                        try await sessionClient.refreshToken()
                        await send(.tokenRefreshed)
                    } catch {
                        await send(.tokenRefreshFailed(error))
                    }
                }
                
            case .tokenRefreshed:
                // Token successfully refreshed, session remains valid
                return .none
                
            case .tokenRefreshFailed(let error):
                state.error = error.localizedDescription
                return .run { send in
                    await send(.sessionExpired)
                }
                
            case .startNetworkMonitoring:
                return .run { send in
                    // Start monitoring network connectivity changes
                    for await isConnected in await sessionClient.monitorConnectivity() {
                        await send(.networkStatusChanged(isConnected))
                    }
                }
                
            case .networkStatusChanged(let isConnected):
                return .run { send in
                    await sessionClient.updateNetworkStatus(isConnected)
                }

            case .performBackgroundSync:
                return .none

            case .backgroundSyncCompleted(.success( _)):
                return .none

            case .backgroundSyncCompleted(.failure(let error)):
                state.error = error.localizedDescription
                return .none

            case .handleNotificationNavigation:
                return .none

            case .mainTabs, .signIn, .onboarding, .connectivity, .notifications:
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
        // Use mock implementations for MVP
        dependencies.sessionClient = .mockValue
        dependencies.userRepository = .mockValue
        dependencies.contactRepository = .mockValue
        dependencies.haptics = .mockValue
        dependencies.userClient = .mockValue
        dependencies.notificationClient = .mockValue
        dependencies.contactsClient = .mockValue
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
            if store.shouldShowMainTabs {
                MainTabsView(store: store.scope(
                    state: \.mainTabs,
                    action: \.mainTabs
                ))
            } else if store.shouldShowOnboarding {
                OnboardingView(store: store.scope(
                    state: \.onboarding,
                    action: \.onboarding
                ))
            } else {
                SignInView(store: store.scope(
                    state: \.signIn,
                    action: \.signIn
                ))
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .overlay(alignment: .top) {
            if !store.isOnline {
                HStack {
                    Image(systemName: "wifi.slash")
                    Text("No Internet Connection")
                    if store.offlineQueueCount > 0 {
                        Text("(\(store.offlineQueueCount) pending)")
                            .opacity(0.8)
                    }
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.red)
                .cornerRadius(8)
                .padding(.top)
            }
        }
    }
}

