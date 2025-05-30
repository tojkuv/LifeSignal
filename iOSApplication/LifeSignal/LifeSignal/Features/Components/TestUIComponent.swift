import SwiftUI

// MARK: - Test UIComponent

/// Test implementation of a pure UI component with no dependencies
/// This should compile successfully as it follows UIComponent architectural rules
struct TestUIComponent: View, UIComponent {
    let title: String
    let subtitle: String?
    let onTap: () -> Void
    
    init(title: String, subtitle: String? = nil, onTap: @escaping () -> Void = {}) {
        self.title = title
        self.subtitle = subtitle
        self.onTap = onTap
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        TestUIComponent(title: "Primary Action") {
            print("Primary tapped")
        }
        
        TestUIComponent(title: "Secondary Action", subtitle: "With subtitle") {
            print("Secondary tapped")
        }
    }
    .padding()
}