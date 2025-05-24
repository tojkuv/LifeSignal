import Foundation
import SwiftUI
import UIKit
import ComposableArchitecture
import CoreImage.CIFilterBuiltins

struct QRCodeGeneratorClient {
    var generateQRCode: @Sendable (String, CGFloat) async throws -> UIImage = { _, _ in UIImage() }
    var generateShareableQRCode: @Sendable (UIImage?, String) async throws -> UIImage = { _, _ in UIImage() }
}

extension QRCodeGeneratorClient: DependencyKey {
    static let liveValue = QRCodeGeneratorClient(
        generateQRCode: { data, size in
            let context = CIContext()
            let filter = CIFilter.qrCodeGenerator()
            
            guard let qrData = data.data(using: .ascii) else {
                throw NSError(domain: "QRCodeGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode QR data"])
            }
            
            filter.setValue(qrData, forKey: "inputMessage")
            filter.setValue("M", forKey: "inputCorrectionLevel")
            
            guard let outputImage = filter.outputImage else {
                throw NSError(domain: "QRCodeGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to generate QR image"])
            }
            
            let scaleX = size / outputImage.extent.size.width
            let scaleY = size / outputImage.extent.size.height
            let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            
            guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
                throw NSError(domain: "QRCodeGenerator", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGImage"])
            }
            
            return UIImage(cgImage: cgImage)
        },
        
        generateShareableQRCode: { qrImage, userName in
            guard let qrImage = qrImage else {
                throw NSError(domain: "QRCodeGenerator", code: 4, userInfo: [NSLocalizedDescriptionKey: "QR image is nil"])
            }
            
            let size = CGSize(width: 400, height: 500)
            let renderer = UIGraphicsImageRenderer(size: size)
            
            return renderer.image { context in
                // Background
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                
                // Title
                let titleText = "LifeSignal QR Code"
                let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: titleFont,
                    .foregroundColor: UIColor.black
                ]
                let titleSize = titleText.size(withAttributes: titleAttributes)
                titleText.draw(at: CGPoint(x: (size.width - titleSize.width) / 2, y: 20), withAttributes: titleAttributes)
                
                // QR Code
                let qrSize: CGFloat = 300
                let qrX = (size.width - qrSize) / 2
                let qrY: CGFloat = 80
                qrImage.draw(in: CGRect(x: qrX, y: qrY, width: qrSize, height: qrSize))
                
                // User name
                let nameText = "\(userName)'s Emergency Contact Code"
                let nameFont = UIFont.systemFont(ofSize: 16, weight: .medium)
                let nameAttributes: [NSAttributedString.Key: Any] = [
                    .font: nameFont,
                    .foregroundColor: UIColor.darkGray
                ]
                let nameSize = nameText.size(withAttributes: nameAttributes)
                nameText.draw(at: CGPoint(x: (size.width - nameSize.width) / 2, y: qrY + qrSize + 20), withAttributes: nameAttributes)
                
                // Instructions
                let instructionText = "Scan to add as emergency contact"
                let instructionFont = UIFont.systemFont(ofSize: 14, weight: .regular)
                let instructionAttributes: [NSAttributedString.Key: Any] = [
                    .font: instructionFont,
                    .foregroundColor: UIColor.gray
                ]
                let instructionSize = instructionText.size(withAttributes: instructionAttributes)
                instructionText.draw(at: CGPoint(x: (size.width - instructionSize.width) / 2, y: qrY + qrSize + 50), withAttributes: instructionAttributes)
            }
        }
    )
    
    static let mockValue = QRCodeGeneratorClient(
        generateQRCode: { data, size in
            // Create a simple mock QR code image with the data as text
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
            return renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: CGSize(width: size, height: size)))
                
                // Draw a simple grid pattern to simulate QR code
                UIColor.black.setStroke()
                let gridSize: CGFloat = size / 20
                for i in 0..<20 {
                    for j in 0..<20 {
                        if (i + j) % 2 == 0 {
                            let rect = CGRect(x: CGFloat(i) * gridSize, y: CGFloat(j) * gridSize, width: gridSize, height: gridSize)
                            context.fill(rect)
                        }
                    }
                }
                
                // Add mock data text in center
                let font = UIFont.systemFont(ofSize: 8)
                let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.red]
                let text = "MOCK\nQR"
                text.draw(in: CGRect(x: size/2 - 20, y: size/2 - 10, width: 40, height: 20), withAttributes: attributes)
            }
        },
        generateShareableQRCode: { qrImage, userName in
            guard let qrImage = qrImage else {
                throw NSError(domain: "QRCodeGenerator", code: 4, userInfo: [NSLocalizedDescriptionKey: "QR image is nil"])
            }
            
            let size = CGSize(width: 400, height: 500)
            let renderer = UIGraphicsImageRenderer(size: size)
            
            return renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                
                let titleText = "MOCK - LifeSignal QR Code"
                let titleFont = UIFont.systemFont(ofSize: 20, weight: .bold)
                let titleAttributes: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: UIColor.red]
                let titleSize = titleText.size(withAttributes: titleAttributes)
                titleText.draw(at: CGPoint(x: (size.width - titleSize.width) / 2, y: 20), withAttributes: titleAttributes)
                
                let qrSize: CGFloat = 300
                let qrX = (size.width - qrSize) / 2
                let qrY: CGFloat = 80
                qrImage.draw(in: CGRect(x: qrX, y: qrY, width: qrSize, height: qrSize))
                
                let nameText = "\(userName)'s Emergency Contact Code (MOCK)"
                let nameFont = UIFont.systemFont(ofSize: 16, weight: .medium)
                let nameAttributes: [NSAttributedString.Key: Any] = [.font: nameFont, .foregroundColor: UIColor.darkGray]
                let nameSize = nameText.size(withAttributes: nameAttributes)
                nameText.draw(at: CGPoint(x: (size.width - nameSize.width) / 2, y: qrY + qrSize + 20), withAttributes: nameAttributes)
            }
        }
    )
    
    static let testValue = QRCodeGeneratorClient()
}


extension DependencyValues {
    var qrCodeGenerator: QRCodeGeneratorClient {
        get { self[QRCodeGeneratorClient.self] }
        set { self[QRCodeGeneratorClient.self] = newValue }
    }
}
