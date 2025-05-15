import SwiftUI

/// A view for the notification feature
struct NotificationView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    @StateObject private var viewModel: NotificationViewModel

    init() {
        // Create the view model with the user view model from the environment
        _viewModel = StateObject(wrappedValue: NotificationViewModel())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Notification settings
                    VStack(spacing: 16) {
                        HStack {
                            Text("Notification Settings")
                                .font(.headline)
                            Spacer()
                        }

                        Toggle("Enable Notifications", isOn: $viewModel.notificationsEnabled)
                            .onChange(of: viewModel.notificationsEnabled) { _, _ in
                                viewModel.toggleNotificationsEnabled()
                            }
                            .disabled(viewModel.isUpdating)

                        if viewModel.notificationsEnabled {
                            Toggle("30-Minute Reminder", isOn: $viewModel.notify30MinBefore)
                                .onChange(of: viewModel.notify30MinBefore) { _, _ in
                                    viewModel.toggle30MinReminder()
                                }
                                .disabled(viewModel.isUpdating)

                            Toggle("2-Hour Reminder", isOn: $viewModel.notify2HoursBefore)
                                .onChange(of: viewModel.notify2HoursBefore) { _, _ in
                                    viewModel.toggle2HourReminder()
                                }
                                .disabled(viewModel.isUpdating)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Notification history
                    VStack(spacing: 16) {
                        HStack {
                            Text("Notification History")
                                .font(.headline)
                            Spacer()
                        }

                        if viewModel.notificationHistory.isEmpty {
                            Text("No notification history")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(viewModel.notificationHistory) { notification in
                                NotificationHistoryRow(notification: notification)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Update the view model with the user view model from the environment
                viewModel.updateUserViewModel(userViewModel)
            }
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
        case .checkInReminder:
            return .green
        case .pingNotification:
            return .blue
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
        case .checkInReminder:
            return "checkmark.circle.fill"
        case .pingNotification:
            return "bell.fill"
        }
    }
}

#Preview {
    NotificationView()
        .environmentObject(UserViewModel())
}
