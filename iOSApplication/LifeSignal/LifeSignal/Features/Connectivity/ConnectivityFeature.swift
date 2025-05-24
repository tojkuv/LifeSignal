import ComposableArchitecture
import Foundation

@Reducer
struct ConnectivityFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.isOnline) var isOnline: Bool = true
        @Shared(.offlineQueue) var offlineQueue: [OfflineAction] = []

        var offlineQueueCount: Int { offlineQueue.count }
        var canSync: Bool { isOnline && !offlineQueue.isEmpty }
        var isSyncing: Bool = false
        var syncError: String?
    }

    enum Action {
        case onAppear
        case connectivityChanged(Bool)
        case syncOfflineActions
        case syncCompleted(Result<Void, Error>)
        case dismissSyncError
    }

    @Dependency(\.connectivity) var connectivity
    @Dependency(\.contactRepository) var contactRepository
    @Dependency(\.analytics) var analytics
    @Dependency(\.hapticClient) var haptics

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    await analytics.track(.featureUsed(feature: "connectivity_monitor_started", context: [:]))
                    for await isOnline in connectivity.onlineStatusStream() {
                        await send(.connectivityChanged(isOnline))
                    }
                }

            case let .connectivityChanged(isOnline):
                let wasOffline = !state.isOnline
                state.$isOnline.withLock { $0 = isOnline }
                
                return .run { [offlineQueueCount = state.offlineQueueCount] send in
                    if isOnline && wasOffline {
                        await analytics.track(.featureUsed(feature: "connectivity_restored", context: [
                            "offline_queue_count": "\(offlineQueueCount)"
                        ]))
                        await haptics.notification(.success)
                        
                        if offlineQueueCount > 0 {
                            await send(.syncOfflineActions)
                        }
                    } else if !isOnline && !wasOffline {
                        await analytics.track(.featureUsed(feature: "connectivity_lost", context: [:]))
                        await haptics.notification(.warning)
                    }
                }

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
                }

            case let .syncCompleted(.failure(error)):
                state.isSyncing = false
                state.syncError = error.localizedDescription
                
                return .run { send in
                    await analytics.track(.featureUsed(feature: "offline_sync_failed", context: [
                        "error": error.localizedDescription
                    ]))
                    await haptics.notification(.error)
                }
                
            case .dismissSyncError:
                state.syncError = nil
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
