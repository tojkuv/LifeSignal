import DependenciesMacros
import Foundation
import SwiftUI
import UIKit
import ComposableArchitecture

/// QR Code Generator Client for dependency injection
@DependencyClient
struct QRCodeGeneratorClient {
    var generateQRCode: @Sendable (String, CGFloat) async throws -> UIImage = { _, _ in throw AppError.qrCode(.generationFailed) }
    var generateShareableQRCode: @Sendable (UIImage?, String) async throws -> UIImage = { _, _ in throw AppError.qrCode(.generationFailed) }
}

extension QRCodeGeneratorClient: DependencyKey {
    static let liveValue = QRCodeGeneratorClient(
        generateQRCode: { string, size in
            try await MainActor.run {
                // Create a QR code generator
                guard let data = string.data(using: .utf8),
                      let qrFilter = CIFilter(name: "CIQRCodeGenerator") else {
                    throw AppError.qrCode(.generationFailed)
                }

                qrFilter.setValue(data, forKey: "inputMessage")
                qrFilter.setValue("M", forKey: "inputCorrectionLevel")

                // Get the output image
                guard let qrImage = qrFilter.outputImage else {
                    throw AppError.qrCode(.generationFailed)
                }

                // Scale the image
                let scale = size / qrImage.extent.width
                let scaledImage = qrImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

                // Convert to UIImage
                let context = CIContext()
                guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
                    throw AppError.qrCode(.generationFailed)
                }

                return UIImage(cgImage: cgImage)
            }
        },
        generateShareableQRCode: { qrImage, userName in
            try await MainActor.run {
                guard let qrImage = qrImage else {
                    throw AppError.qrCode(.generationFailed)
                }
                
                let size = CGSize(width: 400, height: 500)
                let renderer = UIGraphicsImageRenderer(size: size)

                return renderer.image { context in
                    // Background
                    UIColor.white.setFill()
                    context.fill(CGRect(origin: .zero, size: size))

                    // Title
                    let titleText = "\(userName)'s Emergency Contact QR Code"
                    let titleAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: 18),
                        .foregroundColor: UIColor.black
                    ]
                    let titleSize = titleText.size(withAttributes: titleAttributes)
                    let titleRect = CGRect(
                        x: (size.width - titleSize.width) / 2,
                        y: 20,
                        width: titleSize.width,
                        height: titleSize.height
                    )
                    titleText.draw(in: titleRect, withAttributes: titleAttributes)

                    // QR Code - now guaranteed to exist
                    let qrSize: CGFloat = 300
                    let qrRect = CGRect(
                        x: (size.width - qrSize) / 2,
                        y: titleRect.maxY + 20,
                        width: qrSize,
                        height: qrSize
                    )
                    qrImage.draw(in: qrRect)

                    // Instructions
                    let instructionText = "Scan to add \(userName) as an emergency contact"
                    let instructionAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 14),
                        .foregroundColor: UIColor.gray
                    ]
                    let instructionSize = instructionText.size(withAttributes: instructionAttributes)
                    let instructionRect = CGRect(
                        x: (size.width - instructionSize.width) / 2,
                        y: qrRect.maxY + 20,
                        width: instructionSize.width,
                        height: instructionSize.height
                    )
                    instructionText.draw(in: instructionRect, withAttributes: instructionAttributes)
                }
            }
        }
    )

    static let testValue = QRCodeGeneratorClient(
        generateQRCode: { _, _ in UIImage() },
        generateShareableQRCode: { _, _ in UIImage() }
    )
}


extension DependencyValues {
    var qrCodeGenerator: QRCodeGeneratorClient {
        get { self[QRCodeGeneratorClient.self] }
        set { self[QRCodeGeneratorClient.self] = newValue }
    }
}
