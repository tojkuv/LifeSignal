import SwiftUI


/// A view for the unified notification center
struct NotificationCenterView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    @StateObject private var viewModel = NotificationCenterViewModel()
    @State private var selectedFilter: NotificationType? = nil
    @Environment(\.presentationMode) private var presentationMode

    /// Filtered notifications based on the selected filter
    private var filteredNotifications: [NotificationEvent] {
        guard let filter = selectedFilter else {
            return viewModel.notificationHistory
        }

        // Special case for Alerts filter - include both manual alerts and non-responsive notifications
        if filter == .manualAlert {
            return viewModel.notificationHistory.filter { $0.type == .manualAlert || $0.type == .nonResponsive }
        }

        return viewModel.notificationHistory.filter { $0.type == filter }
    }

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
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        HapticFeedback.triggerHaptic()
                        presentationMode.wrappedValue.dismiss()
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

struct NotificationCenterView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationCenterView()
            .environmentObject(UserViewModel())
    }
}
