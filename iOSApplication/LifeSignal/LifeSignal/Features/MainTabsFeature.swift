import ComposableArchitecture
import SwiftUI

@Reducer
struct MainTabsFeature: Sendable {
    @ObservableState
    struct State: Equatable {
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

        // Computed properties for tab badges
        var alertingContactsCount: Int {
            contacts.filter { $0.manualAlertActive }.count
        }

        var respondersCount: Int {
            contacts.filter { $0.isResponder }.count
        }

        var dependentsCount: Int {
            contacts.filter { $0.isDependent }.count
        }

        var activeAlertsCount: Int {
            contacts.filter { contact in
                contact.manualAlertActive || contact.hasIncomingPing || contact.hasOutgoingPing
            }.count
        }

        enum Tab: Int, CaseIterable {
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
    }

    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case tabSelected(State.Tab)
        case updateAlertStatus(Bool)
        case updatePendingPingsCount(Int)
        case updateNonResponsiveDependentsCount(Int)
        case refreshContacts
        case contactsRefreshed(Result<[Contact], Error>)

        case home(HomeFeature.Action)
        case responders(RespondersFeature.Action)
        case checkIn(CheckInFeature.Action)
        case dependents(DependentsFeature.Action)
        case profile(ProfileFeature.Action)
    }

    @Dependency(\.hapticClient) var haptics
    @Dependency(\.contactRepository) var contactRepository

    init() {}

    var body: some ReducerOf<Self> {
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

        Reduce<State, Action> { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                return .run { send in
                    // Refresh contacts on app appear
                    await send(.refreshContacts)
                }

            case let .tabSelected(tab):
                if state.selectedTab != tab {
                    let previousTab = state.selectedTab
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
                return .run { [contacts = state.$contacts] send in
                    await send(.contactsRefreshed(Result {
                        let refreshedContacts = try await contactRepository.getContacts()
                        contacts.withLock { $0 = refreshedContacts }
                        return refreshedContacts
                    }))
                }

            case let .contactsRefreshed(.success(contacts)):
                return .none

            case let .contactsRefreshed(.failure(error)):
                return .none

            case .home, .responders, .checkIn, .dependents, .profile:
                return .none
            }
        }
    }
}

struct MainTabsView: View {
    @Bindable var store: StoreOf<MainTabsFeature>

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
                .tag(MainTabsFeature.State.Tab.home)

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
                .tag(MainTabsFeature.State.Tab.responders)

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
                .tag(MainTabsFeature.State.Tab.checkIn)

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
                .tag(MainTabsFeature.State.Tab.dependents)

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
                .tag(MainTabsFeature.State.Tab.profile)
            }
        }
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance

            store.send(.onAppear)
        }
        .accentColor(.blue)
    }
}