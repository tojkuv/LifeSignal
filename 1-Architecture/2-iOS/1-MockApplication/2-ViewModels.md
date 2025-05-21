# Mock Application ViewModels

## Purpose

This document outlines the view model architecture, patterns, and implementation strategies for the iOS Mock Application. View models in the mock application are focused solely on providing data for UI rendering, without any state management, repositories, or network interactions.

## Core Principles

### Type Safety

- Define strongly typed view models
- Implement type-safe data access
- Create typed mock data generators
- Use enums for representing view model states

### Modularity/Composability

- Organize view models by domain
- Implement repository pattern for data access
- Create composable view models
- Design modular data transformations

### Testability

- Create predictable view models for testing
- Implement deterministic data generation
- Design testable view model patterns
- Create test utilities for view model verification

## Content Structure

### Domain Models

#### Model Definitions

Define clear domain models that match production models:

```swift
// Example: User domain model
struct User: Identifiable, Equatable {
    let id: String
    var displayName: String
    var email: String
    var photoURL: URL?
    var createdAt: Date
    var settings: UserSettings

    struct UserSettings: Equatable {
        var notificationsEnabled: Bool
        var darkModeEnabled: Bool
        var privacyLevel: PrivacyLevel
    }

    enum PrivacyLevel: String, Codable, Equatable {
        case public
        case friendsOnly
        case private
    }
}
```

### View Models

#### Basic Structure

Create view models that contain all the mock data needed by their corresponding views. Each view model should create its own mock domain model instances:

```swift
// Example: User profile view model
class UserProfileViewModel: ObservableObject {
    // Create mock data directly in the view model
    @Published var user: User = User(
        id: "user1",
        displayName: "John Doe",
        email: "john@example.com",
        photoURL: URL(string: "https://example.com/john.jpg"),
        createdAt: Date().addingTimeInterval(-86400 * 30), // 30 days ago
        settings: User.UserSettings(
            notificationsEnabled: true,
            darkModeEnabled: false,
            privacyLevel: .public
        )
    )

    // Computed properties for UI display
    var displayNameInitials: String {
        let components = user.displayName.components(separatedBy: " ")
        if components.count > 1,
           let first = components.first?.first,
           let last = components.last?.first {
            return "\(first)\(last)"
        } else if let first = user.displayName.first {
            return String(first)
        }
        return "?"
    }

    var formattedJoinDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "Joined \(formatter.string(from: user.createdAt))"
    }

    // Simple UI interaction methods without actual state management
    func updateProfile(displayName: String) {
        // Just update the local property - no network calls or repositories
        user.displayName = displayName
    }
}
```

### View Model Implementation

#### Self-Contained Mock Data

Each view model should contain its own mock data directly, rather than relying on shared mock data sources:

```swift
// Example: Post list view model with self-contained mock data
class PostListViewModel: ObservableObject {
    // Create mock posts directly in the view model
    @Published var posts: [Post] = [
        Post(
            id: "post1",
            title: "First Post",
            content: "This is the content of the first post.",
            authorId: "user1",
            authorName: "John Doe",
            createdAt: Date().addingTimeInterval(-86400 * 2) // 2 days ago
        ),
        Post(
            id: "post2",
            title: "Second Post",
            content: "This is the content of the second post.",
            authorId: "user2",
            authorName: "Jane Smith",
            createdAt: Date().addingTimeInterval(-86400) // 1 day ago
        ),
        Post(
            id: "post3",
            title: "Third Post",
            content: "This is the content of the third post.",
            authorId: "user1",
            authorName: "John Doe",
            createdAt: Date() // Today
        )
    ]

    // UI interaction methods
    func likePost(id: String) {
        // Just update the UI state, no actual backend interaction
        if let index = posts.firstIndex(where: { $0.id == id }) {
            posts[index].isLiked = true
            posts[index].likeCount += 1
        }
    }
}
```

#### Child View Models

When a view needs to present child views, create child view models directly in the parent:

```swift
// Example: Main tab view model with child view models
class MainTabViewModel: ObservableObject {
    // Create child view models directly
    let homeViewModel = HomeViewModel()
    let profileViewModel = UserProfileViewModel()
    let notificationsViewModel = NotificationsViewModel()

    @Published var selectedTab: Tab = .home

    enum Tab {
        case home
        case profile
        case notifications
    }
}
```

### View Model Types

#### Screen View Models

Each screen in the application should have its own view model:

```swift
// Example: Settings screen view model
class SettingsViewModel: ObservableObject {
    // Mock settings data
    @Published var notificationsEnabled = true
    @Published var darkModeEnabled = false
    @Published var privacyLevel: PrivacyLevel = .public
    @Published var accountEmail = "user@example.com"

    enum PrivacyLevel: String, CaseIterable, Identifiable {
        case public = "Public"
        case friendsOnly = "Friends Only"
        case private = "Private"

        var id: String { self.rawValue }
    }

    // UI interaction methods
    func toggleNotifications() {
        notificationsEnabled.toggle()
    }

    func toggleDarkMode() {
        darkModeEnabled.toggle()
    }

    func setPrivacyLevel(_ level: PrivacyLevel) {
        privacyLevel = level
    }
}
```

#### Component View Models

For complex UI components that need their own data:

```swift
// Example: User card component view model
class UserCardViewModel: ObservableObject {
    // Mock user data for this specific card
    let userId: String = "user1"
    let name: String = "John Doe"
    let avatarURL: URL? = URL(string: "https://example.com/avatar.jpg")
    let isFollowed: Bool = false
    let followerCount: Int = 245

    // UI interaction methods
    func toggleFollow() {
        // Just for UI demonstration, no actual state management
        print("Toggle follow for user: \(userId)")
    }

    func showProfile() {
        // Just for UI demonstration, no actual navigation
        print("Show profile for user: \(userId)")
    }
}
```

#### Notification View Models

View models for handling different notification types:

```swift
// Example: Notifications view model
class NotificationsViewModel: ObservableObject {
    // Different types of notifications for UI demonstration
    @Published var notifications: [NotificationItem] = [
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

    struct NotificationItem: Identifiable {
        let id: String
        let type: NotificationType
        let title: String
        let message: String
        let timestamp: Date
        var isRead: Bool = false
    }

    enum NotificationType {
        case localSilent       // Confirmation of local interactions
        case remoteRegular     // Regular events from backend
        case remoteHighPriority // High priority events from backend
    }

    // UI interaction methods
    func markAsRead(id: String) {
        if let index = notifications.firstIndex(where: { $0.id == id }) {
            notifications[index].isRead = true
        }
    }

    func clearAll() {
        notifications.removeAll()
    }
}
```

## Error Handling

### Error Simulation Strategy

While error handling is not implemented in mock view models, we can simulate error states for UI testing:

- **Network Errors**: Create view models that simulate network failures
- **Data Errors**: Provide incomplete or malformed mock data
- **Authentication Errors**: Simulate unauthorized states
- **Validation Errors**: Create mock data that would fail validation

### Error State Simulation

```swift
// Example: View model factory for error states
class UserProfileViewModelFactory {
    static func standard() -> UserProfileViewModel {
        return UserProfileViewModel(
            user: User(
                id: "user1",
                displayName: "John Doe",
                email: "john@example.com",
                photoURL: URL(string: "https://example.com/john.jpg"),
                createdAt: Date().addingTimeInterval(-86400 * 30),
                settings: User.UserSettings(
                    notificationsEnabled: true,
                    darkModeEnabled: false,
                    privacyLevel: .public
                )
            )
        )
    }

    static func networkError() -> UserProfileViewModel {
        let viewModel = UserProfileViewModel()
        viewModel.simulatedError = .network(message: "Could not connect to server")
        return viewModel
    }

    static func dataNotFound() -> UserProfileViewModel {
        let viewModel = UserProfileViewModel()
        viewModel.simulatedError = .dataNotFound(message: "User profile not found")
        return viewModel
    }

    static func unauthorized() -> UserProfileViewModel {
        let viewModel = UserProfileViewModel()
        viewModel.simulatedError = .unauthorized(message: "You don't have permission to view this profile")
        return viewModel
    }
}

// Example: View model with simulated error state
class UserProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var simulatedError: SimulatedError?

    enum SimulatedError: Equatable {
        case network(message: String)
        case dataNotFound(message: String)
        case unauthorized(message: String)
        case validation(message: String)

        var message: String {
            switch self {
            case .network(let message): return message
            case .dataNotFound(let message): return message
            case .unauthorized(let message): return message
            case .validation(let message): return message
            }
        }
    }

    init(user: User? = nil) {
        self.user = user
    }

    // Other properties and methods...
}
```

### Guidelines for Error Simulation

- Create factory methods to generate view models with different error states
- Use enums to represent different error types
- Provide meaningful error messages for UI display
- Keep error simulation separate from normal view model functionality
- Do not implement actual error handling logic

## Testing

### Unit Testing Strategy

Implement a comprehensive testing strategy for view models:

1. **Data Generation Testing**: Verify mock data is created correctly
2. **Property Testing**: Test all properties and computed values
3. **Method Testing**: Verify all methods function as expected
4. **Configuration Testing**: Test view models with different configurations

### Unit Testing Implementation

```swift
import XCTest
@testable import MockApplication

class UserProfileViewModelTests: XCTestCase {
    func testInitialization() {
        // Test standard initialization
        let viewModel = UserProfileViewModel()
        XCTAssertNotNil(viewModel.user)
        XCTAssertEqual(viewModel.user?.displayName, "John Doe")
        XCTAssertEqual(viewModel.user?.email, "john@example.com")
    }

    func testDisplayNameInitials() {
        // Test computed property
        let viewModel = UserProfileViewModel()
        XCTAssertEqual(viewModel.displayNameInitials, "JD")

        // Test with single name
        viewModel.user?.displayName = "John"
        XCTAssertEqual(viewModel.displayNameInitials, "J")

        // Test with empty name
        viewModel.user?.displayName = ""
        XCTAssertEqual(viewModel.displayNameInitials, "?")
    }

    func testFormattedJoinDate() {
        // Test date formatting
        let viewModel = UserProfileViewModel()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let expectedDate = "Joined \(formatter.string(from: viewModel.user!.createdAt))"
        XCTAssertEqual(viewModel.formattedJoinDate, expectedDate)
    }

    func testUpdateProfile() {
        // Test update method
        let viewModel = UserProfileViewModel()
        viewModel.updateProfile(displayName: "Jane Smith")
        XCTAssertEqual(viewModel.user?.displayName, "Jane Smith")
    }

    func testErrorStates() {
        // Test network error state
        let networkErrorVM = UserProfileViewModelFactory.networkError()
        XCTAssertNotNil(networkErrorVM.simulatedError)
        XCTAssertEqual(networkErrorVM.simulatedError?.message, "Could not connect to server")

        // Test data not found error state
        let notFoundVM = UserProfileViewModelFactory.dataNotFound()
        XCTAssertEqual(notFoundVM.simulatedError?.message, "User profile not found")
    }
}
```

### Testing Error Simulation

- Create tests for each simulated error state
- Verify error messages are correctly generated
- Test UI rendering with different error states
- Ensure error states don't affect normal functionality

## Best Practices

* Create view models that contain all the mock data needed by their corresponding views
* Each view model should create its own mock domain model instances
* Keep view models focused on UI data only, not state management
* Avoid repositories, network conditions, or error handling in view models
* Document view model assumptions and UI interactions
* Keep domain models in sync with production models
* Use descriptive names for view model properties and methods
* Create realistic mock data that represents actual use cases
* Implement computed properties for derived data
* Use consistent naming conventions across view models

## Anti-patterns

* Using repositories or network calls in view models
* Sharing mock data between view models
* Implementing complex state management in mock view models
* Using local state in views instead of view model properties
* Passing state between views instead of using view models
* Implementing error handling or network conditions
* Creating unrealistic mock data
* Hardcoding data throughout the codebase
* Creating dependencies between view models
* Implementing business logic in view models