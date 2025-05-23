import SwiftUI
import UIKit

/// A unified avatar view component for use throughout the app
struct CommonAvatarView: View {
    // MARK: - Properties
    
    /// The name to display the first letter of (when no image is available)
    let name: String
    
    /// The custom image to display (if available)
    let image: UIImage?
    
    /// The size of the avatar
    let size: CGFloat
    
    /// The background color of the avatar (for default avatar)
    let backgroundColor: Color
    
    /// The color of the text (for default avatar)
    let textColor: Color
    
    /// The width of the stroke around the avatar
    let strokeWidth: CGFloat
    
    /// The color of the stroke
    let strokeColor: Color
    
    // MARK: - Initialization
    
    /// Initialize a new avatar view with default styling
    /// - Parameters:
    ///   - name: The name to display the first letter of
    ///   - image: The custom image to display (if available)
    ///   - size: The size of the avatar (default: 40)
    ///   - backgroundColor: The background color (default: blue opacity 0.1)
    ///   - textColor: The color of the text (default: blue)
    ///   - strokeWidth: The width of the stroke around the avatar (default: 0)
    ///   - strokeColor: The color of the stroke (default: blue)
    init(
        name: String,
        image: UIImage? = nil,
        size: CGFloat = 40,
        backgroundColor: Color = Color.blue.opacity(0.1),
        textColor: Color = .blue,
        strokeWidth: CGFloat = 0,
        strokeColor: Color = .blue
    ) {
        self.name = name
        self.image = image
        self.size = size
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.strokeWidth = strokeWidth
        self.strokeColor = strokeColor
    }
    
    // MARK: - Body
    
    var body: some View {
        if let image = image {
            // Display the custom image
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(strokeColor, lineWidth: strokeWidth)
                        .opacity(strokeWidth > 0 ? 1 : 0)
                )
        } else {
            // Display the default avatar with first letter
            Circle()
                .fill(backgroundColor)
                .frame(width: size, height: size)
                .overlay(
                    Text(String(name.prefix(1).uppercased()))
                        .foregroundColor(textColor)
                        .font(size > 60 ? .title : .headline)
                        .fontWeight(.semibold)
                )
                .overlay(
                    Circle()
                        .stroke(strokeColor, lineWidth: strokeWidth)
                        .opacity(strokeWidth > 0 ? 1 : 0)
                )
        }
    }
}

// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 20) {
        // Default avatar
        CommonAvatarView(name: "John Doe")
        
        // Custom size
        CommonAvatarView(
            name: "Jane Smith",
            size: 60
        )
        
        // With stroke
        CommonAvatarView(
            name: "Alex Johnson",
            size: 80,
            strokeWidth: 2
        )
        
        // Custom colors
        CommonAvatarView(
            name: "Maria Garcia",
            size: 60,
            backgroundColor: Color.green.opacity(0.1),
            textColor: .green,
            strokeWidth: 2,
            strokeColor: .green
        )
        
        // With image
        if let image = UIImage(systemName: "person.fill") {
            CommonAvatarView(
                name: "Robert Taylor",
                image: image,
                size: 60,
                strokeWidth: 2
            )
        }
    }
    .padding()
}
