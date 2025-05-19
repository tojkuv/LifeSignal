# TCA View Example: CheckInView

**Navigation:** [Back to Examples](README.md) | [Feature Example](FeatureExample.md) | [Client Example](ClientExample.md) | [Adapter Example](AdapterExample.md)

---

## Overview

This document provides a complete example of a SwiftUI view implementation using TCA for the CheckInView in the LifeSignal iOS application. The CheckInView is responsible for displaying the user's check-in status and providing controls for checking in and managing check-in intervals.

## View Structure

A TCA view consists of the following components:
- Store binding: Connects the view to the feature's state and actions
- View composition: Organizes the UI into a hierarchy of views
- User interaction: Handles user input and dispatches actions to the store

## Basic View Implementation

```swift
struct CheckInView: View {
    @Bindable var store: StoreOf<CheckInFeature>
    
    var body: some View {
        VStack(spacing: 24) {
            statusSection
            timeRemainingSection
            checkInButton
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .alert($store.scope(state: \.alert, action: \.alert))
        .sheet(
            item: $store.scope(state: \.intervalSelection, action: \.intervalSelection),
            content: IntervalSelectionView.init(store:)
        )
    }
    
    // View components...
}
```

## View Components

```swift
// Status section
private var statusSection: some View {
    VStack(alignment: .leading, spacing: 8) {
        Text("Check-In Status")
            .font(.headline)
        
        HStack {
            Image(systemName: store.isOverdue ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(store.isOverdue ? .red : .green)
            
            Text(store.isOverdue ? "Overdue" : "On Schedule")
                .font(.subheadline)
                .foregroundColor(store.isOverdue ? .red : .primary)
        }
        
        if let lastCheckInTime = store.lastCheckInTime {
            Text("Last check-in: \(lastCheckInTime, formatter: dateFormatter)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(Color(.secondarySystemGroupedBackground))
    .cornerRadius(12)
}

// Time remaining section
private var timeRemainingSection: some View {
    VStack(alignment: .leading, spacing: 8) {
        Text("Time Remaining")
            .font(.headline)
        
        HStack(alignment: .firstTextBaseline) {
            Text(timeString)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(store.isOverdue ? .red : .primary)
            
            Spacer()
            
            Button {
                store.send(.intervalSelectionButtonTapped)
            } label: {
                HStack {
                    Text("Change Interval")
                    Image(systemName: "clock.arrow.circlepath")
                }
                .font(.subheadline)
            }
            .buttonStyle(.bordered)
        }
        
        Text("Current interval: \(intervalString)")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(Color(.secondarySystemGroupedBackground))
    .cornerRadius(12)
}

// Check-in button
private var checkInButton: some View {
    Button {
        store.send(.checkInButtonTapped)
    } label: {
        HStack {
            if store.isCheckingIn {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .tint(.white)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
            }
            
            Text("Check In Now")
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(12)
    }
    .disabled(store.isCheckingIn)
    .sensoryFeedback(.success, trigger: store.lastCheckInTime)
}
```

## Computed Properties

```swift
// Formatted time string
private var timeString: String {
    let timeRemaining = store.timeRemaining
    
    if timeRemaining <= 0 {
        return "Overdue"
    }
    
    let hours = Int(timeRemaining) / 3600
    let minutes = (Int(timeRemaining) % 3600) / 60
    
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    } else {
        let seconds = Int(timeRemaining) % 60
        return "\(minutes)m \(seconds)s"
    }
}

// Formatted interval string
private var intervalString: String {
    let hours = Int(store.checkInInterval) / 3600
    
    if hours == 24 {
        return "1 day"
    } else if hours == 48 {
        return "2 days"
    } else {
        return "\(hours) hours"
    }
}

// Date formatter
private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()
```

## Child View: IntervalSelectionView

```swift
struct IntervalSelectionView: View {
    @Bindable var store: StoreOf<IntervalSelectionFeature>
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(store.availableIntervals, id: \.self) { interval in
                    Button {
                        store.send(.intervalSelected(interval))
                    } label: {
                        HStack {
                            Text(formatInterval(interval))
                            
                            Spacer()
                            
                            if interval == store.currentInterval {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Check-In Interval")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.send(.cancelButtonTapped)
                    }
                }
            }
        }
    }
    
    private func formatInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        
        if hours == 24 {
            return "1 day"
        } else if hours == 48 {
            return "2 days"
        } else {
            return "\(hours) hours"
        }
    }
}
```

## Parent View Integration

```swift
struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                CheckInView(
                    store: store.scope(
                        state: \.checkIn,
                        action: \.checkIn
                    )
                )
                
                AlertView(
                    store: store.scope(
                        state: \.alert,
                        action: \.alert
                    )
                )
                
                // Other view components...
            }
            .padding()
        }
        .navigationTitle("Home")
    }
}
```

## Testing the View

```swift
@MainActor
final class CheckInViewTests: XCTestCase {
    func testCheckInView() {
        let store = Store(initialState: CheckInFeature.State()) {
            CheckInFeature()
        } withDependencies: {
            $0.checkInClient = .mock
            $0.date = .constant(Date(timeIntervalSince1970: 0))
        }
        
        let view = CheckInView(store: store)
        
        // Use ViewInspector or other testing tools to verify view structure
        // and behavior
    }
}

extension CheckInClient {
    static let mock = Self(
        checkIn: { Date(timeIntervalSince1970: 0) }
    )
}
```

## Preview

```swift
#Preview {
    NavigationStack {
        CheckInView(
            store: Store(initialState: CheckInFeature.State(
                lastCheckInTime: Date().addingTimeInterval(-43200), // 12 hours ago
                nextCheckInTime: Date().addingTimeInterval(43200),  // 12 hours from now
                checkInInterval: 86400                              // 24 hours
            )) {
                CheckInFeature()
            } withDependencies: {
                $0.checkInClient = .mock
            }
        )
    }
}
```

## Best Practices

1. **View Organization**
   - Break down complex views into smaller components
   - Use private computed properties for view components
   - Keep the main `body` property clean and readable

2. **Store Binding**
   - Use `@Bindable` for the store property
   - Use `$store.scope` for binding to child features
   - Use `store.send` to dispatch actions

3. **User Interaction**
   - Use SwiftUI's built-in controls for user interaction
   - Dispatch actions in response to user input
   - Provide visual feedback for user actions

4. **Accessibility**
   - Use semantic colors and fonts
   - Provide appropriate accessibility labels
   - Support dynamic type

5. **Testing**
   - Test view structure and behavior
   - Use mock dependencies
   - Test different state configurations

## Conclusion

This example demonstrates a complete implementation of a SwiftUI view using TCA for the CheckInView in the LifeSignal iOS application. It shows how to bind to a store, organize the view into components, handle user interaction, and test the view.

When implementing a new view, use this example as a reference to ensure consistency and adherence to the established architectural patterns.
