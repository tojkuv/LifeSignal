import ComposableArchitecture
import Foundation
import Dependencies
import Perception
import SwiftUI
import UserNotifications

// MARK: - Notifications History Sheet Feature

enum NotificationFilterType: String, CaseIterable {
    case alerts = "Alerts"
    case pings = "Pings"  
    case contactUpdates = "Relationships"
    case system = "System"
    
    var notificationTypes: [NotificationType] {
        switch self {
        case .alerts:
            return [.sendManualAlertActive, .sendManualAlertInactive, .receiveDependentManualAlertActive, .receiveDependentManualAlertInactive, .receiveNonResponsiveAlert, .receiveNonResponsiveDependentAlert]
        case .pings:
            return [.receiveResponderPing, .sendDependentPing, .cancelDependentPing, .receiveDependentPingResponded, .sendClearAllResponderPings]
        case .contactUpdates:
            return [.receiveContactAdded, .receiveContactRemoved, .receiveContactRoleChanged]
        case .system:
            return [.receiveSystemNotification, .receiveSystemNotificationSuccess, .receiveSystemNotificationError]
        }
    }
}

@Reducer
struct NotificationsHistorySheetFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.notificationState) var notificationState: ReadOnlyNotificationState
        var selectedFilter: NotificationFilterType = .alerts // Default to Alerts

        var filteredNotifications: [NotificationItem] {
            let filterTypes = selectedFilter.notificationTypes
            return notificationState.notifications.filter { filterTypes.contains($0.type) }
        }

        var sortedNotifications: [NotificationItem] {
            filteredNotifications.sorted { $0.timestamp > $1.timestamp }
        }
    }

    enum Action {
        case loadNotifications
        case setFilter(NotificationFilterType)
    }

    @Dependency(\.hapticClient) var haptics
    @Dependency(\.timeFormattingClient) var timeFormattingClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadNotifications:
                // Notifications are automatically loaded via stream
                return .none

            case let .setFilter(filter):
                state.selectedFilter = filter
                return .run { _ in
                    await haptics.impact(.light)
                }
            }
        }
    }
}

// MARK: - Notifications History Sheet View

struct NotificationsHistorySheetView: View {
    @Bindable var store: StoreOf<NotificationsHistorySheetFeature>

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
                    ForEach(NotificationFilterType.allCases, id: \.self) { filterType in
                        FilterChip(title: filterType.rawValue, isSelected: store.selectedFilter == filterType) {
                            store.send(.setFilter(filterType), animation: .default)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
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
                    NotificationHistoryRow(notification: notification)
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
    @Dependency(\.timeFormattingClient) var timeFormattingClient
    
    init(notification: NotificationItem) {
        self.notification = notification
    }

    /// Get the color for the notification type
    private var notificationColor: Color {
        switch notification.type {
        case .sendManualAlertActive, .sendManualAlertInactive, .receiveDependentManualAlertActive, .receiveDependentManualAlertInactive:
            return .red
        case .receiveNonResponsiveAlert, .receiveNonResponsiveDependentAlert:
            return .orange
        // Ping operations with specific colors per user request
        case .sendDependentPing, .receiveResponderPing, .sendClearAllResponderPings:
            return .blue
        case .cancelDependentPing:
            return .red  // User requested red for canceled ping
        case .receiveDependentPingResponded:
            return .green  // User requested green for dependent responded
        case .receiveContactAdded:
            return .green
        case .receiveContactRemoved:
            return .pink
        case .receiveContactRoleChanged:
            return .blue
        case .receiveSystemNotification:
            return .blue
        case .receiveSystemNotificationSuccess:
            return Color(UIColor.systemGray)
        case .receiveSystemNotificationError:
            return .red
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
                    Text(notification.title)
                        .font(.headline)

                    Text(notification.message)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Spacer()
                        Text(timeFormattingClient.formatLastSeenText(notification.timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)

            // Divider (will appear between items)
            Divider()
                .padding(.vertical, 4)
        }
    }

    /// Get the icon for the notification type
    /// - Parameter type: The notification type
    /// - Returns: The system image name
    private func iconForType(_ type: NotificationType) -> String {
        switch type {
        case .sendManualAlertActive, .sendManualAlertInactive, .receiveDependentManualAlertActive, .receiveDependentManualAlertInactive:
            return "exclamationmark.octagon.fill"
        case .receiveNonResponsiveAlert, .receiveNonResponsiveDependentAlert:
            return "person.badge.clock.fill"
        // Ping operations - bell variations per user specifications
        case .sendDependentPing:
            return "bell.badge.waveform.fill"  // Sent ping to dependent
        case .receiveResponderPing:
            return "bell.badge.fill"  // Received ping from responder
        case .cancelDependentPing:
            return "bell.badge.waveform"  // User requested bell.badge.waveform for canceled ping
        case .receiveDependentPingResponded:
            return "bell.badge.waveform.fill"  // User requested bell.badge.waveform.fill for dependent responded
        case .sendClearAllResponderPings:
            return "bell.badge.slash.fill"  // Cleared all received pings
        case .receiveContactAdded:
            return "person.badge.plus.fill"
        case .receiveContactRemoved:
            return "person.badge.minus.fill"
        case .receiveContactRoleChanged:
            return "person.2.badge.gearshape.fill"
        case .receiveSystemNotification:
            return "info.circle.fill"
        case .receiveSystemNotificationSuccess:
            return "gear.badge.checkmark"
        case .receiveSystemNotificationError:
            return "gear.badge.xmark"
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
                .cornerRadius(12)
        }
    }
}