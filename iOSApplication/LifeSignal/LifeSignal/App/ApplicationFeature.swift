import ComposableArchitecture
import Foundation

/// Application Feature - Global app state management using TCA
@Reducer
struct ApplicationFeature {
    /// Application state conforming to TCA patterns
    @ObservableState
    struct State: Equatable {
        @Shared(.currentUser) var currentUser: User? = nil
        @Shared(.contacts) var contacts: [Contact] = []
        @Shared(.isOnline) var isOnline: Bool = true
        @Shared(.offlineQueue) var offlineQueue: [OfflineAction] = []

        /// Whether the app is in the foreground
        var isActive: Bool = true

        /// Error state
        var error: String? = nil

        /// Presentation states using @Presents for TCA navigation
        @Presents var contactDetails: ContactDetailsSheetFeature.State? = nil
        @Presents var notificationCenter: NotificationCenterFeature.State? = nil

        /// Selected contact ID for presentation
        var selectedContactId: String? = nil
        
        /// Main tabs state
        var mainTabs = MainTabsFeature.State()
        
        /// Authentication state
        var authentication = AuthenticationFeature.State()
        
        /// Onboarding state
        var onboarding = OnboardingFeature.State()
        
        /// Connectivity state
        var connectivity = ConnectivityFeature.State()
        
        var isLoggedIn: Bool { currentUser != nil }
        var offlineQueueCount: Int { offlineQueue.count }

        /// Initialize with default values
        init() {
            self.isActive = true
            self.error = nil
            self.contactDetails = nil
            self.selectedContactId = nil
        }
    }

    /// Application actions representing events that can occur
    @CasePathable
    enum Action {
        /// App lifecycle actions
        case onAppear
        case appDidBecomeActive
        case appDidEnterBackground

        /// Error handling actions
        case setError(String?)
        case clearError

        /// Presentation actions
        case showContactDetails(Contact)
        case hideContactDetails
        case showNotificationCenter
        case hideNotificationCenter
        case contactDetails(PresentationAction<ContactDetailsSheetFeature.Action>)
        case notificationCenter(PresentationAction<NotificationCenterFeature.Action>)
        
        /// Child feature actions
        case mainTabs(MainTabsFeature.Action)
        case authentication(AuthenticationFeature.Action)
        case onboarding(OnboardingFeature.Action)
        case connectivity(ConnectivityFeature.Action)
    }

    @Dependency(\.userRepository) var userRepository
    @Dependency(\.analytics) var analytics

    // Add explicit initializer
    init() {}

    /// Application reducer body implementing business logic
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
        
        Reduce<State, Action> { state, action in
            switch action {
            case .onAppear:
                return .run { [currentUser = state.$currentUser] send in
                    await analytics.track(.featureUsed(feature: "app_launch", context: [:]))
                    
                    if let user = await userRepository.getCurrentUser() {
                        // User is already logged in, update shared state
                        currentUser.withLock { $0 = user }
                    }
                    
                    // Start connectivity monitoring
                    await send(.connectivity(.onAppear))
                }

            case .appDidBecomeActive:
                state.isActive = true
                return .none

            case .appDidEnterBackground:
                state.isActive = false
                return .none

            case let .setError(message):
                state.error = message
                return .none

            case .clearError:
                state.error = nil
                return .none

            case let .showContactDetails(contact):
                state.contactDetails = ContactDetailsSheetFeature.State(contact: contact)
                return .none

            case .hideContactDetails:
                state.contactDetails = nil
                state.selectedContactId = nil
                return .none
                
            case .showNotificationCenter:
                state.notificationCenter = NotificationCenterFeature.State()
                return .none
                
            case .hideNotificationCenter:
                state.notificationCenter = nil
                return .none

            case .contactDetails:
                return .none
                
            case .notificationCenter(.presented(.dismiss)):
                return .send(.hideNotificationCenter)
                
            case .notificationCenter:
                return .none
                
            case .mainTabs, .authentication, .onboarding, .connectivity:
                return .none
            }
        }
        .ifLet(\.$contactDetails, action: \.contactDetails) {
            ContactDetailsSheetFeature()
        }
        .ifLet(\.$notificationCenter, action: \.notificationCenter) {
            NotificationCenterFeature()
        }
    }
}
