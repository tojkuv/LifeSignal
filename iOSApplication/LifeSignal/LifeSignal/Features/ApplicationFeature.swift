import ComposableArchitecture
import Foundation
import SwiftUI
import Firebase
import UserNotifications
import Perception
@_exported import Sharing

// Network state is now managed by NetworkClient

// MARK: - Onboarding Data Transfer

struct OnboardingData: Equatable {
    let firstName: String
    let lastName: String
    let emergencyNote: String
    let checkInInterval: TimeInterval
    let reminderMinutesBefore: Int
    let biometricAuthEnabled: Bool
}

enum ApplicationTab: Int, CaseIterable {
    case home = 0
    case responders = 1
    case checkIn = 2
    case dependents = 3
    case profile = 4

    var title: String {
        switch self {
        case .home: return "Home"
        case .responders: return "Responders"
        case .checkIn: return "Check In"
        case .dependents: return "Dependents"
        case .profile: return "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .responders: return "person.2"
        case .checkIn: return "checkmark.circle"
        case .dependents: return "person.3"
        case .profile: return "person.circle"
        }
    }
}

@Reducer
struct ApplicationFeature: FeatureContext { // : FeatureContext (will be enforced by macro in Phase 2)
    @ObservableState
    struct State: Equatable {
        // ApplicationFeature has read-only access to authentication, onboarding and contacts state
        @Shared(.authenticationInternalState) var authState: AuthClientState
        @Shared(.onboardingInternalState) var onboardingState: OnboardingClientState
        @Shared(.contactsInternalState) var contactsState: ContactsClientState
        @Shared(.userInternalState) var userState: UserClientState
        @Shared(.networkInternalState) var networkState: NetworkClientState

        var isActive: Bool = true
        var error: String? = nil
        var isValidatingSession: Bool = false
        var isLoadingUserAfterAuth: Bool = false
        
        // Tab navigation state (integrated from MainTabsFeature)
        var selectedTab: ApplicationTab = .home
        var isAlertActive: Bool = false
        var pendingPingsCount: Int = 0
        var nonResponsiveDependentsCount: Int = 0
        
        // Tab feature states
        var home = HomeFeature.State()
        var responders = RespondersFeature.State()
        var checkIn = CheckInFeature.State()
        var dependents = DependentsFeature.State()
        var profile = ProfileFeature.State()
        
        // Other feature states
        var signIn = SignInFeature.State()
        var onboarding = OnboardingFeature.State()
        var notifications = NotificationsHistorySheetFeature.State()

        var isLoggedIn: Bool { authState.authState.isAuthenticated && userState.currentUser != nil }
        var shouldShowOnboarding: Bool { 
            authState.authState.isAuthenticated && 
            userState.currentUser == nil &&
            !isLoadingUserAfterAuth 
        }
        var shouldShowMainTabs: Bool { authState.authState.isAuthenticated && userState.currentUser != nil }
        var isLoadingAfterAuth: Bool { 
            isValidatingSession || 
            isLoadingUserAfterAuth ||
            (authState.authState == .loading && 
             (authState.authenticationToken != nil || onboardingState.needsOnboarding || onboardingState.hasUserProfile))
        }
        var hasValidSession: Bool { authState.authState.isAuthenticated && authState.authenticationToken != nil && userState.currentUser != nil }
        var isOnline: Bool { networkState.isConnected }
        
        // Computed properties for tab badges
        var alertingContactsCount: Int {
            contactsState.contacts.filter { $0.hasManualAlertActive }.count
        }

        var respondersCount: Int {
            contactsState.contacts.filter { $0.isResponder }.count
        }

        var dependentsCount: Int {
            contactsState.contacts.filter { $0.isDependent }.count
        }

        var activeAlertsCount: Int {
            contactsState.contacts.filter { contact in
                contact.hasManualAlertActive || contact.hasIncomingPing || contact.hasOutgoingPing
            }.count
        }

        init() {}
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
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
        
        // Orchestration actions (moved from features)
        case authenticationCompleted
        case loadUserAfterAuth
        case userLoadedAfterAuth(Result<User?, Error>)
        case onboardingDataCompleted(OnboardingData)
        case createUserProfile(OnboardingData)
        case userProfileCreated(Result<Void, Error>)
        case coordinatedSignOut
        case coordinatedDeleteAccount
        
        // Network monitoring
        case startNetworkMonitoring
        case networkStatusChanged(Bool)
        
        // Tab navigation (integrated from MainTabsFeature)
        case tabSelected(ApplicationTab)
        case updateAlertStatus(Bool)
        case updatePendingPingsCount(Int)
        case updateNonResponsiveDependentsCount(Int)
        case refreshContacts
        case contactsRefreshed(Result<Void, Error>)
        
        // Tab feature actions
        case home(HomeFeature.Action)
        case responders(RespondersFeature.Action)
        case checkIn(CheckInFeature.Action)
        case dependents(DependentsFeature.Action)
        case profile(ProfileFeature.Action)
        
        // Other feature actions
        case signIn(SignInFeature.Action)
        case onboarding(OnboardingFeature.Action)
        case notifications(NotificationsHistorySheetFeature.Action)
        
        case performBackgroundSync
        case backgroundSyncCompleted(Result<Int, Error>)
        case handleNotificationNavigation(String)
    }

    // ApplicationFeature orchestrates session management and tab coordination
    // Enhanced: Uses ReducerContext for architectural validation
    @Dependency(\.authenticationClient) var authenticationClient
    @Dependency(\.onboardingClient) var onboardingClient
    @Dependency(\.userClient) var userClient
    @Dependency(\.contactsClient) var contactsClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.networkClient) var networkClient
    @Dependency(\.hapticClient) var haptics

    init() {}

    var body: some ReducerOf<Self> {
        BindingReducer()
        
        // Tab feature scopes (integrated from MainTabsFeature)
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
        
        Scope(state: \.responders, action: \.responders) {
            RespondersFeature()
        }
        
        Scope(state: \.checkIn, action: \.checkIn) {
            CheckInFeature()
        }
        
        Scope(state: \.dependents, action: \.dependents) {
            DependentsFeature()
        }
        
        Scope(state: \.profile, action: \.profile) {
            ProfileFeature()
        }

        // Other feature scopes
        Scope(state: \.signIn, action: \.signIn) {
            SignInFeature()
        }

        Scope(state: \.onboarding, action: \.onboarding) {
            OnboardingFeature()
        }

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
                    // Always validate session when app becomes active
                    // This ensures we check for token expiry, network changes, etc.
                    await send(.validateExistingSession)
                }

            case .appDidEnterBackground:
                state.isActive = false
                return .none

            case .appWillTerminate:
                return .run { _ in
                    do {
                        try await networkClient.stopNetworkMonitoring()
                    } catch {
                        // Log error but don't block app termination
                        print("Failed to stop network monitoring: \(error)")
                    }
                }

            case .clearError:
                state.error = nil
                return .none

            case .validateExistingSession:
                state.isValidatingSession = true
                state.error = nil
                return .run { [authToken = state.authState.authenticationToken, uid = state.authState.internalAuthUID] send in
                    do {
                        // Step 1: Check if user is authenticated
                        guard authenticationClient.isAuthenticated() else {
                            // No valid authentication state, user needs to sign in
                            await send(.sessionValidationFailed(AuthenticationClientError.sessionExpired))
                            return
                        }
                        
                        // Step 2: Check if token is still valid (not expired)
                        guard authenticationClient.isTokenValid() else {
                            // Token expired, attempt refresh
                            await send(.sessionValidationFailed(AuthenticationClientError.tokenRefreshFailed))
                            return
                        }
                        
                        // Step 3: Verify we have current auth user data
                        guard authenticationClient.getCurrentAuthUser() != nil else {
                            // No auth user data, session invalid
                            await send(.sessionValidationFailed(AuthenticationClientError.sessionExpired))
                            return
                        }
                        
                        // Step 4: Try to load user profile data
                        guard let token = authToken, 
                              let userUid = uid else {
                            await send(.sessionValidationFailed(AuthenticationClientError.sessionExpired))
                            return
                        }
                        
                        let user = try await userClient.getUser(token, userUid)
                        if user != nil {
                            // Session is valid with both auth and user data
                            await send(.sessionValidated)
                        } else {
                            // Auth is valid but no user profile exists - user needs onboarding
                            await send(.sessionValidationFailed(UserClientError.userNotFound))
                        }
                    } catch {
                        // Any error during validation means session is invalid
                        await send(.sessionValidationFailed(error))
                    }
                }

            case .sessionValidated:
                // Session is valid, user is authenticated with valid user data
                state.isValidatingSession = false
                state.error = nil
                return .none

            case .sessionValidationFailed(let error):
                state.isValidatingSession = false
                if let authError = error as? AuthenticationClientError {
                    switch authError {
                    case .tokenRefreshFailed:
                        // Token expired, try to refresh it
                        return .run { send in
                            await send(.refreshSessionToken)
                        }
                    case .sessionExpired:
                        // Session completely invalid, clear and require sign in
                        return .run { send in
                            await send(.sessionExpired)
                        }
                    default:
                        // Other auth errors, clear session
                        return .run { send in
                            await send(.sessionExpired)
                        }
                    }
                } else if let userError = error as? UserClientError {
                    switch userError {
                    case .userNotFound:
                        // Auth is valid but no user profile - check onboarding state
                        if onboardingClient.needsOnboarding() {
                            // User is in onboarding flow
                            return .none
                        } else {
                            // User completed onboarding but no profile exists - start onboarding
                            return .run { send in
                                do {
                                    try await onboardingClient.startOnboarding()
                                } catch {
                                    // If onboarding start fails, sign out
                                    await send(.sessionExpired)
                                }
                            }
                        }
                    default:
                        // Other user errors, sign out
                        return .run { send in
                            await send(.sessionExpired)
                        }
                    }
                } else {
                    // Unknown error, sign out for safety
                    return .run { send in
                        await send(.sessionExpired)
                    }
                }

            case .sessionExpired:
                // Handle session expiration by coordinating clear state across all clients
                return .run { send in
                    do {
                        // Coordinate state clearing across all clients (local state only)
                        try await authenticationClient.clearAuthenticationState()
                        try await userClient.clearUserState()
                        try await onboardingClient.clearOnboardingState()
                        try await contactsClient.clearContactsState()
                        try await notificationClient.clearNotificationState()
                    } catch {
                        // Handle error silently
                    }
                }
                
            case .refreshSessionToken:
                return .run { send in
                    do {
                        try await authenticationClient.refreshToken()
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
                    do {
                        try await networkClient.startNetworkMonitoring()
                    } catch {
                        // Log network monitoring error but don't crash the app
                        print("Failed to start network monitoring: \(error)")
                    }
                }
                
            case .networkStatusChanged(let isConnected):
                let wasConnected = state.networkState.isConnected
                // Network state is now managed by NetworkClient, this action may be deprecated
                
                return .run { [wasConnected] send in
                    // Show system notification for connection state changes
                    if wasConnected != isConnected {
                        @Dependency(\.hapticClient) var haptics
                        await haptics.notification(isConnected ? .success : .warning)
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

            // Tab navigation actions (integrated from MainTabsFeature)
            case .binding:
                return .none

            case let .tabSelected(tab):
                if state.selectedTab != tab {
                    state.selectedTab = tab

                    return .run { _ in
                        await haptics.selection()
                    }
                }
                return .none

            case let .updateAlertStatus(isActive):
                state.isAlertActive = isActive
                return .none

            case let .updatePendingPingsCount(count):
                state.pendingPingsCount = count
                return .none

            case let .updateNonResponsiveDependentsCount(count):
                state.nonResponsiveDependentsCount = count
                return .none

            case .refreshContacts:
                return .run { [contactsClient, authToken = state.authState.authenticationToken, userId = state.userState.currentUser?.id] send in
                    await send(.contactsRefreshed(Result {
                        guard let token = authToken, let userID = userId else {
                            throw ContactsClientError.authenticationRequired
                        }
                        try await contactsClient.refreshContacts(token, userID)
                    }))
                }

            case .contactsRefreshed(.success):
                return .none

            case .contactsRefreshed(.failure):
                return .none

            // Orchestration actions (moved from features)
            case .authenticationCompleted:
                // After authentication completes, load user data
                return .send(.loadUserAfterAuth)
                
            case .loadUserAfterAuth:
                return .run { [authToken = state.authState.authenticationToken, uid = state.authState.internalAuthUID] send in
                    await send(.userLoadedAfterAuth(Result {
                        guard let token = authToken, let userUid = uid else {
                            throw UserClientError.authenticationFailed("Missing authentication credentials")
                        }
                        return try await userClient.getUser(token, userUid)
                    }))
                }
                
            case .userLoadedAfterAuth(.success):
                // User data loaded successfully after auth
                state.isLoadingUserAfterAuth = false
                return .none
                
            case .userLoadedAfterAuth(.failure):
                // Failed to load user data - user is authenticated but has no profile, show onboarding
                state.isLoadingUserAfterAuth = false
                return .none
                
            case let .onboardingDataCompleted(onboardingData):
                // Onboarding completed with data, create user profile
                return .send(.createUserProfile(onboardingData))
                
            case let .createUserProfile(onboardingData):
                return .run { [authToken = state.authState.authenticationToken] send in
                    await send(.userProfileCreated(Result {
                        // Get authenticated user info
                        let authUser = authenticationClient.getCurrentAuthUser()
                        guard let uid = authUser?.uid, let phoneNumber = authUser?.phoneNumber, let token = authToken else {
                            throw UserClientError.authenticationFailed("No authenticated user found")
                        }
                        
                        // Create user profile
                        let fullName = "\(onboardingData.firstName) \(onboardingData.lastName)"
                        try await userClient.createUser(uid, fullName, phoneNumber, "US", token)
                        
                        // Update user profile with onboarding data
                        if var user = try await userClient.getUser(token, uid) {
                            user.emergencyNote = onboardingData.emergencyNote
                            user.checkInInterval = onboardingData.checkInInterval
                            user.biometricAuthEnabled = onboardingData.biometricAuthEnabled
                            // Set notification preference based on reminder minutes
                            switch onboardingData.reminderMinutesBefore {
                            case 0:
                                user.notificationPreference = .disabled
                            case 30:
                                user.notificationPreference = .thirtyMinutes
                            case 120:
                                user.notificationPreference = .twoHours
                            default:
                                user.notificationPreference = .thirtyMinutes
                            }
                            try await userClient.updateUser(user, token)
                        }
                    }))
                }
                
            case .userProfileCreated(.success):
                // User profile created successfully - clear onboarding state
                return .run { send in
                    do {
                        try await onboardingClient.clearOnboardingState()
                    } catch {
                        // Handle error silently - profile was created successfully
                    }
                }
                
            case let .userProfileCreated(.failure(error)):
                // Failed to create user profile
                state.error = error.localizedDescription
                return .none
                
            case .coordinatedSignOut:
                // ApplicationFeature handles sign-out orchestration across all clients
                return .run { [haptics, notificationClient] send in
                    do {
                        // Sign out preserving backend data, then clear other client states
                        try await authenticationClient.signOut()
                        try await userClient.clearUserState()
                        try await onboardingClient.clearOnboardingState()
                        try await contactsClient.clearContactsState()
                        try await notificationClient.clearNotificationState()
                        
                        await haptics.notification(.success)
                        
                        try? await notificationClient.sendSystemNotification(
                            "Signed Out",
                            "You have been successfully signed out of your account."
                        )
                    } catch {
                        await haptics.notification(.error)
                        
                        try? await notificationClient.sendSystemNotification(
                            "Sign Out Issue",
                            "There was an issue signing out, but you have been logged out locally."
                        )
                    }
                }
                
            case .coordinatedDeleteAccount:
                // ApplicationFeature handles account deletion orchestration
                return .run { [haptics, notificationClient] send in
                    do {
                        try await authenticationClient.deleteAccount()
                        await haptics.notification(.success)
                        
                        try? await notificationClient.sendSystemNotification(
                            "Account Deleted",
                            "Your account has been permanently deleted."
                        )
                    } catch {
                        await haptics.notification(.error)
                        
                        try? await notificationClient.sendSystemNotification(
                            "Delete Account Error",
                            "There was an issue deleting your account. Please try again."
                        )
                    }
                }

            // Feature delegation - orchestrate cross-client actions
            case .signIn(.sessionStartResult(.success)):
                // SignIn completed authentication, now load user data
                state.isLoadingUserAfterAuth = true
                return .send(.authenticationCompleted)
                
            case .onboarding(.onboardingCompleted):
                // Onboarding completed, extract data and create user profile
                let onboardingData = OnboardingData(
                    firstName: state.onboarding.firstName,
                    lastName: state.onboarding.lastName,
                    emergencyNote: state.onboarding.emergencyNote,
                    checkInInterval: state.onboarding.checkInInterval,
                    reminderMinutesBefore: state.onboarding.reminderMinutesBefore,
                    biometricAuthEnabled: state.onboarding.biometricAuthEnabled
                )
                return .send(.onboardingDataCompleted(onboardingData))
            
            case .onboarding(.cancelOnboarding):
                // Handle onboarding cancellation - coordinate state clearing across all clients
                return .run { send in
                    do {
                        // Coordinate state clearing across all clients (local state only)
                        try await authenticationClient.clearAuthenticationState()
                        try await userClient.clearUserState()
                        try await onboardingClient.clearOnboardingState()
                        try await contactsClient.clearContactsState()
                        try await notificationClient.clearNotificationState()
                    } catch {
                        // Handle error silently
                    }
                }

            // Profile delegate actions
            case .profile(.delegate(.signOutRequested)):
                return .send(.coordinatedSignOut)
                
            case .profile(.delegate(.deleteAccountRequested)):
                return .send(.coordinatedDeleteAccount)

            case .home, .responders, .checkIn, .dependents, .profile, .signIn, .onboarding, .notifications:
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
        dependencies.authenticationClient = .mockValue
        dependencies.onboardingClient = .mockValue
        dependencies.userClient = .mockValue
        dependencies.contactsClient = .mockValue
        dependencies.hapticClient = .mockValue
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
                IntegratedTabsView(store: store)
            } else if store.shouldShowOnboarding {
                OnboardingView(store: store.scope(
                    state: \.onboarding,
                    action: \.onboarding
                ))
            } else if store.isLoadingAfterAuth {
                // Show loading state during session validation or navigation transition
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(store.isValidatingSession ? "Validating session..." : "Loading...")
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

// MARK: - Integrated Tabs View (replaces MainTabsView)

struct IntegratedTabsView: View {
    @Bindable var store: StoreOf<ApplicationFeature>

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
                NavigationStack {
                    HomeView(store: store.scope(
                        state: \.home,
                        action: \.home
                    ))
                    .navigationTitle("Home")
                    .navigationBarTitleDisplayMode(.large)
                }
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(ApplicationTab.home)

                NavigationStack {
                    RespondersView(store: store.scope(
                        state: \.responders,
                        action: \.responders
                    ))
                    .navigationTitle("Responders")
                    .navigationBarTitleDisplayMode(.large)
                }
                .tabItem {
                    Label("Responders", systemImage: "person.2.fill")
                }
                .badge(store.pendingPingsCount > 0 ? "\(store.pendingPingsCount)" : nil)
                .tag(ApplicationTab.responders)

                NavigationStack {
                    CheckInView(store: store.scope(
                        state: \.checkIn,
                        action: \.checkIn
                    ))
                    .navigationTitle("Check-In")
                    .navigationBarTitleDisplayMode(.large)
                }
                .tabItem {
                    Label("Check-In", systemImage: "iphone")
                }
                .tag(ApplicationTab.checkIn)

                NavigationStack {
                    DependentsView(store: store.scope(
                        state: \.dependents,
                        action: \.dependents
                    ))
                    .navigationTitle("Dependents")
                    .navigationBarTitleDisplayMode(.large)
                }
                .tabItem {
                    Label("Dependents", systemImage: "person.3.fill")
                }
                .badge(store.nonResponsiveDependentsCount > 0 ? "\(store.nonResponsiveDependentsCount)" : nil)
                .tag(ApplicationTab.dependents)

                NavigationStack {
                    ProfileView(store: store.scope(
                        state: \.profile,
                        action: \.profile
                    ))
                    .navigationTitle("Profile")
                    .navigationBarTitleDisplayMode(.large)
                }
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.dashed")
                }
                .tag(ApplicationTab.profile)
            }
        }
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance

            store.send(.refreshContacts)
        }
        .accentColor(.blue)
    }
}

