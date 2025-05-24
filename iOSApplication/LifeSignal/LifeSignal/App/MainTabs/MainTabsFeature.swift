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
        var isSyncing: Bool = false
        var syncError: String?
        
        var home = HomeFeature.State()
        var responders = RespondersFeature.State()
        var checkIn = CheckInFeature.State()
        var dependents = DependentsFeature.State()
        var profile = ProfileFeature.State()
        var connectivity = ConnectivityFeature.State()
        
        var isLoggedIn: Bool { currentUser != nil }
        var offlineQueueCount: Int { offlineQueue.count }
        var canSync: Bool { isOnline && !offlineQueue.isEmpty && !isSyncing }
        
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
        case connectivityChanged(Bool)
        case syncOfflineActions
        case syncCompleted(Result<Void, Error>)
        case dismissSyncError
        case refreshContacts
        case contactsRefreshed(Result<[Contact], Error>)
        
        case home(HomeFeature.Action)
        case responders(RespondersFeature.Action)
        case checkIn(CheckInFeature.Action)
        case dependents(DependentsFeature.Action)
        case profile(ProfileFeature.Action)
        case connectivity(ConnectivityFeature.Action)
    }
    
    @Dependency(\.hapticClient) var haptics
    @Dependency(\.connectivity) var connectivity
    @Dependency(\.contactRepository) var contactRepository
    @Dependency(\.analytics) var analytics
    
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
        
        Scope(state: \.connectivity, action: \.connectivity) {
            ConnectivityFeature()
        }
        
        Reduce<State, Action> { state, action in
            switch action {
            case .binding:
                return .none
                
            case .onAppear:
                return .run { send in
                    await analytics.track(.featureUsed(feature: "main_tabs_appeared", context: [
                        "initial_tab": "home"
                    ]))
                    
                    // Refresh contacts on app appear
                    await send(.refreshContacts)
                }
                
            case let .tabSelected(tab):
                if state.selectedTab != tab {
                    let previousTab = state.selectedTab
                    state.selectedTab = tab
                    
                    return .run { _ in
                        await haptics.selection()
                        await analytics.track(.featureUsed(feature: "tab_selected", context: [
                            "from_tab": previousTab.title.lowercased(),
                            "to_tab": tab.title.lowercased()
                        ]))
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
                let wasOffline = !state.isOnline
                state.$isOnline.withLock { $0 = isOnline }
                
                if isOnline && wasOffline && !state.offlineQueue.isEmpty {
                    return .send(.syncOfflineActions)
                }
                return .none
                
            case .syncOfflineActions:
                guard state.canSync else { return .none }
                
                state.isSyncing = true
                state.syncError = nil
                
                let actionsToSync = state.offlineQueue
                
                return .run { send in
                    await analytics.track(.featureUsed(feature: "offline_sync_started", context: [
                        "actions_count": "\(actionsToSync.count)"
                    ]))
                    
                    await send(.syncCompleted(Result {
                        try await processOfflineActions(actionsToSync)
                    }))
                }
                
            case .syncCompleted(.success):
                state.isSyncing = false
                state.syncError = nil
                state.$offlineQueue.withLock { $0 = [] }
                
                return .run { send in
                    await analytics.track(.featureUsed(feature: "offline_sync_completed", context: [:]))
                    await haptics.notification(.success)
                    // Refresh contacts after successful sync
                    await send(.refreshContacts)
                }
                
            case let .syncCompleted(.failure(error)):
                state.isSyncing = false
                state.syncError = error.localizedDescription
                
                return .run { _ in
                    await analytics.track(.featureUsed(feature: "offline_sync_failed", context: [
                        "error": error.localizedDescription
                    ]))
                    await haptics.notification(.error)
                }
                
            case .dismissSyncError:
                state.syncError = nil
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
                return .run { _ in
                    await analytics.track(.featureUsed(feature: "contacts_refreshed", context: [
                        "count": "\(contacts.count)"
                    ]))
                }
                
            case let .contactsRefreshed(.failure(error)):
                return .run { _ in
                    await analytics.track(.featureUsed(feature: "contacts_refresh_failed", context: [
                        "error": error.localizedDescription
                    ]))
                }
                
            case .home, .responders, .checkIn, .dependents, .profile, .connectivity:
                return .none
            }
        }
    }
    
    // MARK: - Private Methods
    
    @Sendable
    private func processOfflineActions(_ actions: [OfflineAction]) async throws {
        for action in actions {
            try await processOfflineAction(action)
        }
    }
    
    @Sendable
    private func processOfflineAction(_ action: OfflineAction) async throws {
        switch action {
        case let .addContact(phoneNumber, name, isResponder, isDependent):
            var contact = try await contactRepository.addContact(phoneNumber)
            contact.name = name
            contact.isResponder = isResponder
            contact.isDependent = isDependent
            _ = try await contactRepository.updateContact(contact)
            
        case let .updateContactResponder(contactID, isResponder):
            _ = try await contactRepository.updateContactResponder(contactID, isResponder)
            
        case let .updateContactDependent(contactID, isDependent):
            _ = try await contactRepository.updateContactDependent(contactID, isDependent)
            
        case let .updateContactPingStatus(contactID, hasIncoming, hasOutgoing):
            _ = try await contactRepository.updateContactPingStatus(contactID, hasIncoming, hasOutgoing)
            
        case let .updateContactManualAlert(contactID, isActive):
            _ = try await contactRepository.updateContactManualAlert(contactID, isActive)
            
        case let .updateContactCheckIn(contactID, timestamp):
            _ = try await contactRepository.updateContactCheckIn(contactID, timestamp)
            
        case let .updateContactInterval(contactID, interval):
            _ = try await contactRepository.updateContactInterval(contactID, interval)
            
        case let .updateContactNote(contactID, note):
            _ = try await contactRepository.updateContactNote(contactID, note)
            
        case let .updateContactName(contactID, name):
            if let contact = try await contactRepository.getContact(contactID) {
                var updatedContact = contact
                updatedContact.name = name
                _ = try await contactRepository.updateContact(updatedContact)
            }
            
        case let .removeContact(contactID):
            try await contactRepository.removeContact(contactID)
            
        case let .updateUser(user):
            // Handle user update - this would typically go to a UserRepository
            // For now, we'll just skip it or handle it appropriately
            break
            
        case let .sendNotification(type, title, message, contactID):
            // Handle notification sending - this would typically go to a NotificationService
            // For now, we'll just skip it or handle it appropriately
            break
        }
    }
}
