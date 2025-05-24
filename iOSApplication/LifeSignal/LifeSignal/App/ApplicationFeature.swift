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
    @Dependency(\.analytics) var analytics
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
                return .run { send in
                    await analytics.track(.featureUsed(feature: "app_launch", context: [:]))
                }

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

            case .backgroundSyncCompleted(.success(let count)):
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

@main
struct LifeSignalApp: App {
    let store = Store(initialState: ApplicationFeature.State()) {
        ApplicationFeature()
    } withDependencies: { dependencies in
        // Force use of mock implementations for MVP
        dependencies.sessionClient = .mockValue
        dependencies.userRepository = .mockValue
        dependencies.contactRepository = .mockValue
        dependencies.qrCodeGenerator = .mockValue
        dependencies.analytics = .mockValue
        dependencies.logging = .testValue  // Use testValue for better console output
        dependencies.haptics = .mockValue
    }

    init() {
        FirebaseApp.configure()
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

struct AuthenticationView: View {
    @Bindable var store: StoreOf<AuthenticationFeature>
    
    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 30) {
            // App Title
            VStack(spacing: 8) {
                Text("LifeSignal")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Emergency Response Network")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 60)
            
            Spacer()
            
            // Login Form
            VStack(spacing: 20) {
                Text("Please log in to continue")
                    .font(.title2)
                    .multilineTextAlignment(.center)
                
                // Regular authentication buttons would go here
                Button("Sign In") {
                    // TODO: Implement actual authentication
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(true) // Disabled until proper auth is implemented
            }
            
            Spacer()
            
            // Debug Section
            VStack(spacing: 16) {
                Divider()
                
                Text("Debug Mode")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("🚀 Skip to Home Screen") {
                    let debugUser = User(
                        id: UUID(),
                        name: "Debug User",
                        phoneNumber: "+1234567890",
                        phoneRegion: "US",
                        emergencyNote: "",
                        checkInInterval: 86400,
                        lastCheckedIn: Date(),
                        isNotificationsEnabled: true,
                        notify30MinBefore: true,
                        notify2HoursBefore: false,
                        qrCodeId: UUID(),
                        avatarURL: nil,
                        avatarImageData: nil,
                        lastModified: Date()
                    )
                    store.currentUser = debugUser
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.orange)
            }
            .padding(.bottom, 50)
        }
        .padding(.horizontal, 30)
        .background(Color(.systemBackground))
        }
    }
}