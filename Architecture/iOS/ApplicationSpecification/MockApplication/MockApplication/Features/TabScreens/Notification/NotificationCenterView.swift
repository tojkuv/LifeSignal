import SwiftUI

/// A view for the unified notification center
struct NotificationCenterView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    @StateObject private var viewModel = NotificationCenterViewModel()
    @State private var selectedFilter: NotificationType? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                HStack {
                    Text("Filter:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            filterButton(for: nil, label: "All")

                            // Use the three existing notification types
                            filterButton(for: .checkInReminder, label: "Check-in")
                            filterButton(for: .manualAlert, label: "Alerts")
                            filterButton(for: .pingNotification, label: "Pings")
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemBackground))

                // Notification list
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
                        ForEach(filteredNotifications) { notification in
                            NotificationHistoryRow(notification: notification)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                        .onDelete { indexSet in
                            deleteNotifications(at: indexSet)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            // Removed Clear All button as requested
            .onAppear {
                viewModel.loadNotifications()
            }
        }
    }

    /// Filtered notifications based on the selected filter
    private var filteredNotifications: [NotificationEvent] {
        guard let filter = selectedFilter else {
            return viewModel.notificationHistory
        }

        return viewModel.notificationHistory.filter { $0.type == filter }
    }

    /// Create a filter button for the given type
    /// - Parameters:
    ///   - type: The notification type to filter by (nil for all)
    ///   - label: The button label
    /// - Returns: A button view
    private func filterButton(for type: NotificationType?, label: String) -> some View {
        Button(action: {
            withAnimation {
                selectedFilter = type
            }
        }) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    selectedFilter == type ?
                        Color.blue :
                        Color(UIColor.systemBackground)
                )
                .foregroundColor(
                    selectedFilter == type ?
                        .white :
                        .primary
                )
                .cornerRadius(16)
        }
    }

    /// Delete notifications at the given indices
    /// - Parameter indexSet: The indices to delete
    private func deleteNotifications(at indexSet: IndexSet) {
        // Get the notifications to delete
        let notificationsToDelete = indexSet.map { filteredNotifications[$0] }

        // Delete the notifications
        viewModel.deleteNotifications(notificationsToDelete)
    }
}

#Preview {
    NotificationCenterView()
        .environmentObject(UserViewModel())
}
