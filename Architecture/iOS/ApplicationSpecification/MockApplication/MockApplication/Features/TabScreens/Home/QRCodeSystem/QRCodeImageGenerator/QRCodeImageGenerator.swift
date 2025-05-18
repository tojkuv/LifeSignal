import Foundation
import SwiftUI
import UIKit

/// Helper for QR code image generation functionality
enum QRCodeImageGenerator {
    // MARK: - QR Code Generation

    /// Generate a QR code image
    /// - Parameters:
    ///   - from: String to encode in the QR code (or a mock UUID if not provided)
    ///   - size: Size of the QR code
    /// - Returns: QR code image
    static func generateQRCode(
        from string: String = UUID().uuidString,
        size: CGFloat = 200
    ) -> UIImage? {
        // For mock implementation, we can simplify this by using a cached image for better performance
        // In a real app, we would generate a real QR code

        // Create a QR code generator
        guard let data = string.data(using: .utf8),
              let qrFilter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }

        qrFilter.setValue(data, forKey: "inputMessage")
        qrFilter.setValue("M", forKey: "inputCorrectionLevel")

        // Get the output image
        guard let qrImage = qrFilter.outputImage else {
            return nil
        }

        // Scale the image
        let scale = size / qrImage.extent.width
        let scaledImage = qrImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        // Convert to UIImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
