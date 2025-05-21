import SwiftUI
import UIKit

/// Utility functions for haptic feedback
struct HapticFeedback {
    /// Trigger a standard haptic feedback (medium impact)
    static func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Trigger a light impact haptic feedback
    static func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Trigger a heavy impact haptic feedback
    static func heavyImpact() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    /// Trigger a selection haptic feedback
    static func selectionFeedback() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    /// Trigger a notification haptic feedback
    static func notificationFeedback(type: UINotificationFeedbackGenerator.FeedbackType = .success) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}

// Global function for backward compatibility - renamed to avoid conflicts
func mockTriggerHaptic() {
    HapticFeedback.triggerHaptic()
}
