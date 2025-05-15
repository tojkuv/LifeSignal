import Foundation
import SwiftUI
import UIKit

/// View model for QR code generation functionality
class QRCodeViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The string to encode in the QR code
    @Published var qrCodeId: String = ""

    /// The size of the QR code
    @Published var size: CGFloat = 200

    /// Whether to use branded styling
    @Published var branded: Bool = true

    /// The foreground color (only used when branded is false)
    @Published var foregroundColor: UIColor = .black

    /// The background color (only used when branded is false)
    @Published var backgroundColor: UIColor = .white

    /// The generated QR code image
    @Published var qrCodeImage: UIImage?

    // MARK: - Initialization

    /// Initialize with default values
    init(qrCodeId: String = "", size: CGFloat = 200, branded: Bool = true) {
        self.qrCodeId = qrCodeId
        self.size = size
        self.branded = branded
        generateQRCodeImage()
    }

    // MARK: - Methods

    /// Generate the QR code image
    func generateQRCodeImage() {
        if branded {
            qrCodeImage = Self.generateBrandedQRCode(from: qrCodeId, size: size)
        } else {
            qrCodeImage = Self.generateQRCode(
                from: qrCodeId,
                size: size,
                backgroundColor: backgroundColor,
                foregroundColor: foregroundColor
            )
        }
    }

    /// Update the QR code ID
    /// - Parameter qrCodeId: The new QR code ID
    func updateQRCodeId(_ qrCodeId: String) {
        self.qrCodeId = qrCodeId
        generateQRCodeImage()
    }

    /// Update the size
    /// - Parameter size: The new size
    func updateSize(_ size: CGFloat) {
        self.size = size
        generateQRCodeImage()
    }

    /// Update whether to use branded styling
    /// - Parameter branded: Whether to use branded styling
    func updateBranded(_ branded: Bool) {
        self.branded = branded
        generateQRCodeImage()
    }

    /// Update the foreground color
    /// - Parameter foregroundColor: The new foreground color
    func updateForegroundColor(_ foregroundColor: UIColor) {
        self.foregroundColor = foregroundColor
        if !branded {
            generateQRCodeImage()
        }
    }

    /// Update the background color
    /// - Parameter backgroundColor: The new background color
    func updateBackgroundColor(_ backgroundColor: UIColor) {
        self.backgroundColor = backgroundColor
        if !branded {
            generateQRCodeImage()
        }
    }

    // MARK: - Static Utility Methods

    /// Generate a QR code image
    /// - Parameters:
    ///   - from: String to encode in the QR code
    ///   - size: Size of the QR code
    ///   - backgroundColor: Background color of the QR code
    ///   - foregroundColor: Foreground color of the QR code
    /// - Returns: QR code image
    static func generateQRCode(
        from string: String,
        size: CGFloat = 200,
        backgroundColor: UIColor = .white,
        foregroundColor: UIColor = .black
    ) -> UIImage? {
        // Create a QR code generator
        guard let data = string.data(using: .utf8),
              let qrFilter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }

        qrFilter.setValue(data, forKey: "inputMessage")
        qrFilter.setValue("M", forKey: "inputCorrectionLevel")

        // Create a color filter
        guard let qrImage = qrFilter.outputImage,
              let colorFilter = CIFilter(name: "CIFalseColor") else {
            return nil
        }

        colorFilter.setValue(qrImage, forKey: "inputImage")
        colorFilter.setValue(CIColor(color: foregroundColor), forKey: "inputColor0")
        colorFilter.setValue(CIColor(color: backgroundColor), forKey: "inputColor1")

        // Create a transform to scale the QR code
        guard let outputImage = colorFilter.outputImage else {
            return nil
        }

        let scale = size / outputImage.extent.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        // Convert to UIImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    /// Generate a QR code image with the app's branding
    /// - Parameters:
    ///   - from: String to encode in the QR code
    ///   - size: Size of the QR code
    /// - Returns: QR code image
    static func generateBrandedQRCode(from string: String, size: CGFloat = 200) -> UIImage? {
        // Generate a basic QR code
        guard let qrCode = generateQRCode(from: string, size: size) else {
            return nil
        }

        // In a real app, we would add branding to the QR code
        // For the mock app, we'll just return the basic QR code with a blue tint

        // Create a blue-tinted QR code
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let brandedQRCode = renderer.image { context in
            // Draw a blue background
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))

            // Draw the QR code
            qrCode.draw(in: CGRect(x: 0, y: 0, width: size, height: size))

            // Add a blue overlay with transparency
            context.cgContext.setFillColor(UIColor.blue.withAlphaComponent(0.1).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))

            // Add a logo in the center (simulated with a blue circle)
            let logoSize = size * 0.2
            let logoRect = CGRect(
                x: (size - logoSize) / 2,
                y: (size - logoSize) / 2,
                width: logoSize,
                height: logoSize
            )
            context.cgContext.setFillColor(UIColor.blue.cgColor)
            context.cgContext.fillEllipse(in: logoRect)
        }

        return brandedQRCode
    }

    /// Scan a QR code from an image
    /// - Parameter image: Image to scan
    /// - Returns: QR code content
    static func scanQRCode(from image: UIImage) -> String? {
        // In a real app, we would scan the image for a QR code
        // For the mock app, we'll just return a mock QR code
        return "mock-qr-code-\(Int.random(in: 1000...9999))"
    }

    /// Generate a QR code image from a SwiftUI view
    /// - Parameters:
    ///   - content: SwiftUI view to render
    ///   - completion: Completion handler with the rendered image
    static func generateQRCodeImage(content: AnyView, completion: @escaping (UIImage?) -> Void) {
        // Create a UIHostingController to render the SwiftUI view
        let hostingController = UIHostingController(rootView: content)

        // Set the size of the hosting controller's view
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 1024, height: 1024)

        // Ensure the view has been laid out
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()

        // Render the view to an image
        let renderer = UIGraphicsImageRenderer(size: hostingController.view.bounds.size)
        let image = renderer.image { context in
            hostingController.view.drawHierarchy(in: hostingController.view.bounds, afterScreenUpdates: true)
        }

        // Call the completion handler with the generated image
        completion(image)
    }
}
