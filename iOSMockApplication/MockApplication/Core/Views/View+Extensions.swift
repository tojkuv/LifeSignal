import SwiftUI

/// Extensions for SwiftUI View
extension View {
    /// Apply a transformation only if a condition is true
    /// - Parameters:
    ///   - condition: The condition to check
    ///   - transform: The transformation to apply
    /// - Returns: The transformed view if the condition is true, otherwise the original view
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Apply a transformation only if a value is not nil
    /// - Parameters:
    ///   - value: The optional value to check
    ///   - transform: The transformation to apply if the value is not nil
    /// - Returns: The transformed view if the value is not nil, otherwise the original view
    @ViewBuilder func ifLet<T, Content: View>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }

    /// Add haptic feedback to a button or other interactive element
    /// - Parameters:
    ///   - style: The haptic feedback style to use (default: .medium)
    /// - Returns: A view with haptic feedback added
    func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        self.simultaneousGesture(TapGesture().onEnded { _ in
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.impactOccurred()
        })
    }

    /// Add selection haptic feedback to a button or other interactive element
    /// - Returns: A view with selection haptic feedback added
    func selectionHapticFeedback() -> some View {
        self.simultaneousGesture(TapGesture().onEnded { _ in
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        })
    }

    /// Add notification haptic feedback to a button or other interactive element
    /// - Parameters:
    ///   - type: The notification feedback type to use (default: .success)
    /// - Returns: A view with notification haptic feedback added
    func notificationHapticFeedback(type: UINotificationFeedbackGenerator.FeedbackType = .success) -> some View {
        self.simultaneousGesture(TapGesture().onEnded { _ in
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(type)
        })
    }
}

/// Extensions for Array
extension Array {
    /// Safe subscript that returns nil if the index is out of bounds
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
