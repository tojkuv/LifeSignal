import SwiftUI
import Foundation
import UIKit
import AVFoundation
import PhotosUI

/// A UIViewControllerRepresentable for sharing content
struct ActivityShareSheet: UIViewControllerRepresentable {
    /// The items to share
    let items: [Any]

    /// Create the UIActivityViewController
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    /// Update the UIActivityViewController (not needed)
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}