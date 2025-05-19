# Non-UI Code Refactoring

This document summarizes the changes made to move non-UI code from views to view models and utility classes.

## 1. Created TimeFormattingUtility

Created a new utility class for formatting time and dates:

```swift
struct TimeFormattingUtility {
    static func formatTimeInterval(_ timeInterval: TimeInterval) -> String
    static func formatDate(_ date: Date) -> String
    static func formatHourInterval(_ hours: Int) -> String
    static func formatTimeAgo(_ date: Date) -> String
}
```

This centralizes all time formatting logic that was previously duplicated across multiple views.

## 2. Updated HomeViewModel

Enhanced the HomeViewModel to include QR code generation and sharing logic that was previously in the HomeView:

```swift
class HomeViewModel: ObservableObject {
    // Properties...
    
    func generateQRCodeImage(completion: @escaping () -> Void = {})
    func shareQRCode()
    func showQRCodeSheet()
    func formatInterval(_ interval: TimeInterval) -> String
}
```

## 3. Updated DependentsViewModel

Enhanced the DependentsViewModel to include sorting logic that was previously in the DependentsView:

```swift
class DependentsViewModel: ObservableObject {
    // Properties...
    
    enum SortMode: String, CaseIterable, Identifiable {
        case countdown = "Time Left"
        case recentlyAdded = "Recently Added"
        case alphabetical = "Alphabetical"
    }
    
    func getSortedDependents() -> [Contact]
    private func sortDependents(_ dependents: [Contact]) -> [Contact]
}
```

## 4. Updated CheckInView

Removed formatting and calculation functions from CheckInView and updated it to use the CheckInViewModel's methods:

```swift
// Removed from CheckInView:
private func calculateProgress() -> CGFloat
private func formatInterval(_ hours: Int) -> String
private func formatDate(_ date: Date) -> String
```

## 5. Connected View Models to Views

Added onAppear handlers to sync view models with the UserViewModel:

```swift
.onAppear {
    // Sync view model with user view model
    viewModel.setUserViewModel(userViewModel)
}
```

## Benefits of These Changes

1. **Improved Separation of Concerns**: UI code is now focused on presentation, while business logic is in view models
2. **Reduced Duplication**: Common formatting logic is now centralized in utility classes
3. **Better Testability**: View models can be tested independently of views
4. **Easier TCA Migration**: The code structure now more closely aligns with TCA patterns
5. **Improved Maintainability**: Changes to business logic can be made without affecting UI code

## Future Improvements

1. **Create More Utility Classes**: Move other common functionality to utility classes
2. **Standardize View Model Initialization**: Ensure all views initialize their view models consistently
3. **Add Unit Tests**: Add tests for view models and utility classes
4. **Complete TCA Migration**: Follow the TCA migration guide to convert view models to TCA features
