import ComposableArchitecture
import SwiftUI

@Reducer
public struct MainTabsFeature {
    @ObservableState
    public struct State: Equatable {
        @Shared(.currentUser) var currentUser: User? = nil
        @Shared(.contacts) var contacts: [Contact] = []
        @Shared(.isOnline) var isOnline: Bool = true
        @Shared(.offlineQueue) var offlineQueue: [OfflineAction] = []
        
        var selectedTab: Tab = .home
        var isAlertActive: Bool = false
        var pendingPingsCount: Int = 0
        var nonResponsiveDependentsCount: Int = 0
        
        var home = HomeFeature.State()
        var responders = RespondersFeature.State()
        var checkIn = CheckInFeature.State()
        var dependents = DependentsFeature.State()
        var profile = ProfileFeature.State()
        
        var isLoggedIn: Bool { currentUser != nil }
        var offlineQueueCount: Int { offlineQueue.count }
        var canSync: Bool { isOnline && !offlineQueue.isEmpty }
        
        public enum Tab: Int, CaseIterable {
            case home = 0
            case responders = 1
            case checkIn = 2
            case dependents = 3
            case profile = 4
        }
    }
    
    @CasePathable
    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case tabSelected(State.Tab)
        case updateAlertStatus(Bool)
        case updatePendingPingsCount(Int)
        case updateNonResponsiveDependentsCount(Int)
        case connectivityChanged(Bool)
        case syncOfflineActions
        
        case home(HomeFeature.Action)
        case responders(RespondersFeature.Action)
        case checkIn(CheckInFeature.Action)
        case dependents(DependentsFeature.Action)
        case profile(ProfileFeature.Action)
    }
    
    @Dependency(\.hapticClient) var haptics
    @Dependency(\.connectivity) var connectivity
    @Dependency(\.contactRepository) var contactRepository
    @Dependency(\.analytics) var analytics
    
    public var body: some Reducer<State, Action> {
        BindingReducer()
        
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
        
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case .onAppear:
                return .run { send in
                    await analytics.track(.featureUsed(feature: "main_tabs", context: [:]))
                    
                    // Start connectivity monitoring
                    for await isOnline in connectivity.onlineStatusStream() {
                        await send(.connectivityChanged(isOnline))
                    }
                }
                
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
                
            case let .connectivityChanged(isOnline):
                state.isOnline = isOnline
                if isOnline && !state.offlineQueue.isEmpty {
                    return .send(.syncOfflineActions)
                }
                return .none
                
            case .syncOfflineActions:
                guard state.canSync else { return .none }
                return .run { _ in
                    try await contactRepository.syncOfflineActions()
                }
                
            case .home, .responders, .checkIn, .dependents, .profile:
                return .none
            }
        }
    }
}