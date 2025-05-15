import Foundation
import UIKit

/// Types of images that can be shared from the home screen
enum HomeShareImage {
    /// QR code image
    case qrCode(UIImage)
    
    /// Check-in status image
    case checkInStatus(UIImage)
    
    /// Get the image to share
    var image: UIImage {
        switch self {
        case .qrCode(let image), .checkInStatus(let image):
            return image
        }
    }
}
