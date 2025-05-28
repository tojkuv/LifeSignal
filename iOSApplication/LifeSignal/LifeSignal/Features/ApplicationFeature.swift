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
        // ApplicationFeature has read-only access to session and contacts state only
        @Shared(.sessionInternalState) var sessionState: ReadOnlySessionState
        @Shared(.contacts) var contactsState: ReadOnlyContactsState
        
        // Legacy individual state access for backward compatibility (session-related only)
        // Note: currentUser access removed - use sessionState.hasUserProfile instead
        @Shared(.needsOnboarding) var needsOnboarding: Bool = false
        @Shared(.isNetworkConnected) var isNetworkConnected: Bool = true
        @Shared(.authenticationToken) var authenticationToken: String? = nil

        var isActive: Bool = true
        var error: String? = nil
        
        var mainTabs = MainTabsFeature.State()
        var signIn = SignInFeature.State()
        var onboarding = OnboardingFeature.State()
        // Network connectivity handled via SessionClient
        var notifications = NotificationsHistorySheetFeature.State()

        var isLoggedIn: Bool { sessionState.sessionState.isAuthenticated && sessionState.hasUserProfile }
        var shouldShowOnboarding: Bool { sessionState.sessionState.isAuthenticated && sessionState.needsOnboarding }
        var shouldShowMainTabs: Bool { sessionState.sessionState.isAuthenticated && !sessionState.needsOnboarding && sessionState.hasUserProfile }
        var isLoadingAfterAuth: Bool { 
            sessionState.sessionState == .loading && 
            (sessionState.authenticationToken != nil || sessionState.needsOnboarding || sessionState.hasUserProfile)
        }
        var hasValidSession: Bool { sessionState.sessionState.isAuthenticated && sessionState.authenticationToken != nil && sessionState.hasUserProfile }
        var isOnline: Bool { sessionState.isNetworkConnected }

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
        // Network connectivity handled via SessionClient
        case notifications(NotificationsHistorySheetFeature.Action)
        
        case performBackgroundSync
        case backgroundSyncCompleted(Result<Int, Error>)
        case handleNotificationNavigation(String)
    }

    // ApplicationFeature integrates SessionClient for session management
    // Only SessionClient can use other clients as dependencies
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

        // Network connectivity handled via SessionClient

        Scope(state: \.notifications, action: \.notifications) {
            NotificationsHistorySheetFeature()
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
                        // Handle error silently
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
                let wasConnected = state.sessionState.isNetworkConnected
                return .run { [wasConnected, sessionClient] send in
                    await sessionClient.updateNetworkStatus(isConnected)
                    
                    // Show system notification for connection state changes via SessionClient
                    if wasConnected != isConnected {
                        @Dependency(\.hapticClient) var haptics
                        await haptics.notification(isConnected ? .success : .warning)
                        // SessionClient coordinates with NotificationClient for system notifications
                    }
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

            case .mainTabs, .signIn, .onboarding, .notifications:
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
        dependencies.userClient = .mockValue
        dependencies.contactsClient = .mockValue
        dependencies.haptics = .mockValue
        dependencies.notificationClient = .mockValue
        dependencies.logging = .mockValue
        dependencies.biometricClient = .liveValue  // Use live biometric authentication
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
            } else if store.isLoadingAfterAuth {
                // Show loading state during navigation transition
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.systemGroupedBackground))
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
        .onChange(of: store.shouldShowOnboarding) { wasShowingOnboarding, isShowingOnboarding in
            // If we're transitioning from onboarding to sign-in, reset the sign-in form
            if wasShowingOnboarding && !isShowingOnboarding && !store.shouldShowMainTabs {
                store.send(.signIn(.resetForm))
            }
        }
        .onChange(of: store.shouldShowMainTabs) { wasShowingMainTabs, isShowingMainTabs in
            // If we're transitioning from main tabs to sign-in (sign out), reset the sign-in form
            if wasShowingMainTabs && !isShowingMainTabs && !store.shouldShowOnboarding {
                store.send(.signIn(.resetForm))
            }
        }
        .overlay(alignment: .top) {
            if !store.isOnline {
                HStack(spacing: 6) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 14, weight: .medium))
                    Text("No Internet Connection")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    .regularMaterial,
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .padding(.top, 4)
                .padding(.horizontal, 16)
            }
        }
    }
}

