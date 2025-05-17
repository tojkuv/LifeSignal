import SwiftUI
import Foundation

/// Enum representing different variations of the check-in tab
enum CheckInVariation: String, CaseIterable, Identifiable {
    /// The default variation (current implementation)
    case standard
    
    /// A compact variation with a circular progress indicator
    case compact
    
    /// A detailed variation with more information
    case detailed
    
    /// A minimal variation with simplified UI
    case minimal
    
    /// The identifier for the variation
    var id: String { rawValue }
    
    /// The display name for the variation
    var displayName: String {
        switch self {
        case .standard:
            return "Standard"
        case .compact:
            return "Compact"
        case .detailed:
            return "Detailed"
        case .minimal:
            return "Minimal"
        }
    }
    
    /// The icon for the variation
    var icon: String {
        switch self {
        case .standard:
            return "square.stack"
        case .compact:
            return "circle.grid.1x1"
        case .detailed:
            return "list.bullet.rectangle"
        case .minimal:
            return "rectangle.on.rectangle.angled"
        }
    }
    
    /// The accent color for the variation
    var accentColor: Color {
        switch self {
        case .standard:
            return .blue
        case .compact:
            return .green
        case .detailed:
            return .purple
        case .minimal:
            return .orange
        }
    }
    
    /// The alert button color for the variation
    var alertButtonColor: Color {
        switch self {
        case .standard, .compact:
            return .red
        case .detailed:
            return .pink
        case .minimal:
            return .red.opacity(0.8)
        }
    }
}
