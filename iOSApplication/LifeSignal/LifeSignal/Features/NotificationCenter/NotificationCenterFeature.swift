import Foundation
import ComposableArchitecture

@Reducer
struct NotificationCenterFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.notifications) var allNotifications: [NotificationItem] = []
        @Shared(.unreadNotificationCount) var unreadCount: Int = 0
        @Shared(.currentUser) var currentUser: User? = nil
        
        var selectedFilter: Notification? = nil
        var isLoading = false
        var errorMessage: String?
        @Presents var confirmationAlert: AlertState<Action.Alert>?
        
        var filteredNotifications: [NotificationItem] {
            if let filter = selectedFilter {
                return allNotifications.filter { $0.type == filter }
            }
            return allNotifications
        }
        
        var sortedNotifications: [NotificationItem] {
            filteredNotifications.sorted { $0.timestamp > $1.timestamp }
        }
        
        var unreadNotifications: [NotificationItem] {
            allNotifications.filter { !$0.isRead }
        }
    }

    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case loadNotifications
        case refreshNotifications
        case markAsRead(NotificationItem)
        case markAllAsRead
        case delete(NotificationItem)
        case clearAll
        case setFilter(Notification?)
        case dismiss
        case confirmationAlert(PresentationAction<Alert>)
        case refreshComplete
        case refreshFailed(String)
        case markAsReadResponse(Result<Void, Error>)
        case deleteResponse(Result<Void, Error>)
        case clearAllResponse(Result<Void, Error>)
        
        enum Alert: Equatable {
            case confirmClearAll
        }
    }

    @Dependency(\.notificationRepository) var notificationRepository
    @Dependency(\.hapticClient) var haptics
    @Dependency(\.analytics) var analytics

    var body: some Reducer<State, Action> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case .loadNotifications:
                return .send(.refreshNotifications)
                
            case .dismiss:
                return .none
                
            case .refreshNotifications:
                guard let currentUser = state.currentUser else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { [state] send in
                    await analytics.track(.featureUsed(feature: "notifications_refresh", context: [:]))
                    do {
                        let notifications = try await notificationRepository.getNotifications()
                        state.$allNotifications.withLock { $0 = notifications }
                        state.$unreadCount.withLock { $0 = notifications.filter { !$0.isRead }.count }
                        await send(.refreshComplete)
                    } catch {
                        await send(.refreshFailed(error.localizedDescription))
                    }
                }
                
            case let .markAsRead(notification):
                guard !notification.isRead else { return .none }
                state.errorMessage = nil
                
                // Optimistically update the UI
                return .run { [state] send in
                    state.$allNotifications.withLock { notifications in
                        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                            notifications[index].isRead = true
                        }
                    }
                    state.$unreadCount.withLock { count in
                        count = max(0, count - 1)
                    }
                    
                    await haptics.impact(.medium)
                    await analytics.track(.featureUsed(feature: "notification_mark_read", context: ["notification_id": notification.id.uuidString]))
                    await send(.markAsReadResponse(Result {
                        try await notificationRepository.markAsRead(notification.id)
                    }))
                }
                
            case .markAllAsRead:
                guard !state.unreadNotifications.isEmpty else { return .none }
                state.errorMessage = nil
                
                let unreadIds = state.unreadNotifications.map { $0.id }
                
                // Optimistically update the UI
                return .run { [state] send in
                    state.$allNotifications.withLock { notifications in
                        for index in notifications.indices {
                            notifications[index].isRead = true
                        }
                    }
                    state.$unreadCount.withLock { $0 = 0 }
                    
                    await haptics.notification(.success)
                    await analytics.track(.featureUsed(feature: "notifications_mark_all_read", context: ["count": "\(unreadIds.count)"]))
                    await send(.markAsReadResponse(Result {
                        for id in unreadIds {
                            try await notificationRepository.markAsRead(id)
                        }
                    }))
                }
                
            case let .delete(notification):
                state.errorMessage = nil
                
                // Optimistically remove from UI
                return .run { [state] send in
                    state.$allNotifications.withLock { notifications in
                        notifications.removeAll { $0.id == notification.id }
                    }
                    if !notification.isRead {
                        state.$unreadCount.withLock { count in
                            count = max(0, count - 1)
                        }
                    }
                    
                    await haptics.notification(.success)
                    await analytics.track(.featureUsed(feature: "notification_delete", context: ["notification_id": notification.id.uuidString]))
                    await send(.deleteResponse(Result {
                        try await notificationRepository.deleteNotification(notification.id)
                    }))
                }
                
            case .clearAll:
                guard !state.allNotifications.isEmpty else { return .none }
                
                state.confirmationAlert = AlertState {
                    TextState("Clear All Notifications")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmClearAll) {
                        TextState("Clear All")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("This will permanently delete all notifications. This action cannot be undone.")
                }
                return .none
                
            case let .setFilter(filter):
                state.selectedFilter = filter
                return .run { _ in
                    await haptics.selection()
                    await analytics.track(.featureUsed(feature: "notifications_filter", context: ["filter": filter?.rawValue ?? "all"]))
                }
                
            case .confirmationAlert(.presented(.confirmClearAll)):
                state.errorMessage = nil
                
                // Optimistically clear all notifications
                return .run { [state] send in
                    state.$allNotifications.withLock { $0.removeAll() }
                    state.$unreadCount.withLock { $0 = 0 }
                    
                    await haptics.notification(.success)
                    await analytics.track(.featureUsed(feature: "notifications_clear_all", context: [:]))
                    await send(.clearAllResponse(Result {
                        try await notificationRepository.clearAll()
                    }))
                }
                
            case .confirmationAlert:
                return .none
                
            case .refreshComplete:
                state.isLoading = false
                return .none
                
            case let .refreshFailed(error):
                state.isLoading = false
                state.errorMessage = error
                return .none
                
            case .markAsReadResponse(.success):
                // UI was already updated optimistically
                return .none
                
            case let .markAsReadResponse(.failure(error)):
                state.errorMessage = error.localizedDescription
                // In production, you might want to revert the optimistic update
                return .none
                
            case .deleteResponse(.success):
                // UI was already updated optimistically
                return .none
                
            case let .deleteResponse(.failure(error)):
                state.errorMessage = error.localizedDescription
                // In production, you might want to revert the optimistic update
                return .none
                
            case .clearAllResponse(.success):
                // UI was already updated optimistically
                return .none
                
            case let .clearAllResponse(.failure(error)):
                state.errorMessage = error.localizedDescription
                // In production, you might want to revert the optimistic update
                return .none
            }
        }
        .ifLet(\.$confirmationAlert, action: \.confirmationAlert)
    }
}
