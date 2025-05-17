import SwiftUI

// MARK: - Dismiss Keyboard Environment Value

/// Environment key for dismissing the keyboard
struct DismissKeyboardKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

/// Extension to add dismissKeyboard to EnvironmentValues
extension EnvironmentValues {
    /// A function to dismiss the keyboard
    var dismissKeyboard: () -> Void {
        get { self[DismissKeyboardKey.self] }
        set { self[DismissKeyboardKey.self] = newValue }
    }
}

/// Extension to add dismissKeyboard to View
extension View {
    /// Adds a function to dismiss the keyboard to the environment
    func dismissKeyboardOnTap() -> some View {
        return self.modifier(DismissKeyboardModifier())
    }
}

/// Modifier to dismiss the keyboard when tapping outside of a text field
struct DismissKeyboardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environment(\.dismissKeyboard, {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            })
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
    }
}
