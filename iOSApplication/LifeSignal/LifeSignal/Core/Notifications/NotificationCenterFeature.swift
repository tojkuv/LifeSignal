import ComposableArchitecture
import Foundation
import Dependencies
import Perception
import SwiftUI
import UserNotifications

// MARK: - Notification Center Feature

@Reducer
struct NotificationCenterFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.notifications) var allNotifications: [NotificationItem] = []
        @Shared(.unreadNotificationCount) var unreadNotificationCount: Int = 0
        @Shared(.currentUser) var currentUser: User? = nil

        var selectedFilter: NotificationType? = nil
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

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case loadNotifications
        case refreshNotifications
        case markAsRead(NotificationItem)
        case markAllAsRead
        case delete(NotificationItem)
        case clearAll
        case setFilter(NotificationType?)
        case dismiss
        case alert(PresentationAction<Alert>)
        case refreshComplete
        case refreshFailed(String)
        case markAsReadResponse(Result<Void, Error>)
        case deleteResponse(Result<Void, Error>)
        case clearAllResponse(Result<Void, Error>)

        enum Alert: Equatable {
            case confirmClearAll
        }
    }

    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.hapticClient) var haptics
    @Dependency(\.analytics) var analytics

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .loadNotifications:
                return .send(.refreshNotifications)

            case .refreshNotifications:
                state.isLoading = true
                state.errorMessage = nil

                return .run { send in
                    await analytics.track(.featureUsed(feature: "notification_center_refresh", context: [:]))
                    do {
                        _ = try await notificationClient.getNotifications()
                        await send(.refreshComplete)
                    } catch {
                        await send(.refreshFailed(error.localizedDescription))
                    }
                }

            case let .markAsRead(notification):
                guard !notification.isRead else { return .none }

                return .run { send in
                    await haptics.impact(.light)
                    await analytics.track(.featureUsed(feature: "notification_mark_read", context: ["notification_id": notification.id.uuidString]))
                    await send(.markAsReadResponse(Result {
                        try await notificationClient.markAsRead(notification.id)
                    }))
                }

            case .markAllAsRead:
                let unreadIds = state.unreadNotifications.map { $0.id }
                guard !unreadIds.isEmpty else { return .none }

                return .run { send in
                    await haptics.notification(.success)
                    await analytics.track(.featureUsed(feature: "notification_mark_all_read", context: ["count": "\(unreadIds.count)"]))

                    for id in unreadIds {
                        _ = try? await notificationClient.markAsRead(id)
                    }
                    await send(.refreshComplete)
                }

            case let .delete(notification):
                return .run { send in
                    await haptics.impact(.medium)
                    await analytics.track(.featureUsed(feature: "notification_delete", context: ["notification_id": notification.id.uuidString]))
                    await send(.deleteResponse(Result {
                        try await notificationClient.deleteNotification(notification.id)
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
                    TextState("Are you sure you want to clear all notifications? This action cannot be undone.")
                }
                return .none

            case let .setFilter(filter):
                state.selectedFilter = filter
                return .run { _ in
                    await haptics.impact(.light)
                    let filterName = filter?.rawValue ?? "all"
                    await analytics.track(.featureUsed(feature: "notification_filter", context: ["filter": filterName]))
                }

            case .dismiss:
                return .none

            case .alert(.presented(.confirmClearAll)):
                state.isLoading = true

                return .run { send in
                    await haptics.notification(.warning)
                    await analytics.track(.featureUsed(feature: "notification_clear_all", context: [:]))
                    await send(.clearAllResponse(Result {
                        try await notificationClient.clearAll()
                    }))
                }

            case .alert:
                return .none

            case .refreshComplete:
                state.isLoading = false
                state.$unreadNotificationCount.withLock { count in
                    count = state.unreadNotifications.count
                }
                return .none

            case let .refreshFailed(error):
                state.isLoading = false
                state.errorMessage = error
                return .none

            case .markAsReadResponse(.success):
                return .send(.refreshNotifications)

            case let .markAsReadResponse(.failure(error)):
                state.errorMessage = error.localizedDescription
                return .none

            case .deleteResponse(.success):
                return .send(.refreshNotifications)

            case let .deleteResponse(.failure(error)):
                state.errorMessage = error.localizedDescription
                return .none

            case .clearAllResponse(.success):
                state.isLoading = false
                state.$allNotifications.withLock { $0.removeAll() }
                state.$unreadNotificationCount.withLock { $0 = 0 }
                return .none

            case let .clearAllResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none
            }
        }
        .ifLet(\.$confirmationAlert, action: \.alert)
    }
}

// MARK: - Notification Center View

struct NotificationCenterView: View {
    @Bindable var store: StoreOf<NotificationCenterFeature>

    private var filteredNotifications: [NotificationItem] {
        store.sortedNotifications
    }

    var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                VStack {
                    filterPicker
                    notificationsList
                }
                .navigationTitle("Notifications")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") {
                            store.send(.dismiss)
                        }
                    }

                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear All") {
                            store.send(.clearAll)
                        }
                        .disabled(store.allNotifications.isEmpty)
                    }
                }
            }
            .onAppear {
                store.send(.loadNotifications)
            }
            .alert($store.scope(state: \.confirmationAlert, action: \.alert))
        }
    }

    private var filterPicker: some View {
        Picker("Filter", selection: $store.selectedFilter) {
            Text("All").tag(NotificationType?.none)
            ForEach(NotificationType.allCases, id: \.self) { type in
                Text(type.title).tag(type as NotificationType?)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
    }

    private var notificationsList: some View {
        Group {
            if store.isLoading {
                ProgressView("Loading notifications...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredNotifications.isEmpty {
                Text("No notifications")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredNotifications, id: \.id) { notification in
                    NotificationRowView(notification: notification) {
                        store.send(.markAsRead(notification))
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) {
                            store.send(.delete(notification))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Notification Row View

struct NotificationRowView: View {
    let notification: NotificationItem
    let onMarkAsRead: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.headline)
                    .foregroundColor(notification.isRead ? .secondary : .primary)

                Text(notification.message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                Text(notification.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !notification.isRead {
                Button("Mark as Read") {
                    onMarkAsRead()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}