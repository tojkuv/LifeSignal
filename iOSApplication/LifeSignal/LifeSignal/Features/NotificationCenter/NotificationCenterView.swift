import SwiftUI
import ComposableArchitecture
import Perception

/// A view for the unified notification center
struct NotificationCenterView: View {
    @Perception.Bindable var store: StoreOf<NotificationCenterFeature>
    
    private var filteredNotifications: [NotificationItem] {
        store.sortedNotifications
    }
    
    var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                VStack {
                    // Filter picker
                    Picker("Filter", selection: $store.selectedFilter) {
                        Text("All").tag(Notification?.none)
                        ForEach(Notification.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type as Notification?)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    // Notifications list
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
                        }
                    }
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
        }
    }
}

/// A row view for displaying individual notifications
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
