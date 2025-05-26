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

        var filteredNotifications: [NotificationItem] {
            if let filter = selectedFilter {
                // Handle grouped filters
                let alertTypes: [NotificationType] = [.sendManualAlertActive, .sendManualAlertInactive, .receiveDependentManualAlertActive, .receiveDependentManualAlertInactive, .receiveNonResponsiveAlert, .receiveNonResponsiveDependentAlert]
                let pingTypes: [NotificationType] = [.receiveResponderPing, .sendDependentPing, .sendResponderPingResponded, .receiveDependentPingResponded, .sendClearAllResponderPings]
                
                if alertTypes.contains(filter) {
                    return allNotifications.filter { alertTypes.contains($0.type) }
                } else if pingTypes.contains(filter) {
                    return allNotifications.filter { pingTypes.contains($0.type) }
                } else {
                    return allNotifications.filter { $0.type == filter }
                }
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
        case setFilter(NotificationType?)
        case dismiss
        case refreshComplete
        case refreshFailed(String)
        case markAsReadResponse(Result<Void, Error>)
    }

    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.hapticClient) var haptics

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

                return .run { send in
                    do {
                        _ = await notificationClient.getNotifications()
                        await send(.refreshComplete)
                    } catch {
                        await send(.refreshFailed(error.localizedDescription))
                    }
                }

            case let .markAsRead(notification):
                guard !notification.isRead else { return .none }

                return .run { send in
                    await haptics.impact(.light)
                    await send(.markAsReadResponse(Result {
                        _ = try await notificationClient.markAsRead(notification.id)
                    }))
                }

            case .markAllAsRead:
                let unreadIds = state.unreadNotifications.map { $0.id }
                guard !unreadIds.isEmpty else { return .none }

                return .run { send in
                    await haptics.notification(.success)
                    _ = try? await notificationClient.markAllAsRead()
                    await send(.refreshComplete)
                }

            case let .setFilter(filter):
                state.selectedFilter = filter
                return .run { _ in
                    await haptics.impact(.light)
                }

            case .dismiss:
                return .none


            case .refreshComplete:
                state.isLoading = false
                return .none

            case let .refreshFailed(error):
                state.isLoading = false
                return .run { _ in
                    try? await notificationClient.sendNotification(
                        NotificationItem(
                            title: "Refresh Failed",
                            message: "Unable to refresh notifications: \(error)",
                            type: .receiveSystemNotification
                        )
                    )
                }

            case .markAsReadResponse(.success):
                return .send(.refreshNotifications)

            case let .markAsReadResponse(.failure(error)):
                return .run { _ in
                    try? await notificationClient.sendNotification(
                        NotificationItem(
                            title: "Mark Read Failed",
                            message: "Unable to mark notification as read: \(error.localizedDescription)",
                            type: .receiveSystemNotification
                        )
                    )
                }
            }
        }
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
                VStack(spacing: 0) {
                    // Filter bar
                    filterPicker()
                    
                    // Notification list
                    notificationsList()
                }
                .navigationTitle("Notifications")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            store.send(.dismiss, animation: .default)
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                        }
                    }
                }
                .navigationBarBackButtonHidden(true)
            }
            .onAppear {
                store.send(.loadNotifications, animation: .default)
            }
        }
    }

    @ViewBuilder
    private func filterPicker() -> some View {
        HStack {
            Text("Filter:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "All", isSelected: store.selectedFilter == nil) {
                        store.send(.setFilter(nil), animation: .default)
                    }
                    
                    FilterChip(title: "Alerts", isSelected: isAlertSelected) {
                        store.send(.setFilter(.sendManualAlertActive), animation: .default)
                    }
                    
                    FilterChip(title: "Pings", isSelected: isPingSelected) {
                        store.send(.setFilter(.receiveResponderPing), animation: .default)
                    }
                    
                    FilterChip(title: "Roles", isSelected: store.selectedFilter == .receiveContactRoleChanged) {
                        store.send(.setFilter(.receiveContactRoleChanged), animation: .default)
                    }
                    
                    FilterChip(title: "Removed", isSelected: store.selectedFilter == .receiveContactRemoved) {
                        store.send(.setFilter(.receiveContactRemoved), animation: .default)
                    }
                    
                    FilterChip(title: "Added", isSelected: store.selectedFilter == .receiveContactAdded) {
                        store.send(.setFilter(.receiveContactAdded), animation: .default)
                    }
                    
                    FilterChip(title: "System", isSelected: store.selectedFilter == .receiveSystemNotification) {
                        store.send(.setFilter(.receiveSystemNotification), animation: .default)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    private var isAlertSelected: Bool {
        if let filter = store.selectedFilter {
            return [.sendManualAlertActive, .sendManualAlertInactive, .receiveDependentManualAlertActive, .receiveDependentManualAlertInactive, .receiveNonResponsiveAlert, .receiveNonResponsiveDependentAlert].contains(filter)
        }
        return false
    }
    
    private var isPingSelected: Bool {
        if let filter = store.selectedFilter {
            return [.receiveResponderPing, .sendDependentPing, .sendResponderPingResponded, .receiveDependentPingResponded, .sendClearAllResponderPings].contains(filter)
        }
        return false
    }

    @ViewBuilder
    private func notificationsList() -> some View {
        if filteredNotifications.isEmpty {
            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "bell.slash")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)

                Text("No notifications")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            List {
                ForEach(filteredNotifications, id: \.id) { notification in
                    NotificationHistoryRow(notification: notification) {
                        store.send(.markAsRead(notification), animation: .default)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Notification History Row

struct NotificationHistoryRow: View {
    let notification: NotificationItem
    let onMarkAsRead: (() -> Void)?
    
    init(notification: NotificationItem, onMarkAsRead: (() -> Void)? = nil) {
        self.notification = notification
        self.onMarkAsRead = onMarkAsRead
    }

    /// Get the color for the notification type
    private var notificationColor: Color {
        switch notification.type {
        case .sendManualAlertActive, .receiveDependentManualAlertActive:
            return .red
        case .receiveNonResponsiveAlert, .receiveNonResponsiveDependentAlert:
            return .orange
        case .receiveResponderPing, .sendDependentPing, .sendResponderPingResponded, .receiveDependentPingResponded, .sendClearAllResponderPings:
            return .blue
        case .receiveContactAdded:
            return .purple
        case .receiveContactRemoved:
            return .pink
        case .receiveContactRoleChanged:
            return .teal
        case .receiveSystemNotification:
            return .indigo
        default:
            return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Notification content
            HStack(alignment: .top, spacing: 12) {
                // Icon with color based on notification type
                Image(systemName: iconForType(notification.type))
                    .foregroundColor(notificationColor)
                    .font(.system(size: 18))
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notification.title)
                            .font(.headline)

                        Spacer()

                        Text(notification.timestamp, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(notification.message)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(8)

            // Divider (will appear between items)
            Divider()
                .padding(.vertical, 4)
        }
        .onTapGesture {
            if !notification.isRead {
                onMarkAsRead?()
            }
        }
    }

    /// Get the icon for the notification type
    /// - Parameter type: The notification type
    /// - Returns: The system image name
    private func iconForType(_ type: NotificationType) -> String {
        switch type {
        case .sendManualAlertActive, .receiveDependentManualAlertActive:
            return "exclamationmark.octagon.fill"
        case .receiveNonResponsiveAlert, .receiveNonResponsiveDependentAlert:
            return "person.badge.clock.fill"
        case .receiveResponderPing, .sendDependentPing, .sendResponderPingResponded, .receiveDependentPingResponded, .sendClearAllResponderPings:
            return "bell.fill"
        case .receiveContactAdded:
            return "person.badge.plus.fill"
        case .receiveContactRemoved:
            return "person.badge.minus.fill"
        case .receiveContactRoleChanged:
            return "person.2.badge.gearshape.fill"
        case .receiveSystemNotification:
            return "gear.fill"
        default:
            return "bell.fill"
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ?
                        Color.blue :
                        Color(UIColor.systemBackground)
                )
                .foregroundColor(
                    isSelected ?
                        .white :
                        .primary
                )
                .cornerRadius(16)
        }
    }
}