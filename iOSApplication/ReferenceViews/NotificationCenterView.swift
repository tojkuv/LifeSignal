import SwiftUI


/// A view for the unified notification center
struct NotificationCenterView: View {
    // Removed userViewModel dependency
    @StateObject private var viewModel = NotificationCenterViewModel()
    // Moved selectedFilter to view model
    @Environment(\.presentationMode) private var presentationMode

    // Moved filteredNotifications to view model

    /// Create a filter button for the given type
    /// - Parameters:
    ///   - type: The notification type to filter by (nil for all)
    ///   - label: The button label
    /// - Returns: A button view
    @ViewBuilder
    private func filterButton(for type: NotificationType?, label: String) -> some View {
        Button(action: {
            HapticFeedback.selectionFeedback()
            withAnimation {
                viewModel.setFilter(type)
            }
        }) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    viewModel.selectedFilter == type ?
                        Color.blue :
                        Color(UIColor.systemBackground)
                )
                .foregroundColor(
                    viewModel.selectedFilter == type ?
                        .white :
                        .primary
                )
                .cornerRadius(16)
        }
    }

    var body: some View {
        NavigationStack {
            // Enable standard swipe-to-dismiss gesture
            VStack(spacing: 0) {
                // Filter bar
                HStack {
                    Text("Filter:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            filterButton(for: nil, label: "All")

                            // Standard notification types
                            filterButton(for: .manualAlert, label: "Alerts")
                            filterButton(for: .pingNotification, label: "Pings")

                            // Contact operations
                            filterButton(for: .contactRoleChanged, label: "Roles")
                            filterButton(for: .contactRemoved, label: "Removed")
                            filterButton(for: .contactAdded, label: "Added")
                            filterButton(for: .checkInReminder, label: "Check-in")
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))

                // Notification list
                if viewModel.filteredNotifications.isEmpty {
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
                        ForEach(viewModel.filteredNotifications) { notification in
                            NotificationHistoryRow(notification: notification)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        viewModel.dismiss {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .onAppear {
                viewModel.loadNotifications()
            }
            .interactiveDismissDisabled(false) // Enable standard swipe-to-dismiss
        }
    }
}

/// A row for displaying a notification history item
struct NotificationHistoryRow: View {
    let notification: NotificationEvent

    /// Get the color for the notification type
    private var notificationColor: Color {
        switch notification.type {
        case .manualAlert:
            return .red
        case .nonResponsive:
            return .orange
        case .checkInReminder:
            return .green
        case .pingNotification:
            return .blue
        case .contactAdded:
            return .purple
        case .contactRemoved:
            return .pink
        case .contactRoleChanged:
            return .teal
        case .qrCodeNotification:
            return .indigo
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

                    Text(notification.body)
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
    }

    /// Get the icon for the notification type
    /// - Parameter type: The notification type
    /// - Returns: The system image name
    private func iconForType(_ type: NotificationType) -> String {
        switch type {
        case .manualAlert:
            return "exclamationmark.octagon.fill"
        case .nonResponsive:
            return "person.badge.clock.fill"
        case .checkInReminder:
            return "checkmark.circle.fill"
        case .pingNotification:
            return "bell.fill"
        case .contactAdded:
            return "person.badge.plus.fill"
        case .contactRemoved:
            return "person.badge.minus.fill"
        case .contactRoleChanged:
            return "person.2.badge.gearshape.fill"
        case .qrCodeNotification:
            return "qrcode.fill"
        }
    }
}