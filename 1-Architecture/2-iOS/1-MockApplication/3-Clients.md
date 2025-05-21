# Mock Application Clients

## Purpose

This document outlines the client architecture for the iOS Mock Application. While the mock application primarily uses view models for UI demonstration, certain shared services like notifications are implemented as clients.

## Core Principles

### Type Safety

- Define strongly typed client interfaces
- Implement type-safe notification models
- Create typed notification types
- Use enums for notification categories

### Modularity/Composability

- Design clients that can be used by multiple view models
- Implement singleton pattern for global access
- Create composable client operations
- Design modular notification handling

### Testability

- Create predictable client behavior
- Implement deterministic notification delivery
- Design testable client interfaces
- Create test utilities for client verification

## Content Structure

### Notification Client

The notification system is implemented as a client that view models can use:

```swift
// NotificationsClient that view models can use
class NotificationsClient {
    static let shared = NotificationsClient()

    // Different types of notifications
    enum NotificationType {
        case localSilent       // Confirmation of local interactions
        case remoteRegular     // Regular events from backend
        case remoteHighPriority // High priority events from backend
    }

    struct NotificationItem: Identifiable {
        let id: String
        let type: NotificationType
        let title: String
        let message: String
        let timestamp: Date
        var isRead: Bool = false
    }

    // Mock notifications for UI demonstration
    private(set) var notifications: [NotificationItem] = [
        // Silent local notification
        NotificationItem(
            id: "local1",
            type: .localSilent,
            title: "Message Sent",
            message: "Your message was delivered",
            timestamp: Date().addingTimeInterval(-300) // 5 minutes ago
        ),
        // Regular remote notification
        NotificationItem(
            id: "remote1",
            type: .remoteRegular,
            title: "New Comment",
            message: "Jane commented on your post",
            timestamp: Date().addingTimeInterval(-3600) // 1 hour ago
        ),
        // High priority remote notification
        NotificationItem(
            id: "remote2",
            type: .remoteHighPriority,
            title: "Emergency Alert",
            message: "Important security update required",
            timestamp: Date().addingTimeInterval(-7200) // 2 hours ago
        )
    ]

    // Methods for view models to use
    func addLocalNotification(title: String, message: String) {
        let notification = NotificationItem(
            id: UUID().uuidString,
            type: .localSilent,
            title: title,
            message: message,
            timestamp: Date()
        )
        notifications.insert(notification, at: 0)
    }

    func addRemoteNotification(title: String, message: String, highPriority: Bool = false) {
        let notification = NotificationItem(
            id: UUID().uuidString,
            type: highPriority ? .remoteHighPriority : .remoteRegular,
            title: title,
            message: message,
            timestamp: Date()
        )
        notifications.insert(notification, at: 0)
    }

    func markAsRead(id: String) {
        if let index = notifications.firstIndex(where: { $0.id == id }) {
            notifications[index].isRead = true
        }
    }

    func clearAll() {
        notifications.removeAll()
    }

    func getUnreadCount() -> Int {
        return notifications.filter { !$0.isRead }.count
    }
}
```

### Using the Notification Client

View models can use the notification client to add and manage notifications:

```swift
// Example of a view model using the notifications client
class MessageViewModel: ObservableObject {
    @Published var messageText = ""

    func sendMessage() {
        guard !messageText.isEmpty else { return }

        // Send the message (mock implementation)
        print("Sending message: \(messageText)")

        // Add a local notification
        NotificationsClient.shared.addLocalNotification(
            title: "Message Sent",
            message: "Your message was delivered"
        )

        // Clear the message text
        messageText = ""
    }
}

// Example of a notifications view model
class NotificationsViewModel: ObservableObject {
    @Published var notifications: [NotificationsClient.NotificationItem] = []

    init() {
        // Get notifications from the client
        notifications = NotificationsClient.shared.notifications
    }

    func markAsRead(id: String) {
        NotificationsClient.shared.markAsRead(id: id)
        // Update the local copy
        if let index = notifications.firstIndex(where: { $0.id == id }) {
            notifications[index].isRead = true
        }
    }

    func clearAll() {
        NotificationsClient.shared.clearAll()
        notifications = []
    }
}
```

### Notification Types

The notification system supports three types of notifications:

1. **Silent Local Notifications**: For confirmation of local interactions
   - Message sent confirmations
   - Item saved confirmations
   - Local action completions

2. **Regular Remote Notifications**: For regular events from the backend
   - New messages
   - Friend requests
   - Comment notifications
   - Like notifications

3. **High Priority Remote Notifications**: For important events requiring immediate attention
   - Security alerts
   - Critical updates
   - Account security notifications
   - Payment issues

## Error Handling

### Error Simulation Strategy

While error handling is not implemented in mock clients, we can simulate error states for UI testing:

- **Network Errors**: Simulate connection failures and timeouts
- **Authentication Errors**: Simulate token expiration and invalid credentials
- **Server Errors**: Simulate server-side failures
- **Data Errors**: Simulate malformed or missing data

### Error State Simulation

```swift
// Example: Notification client with error simulation
class NotificationsClient {
    static let shared = NotificationsClient()

    // Different types of notifications
    enum NotificationType {
        case localSilent       // Confirmation of local interactions
        case remoteRegular     // Regular events from backend
        case remoteHighPriority // High priority events from backend
    }

    // Error simulation types
    enum SimulatedError: Equatable {
        case network(message: String)
        case authentication(message: String)
        case server(message: String)
        case data(message: String)

        var message: String {
            switch self {
            case .network(let message): return message
            case .authentication(let message): return message
            case .server(let message): return message
            case .data(let message): return message
            }
        }
    }

    // Flag to simulate errors
    private(set) var simulatedError: SimulatedError? = nil

    // Methods to simulate different error conditions
    func simulateNetworkError(message: String = "Could not connect to notification server") {
        simulatedError = .network(message: message)
    }

    func simulateAuthenticationError(message: String = "Authentication token expired") {
        simulatedError = .authentication(message: message)
    }

    func simulateServerError(message: String = "Server error occurred") {
        simulatedError = .server(message: message)
    }

    func simulateDataError(message: String = "Invalid notification data received") {
        simulatedError = .data(message: message)
    }

    func resetError() {
        simulatedError = nil
    }

    // Rest of the client implementation...
}
```

### Guidelines for Error Simulation

- Create methods to simulate different error conditions
- Use enums to represent different error types
- Provide meaningful error messages for UI display
- Keep error simulation separate from normal client functionality
- Do not implement actual error handling logic

## Testing

### Unit Testing Strategy

Implement a comprehensive testing strategy for clients:

1. **Functionality Testing**: Verify all client methods work correctly
2. **State Management Testing**: Test client state changes
3. **Error Simulation Testing**: Verify error simulation works correctly
4. **Integration Testing**: Test client usage in view models

### Unit Testing Implementation

```swift
import XCTest
@testable import MockApplication

class NotificationsClientTests: XCTestCase {
    var client: NotificationsClient!

    override func setUp() {
        super.setUp()
        client = NotificationsClient.shared
        client.clearAll() // Start with a clean state
    }

    func testAddLocalNotification() {
        // Initial state
        let initialCount = client.notifications.count

        // Add notification
        client.addLocalNotification(title: "Test Title", message: "Test Message")

        // Verify notification was added
        XCTAssertEqual(client.notifications.count, initialCount + 1)
        XCTAssertEqual(client.notifications[0].title, "Test Title")
        XCTAssertEqual(client.notifications[0].message, "Test Message")
        XCTAssertEqual(client.notifications[0].type, .localSilent)
    }

    func testAddRemoteNotification() {
        // Add regular notification
        client.addRemoteNotification(title: "Regular", message: "Regular message")
        XCTAssertEqual(client.notifications[0].type, .remoteRegular)

        // Add high priority notification
        client.addRemoteNotification(title: "Priority", message: "Priority message", highPriority: true)
        XCTAssertEqual(client.notifications[0].type, .remoteHighPriority)
    }

    func testMarkAsRead() {
        // Add notification
        client.addLocalNotification(title: "Test", message: "Test")
        let id = client.notifications[0].id

        // Verify initial state
        XCTAssertFalse(client.notifications[0].isRead)

        // Mark as read
        client.markAsRead(id: id)

        // Verify state changed
        XCTAssertTrue(client.notifications[0].isRead)
    }

    func testClearAll() {
        // Add notifications
        client.addLocalNotification(title: "Test1", message: "Test1")
        client.addLocalNotification(title: "Test2", message: "Test2")

        // Verify notifications exist
        XCTAssertFalse(client.notifications.isEmpty)

        // Clear all
        client.clearAll()

        // Verify all notifications removed
        XCTAssertTrue(client.notifications.isEmpty)
    }

    func testGetUnreadCount() {
        // Add notifications
        client.addLocalNotification(title: "Test1", message: "Test1")
        client.addLocalNotification(title: "Test2", message: "Test2")

        // Verify unread count
        XCTAssertEqual(client.getUnreadCount(), 2)

        // Mark one as read
        client.markAsRead(id: client.notifications[0].id)

        // Verify updated unread count
        XCTAssertEqual(client.getUnreadCount(), 1)
    }

    func testErrorSimulation() {
        // Initial state
        XCTAssertNil(client.simulatedError)

        // Simulate network error
        client.simulateNetworkError()
        XCTAssertNotNil(client.simulatedError)
        XCTAssertEqual(client.simulatedError?.message, "Could not connect to notification server")

        // Reset error
        client.resetError()
        XCTAssertNil(client.simulatedError)

        // Simulate authentication error
        client.simulateAuthenticationError(message: "Custom auth error")
        XCTAssertEqual(client.simulatedError?.message, "Custom auth error")
    }
}
```

### Integration Testing

```swift
import XCTest
@testable import MockApplication

class NotificationsViewModelTests: XCTestCase {
    var viewModel: NotificationsViewModel!
    var client: NotificationsClient!

    override func setUp() {
        super.setUp()
        client = NotificationsClient.shared
        client.clearAll() // Start with a clean state

        // Add test notifications
        client.addLocalNotification(title: "Test1", message: "Test1")
        client.addRemoteNotification(title: "Test2", message: "Test2")

        // Initialize view model
        viewModel = NotificationsViewModel()
    }

    func testInitialization() {
        // Verify view model has notifications from client
        XCTAssertEqual(viewModel.notifications.count, 2)
        XCTAssertEqual(viewModel.notifications[0].title, "Test2")
        XCTAssertEqual(viewModel.notifications[1].title, "Test1")
    }

    func testMarkAsRead() {
        // Get notification ID
        let id = viewModel.notifications[0].id

        // Mark as read in view model
        viewModel.markAsRead(id: id)

        // Verify both view model and client updated
        XCTAssertTrue(viewModel.notifications[0].isRead)
        XCTAssertTrue(client.notifications[0].isRead)
    }

    func testClearAll() {
        // Clear all notifications
        viewModel.clearAll()

        // Verify both view model and client updated
        XCTAssertTrue(viewModel.notifications.isEmpty)
        XCTAssertTrue(client.notifications.isEmpty)
    }
}
```

## Best Practices

* Use the shared notification client for all notification operations
* Create appropriate notification types based on the event
* Keep notification messages concise and informative
* Use high priority notifications sparingly
* Implement proper notification management
* Document notification types and their purposes
* Ensure view models update their state when notifications change
* Use consistent naming conventions across clients
* Keep clients focused on their specific responsibility
* Document client interfaces thoroughly

## Anti-patterns

* Creating multiple notification systems
* Using notifications for non-user-facing events
* Overusing high priority notifications
* Not clearing or managing notifications
* Creating notifications with unclear messages
* Tightly coupling notification logic with view models
* Not providing visual differentiation between notification types
* Implementing business logic in clients
* Creating dependencies between clients
* Using clients for state management