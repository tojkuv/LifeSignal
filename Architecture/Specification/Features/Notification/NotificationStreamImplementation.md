# Notification Stream Implementation in TCA

## Overview

This document provides a detailed technical guide for implementing the notification stream in The Composable Architecture (TCA) for the LifeSignal app. It covers the infrastructure layer, domain layer, and presentation layer components needed for a robust notification system.

## Infrastructure Layer

### 1. Notification Client Protocol

The notification client protocol defines the interface for interacting with the notification system:

```swift
protocol NotificationClientProtocol: Sendable {
    /// Stream notifications from the server
    func streamNotifications(_ userId: String) -> AsyncStream<[NotificationData]>
    
    /// Get notifications once
    func getNotifications(_ userId: String, limit: Int) async throws -> [NotificationData]
    
    /// Mark a notification as read
    func markAsRead(_ userId: String, notificationId: String) async throws
    
    /// Mark all notifications as read
    func markAllAsRead(_ userId: String) async throws
    
    /// Delete a notification
    func deleteNotification(_ userId: String, notificationId: String) async throws
    
    /// Register for remote notifications
    func registerForRemoteNotifications() async throws
    
    /// Handle device token for push notifications
    func handleDeviceToken(_ deviceToken: Data) async
    
    /// Request notification authorization
    func requestAuthorization() async throws -> Bool
    
    /// Get current authorization status
    func getAuthorizationStatus() async -> UNAuthorizationStatus
    
    /// Stream FCM token updates
    func streamFCMTokenUpdates() -> AsyncStream<String>
    
    /// Stream notification responses (for handling notification taps)
    func streamNotificationResponses() -> AsyncStream<NotificationResponse>
}
```

### 2. Firebase Implementation

The Firebase implementation of the notification client:

```swift
struct FirebaseNotificationClient: NotificationClientProtocol {
    @Dependency(\.typedFirestore) private var typedFirestore
    @Dependency(\.firebaseMessaging) private var firebaseMessaging
    @Dependency(\.userNotificationCenter) private var userNotificationCenter
    
    func streamNotifications(_ userId: String) -> AsyncStream<[NotificationData]> {
        AsyncStream { continuation in
            let path = FirestorePath(path: "notifications/\(userId)/history")
            
            // Create a query that sorts by timestamp descending
            let query = typedFirestore.collection(path)
                .order(by: "timestamp", descending: true)
                .limit(to: 100)
            
            let listener = query.addSnapshotListener { snapshot, error in
                if let error = error {
                    FirebaseLogger.notification.error("Error streaming notifications: \(error.localizedDescription)")
                    continuation.finish()
                    return
                }
                
                guard let snapshot = snapshot else {
                    FirebaseLogger.notification.warning("Empty snapshot when streaming notifications")
                    return
                }
                
                do {
                    let notifications = try snapshot.documents.compactMap { document -> NotificationData? in
                        let data = document.data()
                        
                        // Convert Firestore data to NotificationData
                        return try NotificationData(
                            id: document.documentID,
                            type: NotificationType(rawValue: data["type"] as? String ?? "") ?? .all,
                            title: data["title"] as? String ?? "",
                            message: data["message"] as? String ?? "",
                            timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                            isRead: data["isRead"] as? Bool ?? false,
                            relatedContactID: data["relatedContactID"] as? String,
                            relatedAlertID: data["relatedAlertID"] as? String,
                            relatedPingID: data["relatedPingID"] as? String,
                            // Parse type-specific data if available
                            contactData: parseContactData(from: data),
                            alertData: parseAlertData(from: data),
                            pingData: parsePingData(from: data)
                        )
                    }
                    
                    FirebaseLogger.notification.debug("Streaming \(notifications.count) notifications")
                    continuation.yield(notifications)
                } catch {
                    FirebaseLogger.notification.error("Error parsing notifications: \(error.localizedDescription)")
                }
            }
            
            continuation.onTermination = { _ in
                FirebaseLogger.notification.debug("Terminating notification stream")
                listener.remove()
            }
        }
    }
    
    // Other method implementations...
    
    // Helper methods for parsing type-specific data
    private func parseContactData(from data: [String: Any]) -> ContactData? {
        guard let contactData = data["contactData"] as? [String: Any] else {
            return nil
        }
        
        return ContactData(
            id: contactData["id"] as? String ?? "",
            name: contactData["name"] as? String ?? "",
            role: ContactRole(rawValue: contactData["role"] as? String ?? "") ?? .none,
            action: ContactAction(rawValue: contactData["action"] as? String ?? "") ?? .added
        )
    }
    
    // Similar methods for other type-specific data...
}
```

### 3. Mock Implementation

A mock implementation for testing and development:

```swift
struct MockNotificationClient: NotificationClientProtocol {
    private let userDefaults = UserDefaults.standard
    private let notificationsKey = "mockNotifications"
    
    func streamNotifications(_ userId: String) -> AsyncStream<[NotificationData]> {
        AsyncStream { continuation in
            // Initial value
            Task {
                let notifications = try await getNotifications(userId, limit: 50)
                continuation.yield(notifications)
            }
            
            // Set up notification observer for changes
            let observer = NotificationCenter.default.addObserver(
                forName: NSNotification.Name("NotificationsUpdated"),
                object: nil,
                queue: .main
            ) { _ in
                Task {
                    let notifications = try await getNotifications(userId, limit: 50)
                    continuation.yield(notifications)
                }
            }
            
            continuation.onTermination = { _ in
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    func getNotifications(_ userId: String, limit: Int) async throws -> [NotificationData] {
        // Get notifications from UserDefaults
        guard let data = userDefaults.data(forKey: notificationsKey),
              let notifications = try? JSONDecoder().decode([NotificationData].self, from: data) else {
            return generateMockNotifications()
        }
        
        return notifications.prefix(limit).sorted { $0.timestamp > $1.timestamp }
    }
    
    // Other method implementations...
    
    // Helper method to generate mock notifications
    private func generateMockNotifications() -> [NotificationData] {
        let now = Date()
        
        return [
            NotificationData(
                id: UUID().uuidString,
                type: .alert,
                title: "Emergency Alert",
                message: "John Doe's check-in has expired.",
                timestamp: now.addingTimeInterval(-3600), // 1 hour ago
                isRead: false,
                relatedContactID: "contact1",
                relatedAlertID: "alert1",
                relatedPingID: nil,
                contactData: ContactData(
                    id: "contact1",
                    name: "John Doe",
                    role: .dependent,
                    action: .nonResponsive
                )
            ),
            // More mock notifications...
        ]
    }
}
```

## Domain Layer

### 1. Notification Feature

The notification feature defines the state, actions, and reducer for the notification system:

```swift
@Reducer
struct NotificationFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var notifications: IdentifiedArrayOf<NotificationData> = []
        var selectedFilter: NotificationType = .all
        var showUnreadOnly: Bool = false
        var isLoading: Bool = false
        var error: UserFacingError?
        var unreadCount: Int = 0
        
        var preferences: NotificationPreferencesFeature.State = .init()
        
        var filteredNotifications: IdentifiedArrayOf<NotificationData> {
            var filtered = notifications
            
            // Apply type filter
            if selectedFilter != .all {
                filtered = IdentifiedArray(
                    uniqueElements: filtered.filter { $0.type == selectedFilter }
                )
            }
            
            // Apply read/unread filter
            if showUnreadOnly {
                filtered = IdentifiedArray(
                    uniqueElements: filtered.filter { !$0.isRead }
                )
            }
            
            return filtered
        }
    }
    
    enum Action: Equatable, Sendable {
        // Data loading
        case viewDidAppear
        case loadNotifications
        case notificationsLoaded([NotificationData])
        case notificationsLoadFailed(UserFacingError)
        case notificationsUpdated([NotificationData])
        
        // Filtering
        case setFilter(NotificationType)
        case toggleShowUnreadOnly
        
        // Notification management
        case markAsRead(id: String)
        case markAllAsRead
        case deleteNotification(id: String)
        case notificationActionSucceeded
        case notificationActionFailed(UserFacingError)
        
        // Notification interaction
        case notificationTapped(id: String)
        case notificationResponseReceived(NotificationResponse)
        
        // FCM token
        case updateFCMToken(String)
        case updateFCMTokenSucceeded
        case updateFCMTokenFailed(UserFacingError)
        
        // Preferences
        case preferences(NotificationPreferencesFeature.Action)
        
        // Delegate actions
        case delegate(DelegateAction)
    }
    
    enum DelegateAction: Equatable, Sendable {
        case notificationsUpdated
        case unreadCountChanged(Int)
        case errorOccurred(UserFacingError)
        case navigateToContact(id: String)
        case navigateToAlert(id: String)
        case navigateToPing(id: String)
    }
    
    enum CancelID: Hashable {
        case notificationStream
        case notificationResponseStream
        case fcmTokenStream
    }
    
    @Dependency(\.notificationClient) private var notificationClient
    @Dependency(\.authClient) private var authClient
    @Dependency(\.userClient) private var userClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .viewDidAppear:
                return .merge(
                    .send(.loadNotifications),
                    
                    // Stream notification responses (for handling notification taps)
                    .run { send in
                        for await response in notificationClient.streamNotificationResponses() {
                            await send(.notificationResponseReceived(response))
                        }
                    }
                    .cancellable(id: CancelID.notificationResponseStream)
                )
                
            case .loadNotifications:
                state.isLoading = true
                
                return .run { [authClient, notificationClient] send in
                    do {
                        let userId = try await authClient.currentUserId()
                        
                        // Start streaming notifications
                        for await notifications in notificationClient.streamNotifications(userId) {
                            await send(.notificationsUpdated(notifications))
                        }
                    } catch {
                        let userFacingError = UserFacingError.from(error)
                        await send(.notificationsLoadFailed(userFacingError))
                    }
                }
                .cancellable(id: CancelID.notificationStream)
                
            case let .notificationsLoaded(notifications):
                state.isLoading = false
                state.notifications = IdentifiedArray(uniqueElements: notifications)
                state.unreadCount = notifications.filter { !$0.isRead }.count
                
                return .send(.delegate(.notificationsUpdated))
                
            case let .notificationsLoadFailed(error):
                state.isLoading = false
                state.error = error
                
                return .send(.delegate(.errorOccurred(error)))
                
            case let .notificationsUpdated(notifications):
                state.isLoading = false
                state.notifications = IdentifiedArray(uniqueElements: notifications)
                state.unreadCount = notifications.filter { !$0.isRead }.count
                
                return .merge(
                    .send(.delegate(.notificationsUpdated)),
                    .send(.delegate(.unreadCountChanged(state.unreadCount)))
                )
                
            case let .setFilter(filter):
                state.selectedFilter = filter
                return .none
                
            case .toggleShowUnreadOnly:
                state.showUnreadOnly.toggle()
                return .none
                
            case let .markAsRead(id):
                // Update local state immediately for better UX
                if let index = state.notifications.index(id: id) {
                    state.notifications[index].isRead = true
                }
                
                return .run { [authClient, notificationClient] send in
                    do {
                        let userId = try await authClient.currentUserId()
                        try await notificationClient.markAsRead(userId, notificationId: id)
                        await send(.notificationActionSucceeded)
                    } catch {
                        let userFacingError = UserFacingError.from(error)
                        await send(.notificationActionFailed(userFacingError))
                    }
                }
                
            case .markAllAsRead:
                // Update local state immediately for better UX
                for index in state.notifications.indices {
                    state.notifications[index].isRead = true
                }
                
                return .run { [authClient, notificationClient] send in
                    do {
                        let userId = try await authClient.currentUserId()
                        try await notificationClient.markAllAsRead(userId)
                        await send(.notificationActionSucceeded)
                    } catch {
                        let userFacingError = UserFacingError.from(error)
                        await send(.notificationActionFailed(userFacingError))
                    }
                }
                
            case let .deleteNotification(id):
                // Update local state immediately for better UX
                state.notifications.remove(id: id)
                
                return .run { [authClient, notificationClient] send in
                    do {
                        let userId = try await authClient.currentUserId()
                        try await notificationClient.deleteNotification(userId, notificationId: id)
                        await send(.notificationActionSucceeded)
                    } catch {
                        let userFacingError = UserFacingError.from(error)
                        await send(.notificationActionFailed(userFacingError))
                    }
                }
                
            case .notificationActionSucceeded:
                return .none
                
            case let .notificationActionFailed(error):
                state.error = error
                return .send(.delegate(.errorOccurred(error)))
                
            case let .notificationTapped(id):
                // Mark as read
                if let notification = state.notifications[id: id] {
                    // Navigate based on notification type
                    if let contactId = notification.relatedContactID {
                        return .merge(
                            .send(.markAsRead(id: id)),
                            .send(.delegate(.navigateToContact(id: contactId)))
                        )
                    } else if let alertId = notification.relatedAlertID {
                        return .merge(
                            .send(.markAsRead(id: id)),
                            .send(.delegate(.navigateToAlert(id: alertId)))
                        )
                    } else if let pingId = notification.relatedPingID {
                        return .merge(
                            .send(.markAsRead(id: id)),
                            .send(.delegate(.navigateToPing(id: pingId)))
                        )
                    }
                }
                
                return .send(.markAsRead(id: id))
                
            case let .notificationResponseReceived(response):
                // Handle notification response (when user taps on a push notification)
                if let contactId = response.contactId {
                    return .send(.delegate(.navigateToContact(id: contactId)))
                } else if let alertId = response.alertId {
                    return .send(.delegate(.navigateToAlert(id: alertId)))
                } else if let pingId = response.pingId {
                    return .send(.delegate(.navigateToPing(id: pingId)))
                }
                
                return .none
                
            case let .updateFCMToken(token):
                return .run { [userClient, authClient] send in
                    do {
                        let userId = try await authClient.currentUserId()
                        
                        // Update FCM token in user document
                        let success = try await userClient.updateFCMToken(userId, token: token)
                        
                        if success {
                            await send(.updateFCMTokenSucceeded)
                        } else {
                            throw UserFacingError.operationFailed("Failed to update FCM token")
                        }
                    } catch {
                        let userFacingError = UserFacingError.from(error)
                        await send(.updateFCMTokenFailed(userFacingError))
                    }
                }
                
            case .updateFCMTokenSucceeded:
                return .none
                
            case let .updateFCMTokenFailed(error):
                state.error = error
                return .send(.delegate(.errorOccurred(error)))
                
            case .preferences:
                return .none
                
            case .delegate:
                return .none
            }
        }
        .ifLet(\.preferences, action: \.preferences) {
            NotificationPreferencesFeature()
        }
    }
}
```

### 2. App Feature Integration

The app feature coordinates between different features and initializes the notification streams:

```swift
@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var auth: AuthFeature.State = .init()
        var user: UserFeature.State = .init()
        var contacts: ContactsFeature.State = .init()
        var notification: NotificationFeature.State = .init()
        var selectedTab: Tab = .home
        
        enum Tab: Equatable, Sendable {
            case home
            case contacts
            case settings
        }
    }
    
    enum Action: Equatable, Sendable {
        case appDidLaunch
        case auth(AuthFeature.Action)
        case user(UserFeature.Action)
        case contacts(ContactsFeature.Action)
        case notification(NotificationFeature.Action)
        case tabSelected(State.Tab)
    }
    
    enum CancelID: Hashable {
        case fcmTokenStream
    }
    
    @Dependency(\.notificationClient) private var notificationClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appDidLaunch:
                // Initialize FCM token stream
                return .run { send in
                    for await token in notificationClient.streamFCMTokenUpdates() {
                        await send(.notification(.updateFCMToken(token)))
                    }
                }
                .cancellable(id: CancelID.fcmTokenStream)
                
            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none
                
            case let .notification(.delegate(.navigateToContact(id))):
                // Navigate to contact detail
                state.selectedTab = .contacts
                state.contacts.selectedContactId = id
                return .none
                
            case let .notification(.delegate(.navigateToAlert(id))):
                // Navigate to alert detail
                state.selectedTab = .home
                state.user.selectedAlertId = id
                return .none
                
            case let .notification(.delegate(.navigateToPing(id))):
                // Navigate to ping detail
                state.selectedTab = .contacts
                state.contacts.selectedPingId = id
                return .none
                
            case .auth, .user, .contacts, .notification:
                return .none
            }
        }
        .forEach(\.auth, action: \.auth) {
            AuthFeature()
        }
        .forEach(\.user, action: \.user) {
            UserFeature()
        }
        .forEach(\.contacts, action: \.contacts) {
            ContactsFeature()
        }
        .forEach(\.notification, action: \.notification) {
            NotificationFeature()
        }
    }
}
```

## Presentation Layer

### 1. Notification Center View

The notification center view displays the list of notifications:

```swift
struct NotificationCenterView: View {
    @Bindable var store: StoreOf<NotificationFeature>
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading && store.notifications.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.notifications.isEmpty {
                    ContentUnavailableView(
                        "No Notifications",
                        systemImage: "bell.slash",
                        description: Text("You don't have any notifications yet.")
                    )
                } else {
                    List {
                        ForEach(store.filteredNotifications) { notification in
                            NotificationRow(
                                notification: notification,
                                onTap: {
                                    store.send(.notificationTapped(id: notification.id))
                                }
                            )
                            .swipeActions {
                                Button(role: .destructive) {
                                    store.send(.deleteNotification(id: notification.id))
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                if !notification.isRead {
                                    Button {
                                        store.send(.markAsRead(id: notification.id))
                                    } label: {
                                        Label("Mark as Read", systemImage: "checkmark.circle")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            store.send(.setFilter(.all))
                        } label: {
                            Label("All", systemImage: "tray.full")
                        }
                        
                        Divider()
                        
                        ForEach(NotificationType.allCases.filter { $0 != .all }) { type in
                            Button {
                                store.send(.setFilter(type))
                            } label: {
                                Label(type.rawValue, systemImage: type.iconName)
                            }
                        }
                        
                        Divider()
                        
                        Button {
                            store.send(.toggleShowUnreadOnly)
                        } label: {
                            Label(
                                store.showUnreadOnly ? "Show All" : "Show Unread Only",
                                systemImage: store.showUnreadOnly ? "envelope.open" : "envelope.badge"
                            )
                        }
                        
                        if !store.notifications.isEmpty {
                            Divider()
                            
                            Button {
                                store.send(.markAllAsRead)
                            } label: {
                                Label("Mark All as Read", systemImage: "checkmark.circle")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .onAppear {
                store.send(.viewDidAppear)
            }
        }
    }
}
```

### 2. Notification Row

The notification row displays a single notification:

```swift
struct NotificationRow: View {
    let notification: NotificationData
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Icon based on notification type
                Image(systemName: notification.type.iconName)
                    .font(.title2)
                    .foregroundColor(notification.type.color)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(notification.message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    Text(notification.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.tertiary)
                }
                
                Spacer()
                
                // Unread indicator
                if !notification.isRead {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
```

### 3. Notification Badge

The notification badge displays the unread count:

```swift
struct NotificationBadge: View {
    let count: Int
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "bell.fill")
                .font(.system(size: 24))
            
            if count > 0 {
                Text("\(min(count, 99))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 16, height: 16)
                    .background(Color.red)
                    .clipShape(Circle())
                    .offset(x: 8, y: -8)
            }
        }
    }
}
```

## Dependency Registration

Register the notification client in the dependency system:

```swift
private enum NotificationClientKey: DependencyKey {
    static let liveValue: NotificationClientProtocol = FirebaseNotificationClient()
    static let testValue: NotificationClientProtocol = MockNotificationClient()
    static let previewValue: NotificationClientProtocol = MockNotificationClient()
}

extension DependencyValues {
    var notificationClient: NotificationClientProtocol {
        get { self[NotificationClientKey.self] }
        set { self[NotificationClientKey.self] = newValue }
    }
}
```

## Testing

### 1. Notification Feature Tests

Test the notification feature:

```swift
@MainActor
final class NotificationFeatureTests: XCTestCase {
    func testLoadNotifications() async {
        let store = TestStore(initialState: NotificationFeature.State()) {
            NotificationFeature()
        } withDependencies: {
            $0.notificationClient.streamNotifications = { _ in
                AsyncStream { continuation in
                    continuation.yield([
                        NotificationData(
                            id: "1",
                            type: .alert,
                            title: "Test Alert",
                            message: "Test message",
                            timestamp: Date(),
                            isRead: false,
                            relatedContactID: "contact1",
                            relatedAlertID: nil,
                            relatedPingID: nil
                        )
                    ])
                    continuation.finish()
                }
            }
            $0.authClient.currentUserId = { "user1" }
        }
        
        await store.send(.loadNotifications) {
            $0.isLoading = true
        }
        
        await store.receive(.notificationsUpdated([
            NotificationData(
                id: "1",
                type: .alert,
                title: "Test Alert",
                message: "Test message",
                timestamp: Date(),
                isRead: false,
                relatedContactID: "contact1",
                relatedAlertID: nil,
                relatedPingID: nil
            )
        ])) {
            $0.isLoading = false
            $0.notifications = IdentifiedArray(uniqueElements: [
                NotificationData(
                    id: "1",
                    type: .alert,
                    title: "Test Alert",
                    message: "Test message",
                    timestamp: Date(),
                    isRead: false,
                    relatedContactID: "contact1",
                    relatedAlertID: nil,
                    relatedPingID: nil
                )
            ])
            $0.unreadCount = 1
        }
        
        await store.receive(.delegate(.notificationsUpdated))
        await store.receive(.delegate(.unreadCountChanged(1)))
    }
    
    // More tests...
}
```

### 2. Notification Client Tests

Test the notification client:

```swift
@MainActor
final class FirebaseNotificationClientTests: XCTestCase {
    func testStreamNotifications() async {
        let mockFirestore = MockTypedFirestore()
        
        // Set up mock data
        mockFirestore.mockDocuments = [
            MockDocument(
                id: "1",
                data: [
                    "type": "alert",
                    "title": "Test Alert",
                    "message": "Test message",
                    "timestamp": Timestamp(date: Date()),
                    "isRead": false,
                    "relatedContactID": "contact1"
                ]
            )
        ]
        
        let client = FirebaseNotificationClient()
        
        // Override dependencies
        withDependencies {
            $0.typedFirestore = mockFirestore
        } operation: {
            // Test the stream
            let stream = client.streamNotifications("user1")
            
            var notifications: [NotificationData] = []
            for await batch in stream.prefix(1) {
                notifications = batch
            }
            
            XCTAssertEqual(notifications.count, 1)
            XCTAssertEqual(notifications[0].id, "1")
            XCTAssertEqual(notifications[0].type, .alert)
            XCTAssertEqual(notifications[0].title, "Test Alert")
            XCTAssertEqual(notifications[0].relatedContactID, "contact1")
        }
    }
    
    // More tests...
}
```

## Conclusion

This implementation guide provides a comprehensive approach to implementing the notification stream in TCA. By following this architecture, you can create a robust, testable, and maintainable notification system that integrates seamlessly with the rest of the LifeSignal app.

Key benefits of this approach include:

1. **Clear Separation of Concerns**: The infrastructure layer handles data access, the domain layer manages business logic, and the presentation layer handles UI.

2. **Testability**: Each component can be tested in isolation with mock dependencies.

3. **Composability**: The notification feature can be composed with other features in the app.

4. **Real-Time Updates**: The stream-based approach ensures that notifications are always up-to-date.

5. **Offline Support**: By using Firestore's offline capabilities, notifications can be accessed even when offline.

By implementing this architecture, you'll create a notification system that provides a great user experience while maintaining code quality and testability.
