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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    NotificationView()
        .environmentObject(UserViewModel())
}
