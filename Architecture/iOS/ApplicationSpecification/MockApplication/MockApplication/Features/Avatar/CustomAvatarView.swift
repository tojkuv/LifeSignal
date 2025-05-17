import SwiftUI
import UIKit

/// A reusable avatar view that displays either a custom image or the first letter of a name
struct CustomAvatarView: View {
    /// The name to display the first letter of (when no image is available)
    let name: String
    
    /// The custom image to display (if available)
    let image: UIImage?
    
    /// The size of the avatar
    let size: CGFloat
    
    /// The color of the text (for default avatar)
    let color: Color
    
    /// The width of the stroke around the avatar
    let strokeWidth: CGFloat
    
    /// The color of the stroke
    let strokeColor: Color
    
    /// Initialize a new avatar view
    /// - Parameters:
    ///   - name: The name to display the first letter of
    ///   - image: The custom image to display (if available)
    ///   - size: The size of the avatar (default: 40)
    ///   - color: The color of the text (default: .blue)
    ///   - strokeWidth: The width of the stroke around the avatar (default: 0)
    ///   - strokeColor: The color of the stroke (default: same as text color)
    init(
        name: String,
        image: UIImage? = nil,
        size: CGFloat = 40,
        color: Color = .blue,
        strokeWidth: CGFloat = 0,
        strokeColor: Color? = nil
    ) {
        self.name = name
        self.image = image
        self.size = size
        self.color = color
        self.strokeWidth = strokeWidth
        self.strokeColor = strokeColor ?? color
    }
    
    var body: some View {
        if let image = image {
            // Display the custom image
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .if(strokeWidth > 0) { view in
                    view.overlay(
                        Circle()
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    )
                }
        } else {
            // Display the default avatar with first letter
            Circle()
                .fill(Color(UIColor.systemBackground))
                .frame(width: size, height: size)
                .overlay(
                    Text(String(name.prefix(1).uppercased()))
                        .foregroundColor(color)
                        .font(size > 60 ? .title : .headline)
                )
                .if(strokeWidth > 0) { view in
                    view.overlay(
                        Circle()
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    )
                }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 20) {
        CustomAvatarView(name: "John Doe")
        
        CustomAvatarView(
            name: "Jane Smith",
            image: UIImage(systemName: "person.fill")?.withTintColor(.red, renderingMode: .alwaysOriginal),
            size: 60,
            strokeWidth: 2,
            strokeColor: .blue
        )
        
        CustomAvatarView(
            name: "Alex Johnson",
            size: 80,
            color: .green,
            strokeWidth: 3
        )
    }
    .padding()
}
