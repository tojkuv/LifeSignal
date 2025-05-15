import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Create the activity view controller with the items to share

        // Filter items to ensure images are shared as UIImage only
        let filteredItems = items.map { item -> Any in
            if let image = item as? UIImage {
                // Ensure we're sharing the image directly, not as data or other format
                return image
            }
            return item
        }

        let controller = UIActivityViewController(activityItems: filteredItems, applicationActivities: nil)

        // Exclude some activity types that might not be relevant
        controller.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList
        ]

        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Nothing to update
    }
}
