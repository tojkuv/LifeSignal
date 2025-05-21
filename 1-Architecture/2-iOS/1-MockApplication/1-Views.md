# Mock Application Views

## Purpose

This document outlines the view architecture and design system for the iOS Mock Application. Views in the mock application should only use data from their corresponding view models, without any local state or passed state.

## Core Principles

### Type Safety

- Use strongly typed view modifiers
- Implement type-safe theme constants
- Create typed wrappers for UI components
- Use enums for finite UI states

### Modularity/Composability

- Compose complex views from simpler components
- Implement consistent view builder patterns
- Create modular view modifiers

### Testability

- Create preview providers for all components
- Implement snapshot testing for UI verification
- Design components with testability in mind
- Use dependency injection for view dependencies

## Content Structure

### Design System

#### Colors

The design system defines a consistent color palette:

- Primary colors
- Secondary colors
- Accent colors
- Semantic colors (success, warning, error)
- Background colors
- Text colors

#### Spacing

Consistent spacing values are defined:

- XS: 4 points
- S: 8 points
- M: 16 points
- L: 24 points
- XL: 32 points
- XXL: 48 points

Spacing is implemented as constants:

```swift
struct Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}
```

### View Implementation

#### Screen Views

Each screen in the application should have its own view that uses data exclusively from its view model. Break up complex views into computed properties for different sections of the screen:

```swift
struct ProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        VStack(spacing: 16) {
            profileHeaderSection
            actionButtonsSection
        }
    }

    // Break up the view into computed properties for each section
    private var profileHeaderSection: some View {
        VStack {
            profileAvatar

            Text(viewModel.user.displayName)
                .font(.title)
                .fontWeight(.bold)

            Text(viewModel.user.email)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(viewModel.formattedJoinDate)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private var profileAvatar: some View {
        Group {
            if let photoURL = viewModel.user.photoURL {
                AsyncImage(url: photoURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
            } else {
                Text(viewModel.displayNameInitials)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 100, height: 100)
                    .background(Color.accent)
                    .clipShape(Circle())
            }
        }
    }

    private var actionButtonsSection: some View {
        Button("Edit Profile") {
            viewModel.updateProfile(displayName: "Updated Name")
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.accent)
        .foregroundColor(.white)
        .cornerRadius(10)
        .padding(.horizontal)
    }
}
```

#### Component Views

For complex UI components that need their own view model:

```swift
struct UserCardView: View {
    @ObservedObject var viewModel: UserCardViewModel

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                // Avatar
                if let avatarURL = viewModel.avatarURL {
                    AsyncImage(url: avatarURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 50, height: 50)
                }

                // User info
                VStack(alignment: .leading) {
                    Text(viewModel.name)
                        .font(.headline)

                    Text("\(viewModel.followerCount) followers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Follow button
                Button(viewModel.isFollowed ? "Following" : "Follow") {
                    viewModel.toggleFollow()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(viewModel.isFollowed ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(16)
            }
            .padding()
            .background(Color.secondaryBackground)
            .cornerRadius(12)
        }
        .onTapGesture {
            viewModel.showProfile()
        }
    }
}
```

### Layout Patterns

#### Stack-based Layouts

Consistent use of VStack, HStack, and ZStack with standard spacing:

```swift
VStack(alignment: .leading, spacing: Spacing.m) {
    Text("Title").headingStyle()
    Text("Subtitle").bodyStyle()
    // Content
}
.padding(Spacing.m)
```

#### List Layouts

Consistent list styling:

```swift
List {
    ForEach(items) { item in
        ItemRow(item: item)
    }
}
.listStyle(InsetGroupedListStyle())
```

#### Grid Layouts

Grid layouts using LazyVGrid and LazyHGrid:

```swift
let columns = [
    GridItem(.flexible()),
    GridItem(.flexible())
]

LazyVGrid(columns: columns, spacing: Spacing.m) {
    ForEach(items) { item in
        ItemCell(item: item)
    }
}
```

### Accessibility

Accessibility considerations include:

- Dynamic Type support
- VoiceOver compatibility
- Sufficient color contrast
- Keyboard navigation

Example implementation:

```swift
Text("Label")
    .font(.body)
    .foregroundColor(.primaryText)
    .accessibilityLabel("Descriptive label")
    .accessibilityHint("Tap to perform action")
```

## Error Handling

### Error Types

The mock application should handle the following error types in the UI:

- **Network Errors**: Connection issues, timeouts, server unavailable
- **Authentication Errors**: Invalid credentials, expired tokens
- **Data Errors**: Missing data, invalid format, parsing errors
- **Permission Errors**: Unauthorized access, insufficient privileges
- **Validation Errors**: Invalid input, form validation failures

### Error UI Components

Design error UI components for later implementation in production:

```swift
struct ErrorView: View {
    let title: String
    let message: String
    let retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.warning)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)

            if let retryAction = retryAction {
                Button("Try Again") {
                    retryAction()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.accent)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color.secondaryBackground)
        .cornerRadius(12)
        .padding()
    }
}
```

### Error State Simulation

Simulate error states with mock data:

```swift
struct ProfileViewWithError: View {
    @ObservedObject var viewModel: ProfileViewModel
    let errorType: ErrorType

    enum ErrorType {
        case networkError
        case dataNotFound
        case permissionDenied
    }

    var body: some View {
        VStack {
            switch errorType {
            case .networkError:
                ErrorView(
                    title: "Network Error",
                    message: "Could not connect to the server. Please check your internet connection and try again.",
                    retryAction: { viewModel.reload() }
                )
            case .dataNotFound:
                ErrorView(
                    title: "Profile Not Found",
                    message: "The requested profile could not be found.",
                    retryAction: nil
                )
            case .permissionDenied:
                ErrorView(
                    title: "Access Denied",
                    message: "You don't have permission to view this profile.",
                    retryAction: nil
                )
            }
        }
    }
}
```

### Error Handling Guidelines

* Error handling is not implemented in the mock application
* Views should display mock data without error states in normal operation
* Error UI should be designed but not connected to actual error handling
* Error states should be simulated with mock data for design review
* Error UI components should be designed for later implementation in production
* Create separate preview providers for error states

## Testing

### Unit Testing Strategy

The mock application should implement a comprehensive testing strategy:

1. **Component Testing**: Test individual views in isolation
2. **Layout Testing**: Verify responsive layouts across device sizes
3. **Accessibility Testing**: Ensure views meets accessibility standards
4. **Snapshot Testing**: Capture and verify view appearance

### Preview Providers

Create comprehensive preview providers for all views:

```swift
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Standard preview
            ProfileView(viewModel: MockProfileViewModel.standard)
                .previewDisplayName("Standard Profile")

            // Empty state preview
            ProfileView(viewModel: MockProfileViewModel.empty)
                .previewDisplayName("Empty Profile")

            // Loading state preview
            ProfileView(viewModel: MockProfileViewModel.loading)
                .previewDisplayName("Loading Profile")

            // Dark mode preview
            ProfileView(viewModel: MockProfileViewModel.standard)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")

            // Different device sizes
            ProfileView(viewModel: MockProfileViewModel.standard)
                .previewDevice("iPhone SE (3rd generation)")
                .previewDisplayName("iPhone SE")

            ProfileView(viewModel: MockProfileViewModel.standard)
                .previewDevice("iPhone 14 Pro Max")
                .previewDisplayName("iPhone 14 Pro Max")

            // Accessibility preview (larger text)
            ProfileView(viewModel: MockProfileViewModel.standard)
                .environment(\.sizeCategory, .accessibilityLarge)
                .previewDisplayName("Accessibility Large")
        }
    }
}
```

### Snapshot Testing

Implement snapshot tests for view verification:

```swift
import XCTest
import SnapshotTesting
import SwiftUI
@testable import MockApplication

class ProfileViewTests: XCTestCase {
    func testProfileViewStandard() {
        let view = ProfileView(viewModel: MockProfileViewModel.standard)
        let hostingController = UIHostingController(rootView: view)
        assertSnapshot(matching: hostingController, as: .image(on: .iPhone13))
    }

    func testProfileViewEmpty() {
        let view = ProfileView(viewModel: MockProfileViewModel.empty)
        let hostingController = UIHostingController(rootView: view)
        assertSnapshot(matching: hostingController, as: .image(on: .iPhone13))
    }

    func testProfileViewDarkMode() {
        let view = ProfileView(viewModel: MockProfileViewModel.standard)
        let hostingController = UIHostingController(rootView: view)
        hostingController.overrideUserInterfaceStyle = .dark
        assertSnapshot(matching: hostingController, as: .image(on: .iPhone13))
    }

    func testProfileViewAccessibility() {
        let view = ProfileView(viewModel: MockProfileViewModel.standard)
        let hostingController = UIHostingController(rootView: view)
        // Test with larger content size
        hostingController.preferredContentSizeCategory = .accessibilityLarge
        assertSnapshot(matching: hostingController, as: .image(on: .iPhone13))
    }
}
```

### Accessibility Testing

* Test VoiceOver compatibility with accessibility inspector
* Verify dynamic type support across size categories
* Test color contrast ratios meet accessibility standards
* Verify keyboard navigation works correctly
* Test with accessibility features enabled

### Responsive Layout Testing

* Test views on different device sizes (iPhone SE to iPad Pro)
* Verify layouts adapt correctly to orientation changes
* Test with different text size settings
* Verify views handle safe area insets correctly
* Test with split-screen multitasking on iPad

## Best Practices

* Use SwiftUI previews for rapid UI development
* Maintain consistent spacing and alignment
* Implement responsive layouts that adapt to different screen sizes
* Use semantic colors instead of hard-coded values
* Implement proper accessibility support
* Follow Apple's Human Interface Guidelines
* Ensure views only use data from their view models
* Avoid local state in views (@State, @StateObject, etc.)
* Avoid passing state between views
* Duplicate UI code rather than creating reusable components
* Break up complex views into computed properties for different sections
* Use consistent naming conventions for view components

## Anti-patterns

* Using reusable UI components (increases coupling)
* Using local state in views (@State, @StateObject)
* Passing state between views
* Mixing UI and business logic
* Ignoring accessibility
* Inconsistent naming conventions
* Deeply nested view hierarchies
* Fetching data directly in views instead of through view models
* Using environment objects for state management
* Implementing error handling in mock views
* Creating complex view hierarchies